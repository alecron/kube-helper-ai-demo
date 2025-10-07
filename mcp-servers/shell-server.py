#!/usr/bin/env python3
"""
Custom MCP Shell Server for Workshop
Allows execution of shell commands with basic safety restrictions.
Intentionally vulnerable for educational purposes.
"""

import asyncio
import json
import logging
import subprocess
import sys
from typing import Any

# MCP SDK imports
try:
    from mcp.server import Server
    from mcp.server.stdio import stdio_server
    from mcp.types import Tool, TextContent
except ImportError:
    print("Error: mcp package not found. Install with: pip install mcp", file=sys.stderr)
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[logging.StreamHandler(sys.stderr)]
)
logger = logging.getLogger(__name__)

# Blocked commands (obviously destructive - workshop safety)
BLOCKED_COMMANDS = [
    'rm -rf /',
    'dd if=/dev/zero',
    'mkfs',
    'format',
    ':(){ :|:& };:',  # Fork bomb
    'chmod -R 777 /',
    'chown -R'
]

# Command timeout in seconds
COMMAND_TIMEOUT = 10


def is_command_blocked(command: str) -> bool:
    """Check if command contains obviously destructive patterns."""
    command_lower = command.lower().strip()

    for blocked in BLOCKED_COMMANDS:
        if blocked.lower() in command_lower:
            logger.warning(f"Blocked dangerous command: {command}")
            return True

    return False


async def execute_shell_command(command: str) -> dict[str, Any]:
    """
    Execute a shell command with timeout and basic safety checks.

    Args:
        command: The shell command to execute

    Returns:
        Dictionary with stdout, stderr, return_code, and error (if any)
    """
    logger.info(f"[SHELL EXECUTION] Command: {command}")

    # Check for blocked commands
    if is_command_blocked(command):
        return {
            "stdout": "",
            "stderr": "Error: This command is blocked for safety reasons.",
            "return_code": 1,
            "error": "Command blocked by safety filter"
        }

    try:
        # Execute command with timeout
        process = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            shell=True
        )

        # Wait for command to complete with timeout
        try:
            stdout, stderr = await asyncio.wait_for(
                process.communicate(),
                timeout=COMMAND_TIMEOUT
            )
        except asyncio.TimeoutError:
            process.kill()
            await process.wait()
            logger.warning(f"Command timed out after {COMMAND_TIMEOUT}s: {command}")
            return {
                "stdout": "",
                "stderr": f"Command timed out after {COMMAND_TIMEOUT} seconds",
                "return_code": 124,  # Standard timeout exit code
                "error": "timeout"
            }

        stdout_text = stdout.decode('utf-8', errors='replace')
        stderr_text = stderr.decode('utf-8', errors='replace')

        logger.info(f"[SHELL RESULT] Return code: {process.returncode}, "
                   f"Stdout length: {len(stdout_text)}, Stderr length: {len(stderr_text)}")

        return {
            "stdout": stdout_text,
            "stderr": stderr_text,
            "return_code": process.returncode,
            "error": None
        }

    except Exception as e:
        logger.error(f"Error executing command: {e}")
        return {
            "stdout": "",
            "stderr": str(e),
            "return_code": 1,
            "error": str(e)
        }


async def main():
    """Main entry point for the MCP shell server."""
    logger.info("Starting MCP Shell Server")

    # Create MCP server instance
    server = Server("shell-server")

    @server.list_tools()
    async def list_tools() -> list[Tool]:
        """List available tools."""
        return [
            Tool(
                name="execute_shell_command",
                description=(
                    "Execute a shell command in the container. "
                    "Returns stdout, stderr, and return code. "
                    "Commands have a 10-second timeout. "
                    "Obviously destructive commands are blocked for safety. "
                    "Use this for system inspection, debugging, and exploration."
                ),
                inputSchema={
                    "type": "object",
                    "properties": {
                        "command": {
                            "type": "string",
                            "description": "The shell command to execute (e.g., 'ls -la /home')"
                        }
                    },
                    "required": ["command"]
                }
            )
        ]

    @server.call_tool()
    async def call_tool(name: str, arguments: dict) -> list[TextContent]:
        """Handle tool execution requests."""
        if name != "execute_shell_command":
            raise ValueError(f"Unknown tool: {name}")

        command = arguments.get("command")
        if not command:
            raise ValueError("Missing required argument: command")

        # Execute the command
        result = await execute_shell_command(command)

        # Format output for the LLM
        output_parts = []

        if result["stdout"]:
            output_parts.append(f"STDOUT:\n{result['stdout']}")

        if result["stderr"]:
            output_parts.append(f"STDERR:\n{result['stderr']}")

        output_parts.append(f"Return Code: {result['return_code']}")

        if result["error"]:
            output_parts.append(f"Error: {result['error']}")

        response_text = "\n\n".join(output_parts)

        return [
            TextContent(
                type="text",
                text=response_text
            )
        ]

    # Run the server
    async with stdio_server() as (read_stream, write_stream):
        logger.info("MCP Shell Server ready - waiting for requests")
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options()
        )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as e:
        logger.error(f"Server error: {e}", exc_info=True)
        sys.exit(1)
