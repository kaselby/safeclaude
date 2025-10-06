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

# Delete deploy key for a project
# Usage: delete_key <project_name>
delete_key() {
    local project_name="$1"
    local key_dir="$KEYS_DIR/$project_name"

    if [ -d "$key_dir" ]; then
        rm -rf "$key_dir"
    fi
}
