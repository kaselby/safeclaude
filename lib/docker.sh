#!/bin/bash

# SafeClaude Docker Command Builder
# Constructs docker run commands with proper volume mounting and options

# Use username in image name to prevent namespace collisions on shared systems
IMAGE_NAME="safeclaude-$(whoami)/claude-sandbox"

# Build docker run command
# Usage: build_docker_command <project_name> <repo_url> <key_path> <options>
# Options: --network, --persist, --detach, --name <container_name>
build_docker_command() {
    local project_name="$1"
    local repo_url="$2"
    local key_path="$3"
    shift 3

    local enable_network=false
    local enable_persist=false
    local detach=false
    local container_name=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --network)
                enable_network=true
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

    # Mount deploy key (read-only)
    docker_args+=("-v" "$key_path:/root/.ssh/id_rsa:ro")

    # Pass Anthropic API key
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        docker_args+=("-e" "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
    fi

    # Pass repository URL as environment variable (SECURITY: prevents command injection)
    docker_args+=("-e" "REPO_URL=$repo_url")

    # Persistent volumes (optional)
    if [ "$enable_persist" = true ]; then
        docker_args+=("-v" "safeclaude-${project_name}-config:/home/node/.claude")
        docker_args+=("-v" "safeclaude-${project_name}-history:/commandhistory")
    fi

    # Network isolation (default: isolated)
    if [ "$enable_network" = false ]; then
        docker_args+=("--network" "none")
    fi

    # Image name
    docker_args+=("$IMAGE_NAME")

    # Startup script (only for foreground)
    if [ "$detach" = false ]; then
        docker_args+=("bash" "-c" "cat <<'STARTUP_SCRIPT' | bash
set -e

# Add GitHub to known hosts
ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null

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

STARTUP_SCRIPT
")
    else
        # For background containers, simpler startup
        docker_args+=("bash" "-c" "
ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null
git clone \"\$REPO_URL\" repo 2>&1 && cd repo && claude --dangerously-skip-permissions
")
    fi

    # Export the array for use by caller
    printf '%s\0' "${docker_args[@]}"
}

# Execute docker command from array
# Usage: execute_docker_command <null-separated-args>
execute_docker_command() {
    local -a docker_args
    while IFS= read -r -d '' arg; do
        docker_args+=("$arg")
    done

    docker "${docker_args[@]}"
}
