#!/bin/bash

set -e

echo "Uninstalling Claude Code Sandbox..."
echo ""

IMAGE_NAME="claude-sandbox"
INSTALL_DIR="$HOME/bin"

# Stop and remove any running sandbox containers
echo "Checking for running sandbox containers..."
RUNNING_CONTAINERS=$(docker ps -a --filter "name=claude-sandbox-" -q)

if [ -n "$RUNNING_CONTAINERS" ]; then
    echo "Stopping and removing sandbox containers..."
    docker rm -f $RUNNING_CONTAINERS
    echo "✓ Containers removed"
else
    echo "✓ No running sandbox containers found"
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

# Remove sandbox script
echo "Removing sandbox command..."
if [ -f "$INSTALL_DIR/sandbox" ]; then
    rm "$INSTALL_DIR/sandbox"
    echo "✓ Sandbox command removed from $INSTALL_DIR"
else
    echo "✓ Sandbox command not found (already removed)"
fi
echo ""

# Note about deploy key
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Note: Deploy key preserved at ~/.ssh/sandbox_deploy_key"
echo ""
echo "If you want to remove it:"
echo "  rm ~/.ssh/sandbox_deploy_key*"
echo ""
echo "Don't forget to remove the deploy key from GitHub:"
echo "  Repository → Settings → Deploy keys → Delete 'claude-sandbox'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✓ Uninstall complete!"
