#!/bin/bash

# SafeClaude Container Lifecycle Management
# Functions for starting, stopping, attaching to, and managing containers

# List all SafeClaude containers
# Usage: list_containers
list_containers() {
    docker ps -a --filter "name=safeclaude-" \
        --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}" | \
        sed 's/safeclaude-//g'
}

# Check if container exists
# Usage: container_exists <container_name>
# Returns: 0 if exists, 1 if not
container_exists() {
    local container_name="$1"

    # Add prefix if not present
    if [[ ! "$container_name" =~ ^safeclaude- ]]; then
        container_name="safeclaude-$container_name"
    fi

    docker ps -a --filter "name=^${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"
}

# Check if container is running
# Usage: container_running <container_name>
# Returns: 0 if running, 1 if not
container_running() {
    local container_name="$1"

    # Add prefix if not present
    if [[ ! "$container_name" =~ ^safeclaude- ]]; then
        container_name="safeclaude-$container_name"
    fi

    docker ps --filter "name=^${container_name}$" --format "{{.Names}}" | grep -q "^${container_name}$"
}

# Attach to a running container
# Usage: attach_container <container_name>
attach_container() {
    local container_name="$1"

    # Add prefix if not present
    if [[ ! "$container_name" =~ ^safeclaude- ]]; then
        container_name="safeclaude-$container_name"
    fi

    if ! container_exists "$container_name"; then
        echo -e "${RED}Error: Container '$container_name' does not exist${NC}"
        return 1
    fi

    if ! container_running "$container_name"; then
        echo -e "${RED}Error: Container '$container_name' is not running${NC}"
        return 1
    fi

    echo "Attaching to container '$container_name'"
    echo "Press Ctrl+P, Ctrl+Q to detach without stopping"
    echo ""

    docker attach "$container_name"
}

# View container logs
# Usage: show_logs <container_name> [--follow]
show_logs() {
    local container_name="$1"
    local follow_flag=""

    if [ "$2" = "--follow" ] || [ "$2" = "-f" ]; then
        follow_flag="-f"
    fi

    # Add prefix if not present
    if [[ ! "$container_name" =~ ^safeclaude- ]]; then
        container_name="safeclaude-$container_name"
    fi

    if ! container_exists "$container_name"; then
        echo -e "${RED}Error: Container '$container_name' does not exist${NC}"
        return 1
    fi

    # Use array to safely handle follow flag
    local -a log_args=("logs")
    if [ -n "$follow_flag" ]; then
        log_args+=("$follow_flag")
    fi
    log_args+=("$container_name")

    docker "${log_args[@]}"
}

# Stop a running container
# Usage: stop_container <container_name>
stop_container() {
    local container_name="$1"

    # Add prefix if not present
    if [[ ! "$container_name" =~ ^safeclaude- ]]; then
        container_name="safeclaude-$container_name"
    fi

    if ! container_exists "$container_name"; then
        echo -e "${RED}Error: Container '$container_name' does not exist${NC}"
        return 1
    fi

    if ! container_running "$container_name"; then
        echo -e "${YELLOW}Container '$container_name' is not running${NC}"
        return 0
    fi

    echo "Stopping container '$container_name'..."
    docker stop "$container_name"

    echo "Removing container '$container_name'..."
    docker rm "$container_name"

    echo -e "${GREEN}Container stopped and removed${NC}"
}

# Execute a command in a running container
# Usage: exec_in_container <container_name> <command...>
exec_in_container() {
    local container_name="$1"
    shift

    # Add prefix if not present
    if [[ ! "$container_name" =~ ^safeclaude- ]]; then
        container_name="safeclaude-$container_name"
    fi

    if ! container_exists "$container_name"; then
        echo -e "${RED}Error: Container '$container_name' does not exist${NC}"
        return 1
    fi

    if ! container_running "$container_name"; then
        echo -e "${RED}Error: Container '$container_name' is not running${NC}"
        return 1
    fi

    docker exec -it "$container_name" "$@"
}

# Get container status
# Usage: get_container_status <container_name>
get_container_status() {
    local container_name="$1"

    # Add prefix if not present
    if [[ ! "$container_name" =~ ^safeclaude- ]]; then
        container_name="safeclaude-$container_name"
    fi

    if ! container_exists "$container_name"; then
        echo "not found"
        return 1
    fi

    docker ps -a --filter "name=^${container_name}$" --format "{{.Status}}"
}
