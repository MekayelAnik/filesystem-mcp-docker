#!/bin/bash
set -ex
# Set variables first
REPO_NAME='filesystem-mcp'
BASE_IMAGE=$(cat ./build_data/base-image 2>/dev/null || echo "node:alpine")
FILESYSTEM_MCP_VERSION=$(cat ./build_data/version 2>/dev/null || exit 1)
SUPERGATEWAY_REPO=$(cat ./build_data/supergateway_repo 2>/dev/null || echo "supergateway")
SUPERGATEWAY_VERSION=$(cat ./build_data/supergateway_version 2>/dev/null || echo "latest")
FILESYSTEM_MCP_REPO="@modelcontextprotocol/server-filesystem"
FILESYSTEM_MCP_PKG="${FILESYSTEM_MCP_REPO}@${FILESYSTEM_MCP_VERSION}"
SUPERGATEWAY_PKG="${SUPERGATEWAY_REPO}@${SUPERGATEWAY_VERSION}"
DOCKERFILE_NAME="Dockerfile.$REPO_NAME"
OTHER_NPM_DEPENDENCIES=$(cat ./build_data/npm_dependencies 2>/dev/null || echo "")

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
        echo "FROM $BASE_IMAGE"
    } > "$TEMP_FILE"
else
    # Write the Dockerfile content to the temporary file first
    {
        echo "ARG BASE_IMAGE=$BASE_IMAGE"
        cat << EOF
FROM $BASE_IMAGE AS build

# Author info:
LABEL org.opencontainers.image.authors="MOHAMMAD MEKAYEL ANIK <mekayel.anik@gmail.com>"
LABEL org.opencontainers.image.source="https://github.com/mekayelanik/filesystem-mcp-docker"

# Copy the entrypoint script into the container and make it executable
COPY ./resources/ /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/banner.sh

# Install required APK packages
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" > /etc/apk/repositories && \
    echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk --update-cache --no-cache add bash shadow su-exec tzdata && \
    rm -rf /var/cache/apk/*

# Create node user with specific UID/GID if they don't exist
RUN if ! id -u node >/dev/null 2>&1; then \
        addgroup -g 1000 node && \
        adduser -u 1000 -G node -D node; \
    fi

# Install Filesystem MCP server
RUN echo "Installing Filesystem MCP server: ${FILESYSTEM_MCP_PKG}" && \
    npm install -g ${FILESYSTEM_MCP_PKG} --loglevel verbose && \
    echo "Package installed successfully"

# Install Supergateway
RUN echo "Installing Supergateway..." && \
    npm install -g ${SUPERGATEWAY_PKG} --loglevel verbose && \
    npm cache clean --force

EOF

        # Add Other NPM Dependencies if they exist
        if [ -n "$OTHER_NPM_DEPENDENCIES" ]; then
            cat << EOF
# Install Other NPM Dependencies
RUN echo "Installing other NPM Dependencies: ${OTHER_NPM_DEPENDENCIES}" && \
    npm install -g ${OTHER_NPM_DEPENDENCIES} --loglevel verbose && \
    echo "Packages installed successfully"

EOF
        fi

        cat << EOF
# Use an ARG for the default port
ARG PORT=8015

# Set an ENV variable from the ARG for runtime
ENV PORT=\${PORT}

# Expose the port
EXPOSE \${PORT}

# Create projects directory with proper ownership
RUN mkdir -p /projects && chown node:node /projects

# Set working directory to /projects
WORKDIR /projects

# Health check using nc (netcat) to check if the port is open
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \\
    CMD nc -z localhost \${PORT:-8015} || exit 1

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