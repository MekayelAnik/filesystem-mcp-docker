#!/bin/bash
set -e
/usr/local/bin/banner.sh

# Default values
readonly DEFAULT_PUID=1000
readonly DEFAULT_PGID=1000
readonly DEFAULT_PORT=8015
readonly DEFAULT_PROTOCOL="SHTTP"
readonly DEFAULT_PROJECT_DIRS="/projects"
readonly FIRST_RUN_FILE="/tmp/first_run_complete"

# Function to trim whitespace using parameter expansion
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Validate positive integers
is_positive_int() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

# Validate directory path
validate_directory() {
    local dir="$1"
    [[ -n "$dir" ]] && [[ "$dir" =~ ^/ ]] && [[ ! "$dir" =~ \.\. ]] && [[ "${#dir}" -le 255 ]]
}

# First run handling
handle_first_run() {
    local uid_gid_changed=0

    # Handle PUID/PGID logic
    if [[ -z "$PUID" && -z "$PGID" ]]; then
        PUID="$DEFAULT_PUID"
        PGID="$DEFAULT_PGID"
        echo "PUID and PGID not set. Using defaults: PUID=$PUID, PGID=$PGID"
    elif [[ -n "$PUID" && -z "$PGID" ]]; then
        if is_positive_int "$PUID"; then
            PGID="$PUID"
        else
            echo "Invalid PUID: '$PUID'. Using default: $DEFAULT_PUID"
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    elif [[ -z "$PUID" && -n "$PGID" ]]; then
        if is_positive_int "$PGID"; then
            PUID="$PGID"
        else
            echo "Invalid PGID: '$PGID'. Using default: $DEFAULT_PGID"
            PUID="$DEFAULT_PUID"
            PGID="$DEFAULT_PGID"
        fi
    else
        if ! is_positive_int "$PUID"; then
            echo "Invalid PUID: '$PUID'. Using default: $DEFAULT_PUID"
            PUID="$DEFAULT_PUID"
        fi
        
        if ! is_positive_int "$PGID"; then
            echo "Invalid PGID: '$PGID'. Using default: $DEFAULT_PGID"
            PGID="$DEFAULT_PGID"
        fi
    fi

    # Check existing UID/GID conflicts
    local current_user current_group
    current_user=$(id -un "$PUID" 2>/dev/null || true)
    current_group=$(getent group "$PGID" | cut -d: -f1 2>/dev/null || true)

    [[ -n "$current_user" && "$current_user" != "node" ]] &&
        echo "Warning: UID $PUID already in use by $current_user - may cause permission issues"

    [[ -n "$current_group" && "$current_group" != "node" ]] &&
        echo "Warning: GID $PGID already in use by $current_group - may cause permission issues"

    # Modify UID/GID if needed - use test command instead of arithmetic expressions
    if [ "$(id -u node)" -ne "$PUID" ]; then
        if usermod -o -u "$PUID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            echo "Error: Failed to change UID to $PUID. Using existing UID $(id -u node)"
            PUID=$(id -u node)
        fi
    fi

    if [ "$(id -g node)" -ne "$PGID" ]; then
        if groupmod -o -g "$PGID" node 2>/dev/null; then
            uid_gid_changed=1
        else
            echo "Error: Failed to change GID to $PGID. Using existing GID $(id -g node)"
            PGID=$(id -g node)
        fi
    fi

    [ "$uid_gid_changed" -eq 1 ] && echo "Updated UID/GID to PUID=$PUID, PGID=$PGID"
    touch "$FIRST_RUN_FILE"
}

# Validate and set PORT
validate_port() {
    # Ensure PORT has a value
    PORT=${PORT:-$DEFAULT_PORT}
    
    # Check if PORT is a positive integer
    if ! is_positive_int "$PORT"; then
        echo "Invalid PORT: '$PORT'. Using default: $DEFAULT_PORT"
        PORT="$DEFAULT_PORT"
    elif [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "Invalid PORT: '$PORT'. Using default: $DEFAULT_PORT"
        PORT="$DEFAULT_PORT"
    fi
    
    # Check if port is privileged - use test command instead of arithmetic expression
    if [ "$PORT" -lt 1024 ] && [ "$(id -u)" -ne 0 ]; then
        echo "Warning: Port $PORT is privileged and might require root"
    fi
}

# Validate and parse project directories
validate_project_dirs() {
    # Set default if not provided
    PROJECT_DIRS=${PROJECT_DIRS:-$DEFAULT_PROJECT_DIRS}
    
    # Trim whitespace
    PROJECT_DIRS=$(trim "$PROJECT_DIRS")
    
    # Remove surrounding quotes if present
    PROJECT_DIRS="${PROJECT_DIRS#\"}"
    PROJECT_DIRS="${PROJECT_DIRS%\"}"
    PROJECT_DIRS="${PROJECT_DIRS#\'}"
    PROJECT_DIRS="${PROJECT_DIRS%\'}"
    
    # Parse comma or space-separated directories
    # First, replace commas with spaces to handle both formats uniformly
    PROJECT_DIRS="${PROJECT_DIRS//,/ }"
    
    # Now parse space-separated directories
    local IFS=' '
    read -ra DIR_ARRAY <<< "$PROJECT_DIRS"
    
    # Array to store valid directories
    VALID_DIRS=()
    
    echo "Validating project directories..."
    for dir in "${DIR_ARRAY[@]}"; do
        dir=$(trim "$dir")
        
        # Skip empty entries
        [[ -z "$dir" ]] && continue
        
        # Remove trailing slash if present (except for root)
        if [[ "$dir" != "/" ]]; then
            dir="${dir%/}"
        fi
        
        # Validate directory path
        if ! validate_directory "$dir"; then
            echo "Warning: Invalid directory path '$dir' - skipping"
            continue
        fi
        
        # Check if directory exists
        if [ ! -d "$dir" ]; then
            echo "Warning: Directory '$dir' does not exist - skipping"
            continue
        fi
        
        # Check if directory is accessible
        if [ ! -r "$dir" ]; then
            echo "Warning: Directory '$dir' is not readable - skipping"
            continue
        fi
        
        # Add to valid directories
        VALID_DIRS+=("$dir")
        echo "  ✓ Added: $dir"
    done
    
    # Check if we have at least one valid directory
    if [ ${#VALID_DIRS[@]} -eq 0 ]; then
        echo "ERROR: No valid directories found!"
        echo "Please ensure at least one directory is mounted and accessible."
        echo "Set PROJECT_DIRS with comma or space-separated paths, e.g.:"
        echo "  PROJECT_DIRS=\"/projects/app1 /projects/app2\""
        echo "  PROJECT_DIRS=\"/workspace,/data,/configs\""
        exit 1
    fi
    
    echo "Configured ${#VALID_DIRS[@]} project director(y|ies):"
    printf '  - %s\n' "${VALID_DIRS[@]}"
}

# Check if directories are not empty (at least one should have content)
check_directories_content() {
    local has_content=false
    
    for dir in "${VALID_DIRS[@]}"; do
        if [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
            has_content=true
            echo "Directory '$dir' contains files/subdirectories"
        else
            echo "Warning: Directory '$dir' is empty"
        fi
    done
    
    if [ "$has_content" = false ]; then
        echo "WARNING: All project directories are empty!"
        echo "The server will start but may have limited functionality."
        echo "Consider mounting directories with actual content."
    fi
}

# Build MCP server command with multiple directories
build_mcp_server_cmd() {
    # Start with the base command
    local cmd="npx -y @modelcontextprotocol/server-filesystem"
    
    # Add all valid directories as arguments
    for dir in "${VALID_DIRS[@]}"; do
        cmd="$cmd $dir"
    done
    
    MCP_SERVER_CMD="$cmd"
}

# Validate CORS patterns
validate_cors() {
    CORS_ARGS=()
    ALLOW_ALL_CORS=false
    local cors_value

    if [[ -n "${CORS:-}" ]]; then
        IFS=',' read -ra CORS_VALUES <<< "$CORS"
        for cors_value in "${CORS_VALUES[@]}"; do
            cors_value=$(trim "$cors_value")
            [[ -z "$cors_value" ]] && continue

            if [[ "$cors_value" =~ ^(all|\*)$ ]]; then
                ALLOW_ALL_CORS=true
                CORS_ARGS=(--cors)
                echo "Caution! CORS allowing all origins - security risk in production!"
                break
            elif [[ "$cors_value" =~ ^/.*/$ ]] ||
                 [[ "$cors_value" =~ ^https?:// ]] ||
                 [[ "$cors_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]] ||
                 [[ "$cors_value" =~ ^https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]] ||
                 [[ "$cors_value" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]+)?$ ]]
            then
                CORS_ARGS+=(--cors "$cors_value")
            else
                echo "Warning: Invalid CORS pattern '$cors_value' - skipping"
            fi
        done
    fi
}

# Generate client configuration example
generate_client_config_example() {
    echo ""
    echo "=== FILE SYSTEM MCP Tool List ==="
    echo "To enable auto-approval in your MCP client, add this to your configuration:"
    echo ""
    echo "\"TOOL LIST\": ["
    echo "  \"filesystem_read_text_file\","
    echo "  \"filesystem_read_media_file\","
    echo "  \"filesystem_read_multiple_files\","
    echo "  \"filesystem_write_file\","
    echo "  \"filesystem_edit_file\","
    echo "  \"filesystem_create_directory\","
    echo "  \"filesystem_list_directory\","
    echo "  \"filesystem_list_directory_with_sizes\","
    echo "  \"filesystem_directory_tree\","
    echo "  \"filesystem_move_file\","
    echo "  \"filesystem_search_files\","
    echo "  \"filesystem_get_file_info\","
    echo "  \"filesystem_list_allowed_directories\""
    echo "]"
    echo ""
    echo "=== END TOOL LIST ==="
    echo ""
}

# Main execution
main() {
    # Trim all input parameters
    [[ -n "${PUID:-}" ]] && PUID=$(trim "$PUID")
    [[ -n "${PGID:-}" ]] && PGID=$(trim "$PGID")
    [[ -n "${PORT:-}" ]] && PORT=$(trim "$PORT")
    [[ -n "${PROTOCOL:-}" ]] && PROTOCOL=$(trim "$PROTOCOL")
    [[ -n "${CORS:-}" ]] && CORS=$(trim "$CORS")
    [[ -n "${PROJECT_DIRS:-}" ]] && PROJECT_DIRS=$(trim "$PROJECT_DIRS")

    # First run handling
    if [[ ! -f "$FIRST_RUN_FILE" ]]; then
        handle_first_run
    fi

    # Validate configurations
    validate_port
    validate_project_dirs
    validate_cors
    
    # Check directories content
    check_directories_content

    # Build MCP server command
    build_mcp_server_cmd

    # Generate client configuration example
    generate_client_config_example

    # Protocol selection
    local PROTOCOL_UPPER=${PROTOCOL:-$DEFAULT_PROTOCOL}
    PROTOCOL_UPPER=${PROTOCOL_UPPER^^}

    case "$PROTOCOL_UPPER" in
        "SHTTP"|"STREAMABLEHTTP")
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --streamableHttpPath /mcp --outputTransport streamableHttp "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SHTTP/streamableHttp"
            ;;
        "SSE")
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --ssePath /sse --outputTransport sse "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SSE/Server-Sent Events"
            ;;
        "WS"|"WEBSOCKET")
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --messagePath /message --outputTransport ws "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="WS/WebSocket"
            ;;
        *)
            echo "Invalid PROTOCOL: '$PROTOCOL'. Using default: $DEFAULT_PROTOCOL"
            CMD_ARGS=(npx --yes supergateway --port "$PORT" --streamableHttpPath /mcp --outputTransport streamableHttp "${CORS_ARGS[@]}" --healthEndpoint /healthz --stdio "$MCP_SERVER_CMD")
            PROTOCOL_DISPLAY="SHTTP/streamableHttp"
            ;;
    esac

    # Debug mode handling
    case "${DEBUG_MODE:-}" in
        [1YyTt]*|[Oo][Nn]|[Yy][Ee][Ss]|[Ee][Nn][Aa][Bb][Ll][Ee]*)
            echo "DEBUG MODE: Installing nano and pausing container"
            apk add --no-cache nano 2>/dev/null || echo "Warning: Failed to install nano"
            echo "Container paused for debugging. Exec into container to investigate."
            exec tail -f /dev/null
            ;;
        *)
            # Normal execution
            echo "Launching Filesystem MCP Server with protocol: $PROTOCOL_DISPLAY on port: $PORT"
            echo "Project directories: ${VALID_DIRS[*]}"
            
            # Check for npx availability
            if ! command -v npx &>/dev/null; then
                echo "Error: npx not available. Cannot start server."
                exit 1
            fi

            if [ "$(id -u)" -eq 0 ]; then
                exec su-exec node "${CMD_ARGS[@]}"
            else
                if [ "$PORT" -lt 1024 ]; then
                    echo "Error: Cannot bind to privileged port $PORT without root"
                    exit 1
                fi
                exec "${CMD_ARGS[@]}"
            fi
            ;;
    esac
}

# Run the script with error handling
if main "$@"; then
    exit 0
else
    exit 1
fi