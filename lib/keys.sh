#!/bin/bash

# SafeClaude Deploy Key Management
# Generates and manages per-project SSH deploy keys

# Generate a deploy key for a project
# Usage: generate_deploy_key <project_name>
# Returns: path to private key
generate_deploy_key() {
    local project_name="$1"
    local key_dir="$KEYS_DIR/$project_name"

    # Create project key directory
    mkdir -p "$key_dir"

    local key_path="$key_dir/deploy_key"

    # Generate key if it doesn't exist
    if [ ! -f "$key_path" ]; then
        ssh-keygen -t ed25519 -f "$key_path" -N "" -C "safeclaude-$project_name" > /dev/null 2>&1
        chmod 600 "$key_path"
        chmod 644 "$key_path.pub"
    fi

    echo "$key_path"
}

# Get deploy key path for a project
# Usage: get_key_path <project_name>
get_key_path() {
    local project_name="$1"
    echo "$KEYS_DIR/$project_name/deploy_key"
}

# Check if deploy key exists for a project
# Usage: key_exists <project_name>
# Returns: 0 if exists, 1 if not
key_exists() {
    local project_name="$1"
    local key_path=$(get_key_path "$project_name")

    if [ -f "$key_path" ] && [ -f "$key_path.pub" ]; then
        return 0
    else
        return 1
    fi
}

# Read public key content
# Usage: get_public_key <project_name>
get_public_key() {
    local project_name="$1"
    local key_path=$(get_key_path "$project_name")

    if [ -f "$key_path.pub" ]; then
        cat "$key_path.pub"
    fi
}

# Get deploy key ID from GitHub
# Usage: get_github_key_id <owner_repo> <public_key_content>
# Returns: key ID if found, empty if not
get_github_key_id() {
    local owner_repo="$1"
    local public_key="$2"

    # Extract key type and key content (first two fields)
    local key_type=$(echo "$public_key" | awk '{print $1}')
    local key_content=$(echo "$public_key" | awk '{print $2}')

    # List all deploy keys and find exact match
    # GitHub API returns keys in format "ssh-ed25519 AAAAC3Nza..."
    local api_output
    if ! api_output=$(gh api "repos/$owner_repo/keys" 2>&1); then
        return 1
    fi

    local key_id
    if ! key_id=$(echo "$api_output" | jq -r \
        --arg type "$key_type" \
        --arg key "$key_content" \
        '.[] | select(.key | startswith($type + " " + $key)) | .id' 2>&1 | head -n1); then
        echo "Error: Failed to parse GitHub API response" >&2
        return 1
    fi

    echo "$key_id"
}

# Check if deploy key settings match current requirements
# Usage: check_key_settings_match <owner_repo> <project_name>
# Returns: 0 if settings match, 1 if they don't or key not found
check_key_settings_match() {
    local owner_repo="$1"
    local project_name="$2"
    local public_key=$(get_public_key "$project_name")

    if [ -z "$public_key" ]; then
        return 1
    fi

    local key_id=$(get_github_key_id "$owner_repo" "$public_key")

    if [ -z "$key_id" ]; then
        return 1
    fi

    # Check if key has write access (read_only should be false)
    local read_only
    if ! read_only=$(gh api "repos/$owner_repo/keys/$key_id" --jq '.read_only' 2>&1); then
        echo "Warning: Failed to check deploy key settings on GitHub" >&2
        echo "  Error: $read_only" >&2
        return 1
    fi

    if [ "$read_only" = "false" ]; then
        return 0
    else
        return 1
    fi
}

# Delete deploy key from GitHub
# Usage: delete_github_key <owner_repo> <project_name>
# Returns: 0 on success, 1 on failure
delete_github_key() {
    local owner_repo="$1"
    local project_name="$2"
    local public_key=$(get_public_key "$project_name")

    if [ -z "$public_key" ]; then
        return 0  # No key to delete
    fi

    local key_id=$(get_github_key_id "$owner_repo" "$public_key")

    if [ -z "$key_id" ]; then
        return 0  # Key not found on GitHub (already deleted or never added)
    fi

    local delete_output
    if ! delete_output=$(gh api "repos/$owner_repo/keys/$key_id" --method DELETE 2>&1); then
        echo "Warning: Failed to delete deploy key from GitHub" >&2
        echo "  Error: $delete_output" >&2
        echo "  You may need to delete it manually at: https://github.com/$owner_repo/settings/keys" >&2
        return 1
    fi

    return 0
}

# Delete deploy key for a project
# Usage: delete_key <project_name>
delete_key() {
    local project_name="$1"
    local key_dir="$KEYS_DIR/$project_name"

    if [ -d "$key_dir" ]; then
        rm -rf "$key_dir"
    fi
}
