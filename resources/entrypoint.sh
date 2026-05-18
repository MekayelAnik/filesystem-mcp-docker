#!/usr/bin/env bash
set -euo pipefail

readonly DEFAULT_PUID=1000
readonly DEFAULT_PGID=1000
readonly DEFAULT_PORT=8015
readonly DEFAULT_INTERNAL_PORT=38011
readonly DEFAULT_PROTOCOL="SHTTP"
readonly DEFAULT_TLS_DAYS=365
readonly DEFAULT_TLS_CN="localhost"
readonly DEFAULT_TLS_MIN_VERSION="TLSv1.3"
readonly DEFAULT_HTTP_VERSION_MODE="auto"
readonly SAFE_API_KEY_REGEX='^[[:graph:]]+$'
readonly MIN_API_KEY_LEN=5
readonly MAX_API_KEY_LEN=256
readonly FIRST_RUN_FILE="/tmp/first_run_complete"
readonly HAPROXY_SERVER_NAME="filesystem"
readonly HAPROXY_TEMPLATE="/etc/haproxy/haproxy.cfg.template"
readonly HAPROXY_CONFIG="/tmp/haproxy.cfg"

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

is_positive_int() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

is_true() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

validate_port() {
    local name="$1"
    local value="$2"
    local fallback="$3"

    if ! is_positive_int "$value" || [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
        echo "Invalid ${name}='${value}', using default ${fallback}" >&2
        printf '%s' "$fallback"
        return
    fi

    printf '%s' "$value"
}

validate_tls_days() {
    local value="$1"
    local fallback="$2"

    if ! is_positive_int "$value"; then
        echo "Invalid TLS_DAYS='${value}', using default ${fallback}" >&2
        printf '%s' "$fallback"
        return
    fi

    printf '%s' "$value"
}

validate_tls_min_version() {
    local value="$1"
    local fallback="$2"

    case "$value" in
        TLSv1.2|TLSv1.3)
            printf '%s' "$value"
            ;;
        *)
            echo "Invalid TLS_MIN_VERSION='${value}', using default ${fallback}" >&2
            printf '%s' "$fallback"
            ;;
    esac
}

normalize_http_version_mode() {
    local raw="$1"
    local mode

    mode="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    mode="$(trim "$mode")"

    case "$mode" in
        auto|all|h1|h2|h3|h1+h2)
            printf '%s' "$mode"
            ;;
        http/1.1|http1|http1.1)
            printf 'h1'
            ;;
        http/2|http2)
            printf 'h2'
            ;;
        http/3|http3)
            printf 'h3'
            ;;
        *)
            echo "Invalid HTTP_VERSION_MODE='${raw}', using default ${DEFAULT_HTTP_VERSION_MODE}" >&2
            printf '%s' "$DEFAULT_HTTP_VERSION_MODE"
            ;;
    esac
}

validate_api_key() {
    API_KEY="${API_KEY:-}"
    API_KEY="$(trim "$API_KEY")"
    local api_key_len=0

    if [[ -z "$API_KEY" ]]; then
        export API_KEY=""
        return
    fi

    api_key_len="${#API_KEY}"
    if (( api_key_len < MIN_API_KEY_LEN || api_key_len > MAX_API_KEY_LEN )); then
        echo "Invalid API_KEY length (${api_key_len}). Expected ${MIN_API_KEY_LEN}-${MAX_API_KEY_LEN} characters." >&2
        exit 1
    fi

    if [[ ! "$API_KEY" =~ $SAFE_API_KEY_REGEX ]]; then
        echo "Invalid API_KEY format. Refusing to start with malformed API key (whitespace/control chars are not allowed)." >&2
        exit 1
    fi

    export API_KEY
}

validate_rate_limit() {
    RATE_LIMIT="${RATE_LIMIT:-0}"
    RATE_LIMIT="$(trim "$RATE_LIMIT")"
    RATE_LIMIT_PERIOD="${RATE_LIMIT_PERIOD:-10s}"
    RATE_LIMIT_PERIOD="$(trim "$RATE_LIMIT_PERIOD")"
    MAX_CONNECTIONS_PER_IP="${MAX_CONNECTIONS_PER_IP:-0}"
    MAX_CONNECTIONS_PER_IP="$(trim "$MAX_CONNECTIONS_PER_IP")"

    if [[ "$RATE_LIMIT" != "0" ]]; then
        if ! [[ "$RATE_LIMIT" =~ ^[1-9][0-9]*$ ]]; then
            echo "Invalid RATE_LIMIT='${RATE_LIMIT}'. Must be a positive integer or 0 to disable." >&2
            exit 1
        fi
        if ! [[ "$RATE_LIMIT_PERIOD" =~ ^[1-9][0-9]*(s|m|h|d)$ ]]; then
            echo "Invalid RATE_LIMIT_PERIOD='${RATE_LIMIT_PERIOD}'. Must be a duration like 10s, 1m, 1h." >&2
            exit 1
        fi
    fi

    if [[ "$MAX_CONNECTIONS_PER_IP" != "0" ]]; then
        if ! [[ "$MAX_CONNECTIONS_PER_IP" =~ ^[1-9][0-9]*$ ]]; then
            echo "Invalid MAX_CONNECTIONS_PER_IP='${MAX_CONNECTIONS_PER_IP}'. Must be a positive integer or 0 to disable." >&2
            exit 1
        fi
    fi

    export RATE_LIMIT RATE_LIMIT_PERIOD MAX_CONNECTIONS_PER_IP
}

validate_ip_access() {
    IP_ALLOWLIST="${IP_ALLOWLIST:-}"
    IP_BLOCKLIST="${IP_BLOCKLIST:-}"
    IP_ALLOWLIST="$(trim "$IP_ALLOWLIST")"
    IP_BLOCKLIST="$(trim "$IP_BLOCKLIST")"

    local ip_cidr_regex='^[0-9a-fA-F.:]+(/[0-9]+)?$'

    if [[ -n "$IP_BLOCKLIST" ]]; then
        : > /tmp/haproxy_blocklist.txt
        IFS=',' read -ra BLOCK_IPS <<< "$IP_BLOCKLIST"
        for ip in "${BLOCK_IPS[@]}"; do
            ip="$(trim "$ip")"
            [[ -z "$ip" ]] && continue
            if [[ "$ip" =~ $ip_cidr_regex ]]; then
                echo "$ip" >> /tmp/haproxy_blocklist.txt
            else
                echo "Warning: Invalid IP_BLOCKLIST entry '${ip}' — skipping" >&2
            fi
        done
        echo "IP blocklist loaded: $(wc -l < /tmp/haproxy_blocklist.txt) entries"
    fi

    if [[ -n "$IP_ALLOWLIST" ]]; then
        : > /tmp/haproxy_allowlist.txt
        IFS=',' read -ra ALLOW_IPS <<< "$IP_ALLOWLIST"
        for ip in "${ALLOW_IPS[@]}"; do
            ip="$(trim "$ip")"
            [[ -z "$ip" ]] && continue
            if [[ "$ip" =~ $ip_cidr_regex ]]; then
                echo "$ip" >> /tmp/haproxy_allowlist.txt
            else
                echo "Warning: Invalid IP_ALLOWLIST entry '${ip}' — skipping" >&2
            fi
        done
        echo "IP allowlist loaded: $(wc -l < /tmp/haproxy_allowlist.txt) entries"
    fi

    export IP_ALLOWLIST IP_BLOCKLIST
}

validate_fs_allowed_dirs() {
    FS_ALLOWED_DIRS="${FS_ALLOWED_DIRS:-}"
    FS_ALLOWED_DIRS="$(trim "$FS_ALLOWED_DIRS")"
    FS_ALLOWED_DIRS_ARGS=()

    if [[ -z "$FS_ALLOWED_DIRS" ]]; then
        echo "Error: FS_ALLOWED_DIRS is required. Provide one or more host paths (comma or space separated) that are mounted into the container." >&2
        echo "Example: -e FS_ALLOWED_DIRS=\"/data,/projects\" (also mount those paths with -v)" >&2
        exit 1
    fi

    local normalized="${FS_ALLOWED_DIRS//,/ }"
    local dir
    for dir in $normalized; do
        dir="$(trim "$dir")"
        [[ -z "$dir" ]] && continue
        if [[ "$dir" != /* ]]; then
            echo "Invalid FS_ALLOWED_DIRS entry '${dir}': must be an absolute path." >&2
            exit 1
        fi
        if [[ ! -d "$dir" ]]; then
            echo "Warning: FS_ALLOWED_DIRS entry '${dir}' does not exist inside the container. Did you forget to mount it?" >&2
        fi
        FS_ALLOWED_DIRS_ARGS+=("$dir")
    done

    if [[ ${#FS_ALLOWED_DIRS_ARGS[@]} -eq 0 ]]; then
        echo "Error: FS_ALLOWED_DIRS is set but contains no valid paths." >&2
        exit 1
    fi

    echo "Filesystem allowed directories: ${FS_ALLOWED_DIRS_ARGS[*]}"
}

validate_cors() {
    ALLOW_ALL_CORS=false
    HAPROXY_CORS_ENABLED=false
    HAPROXY_CORS_ORIGINS=()

    local cors_value
    if [[ -z "${CORS:-}" ]]; then
        return
    fi

    HAPROXY_CORS_ENABLED=true
    IFS=',' read -ra CORS_VALUES <<< "$CORS"
    for cors_value in "${CORS_VALUES[@]}"; do
        cors_value="$(trim "$cors_value")"
        [[ -z "$cors_value" ]] && continue

        if [[ "$cors_value" =~ ^(all|\*)$ ]]; then
            ALLOW_ALL_CORS=true
            HAPROXY_CORS_ORIGINS=("*")
            break
        elif [[ "$cors_value" =~ ^https?:// ]]; then
            HAPROXY_CORS_ORIGINS+=("$cors_value")
        elif [[ "$cors_value" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]+)?$ ]]; then
            HAPROXY_CORS_ORIGINS+=("http://$cors_value" "https://$cors_value")
        elif [[ "$cors_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]]; then
            HAPROXY_CORS_ORIGINS+=("http://$cors_value" "https://$cors_value")
        else
            echo "Warning: Invalid CORS pattern '$cors_value' - skipping"
        fi
    done
}

handle_first_run() {
    local uid_gid_changed=0

    if [[ -z "${PUID:-}" && -z "${PGID:-}" ]]; then
        PUID="$DEFAULT_PUID"
        PGID="$DEFAULT_PGID"
    elif [[ -n "${PUID:-}" && -z "${PGID:-}" ]]; then
        if is_positive_int "$PUID"; then
            PGID="$PUID"
        else
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    elif [[ -z "${PUID:-}" && -n "${PGID:-}" ]]; then
        if is_positive_int "$PGID"; then
            PUID="$PGID"
        else
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    else
        if ! is_positive_int "$PUID"; then
            PUID="$DEFAULT_PUID"
        fi
        if ! is_positive_int "$PGID"; then
            PGID="$DEFAULT_PGID"
        fi
    fi

    if [ "$(id -u node)" -ne "$PUID" ]; then
        if usermod -o -u "$PUID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            PUID="$(id -u node)"
        fi
    fi

    if [ "$(id -g node)" -ne "$PGID" ]; then
        if groupmod -o -g "$PGID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            PGID="$(id -g node)"
        fi
    fi

    if [ "$uid_gid_changed" -eq 1 ]; then
        echo "Updated UID/GID to PUID=${PUID}, PGID=${PGID}"
    fi

    touch "$FIRST_RUN_FILE"
}

haproxy_supports_quic() {
    # Build flag check (fast pre-filter)
    # Note: avoid pipe + grep -q with pipefail (SIGPIPE can cause false negatives)
    local vv_output
    vv_output="$(haproxy -vv 2>/dev/null)" || true
    if ! echo "$vv_output" | grep -Eiq 'USE_QUIC=1|[[:space:]]quic[[:space:]]: mode=HTTP'; then
        return 1
    fi

    # Runtime probe: verify QUIC bind actually works with the current SSL library
    local probe_dir probe_cfg probe_pem output
    probe_dir="$(mktemp -d)" || return 1
    probe_cfg="${probe_dir}/probe.cfg"
    probe_pem="${probe_dir}/probe.pem"

    if ! openssl req -x509 -newkey rsa:2048 -keyout "${probe_dir}/probe.key" -out "${probe_dir}/probe.crt" \
         -days 1 -nodes -subj "/CN=quic-probe" -batch 2>/dev/null; then
        rm -rf "$probe_dir"
        return 1
    fi
    cat "${probe_dir}/probe.crt" "${probe_dir}/probe.key" > "$probe_pem"

    printf 'global\n  log stderr format raw local0\ndefaults\n  mode http\n  timeout connect 5s\n  timeout client 5s\n  timeout server 5s\nfrontend quic_probe\n  bind quic4@*:65535 ssl crt %s alpn h3\n  default_backend quic_probe_be\nbackend quic_probe_be\n  server s1 127.0.0.1:1\n' \
        "$probe_pem" > "$probe_cfg"

    output="$(haproxy -c -f "$probe_cfg" 2>&1)" || true
    rm -rf "$probe_dir"

    if echo "$output" | grep -qi 'does not support the QUIC protocol'; then
        return 1
    fi
    return 0
}

ensure_parent_dir() {
    local target="$1"
    mkdir -p "$(dirname "$target")"
}

prepare_tls_pem() {
    local cert_path="$1"
    local key_path="$2"
    local pem_path="$3"
    local tls_days="$4"
    local tls_cn="$5"
    local tls_san="$6"

    if [[ -f "$pem_path" ]]; then
        return
    fi

    ensure_parent_dir "$pem_path"

    if [[ -f "$cert_path" && -f "$key_path" ]]; then
        cat "$cert_path" "$key_path" > "$pem_path"
        chmod 600 "$pem_path"
        return
    fi

    echo "TLS enabled and no certificate material found; generating self-signed certificate (CN=${tls_cn})"
    ensure_parent_dir "$cert_path"
    ensure_parent_dir "$key_path"

    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout "$key_path" \
      -out "$cert_path" \
      -days "$tls_days" \
      -subj "/CN=${tls_cn}" \
      -addext "subjectAltName=${tls_san}" >/dev/null 2>&1

    chmod 600 "$cert_path" "$key_path"
    cat "$cert_path" "$key_path" > "$pem_path"
    chmod 600 "$pem_path"
}

resolve_listener_protocols() {
    local mode="$1"

    if ! is_true "$ENABLE_HTTPS"; then
        if [[ "$mode" != "h1" && "$mode" != "auto" ]]; then
            echo "HTTP_VERSION_MODE='${mode}' requested without TLS; falling back to HTTP/1.1" >&2
        fi

        BIND_PARAMS=""
        QUIC_BIND_LINE="# HTTP/3 disabled"
        EFFECTIVE_HTTP_VERSIONS="h1"
        return
    fi

    local alpn="http/1.1"
    local want_h3="false"

    case "$mode" in
        h1)
            alpn="http/1.1"
            ;;
        h2)
            alpn="h2"
            ;;
        h1+h2)
            alpn="h2,http/1.1"
            ;;
        h3)
            alpn="h2,http/1.1"
            want_h3="true"
            ;;
        auto|all)
            alpn="h2,http/1.1"
            want_h3="true"
            ;;
    esac

    BIND_PARAMS="ssl crt ${TLS_PEM_PATH} ssl-min-ver ${TLS_MIN_VERSION} alpn ${alpn}"
    EFFECTIVE_HTTP_VERSIONS="${alpn}"
    QUIC_BIND_LINE="# HTTP/3 disabled"

    if [[ "$want_h3" == "true" ]]; then
        if haproxy_supports_quic; then
            QUIC_BIND_LINE="bind quic4@*:${PORT} ssl crt ${TLS_PEM_PATH} ssl-min-ver ${TLS_MIN_VERSION} alpn h3"
            EFFECTIVE_HTTP_VERSIONS="${EFFECTIVE_HTTP_VERSIONS},h3"
        else
            echo "HTTP_VERSION_MODE='${mode}' requested h3, but QUIC is not available in this HAProxy build; continuing with ${alpn}" >&2
        fi
    fi
}

escape_sed_replacement() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//&/\\&}"
    value="${value//|/\\|}"
    printf '%s' "$value"
}

escape_haproxy_regex() {
    local value="$1"
    local escaped=""
    local i ch

    for ((i = 0; i < ${#value}; i++)); do
        ch="${value:i:1}"
        if [[ "$ch" =~ [\\.^$\|?*+(){}\[\]] ]]; then
            escaped+="\\$ch"
        else
            escaped+="$ch"
        fi
    done

    printf '%s' "$escaped"
}

generate_haproxy_config() {
    if [[ ! -f "$HAPROXY_TEMPLATE" ]]; then
        echo "Error: HAProxy template missing at ${HAPROXY_TEMPLATE}" >&2
        exit 1
    fi

    # Rate limiting and connection limiting
    local rate_limit_table
    local rate_limit_check
    if [[ "$RATE_LIMIT" != "0" || "$MAX_CONNECTIONS_PER_IP" != "0" ]]; then
        local store_counters=""
        [[ "$RATE_LIMIT" != "0" ]] && store_counters="http_req_rate(${RATE_LIMIT_PERIOD})"
        [[ "$MAX_CONNECTIONS_PER_IP" != "0" ]] && {
            [[ -n "$store_counters" ]] && store_counters+=","
            store_counters+="conn_cur"
        }

        rate_limit_table="backend rate_limit_table
    stick-table type ipv6 size 100k expire 30s store ${store_counters}"

        rate_limit_check="    # Track client IP for rate/connection limiting
    http-request track-sc0 src table rate_limit_table"

        if [[ "$RATE_LIMIT" != "0" ]]; then
            rate_limit_check+="
    http-request return status 429 content-type \"application/json\" string '{\"error\":\"Too Many Requests\",\"message\":\"Rate limit exceeded\"}' hdr \"Retry-After\" \"${RATE_LIMIT_PERIOD%%[smhd]*}\" if !is_health_check { sc_http_req_rate(0,rate_limit_table) gt ${RATE_LIMIT} }"
            echo "Rate limiting enabled: ${RATE_LIMIT} requests per ${RATE_LIMIT_PERIOD}"
        fi

        if [[ "$MAX_CONNECTIONS_PER_IP" != "0" ]]; then
            rate_limit_check+="
    http-request deny deny_status 429 content-type \"application/json\" string '{\"error\":\"Too Many Connections\",\"message\":\"Connection limit exceeded\"}' if !is_health_check { sc_conn_cur(0,rate_limit_table) gt ${MAX_CONNECTIONS_PER_IP} }"
            echo "Connection limiting enabled: ${MAX_CONNECTIONS_PER_IP} concurrent connections per IP"
        fi
    else
        rate_limit_table="# Rate limiting disabled"
        rate_limit_check="    # Rate limiting disabled"
    fi

    # IP access control
    local ip_access_check
    if [[ -n "$IP_BLOCKLIST" && -s /tmp/haproxy_blocklist.txt ]]; then
        ip_access_check="    # IP blocklist
    acl is_blocked_ip src -f /tmp/haproxy_blocklist.txt
    http-request deny deny_status 403 content-type \"application/json\" string '{\"error\":\"Forbidden\",\"message\":\"IP address blocked\"}' if is_blocked_ip !is_health_check"
    else
        ip_access_check=""
    fi

    if [[ -n "$IP_ALLOWLIST" && -s /tmp/haproxy_allowlist.txt ]]; then
        [[ -n "$ip_access_check" ]] && ip_access_check+="
"
        ip_access_check+="    # IP allowlist (only listed IPs may connect)
    acl is_allowed_ip src -f /tmp/haproxy_allowlist.txt
    acl is_allowed_ip src 127.0.0.1 ::1
    http-request deny deny_status 403 content-type \"application/json\" string '{\"error\":\"Forbidden\",\"message\":\"IP address not allowed\"}' if !is_allowed_ip"
    fi

    if [[ -z "$ip_access_check" ]]; then
        ip_access_check="    # IP access control disabled"
    fi

    local api_key_check
    if [[ -n "$API_KEY" ]]; then
        local escaped_key_sed
        escaped_key_sed="$(escape_sed_replacement "$API_KEY")"
        api_key_check="    # API Key authentication enabled (localhost /healthz excluded)
    acl auth_header_present var(txn.auth_header) -m found

    # Extract token: strip 'Bearer ' prefix (case-insensitive) into txn.api_token
    http-request set-var(txn.api_token) var(txn.auth_header),regsub(^[Bb][Ee][Aa][Rr][Ee][Rr][[:space:]]+,)

    # Validate extracted token via exact string match (no regex escaping issues)
    acl auth_valid var(txn.api_token) -m str ${escaped_key_sed}

    # Deny requests without valid authentication (except localhost health checks)
    http-request deny deny_status 401 content-type \"application/json\" string '{\"error\":\"Unauthorized\",\"message\":\"Valid API key required\"}' if !is_health_check !auth_header_present
    http-request deny deny_status 401 content-type \"application/json\" string '{\"error\":\"Unauthorized\",\"message\":\"Valid API key required\"}' if is_health_check !is_localhost !auth_header_present
    http-request deny deny_status 403 content-type \"application/json\" string '{\"error\":\"Forbidden\",\"message\":\"Invalid API key\"}' if !is_health_check auth_header_present !auth_valid
    http-request deny deny_status 403 content-type \"application/json\" string '{\"error\":\"Forbidden\",\"message\":\"Invalid API key\"}' if is_health_check !is_localhost auth_header_present !auth_valid"
    else
        api_key_check="    # API Key authentication disabled - all requests allowed"
    fi

    local cors_check
    local cors_preflight_condition
    local cors_response_condition

    if [[ "$HAPROXY_CORS_ENABLED" == "true" ]]; then
        if [[ "$ALLOW_ALL_CORS" == "true" ]]; then
            cors_check="    # CORS enabled - allowing ALL origins"
            cors_preflight_condition="{ var(txn.origin) -m found }"
            cors_response_condition="{ var(txn.origin) -m found }"
        else
            cors_check="    # CORS enabled - allowing specific origins
    acl cors_origin_allowed var(txn.origin) -m str -i"

            local origin
            for origin in "${HAPROXY_CORS_ORIGINS[@]}"; do
                cors_check+=" ${origin}"
            done

            cors_check+="

    # Deny requests from non-allowed origins
    http-request deny deny_status 403 content-type \"application/json\" string '{\"error\":\"Forbidden\",\"message\":\"Origin not allowed\"}' if { var(txn.origin) -m found } !cors_origin_allowed"
            cors_preflight_condition="cors_origin_allowed"
            cors_response_condition="cors_origin_allowed"
        fi
    else
        cors_check="    # CORS disabled"
        cors_preflight_condition="{ always_false }"
        cors_response_condition="{ always_false }"
    fi

    local escaped_bind_params
    local escaped_quic_bind_line
    escaped_bind_params="$(escape_sed_replacement "$BIND_PARAMS")"
    escaped_quic_bind_line="$(escape_sed_replacement "$QUIC_BIND_LINE")"

    # Concurrency caps. Bound HAProxy-level acceptance so a burst cannot
    # trigger unbounded upstream mcp-proxy child reuse / spawn. Empty = no cap.
    local frontend_maxconn_clause=""
    local server_maxconn_clause=""
    if [[ "${HAPROXY_FRONTEND_MAXCONN:-0}" =~ ^[1-9][0-9]*$ ]]; then
        frontend_maxconn_clause="maxconn ${HAPROXY_FRONTEND_MAXCONN}"
    fi
    if [[ "${HAPROXY_SERVER_MAXCONN:-0}" =~ ^[1-9][0-9]*$ ]]; then
        server_maxconn_clause="maxconn ${HAPROXY_SERVER_MAXCONN}"
    fi
    local escaped_frontend_maxconn
    local escaped_server_maxconn
    escaped_frontend_maxconn="$(escape_sed_replacement "$frontend_maxconn_clause")"
    escaped_server_maxconn="$(escape_sed_replacement "$server_maxconn_clause")"

    sed -e "s|__SERVER_PORT__|${PORT}|g" \
        -e "s|__BIND_PARAMS__|${escaped_bind_params}|g" \
        -e "s|__QUIC_BIND_LINE__|${escaped_quic_bind_line}|g" \
        -e "s|__INTERNAL_PORT__|${INTERNAL_PORT}|g" \
        -e "s|__SERVER_NAME__|${HAPROXY_SERVER_NAME}|g" \
        -e "s|__CORS_PREFLIGHT_CONDITION__|${cors_preflight_condition}|g" \
        -e "s|__CORS_RESPONSE_CONDITION__|${cors_response_condition}|g" \
        -e "s|__FRONTEND_MAXCONN__|${escaped_frontend_maxconn}|g" \
        -e "s|__SERVER_MAXCONN__|${escaped_server_maxconn}|g" \
        "$HAPROXY_TEMPLATE" > "${HAPROXY_CONFIG}.tmp"

    awk -v replacement="$api_key_check" -v replacement_cors="$cors_check" \
        -v replacement_rate_table="$rate_limit_table" -v replacement_rate_check="$rate_limit_check" \
        -v replacement_ip_access="$ip_access_check" '
        /__API_KEY_CHECK__/ { print replacement; next }
        /__CORS_CHECK__/ { print replacement_cors; next }
        /__RATE_LIMIT_TABLE__/ { print replacement_rate_table; next }
        /__RATE_LIMIT_CHECK__/ { print replacement_rate_check; next }
        /__IP_ACCESS_CHECK__/ { print replacement_ip_access; next }
        { print }
    ' "${HAPROXY_CONFIG}.tmp" > "$HAPROXY_CONFIG"

    rm -f "${HAPROXY_CONFIG}.tmp"

    haproxy -c -f "$HAPROXY_CONFIG" >/dev/null
}

start_haproxy() {
    echo "Starting HAProxy on port ${PORT}"
    haproxy -db -f "$HAPROXY_CONFIG" &
    HAPROXY_PID=$!
}

shell_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}

start_mcp_server() {
    local mcp_server_cmd="npx -y @modelcontextprotocol/server-filesystem"
    local dir
    for dir in "${FS_ALLOWED_DIRS_ARGS[@]}"; do
        mcp_server_cmd+=" $(shell_quote "$dir")"
    done

    # Build mcp-proxy CORS args. CORS env may be comma-separated origins or "*".
    local cors_args=()
    if [[ -n "${CORS:-}" ]]; then
        local origin
        for origin in ${CORS//,/ }; do
            cors_args+=(--allow-origin "$origin")
        done
    fi

    local stateless_args=()
    if [[ "${MCP_PROXY_STATELESS,,}" == "true" ]]; then
        stateless_args+=(--stateless)
    else
        stateless_args+=(--no-stateless)
    fi

    local mode_tag="stateful"
    [[ "${MCP_PROXY_STATELESS,,}" == "true" ]] && mode_tag="stateless"

    # mcp-proxy expects an argv array; split the prebuilt stdio command
    # preserving any quoted segments (callers may inject env wrappers).
    local -a backend_argv
    # shellcheck disable=SC2086
    eval "backend_argv=(${mcp_server_cmd:-${MCP_SERVER_CMD:-${snyk_mcp_cmd:-}}})"

    case "${PROTOCOL^^}" in
        SHTTP|STREAMABLEHTTP|SSE)
            # mcp-proxy exposes /mcp (StreamableHTTP) and /sse simultaneously.
            CMD_ARGS=(mcp-proxy
                --host 127.0.0.1
                --port "$INTERNAL_PORT"
                --pass-environment
                --expose-header Mcp-Session-Id
                "${stateless_args[@]}"
                "${cors_args[@]}"
                --
                "${backend_argv[@]}")
            PROTOCOL_DISPLAY="mcp-proxy: /mcp (StreamableHTTP) + /sse (${mode_tag})"
            ;;
        WS|WEBSOCKET)
            echo "ERROR: WebSocket transport is not supported by mcp-proxy." >&2
            echo "       Use PROTOCOL=SHTTP or PROTOCOL=SSE instead." >&2
            return 1
            ;;
        *)
            echo "Invalid PROTOCOL='${PROTOCOL}', defaulting to ${DEFAULT_PROTOCOL}"
            CMD_ARGS=(mcp-proxy
                --host 127.0.0.1
                --port "$INTERNAL_PORT"
                --pass-environment
                --expose-header Mcp-Session-Id
                "${stateless_args[@]}"
                "${cors_args[@]}"
                --
                "${backend_argv[@]}")
            PROTOCOL_DISPLAY="mcp-proxy: /mcp (StreamableHTTP) + /sse (${mode_tag})"
            ;;
    esac

    echo "Launching Filesystem MCP via ${PROTOCOL_DISPLAY}"

    if [ "$(id -u)" -eq 0 ]; then
        su-exec node "${CMD_ARGS[@]}" &
    else
        "${CMD_ARGS[@]}" &
    fi

    MCP_PID=$!

    local i=0
    until nc -z 127.0.0.1 "$INTERNAL_PORT" >/dev/null 2>&1; do
        if ! kill -0 "$MCP_PID" >/dev/null 2>&1; then
            echo "MCP server exited before becoming ready" >&2
            return 1
        fi

        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            echo "MCP server did not become ready on ${INTERNAL_PORT}" >&2
            return 1
        fi

        sleep 1
    done
}

shutdown() {
    set +e
    if [[ -n "${HAPROXY_PID:-}" ]]; then
        kill "$HAPROXY_PID" 2>/dev/null || true
    fi
    if [[ -n "${MCP_PID:-}" ]]; then
        kill "$MCP_PID" 2>/dev/null || true
    fi
    wait 2>/dev/null || true
}

main() {
    if [[ $# -gt 0 ]]; then
        exec "$@"
    fi

    PUID="${PUID:-$DEFAULT_PUID}"
    PGID="${PGID:-$DEFAULT_PGID}"
    PUID="$(trim "$PUID")"
    PGID="$(trim "$PGID")"

    PORT="${PORT:-$DEFAULT_PORT}"
    INTERNAL_PORT="${INTERNAL_PORT:-$DEFAULT_INTERNAL_PORT}"
    PROTOCOL="${PROTOCOL:-$DEFAULT_PROTOCOL}"
    ENABLE_HTTPS="${ENABLE_HTTPS:-false}"
    TLS_CERT_PATH="${TLS_CERT_PATH:-/etc/haproxy/certs/server.crt}"
    TLS_KEY_PATH="${TLS_KEY_PATH:-/etc/haproxy/certs/server.key}"
    TLS_PEM_PATH="${TLS_PEM_PATH:-/etc/haproxy/certs/server.pem}"
    TLS_CN="${TLS_CN:-$DEFAULT_TLS_CN}"
    TLS_SAN="${TLS_SAN:-DNS:${TLS_CN}}"
    TLS_DAYS="${TLS_DAYS:-$DEFAULT_TLS_DAYS}"
    TLS_MIN_VERSION="${TLS_MIN_VERSION:-$DEFAULT_TLS_MIN_VERSION}"
    HTTP_VERSION_MODE="${HTTP_VERSION_MODE:-$DEFAULT_HTTP_VERSION_MODE}"
    CORS="${CORS:-}"

    PORT="$(validate_port "PORT" "$PORT" "$DEFAULT_PORT")"
    INTERNAL_PORT="$(validate_port "INTERNAL_PORT" "$INTERNAL_PORT" "$DEFAULT_INTERNAL_PORT")"
    TLS_DAYS="$(validate_tls_days "$TLS_DAYS" "$DEFAULT_TLS_DAYS")"
    TLS_MIN_VERSION="$(validate_tls_min_version "$TLS_MIN_VERSION" "$DEFAULT_TLS_MIN_VERSION")"
    HTTP_VERSION_MODE="$(normalize_http_version_mode "$HTTP_VERSION_MODE")"

    validate_api_key
    validate_rate_limit
    validate_ip_access
    validate_cors
    validate_fs_allowed_dirs

    if [[ ! -f "$FIRST_RUN_FILE" ]]; then
        handle_first_run
    fi

    # Export variables for banner.sh (runs as child process)
    export PORT PUID PGID PROTOCOL
    /usr/local/bin/banner.sh

    if is_true "$ENABLE_HTTPS"; then
        prepare_tls_pem "$TLS_CERT_PATH" "$TLS_KEY_PATH" "$TLS_PEM_PATH" "$TLS_DAYS" "$TLS_CN" "$TLS_SAN"
    fi

    resolve_listener_protocols "$HTTP_VERSION_MODE"
    generate_haproxy_config

    trap shutdown INT TERM EXIT

    start_mcp_server
    start_haproxy

    if [[ -n "$API_KEY" ]]; then
        echo "API key authentication enabled"
    else
        echo "API key authentication disabled"
    fi

    if is_true "$ENABLE_HTTPS"; then
        echo "HTTPS enabled on port ${PORT}"
        echo "HTTP versions enabled: ${EFFECTIVE_HTTP_VERSIONS}"
    else
        echo "HTTPS disabled; listening on HTTP port ${PORT}"
        echo "WARNING: Traffic is NOT encrypted when ENABLE_HTTPS=false." >&2
        echo "WARNING: Use ENABLE_HTTPS=true for internet-facing or untrusted networks." >&2
        if [[ "${NODE_ENV:-}" =~ ^([Pp][Rr][Oo][Dd][Uu][Cc][Tt][Ii][Oo][Nn])$ ]]; then
            echo "====================================================================" >&2
            echo "SECURITY WARNING: NODE_ENV=production with ENABLE_HTTPS=false" >&2
            echo "SECURITY WARNING: Requests and responses are plaintext over the network." >&2
            echo "SECURITY WARNING: Enable TLS now by setting ENABLE_HTTPS=true." >&2
            echo "====================================================================" >&2
        fi
        if [[ -n "$API_KEY" ]]; then
            echo "WARNING: API_KEY protects access but does not encrypt HTTP traffic." >&2
        fi
    fi

    wait -n "$MCP_PID" "$HAPROXY_PID"
}

main "$@"
