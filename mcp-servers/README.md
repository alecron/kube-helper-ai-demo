# MCP Servers for Workshop

Custom Model Context Protocol (MCP) servers for the AI security workshop.

## Overview

This directory contains custom MCP servers that provide tools to the AI assistant:

- **shell-server.py**: Execute shell commands with safety restrictions

## Development Setup

### Using Nix (Recommended)

```bash
# Enter the development shell
nix develop

# Install MCP server dependencies
cd mcp-servers
uv pip install -e .
```

### Without Nix

```bash
# Install uv if not already installed
pip install uv

# Install dependencies
cd mcp-servers
uv pip install -e .
```

## Testing the Shell Server

```bash
# Run the server directly
python3 shell-server.py

# Test with a simple command (in another terminal)
echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | python3 shell-server.py
```

## MCP Server Details

### Shell Server

**Purpose**: Execute shell commands in the container for system exploration.

**Tools**:
- `execute_shell_command`: Run shell commands with timeout and basic safety checks

**Safety Features**:
- 10-second command timeout
- Blocked obviously destructive commands (rm -rf /, dd, mkfs, etc.)
- Logging all executions for Sysdig monitoring

**Configuration**:
```json
{
  "shell": {
    "command": "python3",
    "args": ["/app/mcp-servers/shell-server.py"]
  }
}
```

## Docker Integration

These MCP servers will be included in the MCPO container image and launched by the MCPO proxy.

## Workshop Context

These servers are intentionally designed with limited safety restrictions to demonstrate:
- How AI agents can access system resources
- The importance of proper RBAC and security boundaries
- Runtime detection with Sysdig
