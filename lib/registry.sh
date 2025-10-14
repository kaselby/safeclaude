#!/bin/bash

# SafeClaude Project Registry
# Manages the database of configured projects

SAFECLAUDE_DIR="$HOME/.safeclaude"
PROJECTS_FILE="$SAFECLAUDE_DIR/projects.json"
KEYS_DIR="$SAFECLAUDE_DIR/keys"

# Initialize SafeClaude directory structure
init_safeclaude_dir() {
    mkdir -p "$SAFECLAUDE_DIR"
    mkdir -p "$KEYS_DIR"

    # Create transfer directory with secure permissions (700 - owner only)
    mkdir -p "$SAFECLAUDE_DIR/transfer"
    chmod 700 "$SAFECLAUDE_DIR/transfer"

    # Create empty projects.json if it doesn't exist
    if [ ! -f "$PROJECTS_FILE" ]; then
        echo '{}' > "$PROJECTS_FILE"
    fi

    # Create empty config.json if it doesn't exist
    if [ ! -f "$SAFECLAUDE_DIR/config.json" ]; then
        cat > "$SAFECLAUDE_DIR/config.json" <<EOF
{
  "default_persist": false,
  "default_network": false,
  "auto_setup_branch_protection": true,
  "use_host_prompt": true,
  "use_host_agents": true,
  "use_host_commands": true,
  "sandbox_instructions_file": "$SAFECLAUDE_DIR/sandbox_instructions.md"
}
EOF
        chmod 600 "$SAFECLAUDE_DIR/config.json"
    fi
}

# Add a project to the registry
# Usage: add_project <name> <url> <owner_repo> <key_path> <default_branch>
add_project() {
    local name="$1"
    local url="$2"
    local owner_repo="$3"
    local key_path="$4"
    local default_branch="${5:-main}"

    init_safeclaude_dir

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Use jq to add/update the project with proper temp file handling
    trap "rm -f '$temp_file' 2>/dev/null" EXIT INT TERM
    local temp_file=$(mktemp "${PROJECTS_FILE}.tmp.XXXXXXXXXX")
    chmod 600 "$temp_file"

    if ! jq --arg name "$name" \
       --arg url "$url" \
       --arg owner_repo "$owner_repo" \
       --arg key_path "$key_path" \
       --arg default_branch "$default_branch" \
       --arg created "$timestamp" \
       --arg last_used "$timestamp" \
       '.[$name] = {
         "url": $url,
         "owner_repo": $owner_repo,
         "key_path": $key_path,
         "default_branch": $default_branch,
         "created_at": $created,
         "last_used": $last_used
       }' "$PROJECTS_FILE" > "$temp_file"; then
        echo "Error: Failed to update projects database" >&2
        rm -f "$temp_file"
        return 1
    fi

    mv -f "$temp_file" "$PROJECTS_FILE" || {
        rm -f "$temp_file"
        return 1
    }
}

# Get project info from registry
# Usage: get_project <name>
# Returns: JSON object with project info, or empty if not found
get_project() {
    local name="$1"

    if [ ! -f "$PROJECTS_FILE" ]; then
        echo "{}"
        return 1
    fi

    jq -r --arg name "$name" '.[$name] // {}' "$PROJECTS_FILE"
}

# Check if project exists
# Usage: project_exists <name>
# Returns: 0 if exists, 1 if not
project_exists() {
    local name="$1"
    local result=$(get_project "$name")

    if [ "$result" = "{}" ]; then
        return 1
    else
        return 0
    fi
}

# List all projects
# Usage: list_projects
list_projects() {
    if [ ! -f "$PROJECTS_FILE" ]; then
        echo "{}"
        return
    fi

    cat "$PROJECTS_FILE"
}

# Remove a project from registry
# Usage: remove_project <name>
remove_project() {
    local name="$1"

    if [ ! -f "$PROJECTS_FILE" ]; then
        return 1
    fi

    trap "rm -f '$temp_file' 2>/dev/null" EXIT INT TERM
    local temp_file=$(mktemp "${PROJECTS_FILE}.tmp.XXXXXXXXXX")
    chmod 600 "$temp_file"

    if ! jq --arg name "$name" 'del(.[$name])' "$PROJECTS_FILE" > "$temp_file"; then
        echo "Error: Failed to update projects database" >&2
        rm -f "$temp_file"
        return 1
    fi

    mv -f "$temp_file" "$PROJECTS_FILE" || {
        rm -f "$temp_file"
        return 1
    }
}

# Update last_used timestamp
# Usage: update_last_used <name>
update_last_used() {
    local name="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [ ! -f "$PROJECTS_FILE" ]; then
        return 1
    fi

    trap "rm -f '$temp_file' 2>/dev/null" EXIT INT TERM
    local temp_file=$(mktemp "${PROJECTS_FILE}.tmp.XXXXXXXXXX")
    chmod 600 "$temp_file"

    if ! jq --arg name "$name" \
       --arg last_used "$timestamp" \
       '.[$name].last_used = $last_used' "$PROJECTS_FILE" > "$temp_file"; then
        echo "Error: Failed to update projects database" >&2
        rm -f "$temp_file"
        return 1
    fi

    mv -f "$temp_file" "$PROJECTS_FILE" || {
        rm -f "$temp_file"
        return 1
    }
}

# Get project URL
# Usage: get_project_url <name>
get_project_url() {
    local name="$1"
    get_project "$name" | jq -r '.url // ""'
}

# Get project key path
# Usage: get_project_key_path <name>
get_project_key_path() {
    local name="$1"
    get_project "$name" | jq -r '.key_path // ""'
}

# Get project owner/repo
# Usage: get_project_owner_repo <name>
get_project_owner_repo() {
    local name="$1"
    get_project "$name" | jq -r '.owner_repo // ""'
}

# Set API key in config
# Usage: set_api_key <key>
set_api_key() {
    local api_key="$1"

    init_safeclaude_dir

    local config_file="$SAFECLAUDE_DIR/config.json"
    trap "rm -f '$temp_file' 2>/dev/null" EXIT INT TERM
    local temp_file=$(mktemp "${config_file}.tmp.XXXXXXXXXX")
    chmod 600 "$temp_file"

    if ! jq --arg key "$api_key" \
       '.anthropic_api_key = $key' "$config_file" > "$temp_file"; then
        echo "Error: Failed to update config" >&2
        rm -f "$temp_file"
        return 1
    fi

    mv -f "$temp_file" "$config_file" || {
        rm -f "$temp_file"
        return 1
    }

    chmod 600 "$config_file"
}

# Get API key from config
# Usage: get_api_key
# Returns: API key or empty string if not set
get_api_key() {
    local config_file="$SAFECLAUDE_DIR/config.json"

    if [ ! -f "$config_file" ]; then
        echo ""
        return
    fi

    jq -r '.anthropic_api_key // ""' "$config_file"
}

# Check if OAuth token is expired or expiring soon
# Usage: check_token_expiry [warn_days]
# Returns: 0 if valid, 1 if expired, 2 if expiring soon
check_token_expiry() {
    local warn_days="${1:-7}"  # Default: warn 7 days before expiry

    # Get token from environment or config
    local token="$ANTHROPIC_API_KEY"
    if [ -z "$token" ]; then
        token=$(get_api_key)
    fi

    # If no token, skip check (might be using browser auth)
    if [ -z "$token" ]; then
        return 0
    fi

    # Only check OAuth tokens (start with sk-ant-oat)
    if [[ ! "$token" =~ ^sk-ant-oat ]]; then
        return 0
    fi

    # Parse JWT token to extract expiry
    # OAuth tokens are JWTs: header.payload.signature
    local payload=$(echo "$token" | cut -d'.' -f2)

    # Decode base64 (handle URL-safe base64 with proper padding)
    # Convert URL-safe chars and add padding based on length
    payload=$(echo "$payload" | tr '_-' '/+')
    local len=${#payload}
    local padding=""
    case $((len % 4)) in
        2) padding="==" ;;
        3) padding="=" ;;
    esac
    local decoded=$(echo "${payload}${padding}" | base64 -d 2>/dev/null)

    if [ -z "$decoded" ]; then
        # Can't decode, skip check
        return 0
    fi

    # Extract expiry timestamp
    local exp=$(echo "$decoded" | jq -r '.exp // empty' 2>/dev/null)

    if [ -z "$exp" ]; then
        # No expiry field, skip check
        return 0
    fi

    # Validate exp is a positive integer (JWT allows floats, truncate them)
    exp=${exp%.*}  # Remove decimal part if present
    if ! [[ "$exp" =~ ^[0-9]+$ ]]; then
        # Not a valid integer, skip check
        return 0
    fi

    local now=$(date +%s)
    local warn_threshold=$((now + warn_days * 86400))

    if [ "$exp" -lt "$now" ]; then
        echo "Error: OAuth token has expired" >&2
        echo "" >&2
        echo "Generate a new token with:" >&2
        echo "  claude setup-token" >&2
        echo "" >&2
        echo "Then store it with:" >&2
        echo "  safeclaude config set-api-key 'sk-ant-oat...'" >&2
        echo "" >&2
        return 1
    elif [ "$exp" -lt "$warn_threshold" ]; then
        local days_left=$(( (exp - now) / 86400 ))
        echo "Warning: OAuth token expires in $days_left days" >&2
        echo "Generate a new token soon with: claude setup-token" >&2
        echo "" >&2
        return 2
    fi

    return 0
}

# Remove API key from config
# Usage: remove_api_key
remove_api_key() {
    local config_file="$SAFECLAUDE_DIR/config.json"

    if [ ! -f "$config_file" ]; then
        return 0
    fi

    trap "rm -f '$temp_file' 2>/dev/null" EXIT INT TERM
    local temp_file=$(mktemp "${config_file}.tmp.XXXXXXXXXX")
    chmod 600 "$temp_file"

    if ! jq 'del(.anthropic_api_key)' "$config_file" > "$temp_file"; then
        echo "Error: Failed to update config" >&2
        rm -f "$temp_file"
        return 1
    fi

    mv -f "$temp_file" "$config_file" || {
        rm -f "$temp_file"
        return 1
    }
}

# Get config value
# Usage: get_config_value <key> [default]
get_config_value() {
    local key="$1"
    local default="${2:-false}"
    local config_file="$SAFECLAUDE_DIR/config.json"

    if [ ! -f "$config_file" ]; then
        echo "$default"
        return
    fi

    local value=$(jq -r --arg key "$key" --arg default "$default" '.[$key] // $default' "$config_file")
    echo "$value"
}

# Set config value
# Usage: set_config_value <key> <value>
set_config_value() {
    local key="$1"
    local value="$2"

    init_safeclaude_dir

    local config_file="$SAFECLAUDE_DIR/config.json"
    trap "rm -f '$temp_file' 2>/dev/null" EXIT INT TERM
    local temp_file=$(mktemp "${config_file}.tmp.XXXXXXXXXX")
    chmod 600 "$temp_file"

    # Convert string boolean values to actual JSON booleans
    if [[ "$value" == "true" ]] || [[ "$value" == "false" ]]; then
        if ! jq --arg key "$key" --argjson val "$value" '.[$key] = $val' "$config_file" > "$temp_file"; then
            echo "Error: Failed to update config" >&2
            rm -f "$temp_file"
            return 1
        fi
    else
        if ! jq --arg key "$key" --arg val "$value" '.[$key] = $val' "$config_file" > "$temp_file"; then
            echo "Error: Failed to update config" >&2
            rm -f "$temp_file"
            return 1
        fi
    fi

    mv -f "$temp_file" "$config_file" || {
        rm -f "$temp_file"
        return 1
    }

    chmod 600 "$config_file"
}
