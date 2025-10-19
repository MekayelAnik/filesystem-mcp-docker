# Filesystem MCP Server
### Multi-Architecture Docker Image for Distributed Deployment

<div align="left">

<img alt="filesystem-mcp" src="https://img.shields.io/badge/Filesystem-MCP-4A90E2?style=for-the-badge&logo=files&logoColor=white" width="400">

[![Docker Pulls](https://img.shields.io/docker/pulls/mekayelanik/filesystem-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/filesystem-mcp)
[![Docker Stars](https://img.shields.io/docker/stars/mekayelanik/filesystem-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/filesystem-mcp)
[![License](https://img.shields.io/badge/license-GPL-blue.svg?style=flat-square)](https://raw.githubusercontent.com/MekayelAnik/filesystem-mcp-docker/refs/heads/main/LICENSE)

**[NPM Package](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem)** • **[GitHub Repository](https://github.com/mekayelanik/filesystem-mcp-docker)** • **[Docker Hub](https://hub.docker.com/r/mekayelanik/filesystem-mcp)**

</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [MCP Client Setup](#mcp-client-setup)
- [Available Tools](#available-tools)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

---

## Overview

Filesystem MCP Server provides AI assistants with secure, controlled filesystem access. Read, write, edit, search, and manage files and directories within designated project folders. Seamlessly integrates with VS Code, Cursor, Windsurf, Claude Desktop, and any MCP-compatible client.

### Key Features

✨ **Comprehensive File Operations** - Read, write, edit, move, and search files  
📁 **Directory Management** - Create, list, and navigate directory structures  
🔒 **Secure & Sandboxed** - Access limited to project directories  
🔍 **Advanced Search** - Pattern-based file search with regex support  
📊 **File Metadata** - Detailed file information and directory trees  
🚀 **Multiple Protocols** - HTTP, SSE, and WebSocket transport support  
🎯 **Zero Configuration** - Works out of the box with sensible defaults  
🔧 **Highly Customizable** - Fine-tune via environment variables  
💾 **Media Support** - Handle text and binary files seamlessly  
🗂️ **Multi-Directory Support** - Configure multiple project directories

### Supported Architectures

| Architecture | Status |
|:-------------|:------:|
| **x86-64** | ✅ Stable |
| **ARM64** | ✅ Stable |

### Available Tags

| Tag | Use Case |
|:----|:---------|
| `stable` | **Production (recommended)** |
| `latest` | Latest stable features |
| `1.x.x` | Version pinning |
| `beta` | Testing only |

---

## Quick Start

### Docker Compose (Recommended)

**Single Directory:**
```yaml
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:stable
    container_name: filesystem-mcp
    restart: unless-stopped
    ports:
      - "8015:8015"
    volumes:
      - /home/user/workspace:/home/user/workspace
    environment:
      PORT: "8015"
      PUID: "1000"
      PGID: "1000"
      PROJECT_DIRS: /home/user/workspace
```

**Multiple Directories:**
```yaml
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:stable
    container_name: filesystem-mcp
    restart: unless-stopped
    ports:
      - "8015:8015"
    volumes:
      - /home/user/projects/web:/home/user/projects/web
      - /home/user/projects/api:/home/user/projects/api
      - /home/user/shared:/home/user/shared
    environment:
      PORT: "8015"
      PUID: "1000"
      PGID: "1000"
      PROJECT_DIRS: "/home/user/projects/web,/home/user/projects/api,/home/user/shared"
```

**Deploy:**
```bash
docker compose up -d
docker compose logs -f filesystem-mcp
```

### Docker CLI

**Single Directory:**
```bash
docker run -d \
  --name=filesystem-mcp \
  --restart=unless-stopped \
  -p 8015:8015 \
  -v /home/user/workspace:/home/user/workspace \
  -e PROJECT_DIRS=/home/user/workspace \
  -e PORT=8015 \
  -e PUID=1000 \
  -e PGID=1000 \
  mekayelanik/filesystem-mcp:stable
```

**Multiple Directories (space-separated):**
```bash
docker run -d \
  --name=filesystem-mcp \
  -p 8015:8015 \
  -v /home/user/projects/web:/home/user/projects/web \
  -v /home/user/projects/api:/home/user/projects/api \
  -e PROJECT_DIRS="/home/user/projects/web /home/user/projects/api" \
  mekayelanik/filesystem-mcp:stable
```

### Access Endpoints

| Protocol | Endpoint |
|:---------|:---------|
| **HTTP** | `http://host-ip:8015/mcp` |
| **SSE** | `http://host-ip:8015/sse` |
| **WebSocket** | `ws://host-ip:8015/message` |
| **Health** | `http://host-ip:8015/healthz` |

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|:---------|:-------:|:------------|
| **`PROJECT_DIRS`** | **`/projects`** | **Project directories (comma or space-separated)** |
| `PORT` | `8015` | Server port (1-65535) |
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `Asia/Dhaka` | Container timezone |
| `PROTOCOL` | `SHTTP` | Transport protocol |
| `CORS` | _(none)_ | Cross-Origin configuration |
| `DEBUG_MODE` | `false` | Enable debug mode |

### PROJECT_DIRS Configuration

The `PROJECT_DIRS` environment variable specifies which directories the MCP server can access.

**Format:** Comma (`,`) or space (` `) separated absolute paths

**Examples:**

```yaml
# Single directory
environment:
  - PROJECT_DIRS=/workspace

# Multiple directories (comma-separated)
environment:
  - PROJECT_DIRS=/workspace,/data,/configs

# Multiple directories (space-separated)
environment:
  - PROJECT_DIRS="/workspace /data /configs"
```

**Requirements:**
- All paths must be absolute (start with `/`)
- Directories must exist and be mounted
- At least one directory must be accessible
- Maximum 255 characters per path
- No directory traversal (`..`) allowed

### Volume Mounting Strategies

#### Strategy 1: Single Workspace
```yaml
volumes:
  - /home/user/projects:/home/user/projects
environment:
  PROJECT_DIRS: /home/user/projects
```

#### Strategy 2: Multiple Projects
```yaml
volumes:
  - /home/user/projects/web:/home/user/projects/web
  - /home/user/projects/mobile:/home/user/projects/mobile
  - /home/user/projects/api:/home/user/projects/api
environment:
  PROJECT_DIRS: "/home/user/projects/web,/home/user/projects/mobile,/home/user/projects/api"
```

#### Strategy 3: Mixed Access
```yaml
volumes:
  - /opt/applications:/opt/applications
  - /var/data:/var/data
  - /etc/configs:/etc/configs:ro
environment:
  PROJECT_DIRS: "/opt/applications,/var/data,/etc/configs"
```

#### Strategy 4: Default /projects
```yaml
volumes:
  - /home/user/project1:/projects/project1
  - /home/user/project2:/projects/project2
environment:
  PROJECT_DIRS: /projects
```

### Protocol Configuration

```yaml
# HTTP (Recommended)
environment:
  - PROTOCOL=SHTTP

# Server-Sent Events
environment:
  - PROTOCOL=SSE

# WebSocket
environment:
  - PROTOCOL=WS
```

### CORS Configuration

```yaml
# Development
environment:
  - CORS=*

# Production
environment:
  - CORS=https://example.com,https://app.example.com
```

> ⚠️ Never use `CORS=*` in production

### Permission Management

```yaml
environment:
  - PUID=1000  # Run: id -u
  - PGID=1000  # Run: id -g
```

---

## MCP Client Setup

### VS Code (Cline/Roo-Cline)

`.vscode/settings.json`:

```json
{
  "mcp.servers": {
    "filesystem": {
      "url": "http://host-ip:8015/mcp",
      "transport": "http",
      "autoApprove": [
        "read_text_file",
        "read_media_file",
        "read_multiple_files",
        "write_file",
        "edit_file",
        "create_directory",
        "list_directory",
        "list_directory_with_sizes",
        "directory_tree",
        "move_file",
        "search_files",
        "get_file_info",
        "list_allowed_directories
      ]
    }
  }
}
```

### Claude Desktop

**Linux:** `~/.config/Claude/claude_desktop_config.json`  
**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`  
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "filesystem": {
      "transport": "http",
      "url": "http://localhost:8015/mcp"
    }
  }
}
```

### Cursor

`~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "filesystem": {
      "transport": "http",
      "url": "http://host-ip:8015/mcp"
    }
  }
}
```

### Windsurf

`.codeium/mcp_settings.json`:

```json
{
  "mcpServers": {
    "filesystem": {
      "transport": "http",
      "url": "http://host-ip:8015/mcp"
    }
  }
}
```

---

## Available Tools

### 📄 read_text_file
Read complete contents of a text file from the filesystem.

**Parameters:**
- `path` (string, required): Path to file
- `head` (number, optional): Read first N lines
- `tail` (number, optional): Read last N lines

**Example:** "Read config.json" or "Show me the first 50 lines of app.log"

---

### 🖼️ read_media_file
Read media files (images, videos, PDFs) as base64-encoded data with MIME type.

**Parameters:**
- `path` (string, required): Path to media file

**Example:** "Load the logo.png image" or "Read document.pdf"

---

### 📚 read_multiple_files
Read multiple files simultaneously. Failed reads won't stop the operation.

**Parameters:**
- `paths` (array, required): Array of file paths

**Example:** "Read all Python files in src/" or "Load config.json and settings.yaml"

---

### ✏️ write_file
Create new files or overwrite existing ones with specified content.

**Parameters:**
- `path` (string, required): File location
- `content` (string, required): File content

**Example:** "Create test.js with this code" or "Save output to results.txt"

---

### ✏️ edit_file
Make selective edits using pattern matching with whitespace normalization and indentation preservation.

**Parameters:**
- `path` (string, required): File to edit
- `edits` (array, required): Edit operations with `oldText` and `newText`
- `dryRun` (boolean, optional): Preview changes without applying

**Example:** "Replace 'oldFunc' with 'newFunc' in utils.js"

---

### 📁 create_directory
Create new directory with automatic parent directory creation.

**Parameters:**
- `path` (string, required): Directory path

**Example:** "Create folder structure: src/utils/helpers"

---

### 📋 list_directory
List directory contents with [FILE] or [DIR] prefixes.

**Parameters:**
- `path` (string, required): Directory path

**Example:** "List all files in the src directory"

---

### 📊 list_directory_with_sizes
List directory contents with detailed size information and sorting options.

**Parameters:**
- `path` (string, required): Directory path
- `sortBy` (string, optional): Sort by "name" or "size"

**Returns:** File listings with sizes, total files, directories, and combined size

**Example:** "Show file sizes in the uploads directory sorted by size"

---

### 🌳 directory_tree
Get recursive tree view of files and directories as JSON structure.

**Parameters:**
- `path` (string, required): Starting directory

**Returns:** JSON with `name`, `type`, and `children` (for directories)

**Example:** "Show the directory tree of the entire project"

---

### 📦 move_file
Move or rename files and directories. Fails if destination exists.

**Parameters:**
- `source` (string, required): Current path
- `destination` (string, required): New path

**Example:** "Rename config.old.json to config.json" or "Move test.js to tests/"

---

### 🔍 search_files
Recursively search for files/directories using glob patterns.

**Parameters:**
- `path` (string, required): Starting directory
- `pattern` (string, required): Search pattern (e.g., `*.js`, `**/*.py`)
- `excludePatterns` (array, optional): Patterns to exclude

**Example:** "Find all JavaScript files" or "Search for *.test.js excluding node_modules"

---

### ℹ️ get_file_info
Get detailed file/directory metadata.

**Parameters:**
- `path` (string, required): File or directory path

**Returns:** Size, creation time, modified time, access time, type, permissions

**Example:** "Get information about config.json" or "Check properties of logs/"

---

### 📂 list_allowed_directories
List all directories the server is allowed to access.

**Parameters:** None

**Returns:** List of accessible directories configured via PROJECT_DIRS

**Example:** "What directories can you access?" or "Show allowed directories"

---

## Advanced Usage

### Production Configuration

```yaml
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:stable
    restart: unless-stopped
    ports:
      - "8015:8015"
    volumes:
      - /opt/apps/web:/opt/apps/web
      - /opt/apps/api:/opt/apps/api:ro
      - /var/data:/var/data
    environment:
      PORT: "8015"
      PUID: "1000"
      PGID: "1000"
      TZ: UTC
      PROTOCOL: SHTTP
      CORS: "https://app.example.com"
      PROJECT_DIRS: "/opt/apps/web,/opt/apps/api,/var/data"
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "8015"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Development Setup

```yaml
volumes:
  - /home/user/code/frontend:/home/user/code/frontend
  - /home/user/code/backend:/home/user/code/backend
  - /home/user/code/shared:/home/user/code/shared
environment:
  PROJECT_DIRS: "/home/user/code/frontend,/home/user/code/backend,/home/user/code/shared"
  CORS: "*"
```

### Data Science Workspace

```yaml
volumes:
  - /mnt/datasets:/mnt/datasets:ro
  - /mnt/models:/mnt/models
  - /mnt/notebooks:/mnt/notebooks
  - /mnt/outputs:/mnt/outputs
environment:
  PROJECT_DIRS: "/mnt/datasets,/mnt/models,/mnt/notebooks,/mnt/outputs"
```

### Docker Network

```yaml
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:stable
    networks:
      - mcp-network
    volumes:
      - /var/app-data:/var/app-data
    environment:
      PROJECT_DIRS: /var/app-data
    
  ai-app:
    networks:
      - mcp-network
    environment:
      MCP_URL: http://filesystem-mcp:8015/mcp

networks:
  mcp-network:
```

### Nginx Reverse Proxy

```nginx
server {
    listen 80;
    server_name filesystem.example.com;
    
    location / {
        proxy_pass http://localhost:8015;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        
        client_max_body_size 100M;
    }
}
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filesystem-mcp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: filesystem-mcp
  template:
    metadata:
      labels:
        app: filesystem-mcp
    spec:
      containers:
      - name: filesystem-mcp
        image: mekayelanik/filesystem-mcp:stable
        ports:
        - containerPort: 8015
        env:
        - name: PROJECT_DIRS
          value: "/workspace,/data"
        - name: PORT
          value: "8015"
        volumeMounts:
        - name: workspace
          mountPath: /workspace
        - name: data
          mountPath: /data
      volumes:
      - name: workspace
        persistentVolumeClaim:
          claimName: workspace-pvc
      - name: data
        persistentVolumeClaim:
          claimName: data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: filesystem-mcp
spec:
  selector:
    app: filesystem-mcp
  ports:
  - port: 8015
    targetPort: 8015
```

---

## Troubleshooting

### Common Issues

**Container Won't Start**
```bash
docker logs filesystem-mcp
docker pull mekayelanik/filesystem-mcp:stable
docker restart filesystem-mcp
```

**No Valid Directories**
```bash
# Ensure PROJECT_DIRS paths exist and are mounted
docker run -d \
  -v /home/user/workspace:/home/user/workspace \
  -e PROJECT_DIRS=/home/user/workspace \
  mekayelanik/filesystem-mcp:stable

# Check mounted volumes
docker inspect filesystem-mcp | grep -A 10 Mounts
```

**Directory Not Accessible**
```bash
# Verify directory exists
docker exec filesystem-mcp ls -la /home/user/workspace

# Check PROJECT_DIRS
docker exec filesystem-mcp env | grep PROJECT_DIRS

# View validation logs
docker logs filesystem-mcp | grep "Validating"
```

**Permission Denied**
```bash
# Check UID/GID
id -u  # Use for PUID
id -g  # Use for PGID

# Fix ownership
sudo chown -R 1000:1000 /home/user/workspace
```

**Multiple Directories Not Working**
```bash
# IMPORTANT: Use dictionary format in docker-compose.yml
# ✅ CORRECT:
environment:
  PROJECT_DIRS: "/home/user/web,/home/user/api"
  
# ❌ WRONG: List format causes issues with commas
environment:
  - PROJECT_DIRS="/home/user/web,/home/user/api"

# Alternative: Use space separator
environment:
  PROJECT_DIRS: "/home/user/web /home/user/api"

# Verify all mounted
docker exec filesystem-mcp ls -la /home/user/web /home/user/api

# Check startup logs
docker logs filesystem-mcp | grep "Added:"
```

**Connection Refused**
```bash
# Check container status
docker ps | grep filesystem-mcp

# Test health
curl http://localhost:8015/healthz

# Check port
docker port filesystem-mcp
```

### Health Checks

```bash
# Basic health
curl http://localhost:8015/healthz

# Test MCP endpoint
curl http://localhost:8015/mcp

# List directories
curl -X POST http://localhost:8015/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_allowed_directories"},"id":1}'
```

### Debug Mode

```yaml
environment:
  - DEBUG_MODE=true

# Exec into container
docker exec -it filesystem-mcp /bin/bash

# Check directories
ls -la /workspace /data

# View environment
env | grep PROJECT_DIRS
```

### Validation Messages

```bash
# Expected startup output:
docker logs filesystem-mcp

# Output shows:
# Validating project directories...
#   ✓ Added: /home/user/workspace
#   ✓ Added: /var/data
# Configured 2 project director(y|ies):
#   - /home/user/workspace
#   - /var/data
```

---

## Migration Guide

### From Single to Multiple Directories

**Before:**
```yaml
volumes:
  - /home/user/workspace:/home/user/workspace
environment:
  PROJECT_DIRS: /home/user/workspace
```

**After:**
```yaml
volumes:
  - /home/user/projects/web:/home/user/projects/web
  - /home/user/projects/api:/home/user/projects/api
environment:
  PROJECT_DIRS: "/home/user/projects/web,/home/user/projects/api"
```

---

## Security Best Practices

1. **Never use `CORS=*` in production**
2. **Use read-only mounts** (`:ro`) for sensitive directories
3. **Limit PROJECT_DIRS** to necessary paths only
4. **Set appropriate PUID/PGID** matching host user
5. **Use reverse proxy** with authentication
6. **Monitor logs** for suspicious operations
7. **Keep image updated** regularly
8. **Validate paths** before mounting
9. **Implement rate limiting** at proxy level
10. **Regular backups** of important directories

---

## Performance Tips

1. **Local volumes** perform better than network mounts
2. **Avoid NFS/CIFS** for frequently accessed directories
3. **Use SSD storage** for better I/O performance
4. **Limit directory depth** when possible
5. **Regular cleanup** of temporary files
6. **Resource limits** prevent overconsumption

---

## Resources

### Documentation
- 📦 [NPM Package](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem)
- 📧 [GitHub Repository](https://github.com/mekayelanik/filesystem-mcp-docker)
- 🐳 [Docker Hub](https://hub.docker.com/r/mekayelanik/filesystem-mcp)

### MCP Resources
- 📘 [MCP Protocol](https://modelcontextprotocol.io)
- 🎓 [MCP Documentation](https://modelcontextprotocol.io/docs)

### Support
- [GitHub Issues](https://github.com/mekayelanik/filesystem-mcp-docker/issues)
- Check logs: `docker logs filesystem-mcp`
- Test health: `curl http://localhost:8015/healthz`

### Updating

```bash
# Docker Compose
docker compose pull && docker compose up -d

# Docker CLI
docker pull mekayelanik/filesystem-mcp:stable
docker stop filesystem-mcp && docker rm filesystem-mcp
# Re-run docker run command
```

---

## Examples

### Web Development

```yaml
volumes:
  - /home/user/dev/frontend:/home/user/dev/frontend
  - /home/user/dev/backend:/home/user/dev/backend
  - /home/user/dev/shared:/home/user/dev/shared
environment:
  PROJECT_DIRS: "/home/user/dev/frontend,/home/user/dev/backend,/home/user/dev/shared"
```

### Content Management

```yaml
volumes:
  - /var/www/html:/var/www/html:ro
  - /var/content:/var/content
  - /var/uploads:/var/uploads
environment:
  PROJECT_DIRS: "/var/www/html,/var/content,/var/uploads"
```

### CI/CD Pipeline

```yaml
volumes:
  - /ci/src:/ci/src:ro
  - /ci/build:/ci/build
  - /ci/dist:/ci/dist
environment:
  PROJECT_DIRS: "/ci/src,/ci/build,/ci/dist"
```

### Machine Learning

```yaml
volumes:
  - /ml/datasets:/ml/datasets:ro
  - /ml/models:/ml/models
  - /ml/experiments:/ml/experiments
  - /ml/outputs:/ml/outputs
environment:
  PROJECT_DIRS: "/ml/datasets,/ml/models,/ml/experiments,/ml/outputs"
```

---

## FAQ

**Q: Can I use environment variables in PROJECT_DIRS?**  
A: No, PROJECT_DIRS must contain literal paths. Set them in your compose file.

**Q: What separators are supported?**  
A: Comma (`,`) or space (` `). Use quotes for space-separated paths.

**Q: Can I mount nested directories?**  
A: Yes, but only specify the directories you need access to in PROJECT_DIRS.

**Q: Does the server follow symlinks?**  
A: Symlinks within PROJECT_DIRS are followed, but not outside.

**Q: How many directories can I configure?**  
A: No hard limit, but keep it reasonable for performance.

**Q: Can I change PROJECT_DIRS without recreating the container?**  
A: No, you must restart the container with new environment variables.

---

## License

GPL License - See [LICENSE](https://raw.githubusercontent.com/MekayelAnik/filesystem-mcp-docker/refs/heads/main/LICENSE)

**Disclaimer:** Unofficial Docker image for [@modelcontextprotocol/server-filesystem](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem). Users responsible for proper security configuration.

---

<div align="center">

[Report Bug](https://github.com/mekayelanik/filesystem-mcp-docker/issues) • [Request Feature](https://github.com/mekayelanik/filesystem-mcp-docker/issues) • [Contribute](https://github.com/mekayelanik/filesystem-mcp-docker/pulls)

</div>