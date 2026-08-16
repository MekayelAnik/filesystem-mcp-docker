#!/bin/bash
set -euxo pipefail
# Set variables first
REPO_NAME='filesystem-mcp'
BASE_IMAGE=$(cat ./build_data/base-image 2>/dev/null || echo "node:current-alpine")
HAPROXY_IMAGE=$(cat ./build_data/haproxy-image 2>/dev/null || echo "haproxy:lts-alpine")
FILESYSTEM_VERSION=$(cat ./build_data/version 2>/dev/null || exit 1)
FILESYSTEM_MCP_PKG="@modelcontextprotocol/server-filesystem@${FILESYSTEM_VERSION}"
# mcp-proxy: stdio<->StreamableHTTP/SSE bridge. Replaces supergateway.
# Stateful by default (one stdio child shared across all sessions) - avoids
# the spawn-per-request memory leak that affected supergateway in stateless
# mode (supercorp-ai/supergateway#108).
MCP_PROXY_PKG=$(cat ./build_data/mcp_proxy_version 2>/dev/null || echo "mcp-proxy")
DOCKERFILE_NAME="Dockerfile.$REPO_NAME"

# Create a temporary file safely
TEMP_FILE=$(mktemp "${DOCKERFILE_NAME}.XXXXXX") || {
    echo "Error creating temporary file" >&2
    exit 1
}

# Check if this is a publication build
if [ -e ./build_data/publication ]; then
    # For publication builds, create a minimal Dockerfile that just tags the existing image
    {
        echo "ARG BASE_IMAGE=$BASE_IMAGE"
        echo "ARG FILESYSTEM_VERSION=$FILESYSTEM_VERSION"
        echo "FROM $BASE_IMAGE"
    } > "$TEMP_FILE"
else
    # Write the Dockerfile content to the temporary file first
    {
        echo "ARG BASE_IMAGE=$BASE_IMAGE"
        echo "ARG FILESYSTEM_VERSION=$FILESYSTEM_VERSION"
        cat << EOF
FROM $HAPROXY_IMAGE AS haproxy-src
FROM $BASE_IMAGE AS build

# Author info:
LABEL org.opencontainers.image.authors="MOHAMMAD MEKAYEL ANIK <mekayel.anik@gmail.com>"
LABEL org.opencontainers.image.source="https://github.com/mekayelanik/filesystem-mcp-docker"

# Copy the entrypoint script into the container and make it executable
COPY ./resources/ /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/banner.sh /usr/local/bin/healthcheck.sh \\
    && if [ -f /usr/local/bin/build-timestamp.txt ]; then chmod +r /usr/local/bin/build-timestamp.txt; fi \\
    && mkdir -p /etc/haproxy \\
    && mv -vf /usr/local/bin/haproxy.cfg.template /etc/haproxy/haproxy.cfg.template \\
    && ls -la /etc/haproxy/haproxy.cfg.template

# Install required APK packages
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" > /etc/apk/repositories && \\
    echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \\
    apk --update-cache --no-cache add bash shadow su-exec tzdata haproxy netcat-openbsd openssl ca-certificates curl python3 py3-pip && \\
    rm -rf /var/cache/apk/*

# HAProxy with native QUIC/H3 support from official image
COPY --from=haproxy-src /usr/local/sbin/haproxy /usr/sbin/haproxy
RUN mkdir -p /usr/local/sbin && ln -sf /usr/sbin/haproxy /usr/local/sbin/haproxy

# Check if package exists before installing
RUN --mount=type=cache,target=/root/.npm \\
    echo "Checking if package exists: ${FILESYSTEM_MCP_PKG}" && \\
    if npm view ${FILESYSTEM_MCP_PKG} >/dev/null 2>&1; then \\
        echo "Package found, installing..." && \\
        npm install -g ${FILESYSTEM_MCP_PKG} --omit=dev --no-audit --no-fund --loglevel error && \\
        echo "Package installed successfully"; \\
    else \\
        echo "ERROR: Package ${FILESYSTEM_MCP_PKG} not found in registry!" >&2; \\
        echo "Available versions:" && \\
        npm view @modelcontextprotocol/server-filesystem versions --json | tr -d '\[\],' | tr '"' '\n' | grep -v '^$' | head -10; \\
        exit 1; \\
    fi

# Install mcp-proxy (replaces supergateway). Pure-Python via pip.
RUN --mount=type=cache,target=/root/.cache/pip \\
    echo "Installing ${MCP_PROXY_PKG}..." && \\
    pip install --no-cache-dir --break-system-packages ${MCP_PROXY_PKG} && \\
    mcp-proxy --version && \\
    rm -rf /tmp/* /var/tmp/* && \\
    rm -rf /usr/local/lib/node_modules/npm/man /usr/local/lib/node_modules/npm/docs /usr/local/lib/node_modules/npm/html

LABEL org.opencontainers.image.description="Filesystem MCP (mcp-proxy stdio<->HTTP bridge)"

# mcp-proxy and HAProxy concurrency defaults (overridable at runtime).
ENV MCP_PROXY_STATELESS=false
ENV FILESYSTEM_MAX_MEM_MB=4096
ENV HAPROXY_FRONTEND_MAXCONN=64
ENV HAPROXY_SERVER_MAXCONN=16

# Use an ARG for the default port
ARG PORT=8010

# Add ARG for API key
ARG API_KEY=""

# Set an ENV variable from the ARG for runtime
ENV PORT=\${PORT}
ENV API_KEY=\${API_KEY}

# L7 health check: auto-detects HTTP/HTTPS via ENABLE_HTTPS env var
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \\
    CMD ["/usr/local/bin/healthcheck.sh"]

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

EOF
    } > "$TEMP_FILE"
fi

# Atomically replace the target file with the temporary file
if mv -f "$TEMP_FILE" "$DOCKERFILE_NAME"; then
    echo "Dockerfile for $REPO_NAME created successfully."
else
    echo "Error: Failed to create Dockerfile for $REPO_NAME" >&2
    rm -f "$TEMP_FILE"
    exit 1
fi