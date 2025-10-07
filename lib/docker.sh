#!/bin/bash

# SafeClaude Docker Command Builder
# Constructs docker run commands with proper volume mounting and options

# Use username in image name to prevent namespace collisions on shared systems
IMAGE_NAME="safeclaude-$(whoami)/claude-sandbox"

# Build docker run command
# Usage: build_docker_command <project_name> <repo_url> <key_path> <instructions_file> <options>
# Options: --no-network, --persist, --detach, --name <container_name>, --host-config, --no-host-config,
#          --use-host-prompt=, --use-host-agents=, --use-host-commands=
build_docker_command() {
    local project_name="$1"
    local repo_url="$2"
    local key_path="$3"
    local instructions_file="$4"
    shift 4

    local enable_network=true
    local enable_persist=false
    local detach=false
    local container_name=""
    local enable_host_config=true  # Default: copy host config
    local copy_prompt=true
    local copy_agents=true
    local copy_commands=true

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-network)
                enable_network=false
                shift
                ;;
            --persist)
                enable_persist=true
                shift
                ;;
            --detach)
                detach=true
                shift
                ;;
            --name)
                container_name="$2"
                shift 2
                ;;
            --host-config)
                enable_host_config=true
                shift
                ;;
            --no-host-config)
                enable_host_config=false
                copy_prompt=false
                copy_agents=false
                copy_commands=false
                shift
                ;;
            --use-host-prompt=*)
                local value="${1#*=}"
                # Normalize boolean value
                value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
                if [[ "$value" == "true" ]] || [[ "$value" == "yes" ]] || [[ "$value" == "1" ]]; then
                    copy_prompt="true"
                else
                    copy_prompt="false"
                fi
                shift
                ;;
            --use-host-agents=*)
                local value="${1#*=}"
                # Normalize boolean value
                value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
                if [[ "$value" == "true" ]] || [[ "$value" == "yes" ]] || [[ "$value" == "1" ]]; then
                    copy_agents="true"
                else
                    copy_agents="false"
                fi
                shift
                ;;
            --use-host-commands=*)
                local value="${1#*=}"
                # Normalize boolean value
                value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
                if [[ "$value" == "true" ]] || [[ "$value" == "yes" ]] || [[ "$value" == "1" ]]; then
                    copy_commands="true"
                else
                    copy_commands="false"
                fi
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Generate container name if not provided
    if [ -z "$container_name" ]; then
        if [ "$detach" = true ]; then
            # Background containers need stable names
            echo "Error: --detach requires --name <container-name>" >&2
            return 1
        else
            # Foreground containers get unique auto-generated names
            container_name="safeclaude-${project_name}-$(date +%s)-$$"
        fi
    else
        # Add prefix if not already present
        if [[ ! "$container_name" =~ ^safeclaude- ]]; then
            container_name="safeclaude-${project_name}-${container_name}"
        fi
    fi

    # Start building docker args array
    local docker_args=("run")

    # Remove container on exit (unless detached)
    if [ "$detach" = false ]; then
        docker_args+=("--rm")
    fi

    # Interactive TTY (unless detached)
    if [ "$detach" = false ]; then
        docker_args+=("-it")
    else
        docker_args+=("-d")
    fi

    # Container name
    docker_args+=("--name" "$container_name")

    # Mount deploy key (read-only) for node user
    docker_args+=("-v" "$key_path:/home/node/.ssh/id_ed25519:ro")

    # Mount host ~/.claude/ directory if host-config is enabled (read-only)
    # Copies: CLAUDE.md, agents/, commands/ (via startup script)
    # Skips: config.json, mcp_config.json (security/compatibility reasons)
    # TODO: Future enhancement - support MCP tools (requires running MCP servers in container)
    if [ "$enable_host_config" = true ] && [ -d "$HOME/.claude" ]; then
        docker_args+=("-v" "$HOME/.claude:/tmp/host_claude:ro")
    fi

    # Mount sandbox instructions file if it exists (read-only)
    if [ -f "$instructions_file" ]; then
        docker_args+=("-v" "$instructions_file:/tmp/sandbox_instructions.md:ro")
    fi

    # Pass Anthropic API key if set (optional - Claude Code can use subscription auth)
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        docker_args+=("-e" "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
    fi

    # Pass repository URL as environment variable (SECURITY: prevents command injection)
    docker_args+=("-e" "REPO_URL=$repo_url")

    # Pass host config copy flags as environment variables
    docker_args+=("-e" "USE_HOST_PROMPT=$copy_prompt")
    docker_args+=("-e" "USE_HOST_AGENTS=$copy_agents")
    docker_args+=("-e" "USE_HOST_COMMANDS=$copy_commands")

    # Persistent volumes (optional)
    if [ "$enable_persist" = true ]; then
        docker_args+=("-v" "safeclaude-${project_name}-config:/home/node/.claude")
        docker_args+=("-v" "safeclaude-${project_name}-history:/commandhistory")
    fi

    # Network isolation (default: enabled, required for git operations)
    if [ "$enable_network" = false ]; then
        docker_args+=("--network" "none")
    fi

    # Image name
    docker_args+=("$IMAGE_NAME")

    # Startup script (only for foreground)
    if [ "$detach" = false ]; then
        docker_args+=("bash" "-c" "
set -e

# Fix ownership of .claude directory (volume may be owned by root)
sudo chown -R node:node /home/node/.claude 2>/dev/null || true

# Add GitHub to known hosts
ssh-keyscan github.com >> /home/node/.ssh/known_hosts 2>/dev/null

# Copy host Claude config if available
if [ -d /tmp/host_claude ]; then
    echo 'Copying host Claude configuration...'
    mkdir -p /home/node/.claude

    # Copy CLAUDE.md if enabled and it exists
    if [ \"\$USE_HOST_PROMPT\" = \"true\" ] && [ -f /tmp/host_claude/CLAUDE.md ]; then
        cp /tmp/host_claude/CLAUDE.md /home/node/.claude/CLAUDE.md

        # Append SafeClaude sandbox instructions from file
        if [ -f /tmp/sandbox_instructions.md ]; then
            echo '' >> /home/node/.claude/CLAUDE.md
            cat /tmp/sandbox_instructions.md >> /home/node/.claude/CLAUDE.md
        fi

        echo '  ✓ Copied CLAUDE.md with sandbox instructions'
    fi

    # Copy agents/ directory if enabled and it exists
    if [ \"\$USE_HOST_AGENTS\" = \"true\" ] && [ -d /tmp/host_claude/agents ]; then
        cp -r /tmp/host_claude/agents /home/node/.claude/
        echo '  ✓ Copied agents/'
    fi

    # Copy commands/ directory if enabled and it exists
    if [ \"\$USE_HOST_COMMANDS\" = \"true\" ] && [ -d /tmp/host_claude/commands ]; then
        cp -r /tmp/host_claude/commands /home/node/.claude/
        echo '  ✓ Copied commands/'
    fi

    echo ''
fi

echo 'Cloning repository...'
if ! git clone \"\$REPO_URL\" repo 2>&1; then
    echo ''
    echo 'Error: Failed to clone repository'
    echo 'This might be because:'
    echo '  1. The deploy key is not added to GitHub'
    echo '  2. The repository URL is incorrect'
    echo '  3. Network access is disabled (use --network flag)'
    echo ''
    exit 1
fi

cd repo

echo ''
echo 'Repository cloned successfully!'
echo ''
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo 'Starting Claude Code with bypassed permissions...'
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo ''

# Launch Claude Code with bypassed permissions
exec claude --dangerously-skip-permissions
")
    else
        # For background containers, include host config copy
        docker_args+=("bash" "-c" "
set -e

# Fix ownership of .claude directory (volume may be owned by root)
sudo chown -R node:node /home/node/.claude 2>/dev/null || true

ssh-keyscan github.com >> /home/node/.ssh/known_hosts 2>/dev/null

# Copy host Claude config if available
if [ -d /tmp/host_claude ]; then
    mkdir -p /home/node/.claude

    # Copy based on environment flags
    if [ \"\$USE_HOST_PROMPT\" = \"true\" ] && [ -f /tmp/host_claude/CLAUDE.md ]; then
        cp /tmp/host_claude/CLAUDE.md /home/node/.claude/CLAUDE.md

        # Append SafeClaude sandbox instructions from file
        if [ -f /tmp/sandbox_instructions.md ]; then
            echo '' >> /home/node/.claude/CLAUDE.md
            cat /tmp/sandbox_instructions.md >> /home/node/.claude/CLAUDE.md
        fi
    fi

    [ \"\$USE_HOST_AGENTS\" = \"true\" ] && [ -d /tmp/host_claude/agents ] && cp -r /tmp/host_claude/agents /home/node/.claude/ || true
    [ \"\$USE_HOST_COMMANDS\" = \"true\" ] && [ -d /tmp/host_claude/commands ] && cp -r /tmp/host_claude/commands /home/node/.claude/ || true
fi

# Clone repository with error handling
if ! git clone \"\$REPO_URL\" repo 2>&1; then
    echo '' >&2
    echo 'FATAL: Failed to clone repository' >&2
    echo 'Possible causes:' >&2
    echo '  - Deploy key not added to GitHub' >&2
    echo '  - Repository URL is incorrect' >&2
    echo '  - Network access is disabled' >&2
    echo '' >&2
    sleep 5
    exit 1
fi

cd repo && exec claude --dangerously-skip-permissions
")
    fi

    # Export the array to global variable for caller
    SAFECLAUDE_DOCKER_ARGS=("${docker_args[@]}")
}

# Execute docker command from global array
# Usage: execute_docker_command (reads from SAFECLAUDE_DOCKER_ARGS)
execute_docker_command() {
    if [ ${#SAFECLAUDE_DOCKER_ARGS[@]} -eq 0 ]; then
        echo "Error: No docker arguments available" >&2
        return 1
    fi

    docker "${SAFECLAUDE_DOCKER_ARGS[@]}"
}
