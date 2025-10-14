#!/bin/bash

# SafeClaude Docker Command Builder
# Constructs docker run commands with proper volume mounting and options

# Use username in image name to prevent namespace collisions on shared systems
IMAGE_NAME="safeclaude-$(whoami)/claude-sandbox"

# Container working directory (must match: Dockerfile WORKDIR + startup script git clone location)
# See: Dockerfile:36 (WORKDIR /workspace), docker.sh:271 (git clone ... repo)
CONTAINER_WORKDIR="/workspace/repo"

# Build docker run command
# Usage: build_docker_command <project_name> <repo_url> <key_path> <instructions_file> <options>
# Options: --no-network, --persist, --detach, --name <container_name>, --host-config, --no-host-config,
#          --use-host-prompt=, --use-host-agents=, --use-host-commands=, --mount <host>:<container>[:<mode>]
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

    # Array to store custom mount specifications
    declare -a custom_mounts=()

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
            --mount)
                custom_mounts+=("$2")
                shift 2
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

    # Mount recovery directory for git bundle backups (read-write)
    local recovery_dir="$HOME/.safeclaude/recovery/$project_name"
    mkdir -p "$recovery_dir"
    docker_args+=("-v" "$recovery_dir:/recovery:rw")

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

    # Process custom mounts
    for mount_spec in "${custom_mounts[@]}"; do
        # Parse mount specification: host_path:container_path[:mode]
        local host_path container_path mount_mode

        # Split on colons
        IFS=':' read -ra mount_parts <<< "$mount_spec"

        if [ ${#mount_parts[@]} -lt 2 ]; then
            echo "Error: Invalid mount specification '$mount_spec'" >&2
            echo "Format: <host-path>:<container-path>[:<ro|rw>]" >&2
            return 1
        fi

        host_path="${mount_parts[0]}"
        container_path="${mount_parts[1]}"
        mount_mode="${mount_parts[2]:-ro}"  # Default to read-only

        # Expand tilde in host path
        host_path="${host_path/#\~/$HOME}"

        # Validate host path exists
        if [ ! -e "$host_path" ]; then
            echo "Error: Mount source does not exist: $host_path" >&2
            return 1
        fi

        # Validate mount mode
        if [[ "$mount_mode" != "ro" ]] && [[ "$mount_mode" != "rw" ]]; then
            echo "Error: Invalid mount mode '$mount_mode' (must be 'ro' or 'rw')" >&2
            return 1
        fi

        # Validate container path (must be absolute)
        if [[ ! "$container_path" =~ ^/ ]]; then
            echo "Error: Container path must be absolute: $container_path" >&2
            return 1
        fi

        # Add mount to docker args
        docker_args+=("-v" "$host_path:$container_path:$mount_mode")
    done

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

# Set up recovery system
CONTAINER_ID=\$(hostname | cut -c1-12)

# Validate container ID format (security: prevent path traversal)
if [[ ! \"\$CONTAINER_ID\" =~ ^[a-z0-9-]+$ ]]; then
    echo 'ERROR: Invalid container ID format' >&2
    exit 1
fi

SESSION_START_TIME=\$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Record session start ref and timestamp (handle empty repos)
git rev-parse HEAD 2>/dev/null > /recovery/.session-start-ref || echo '0000000000000000000000000000000000000000' > /recovery/.session-start-ref
echo \"\$SESSION_START_TIME\" > /recovery/.session-start-time

# Install post-commit hook for automatic bundle creation
cat > .git/hooks/post-commit << 'HOOK_EOF'
#!/bin/sh
# SafeClaude automatic recovery bundle creation

SESSION_START=\$(cat /recovery/.session-start-ref 2>/dev/null || echo HEAD)
CONTAINER_ID=\$(hostname | cut -c1-12)

# Validate container ID (security: prevent path traversal)
if [ -z \"\$CONTAINER_ID\" ] || ! echo \"\$CONTAINER_ID\" | grep -qE '^[a-z0-9-]+$'; then
    echo 'ERROR: Invalid container ID' >&2
    exit 1
fi

SESSION_START_TIME=\$(cat /recovery/.session-start-time 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)

# Create bundle with atomic write (security: prevent corruption on crash)
BUNDLE_TEMP=\"/recovery/.\${CONTAINER_ID}.bundle.tmp\"
BUNDLE_FINAL=\"/recovery/\${CONTAINER_ID}.bundle\"

if git bundle create \"\$BUNDLE_TEMP\" \${SESSION_START}..HEAD 2>/tmp/bundle-error.log; then
    mv -f \"\$BUNDLE_TEMP\" \"\$BUNDLE_FINAL\"
else
    # Log failure but don't fail the commit
    echo \"[\$(date)] Bundle creation failed for \${CONTAINER_ID}\" >> /recovery/.bundle-errors.log 2>/dev/null || true
    rm -f \"\$BUNDLE_TEMP\" 2>/dev/null || true
    exit 0
fi

# Count commits in this session
COMMIT_COUNT=\$(git rev-list --count \${SESSION_START}..HEAD 2>/dev/null || echo 0)

# Get branches containing HEAD
BRANCHES=\$(git branch --contains HEAD --format='%(refname:short)' | jq -R -s -c 'split(\"\\n\") | map(select(length > 0))' 2>/dev/null || echo '[]')

# Get last commit message
LAST_COMMIT=\$(git log -1 --pretty=format:%s 2>/dev/null || echo '')

# Create/update metadata JSON using jq (security: prevent injection in commit messages)
jq -n \\
    --arg cid \"\$CONTAINER_ID\" \\
    --arg start \"\$SESSION_START_TIME\" \\
    --arg update \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \\
    --argjson count \"\$COMMIT_COUNT\" \\
    --argjson branches \"\$BRANCHES\" \\
    --arg last \"\$LAST_COMMIT\" \\
    '{
      container_id: \$cid,
      session_start: \$start,
      last_update: \$update,
      commits: \$count,
      branches: \$branches,
      last_commit: \$last
    }' > \"/recovery/\${CONTAINER_ID}.json\" 2>/dev/null || true

chmod 644 \"/recovery/\${CONTAINER_ID}.json\" 2>/dev/null || true
HOOK_EOF

chmod +x .git/hooks/post-commit

echo ''
echo 'Repository cloned successfully!'
echo 'Recovery system enabled (bundles saved to ~/.safeclaude/recovery)'
echo ''
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo 'Starting Claude Code with bypassed permissions...'
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
echo ''
echo 'Tmux keybindings:'
echo '  Ctrl+B C    - Create new shell window'
echo '  Ctrl+B N    - Switch to next window'
echo '  Ctrl+B P    - Switch to previous window'
echo '  Ctrl+B D    - Detach (container keeps running)'
echo ''

# Launch Claude Code inside tmux session
# When you detach (Ctrl+B D), you'll return to a bash shell
# Type 'tmux attach -t claude' to reattach, or 'exit' to quit
# When you exit the shell, container auto-removes
tmux new-session -s claude claude --dangerously-skip-permissions

# After tmux exits (Claude closed or you detached), drop to shell
echo ''
echo 'Claude session ended or detached.'
echo 'You are now in a shell inside the container.'
echo ''
echo 'Commands:'
echo '  tmux attach -t claude  - Reattach to Claude session (if detached)'
echo '  exit                   - Exit container (auto-removes)'
echo ''

# Start interactive bash shell
exec /bin/bash
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

cd repo

# Set up recovery system
CONTAINER_ID=\$(hostname | cut -c1-12)

# Validate container ID format (security: prevent path traversal)
if [[ ! \"\$CONTAINER_ID\" =~ ^[a-z0-9-]+$ ]]; then
    echo 'ERROR: Invalid container ID format' >&2
    exit 1
fi

SESSION_START_TIME=\$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Record session start ref and timestamp (handle empty repos)
git rev-parse HEAD 2>/dev/null > /recovery/.session-start-ref || echo '0000000000000000000000000000000000000000' > /recovery/.session-start-ref
echo \"\$SESSION_START_TIME\" > /recovery/.session-start-time

# Install post-commit hook
cat > .git/hooks/post-commit << 'HOOK_EOF'
#!/bin/sh
SESSION_START=\$(cat /recovery/.session-start-ref 2>/dev/null || echo HEAD)
CONTAINER_ID=\$(hostname | cut -c1-12)

# Validate container ID (security: prevent path traversal)
if [ -z \"\$CONTAINER_ID\" ] || ! echo \"\$CONTAINER_ID\" | grep -qE '^[a-z0-9-]+$'; then
    echo 'ERROR: Invalid container ID' >&2
    exit 1
fi

SESSION_START_TIME=\$(cat /recovery/.session-start-time 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)

# Create bundle with atomic write (security: prevent corruption on crash)
BUNDLE_TEMP=\"/recovery/.\${CONTAINER_ID}.bundle.tmp\"
BUNDLE_FINAL=\"/recovery/\${CONTAINER_ID}.bundle\"

if git bundle create \"\$BUNDLE_TEMP\" \${SESSION_START}..HEAD 2>/tmp/bundle-error.log; then
    mv -f \"\$BUNDLE_TEMP\" \"\$BUNDLE_FINAL\"
else
    # Log failure but don't fail the commit
    echo \"[\$(date)] Bundle creation failed for \${CONTAINER_ID}\" >> /recovery/.bundle-errors.log 2>/dev/null || true
    rm -f \"\$BUNDLE_TEMP\" 2>/dev/null || true
    exit 0
fi

COMMIT_COUNT=\$(git rev-list --count \${SESSION_START}..HEAD 2>/dev/null || echo 0)
BRANCHES=\$(git branch --contains HEAD --format='%(refname:short)' | jq -R -s -c 'split(\"\\n\") | map(select(length > 0))' 2>/dev/null || echo '[]')
LAST_COMMIT=\$(git log -1 --pretty=format:%s 2>/dev/null || echo '')

# Create/update metadata JSON using jq (security: prevent injection in commit messages)
jq -n \\
    --arg cid \"\$CONTAINER_ID\" \\
    --arg start \"\$SESSION_START_TIME\" \\
    --arg update \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \\
    --argjson count \"\$COMMIT_COUNT\" \\
    --argjson branches \"\$BRANCHES\" \\
    --arg last \"\$LAST_COMMIT\" \\
    '{
      container_id: \$cid,
      session_start: \$start,
      last_update: \$update,
      commits: \$count,
      branches: \$branches,
      last_commit: \$last
    }' > \"/recovery/\${CONTAINER_ID}.json\" 2>/dev/null || true

chmod 644 \"/recovery/\${CONTAINER_ID}.json\" 2>/dev/null || true
HOOK_EOF

chmod +x .git/hooks/post-commit

exec claude --dangerously-skip-permissions
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
