# Filesystem MCP Server
### Multi-Architecture Docker Image for Distributed Deployment

<div align="left">

<img alt="filesystem-mcp" src="https://img.shields.io/badge/Filesystem-MCP-4A90E2?style=for-the-badge&logo=files&logoColor=white" width="400">

[![Docker Pulls](https://img.shields.io/docker/pulls/mekayelanik/filesystem-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/filesystem-mcp)
[![Docker Stars](https://img.shields.io/docker/stars/mekayelanik/filesystem-mcp.svg?style=flat-square)](https://hub.docker.com/r/mekayelanik/filesystem-mcp)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://raw.githubusercontent.com/MekayelAnik/filesystem-mcp-docker/refs/heads/main/LICENSE)

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
- [Resources & Support](#resources--support)

---

## Overview

Filesystem MCP Server provides AI assistants with secure, controlled filesystem access capabilities. Read, write, edit, search, and manage files and directories within designated project folders. Seamlessly integrates with VS Code, Cursor, Windsurf, Claude Desktop, and any MCP-compatible client.

### Key Features

✨ **Comprehensive File Operations** - Read, write, edit, move, and search files  
📁 **Directory Management** - Create, list, and navigate directory structures  
🔒 **Secure & Sandboxed** - Access limited to mounted project directories  
🔍 **Advanced Search** - Pattern-based file search with regex support  
📊 **File Metadata** - Detailed file information and directory trees  
🚀 **Multiple Protocols** - HTTP, SSE, and WebSocket transport support  
🎯 **Zero Configuration** - Works out of the box with sensible defaults  
🔧 **Highly Customizable** - Fine-tune via environment variables  
💾 **Media Support** - Handle text and binary files seamlessly  
📈 **Health Monitoring** - Built-in health check endpoint

### Supported Architectures

| Architecture | Status | Notes |
|:-------------|:------:|:------|
| **x86-64** | ✅ Stable | Intel/AMD processors |
| **ARM64** | ✅ Stable | Raspberry Pi, Apple Silicon |

### Available Tags

| Tag | Stability | Use Case |
|:----|:---------:|:---------|
| `stable` | ⭐⭐⭐ | **Production (recommended)** |
| `latest` | ⭐⭐⭐ | Latest stable features |
| `1.x.x` | ⭐⭐⭐ | Version pinning |
| `beta` | ⚠️ | Testing only |

---

## Quick Start

### Prerequisites

- Docker Engine 23.0+
- Project directories to mount
- Network access for MCP communication

### Docker Compose (Recommended)

```yaml
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:stable
    container_name: filesystem-mcp
    restart: unless-stopped
    ports:
      - "8015:8015"
    volumes:
      - /path/to/project1:/projects/project1
      - /path/to/project2:/projects/project2
    environment:
      - PORT=8015
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Dhaka
      - PROTOCOL=SHTTP
      - CORS=*
```

**Deploy:**

```bash
docker compose up -d
docker compose logs -f filesystem-mcp
```

### Docker CLI

```bash
docker run -d \
  --name=filesystem-mcp \
  --restart=unless-stopped \
  -p 8015:8015 \
  -v /path/to/project:/projects/myproject \
  -e PORT=8015 \
  -e PUID=1000 \
  -e PGID=1000 \
  -e PROTOCOL=SHTTP \
  -e CORS=* \
  mekayelanik/filesystem-mcp:stable
```

### Access Endpoints

| Protocol | Endpoint | Use Case |
|:---------|:---------|:---------|
| **HTTP** | `http://host-ip:8015/mcp` | **Recommended** |
| **SSE** | `http://host-ip:8015/sse` | Real-time streaming |
| **WebSocket** | `ws://host-ip:8015/message` | Bidirectional |
| **Health** | `http://host-ip:8015/healthz` | Monitoring |

> ⏱️ Server ready in 5-10 seconds after container start

---

## Configuration

### Environment Variables

#### Core Settings

| Variable | Default | Description |
|:---------|:-------:|:------------|
| `PORT` | `8015` | Server port (1-65535) |
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `Asia/Dhaka` | Container timezone |
| `PROTOCOL` | `SHTTP` | Transport protocol |
| `CORS` | _(none)_ | Cross-Origin configuration |

#### Advanced Settings

| Variable | Default | Description |
|:---------|:-------:|:------------|
| `DEBUG_MODE` | `false` | Enable debug mode (`true`, `false`, `1`, `yes`) |

### Volume Mounting

**Critical:** You MUST mount at least one directory to `/projects`. The container will exit if `/projects` is empty.

```yaml
volumes:
  # Single project
  - /home/user/myproject:/projects/myproject

  # Multiple projects
  - /home/user/web-app:/projects/web-app
  - /home/user/api:/projects/api
  - /home/user/docs:/projects/docs

  # Entire workspace
  - /home/user/workspace:/projects
```

### Protocol Configuration

```yaml
# HTTP/Streamable HTTP (Recommended)
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
# Development - Allow all origins
environment:
  - CORS=*

# Production - Specific domains
environment:
  - CORS=https://example.com,https://app.example.com

# Mixed domains and IPs
environment:
  - CORS=https://example.com,192.168.1.100:3000,/.*\.myapp\.com$/

# Regex patterns
environment:
  - CORS=/^https:\/\/.*\.example\.com$/
```

> ⚠️ **Security:** Never use `CORS=*` in production environments

### Permission Management

The container runs as a non-root user with configurable UID/GID:

```yaml
environment:
  # Match your host user ID
  - PUID=1000  # Run: id -u
  - PGID=1000  # Run: id -g
```

**Finding your UID/GID:**
```bash
# Linux/macOS
id -u  # Shows your UID
id -g  # Shows your GID

# Use these values for PUID/PGID
```

---

## MCP Client Setup

### Transport Compatibility

| Client | HTTP | SSE | WebSocket | Recommended |
|:-------|:----:|:---:|:---------:|:------------|
| **VS Code (Cline/Roo-Cline)** | ✅ | ✅ | ❌ | HTTP |
| **Claude Desktop** | ✅ | ✅ | ⚠️* | HTTP |
| **Cursor** | ✅ | ✅ | ⚠️* | HTTP |
| **Windsurf** | ✅ | ✅ | ⚠️* | HTTP |

> ⚠️ *WebSocket support is experimental

### VS Code (Cline/Roo-Cline)

Add to `.vscode/settings.json`:

```json
{
  "mcp.servers": {
    "filesystem": {
      "url": "http://host-ip:8015/mcp",
      "transport": "http",
      "autoApprove": [
        "filesystem_read_text_file",
        "filesystem_read_media_file",
        "filesystem_read_multiple_files",
        "filesystem_write_file",
        "filesystem_edit_file",
        "filesystem_create_directory",
        "filesystem_list_directory",
        "filesystem_list_directory_with_sizes",
        "filesystem_directory_tree",
        "filesystem_move_file",
        "filesystem_search_files",
        "filesystem_get_file_info",
        "filesystem_list_allowed_directories"
      ]
    }
  }
}
```

### Claude Desktop

**Config Locations:**
- **Linux:** `~/.config/Claude/claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

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

Add to `~/.cursor/mcp.json`:

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

### Windsurf (Codeium)

Add to `.codeium/mcp_settings.json`:

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

### Claude Code

Add to `~/.config/claude-code/mcp_config.json`:

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

Or configure via CLI:

```bash
claude-code config mcp add filesystem \
  --transport http \
  --url http://localhost:8015/mcp
```

### GitHub Copilot CLI

Add to `~/.github-copilot/mcp.json`:

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

Or use environment variable:

```bash
export GITHUB_COPILOT_MCP_SERVERS='{"filesystem":{"transport":"http","url":"http://localhost:8015/mcp"}}'
```

---

## Available Tools

### 📄 filesystem_read_text_file
Read complete contents of a text file from the filesystem.

**Parameters:**
- `path` (string, required): Path to the file (relative to allowed directories)

**Use Cases:**
- Reading configuration files
- Analyzing source code
- Processing log files
- Reading documentation

**Example Prompts:**
- "Read the contents of /projects/myapp/config.json"
- "Show me the README.md file"
- "What's in the main.py file?"

---

### 🖼️ filesystem_read_media_file
Read media files (images, videos, PDFs) and return as base64-encoded data.

**Parameters:**
- `path` (string, required): Path to the media file

**Use Cases:**
- Processing images
- Analyzing PDFs
- Handling binary files
- Media file inspection

**Example Prompts:**
- "Read the logo.png image"
- "Show me the contents of document.pdf"
- "Load the profile picture"

---

### 📚 filesystem_read_multiple_files
Read multiple files simultaneously with efficient batch processing.

**Parameters:**
- `paths` (array, required): Array of file paths to read

**Use Cases:**
- Comparing multiple files
- Batch file processing
- Project structure analysis
- Multi-file refactoring

**Example Prompts:**
- "Read all Python files in the src directory"
- "Show me config.json and settings.yaml"
- "Load all markdown files from docs/"

---

### ✍️ filesystem_write_file
Create new files or overwrite existing ones with specified content.

**Parameters:**
- `path` (string, required): Path where the file should be written
- `content` (string, required): Content to write to the file

**Use Cases:**
- Creating new files
- Saving generated code
- Writing configuration files
- Updating documentation

**Example Prompts:**
- "Create a new file called test.js with this code"
- "Write this configuration to config.yaml"
- "Save this content to output.txt"

---

### ✏️ filesystem_edit_file
Make selective edits to files using advanced pattern matching and replacement.

**Parameters:**
- `path` (string, required): Path to the file to edit
- `edits` (array, required): Array of edit operations
- `dryRun` (boolean, optional): Preview changes without applying

**Edit Operations:**
- `oldText` (string, required): Text to search for (supports regex)
- `newText` (string, required): Replacement text

**Use Cases:**
- Refactoring code
- Updating configurations
- Fixing bugs across files
- Batch text replacements

**Example Prompts:**
- "Replace all instances of 'oldFunc' with 'newFunc' in utils.js"
- "Update the version number in package.json"
- "Change the API endpoint in config.js"

---

### 📁 filesystem_create_directory
Create new directories with full path support (creates parent directories automatically).

**Parameters:**
- `path` (string, required): Path of the directory to create

**Use Cases:**
- Setting up project structure
- Creating organized folder hierarchies
- Preparing build directories
- Organizing file outputs

**Example Prompts:**
- "Create a new directory called 'components'"
- "Make a folder structure: src/utils/helpers"
- "Create the build/output directory"

---

### 📋 filesystem_list_directory
List contents of a directory with basic file information.

**Parameters:**
- `path` (string, required): Path to the directory to list

**Use Cases:**
- Exploring project structure
- Finding specific files
- Directory content inspection
- File organization review

**Example Prompts:**
- "List all files in the src directory"
- "Show me what's in the components folder"
- "What files are in the root directory?"

---

### 📊 filesystem_list_directory_with_sizes
List directory contents with detailed size information for each file.

**Parameters:**
- `path` (string, required): Path to the directory

**Use Cases:**
- Analyzing disk usage
- Finding large files
- Project size management
- Storage optimization

**Example Prompts:**
- "Show file sizes in the uploads directory"
- "List all files with their sizes in /projects/data"
- "What are the largest files in this folder?"

---

### 🌳 filesystem_directory_tree
Generate a hierarchical tree view of directory structure and contents.

**Parameters:**
- `path` (string, required): Root directory path for the tree

**Use Cases:**
- Visualizing project structure
- Documentation generation
- Architecture understanding
- Project overview

**Example Prompts:**
- "Show me the directory tree of the entire project"
- "Generate a tree view of the src folder"
- "Display the file structure of /projects/myapp"

---

### 🔄 filesystem_move_file
Move or rename files and directories safely.

**Parameters:**
- `source` (string, required): Current file/directory path
- `destination` (string, required): New file/directory path

**Use Cases:**
- Renaming files
- Reorganizing project structure
- Moving files between directories
- Batch file organization

**Example Prompts:**
- "Rename config.old.json to config.json"
- "Move test.js to the tests directory"
- "Relocate utils.py to src/helpers/"

---

### 🔍 filesystem_search_files
Search for files using glob patterns with powerful pattern matching.

**Parameters:**
- `path` (string, required): Directory to search in
- `pattern` (string, required): Glob pattern (e.g., "*.js", "**/*.py")
- `excludePatterns` (array, optional): Patterns to exclude

**Pattern Examples:**
- `*.js` - All JavaScript files in directory
- `**/*.py` - All Python files recursively
- `src/**/*.test.js` - All test files in src

**Use Cases:**
- Finding files by extension
- Locating test files
- Searching for specific patterns
- Project-wide file discovery

**Example Prompts:**
- "Find all JavaScript files in the project"
- "Search for all test files"
- "Locate all markdown files recursively"

---

### ℹ️ filesystem_get_file_info
Get detailed metadata about files and directories.

**Parameters:**
- `path` (string, required): Path to the file or directory

**Returns:**
- Size, type, permissions
- Creation and modification times
- File attributes

**Use Cases:**
- File metadata inspection
- Checking file properties
- Verifying file existence
- Permission validation

**Example Prompts:**
- "Get information about config.json"
- "Show me details of the logs directory"
- "Check the properties of index.html"

---

### 📍 filesystem_list_allowed_directories
List all directories that the MCP server has access to.

**Use Cases:**
- Discovering available project directories
- Verifying access permissions
- Understanding server scope
- Configuration validation

**Example Prompts:**
- "What directories can you access?"
- "Show me all allowed directories"
- "List available project folders"

---

## Advanced Usage

### Production Configuration

```yaml
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:stable
    container_name: filesystem-mcp
    restart: unless-stopped
    ports:
      - "8015:8015"
    volumes:
      - /opt/projects/web-app:/projects/web-app:ro  # Read-only
      - /opt/projects/api:/projects/api
      - /var/log/apps:/projects/logs:ro
    environment:
      # Core settings
      - PORT=8015
      - PUID=1000
      - PGID=1000
      - TZ=UTC
      - PROTOCOL=SHTTP
      
      # Security
      - CORS=https://app.example.com,https://admin.example.com
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    
    # Health check
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "8015"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

### Read-Only Access

Protect sensitive directories from modifications:

```yaml
volumes:
  - /path/to/source:/projects/source:ro
  - /path/to/configs:/projects/configs:ro
  - /path/to/logs:/projects/logs:ro
```

### Multiple Project Workspaces

```yaml
volumes:
  # Client projects
  - /home/user/clients/acme:/projects/acme
  - /home/user/clients/techcorp:/projects/techcorp
  
  # Personal projects
  - /home/user/personal/blog:/projects/blog
  - /home/user/personal/scripts:/projects/scripts
  
  # Shared resources
  - /home/user/shared/templates:/projects/templates:ro
  - /home/user/shared/assets:/projects/assets:ro
```

### Docker Network Setup

```yaml
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:stable
    container_name: filesystem-mcp
    networks:
      - mcp-network
    volumes:
      - ./projects:/projects
    environment:
      - PORT=8015
      - PROTOCOL=SHTTP
    
  ai-application:
    image: ai-app:latest
    networks:
      - mcp-network
    environment:
      - FILESYSTEM_MCP_URL=http://filesystem-mcp:8015/mcp

networks:
  mcp-network:
    driver: bridge
```

### Reverse Proxy Setup

#### Nginx

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
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts for file operations
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        
        # Larger buffer for file content
        client_max_body_size 100M;
    }
}
```

#### Traefik

```yaml
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:stable
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.filesystem-mcp.rule=Host(`filesystem.example.com`)"
      - "traefik.http.routers.filesystem-mcp.entrypoints=websecure"
      - "traefik.http.routers.filesystem-mcp.tls.certresolver=myresolver"
      - "traefik.http.services.filesystem-mcp.loadbalancer.server.port=8015"
```

---

## Troubleshooting

### Pre-Flight Checklist

- ✅ Docker 23.0+
- ✅ Port 8015 available
- ✅ At least one volume mounted to `/projects`
- ✅ Correct PUID/PGID for file permissions
- ✅ Latest stable image

### Common Issues

**Container Won't Start**
```bash
# Check logs
docker logs filesystem-mcp

# Pull latest image
docker pull mekayelanik/filesystem-mcp:stable

# Restart container
docker restart filesystem-mcp
```

**"ERROR: /projects directory is empty!"**
```bash
# You must mount at least one directory
docker run -d \
  --name filesystem-mcp \
  -v /path/to/your/project:/projects/myproject \
  mekayelanik/filesystem-mcp:stable
```

**Permission Denied Errors**
```bash
# Check your user ID
id -u  # Use this for PUID
id -g  # Use this for PGID

# Update environment variables
-e PUID=1000 \
-e PGID=1000
```

**Cannot Read/Write Files**
```bash
# Check volume mount permissions
ls -la /path/to/mounted/directory

# Fix ownership if needed
sudo chown -R 1000:1000 /path/to/mounted/directory
```

**Connection Refused**
```bash
# Verify container is running
docker ps | grep filesystem-mcp

# Check port binding
docker port filesystem-mcp

# Test health endpoint
curl http://localhost:8015/healthz
```

**CORS Errors**
```yaml
# Development - allow all
environment:
  - CORS=*

# Production - specific origins
environment:
  - CORS=https://yourdomain.com
```

**Debug Mode**
```yaml
# Enable debug mode
environment:
  - DEBUG_MODE=true

# Container will pause with nano installed
docker exec -it filesystem-mcp /bin/bash
```

### Health Check Testing

```bash
# Basic health check
curl http://localhost:8015/healthz

# Test MCP endpoint
curl http://localhost:8015/mcp

# List server capabilities
curl -X POST http://localhost:8015/mcp \
  -H "Content-Type: application/json" \
  -d '{"method":"tools/list"}'
```

### Checking Mounted Directories

```bash
# View mounted directories
docker exec filesystem-mcp ls -la /projects/

# Check specific directory contents
docker exec filesystem-mcp ls -la /projects/myproject/

# Verify permissions
docker exec filesystem-mcp stat /projects/myproject/
```

---

## Resources & Support

### Documentation
- 📦 [NPM Package](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem)
- 🔧 [GitHub Repository](https://github.com/mekayelanik/filesystem-mcp)
- 🐳 [Docker Hub](https://hub.docker.com/r/mekayelanik/filesystem-mcp)

### MCP Resources
- 📘 [MCP Protocol Specification](https://modelcontextprotocol.io)
- 🎓 [MCP Documentation](https://modelcontextprotocol.io/docs)
- 💬 [MCP Community](https://discord.gg/mcp)

### Getting Help

**Docker Image Issues:**
- [GitHub Issues](https://github.com/mekayelanik/filesystem-mcp/issues)
- [Discussions](https://github.com/mekayelanik/filesystem-mcp/discussions)

**General Questions:**
- Check logs: `docker logs filesystem-mcp`
- Test health: `curl http://localhost:8015/healthz`
- Review configuration in this README

### Updating

```bash
# Docker Compose
docker compose pull
docker compose up -d

# Docker CLI
docker pull mekayelanik/filesystem-mcp:stable
docker stop filesystem-mcp
docker rm filesystem-mcp
# Re-run your docker run command
```

### Version Pinning

```yaml
# Use specific version
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:1.0.0

# Or use stable tag (recommended)
services:
  filesystem-mcp:
    image: mekayelanik/filesystem-mcp:stable
```

---

## Security Best Practices

1. **Never use `CORS=*` in production**
2. **Use read-only mounts** for sensitive directories (`:ro`)
3. **Set appropriate PUID/PGID** to match your user
4. **Limit mounted directories** to only what's needed
5. **Use reverse proxy** with authentication in production
6. **Monitor logs** for suspicious file operations
7. **Keep Docker image updated**
8. **Use specific version tags** for production
9. **Implement file size limits** at reverse proxy level
10. **Regular backup** of mounted project directories

---

## Performance Tips

### Resource Allocation

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
    reservations:
      cpus: '0.5'
      memory: 256M
```

### Optimize for Large Projects

- Use `.dockerignore` to exclude unnecessary files
- Mount only active project directories
- Consider using read-only mounts where possible
- Regular cleanup of temporary files

---

## License

Docker Image: GPL License - See [LICENSE](https://raw.githubusercontent.com/MekayelAnik/filesystem-mcp-docker/refs/heads/main/LICENSE) for details.

**Disclaimer:** Unofficial Docker image for [@modelcontextprotocol/server-filesystem](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem). Users are responsible for ensuring proper file permissions and security of mounted directories.

---

<div align="center">

[Report docker image related Bug](https://github.com/mekayelanik/filesystem-mcp/issues) • [Request Feature](https://github.com/mekayelanik/filesystem-mcp/issues) • [Contribute](https://github.com/mekayelanik/filesystem-mcp/pulls)

</div>