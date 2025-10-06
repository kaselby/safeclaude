#!/bin/bash

set -e

echo "Uninstalling SafeClaude..."
echo ""

# Use username in image name to prevent namespace collisions on shared systems
IMAGE_NAME="safeclaude-$(whoami)/claude-sandbox"
INSTALL_DIR="$HOME/bin"
SAFECLAUDE_DIR="$HOME/.safeclaude"

# Stop and remove any running SafeClaude containers
echo "Checking for running SafeClaude containers..."
RUNNING_CONTAINERS=$(docker ps -a --filter "name=safeclaude-" -q)

if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "Stopping and removing SafeClaude containers..."
    echo "$RUNNING_CONTAINERS" | xargs docker rm -f
    echo "✓ Containers removed"
else
    echo "✓ No running SafeClaude containers found"
fi
echo ""

# Remove Docker image
echo "Removing Docker image..."
if docker image inspect "$IMAGE_NAME" &> /dev/null; then
    docker rmi "$IMAGE_NAME"
    echo "✓ Docker image removed"
else
    echo "✓ Docker image not found (already removed)"
fi
echo ""

# Remove safeclaude script and lib directory
echo "Removing SafeClaude command..."
if [ -f "$INSTALL_DIR/safeclaude" ]; then
    rm "$INSTALL_DIR/safeclaude"
    echo "✓ SafeClaude command removed from $INSTALL_DIR"
else
    echo "✓ SafeClaude command not found (already removed)"
fi

if [ -d "$INSTALL_DIR/lib" ]; then
    rm -rf "$INSTALL_DIR/lib"
    echo "✓ Library files removed from $INSTALL_DIR/lib"
fi
echo ""

# Check for persistent volumes
echo "Checking for persistent volumes..."
VOLUMES=$(docker volume ls --filter "name=safeclaude-" -q)
if [ -n "$VOLUMES" ]; then
    echo "Found persistent volumes:"
    docker volume ls --filter "name=safeclaude-" --format "  {{.Name}}"
    echo ""
    read -p "Remove these volumes? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$VOLUMES" | xargs docker volume rm
        echo "✓ Volumes removed"
    else
        echo "⚠ Volumes preserved"
    fi
else
    echo "✓ No persistent volumes found"
fi
echo ""

# Note about project data
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Note: Project data preserved at $SAFECLAUDE_DIR"
echo ""
echo "This includes:"
echo "  - Project registry (projects.json)"
echo "  - Per-project deploy keys (keys/)"
echo "  - Configuration (config.json)"
echo ""
echo "To remove all SafeClaude data:"
echo "  rm -rf $SAFECLAUDE_DIR"
echo ""
echo "Don't forget to remove deploy keys from GitHub repositories:"
echo "  Repository → Settings → Deploy keys → Delete 'safeclaude-<project>'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✓ Uninstall complete!"
