#!/bin/bash

set -e

echo "Installing Claude Code Sandbox..."
echo ""

# Get the absolute path to this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
IMAGE_NAME="claude-sandbox"
DEPLOY_KEY_PATH="$HOME/.ssh/sandbox_deploy_key"
INSTALL_DIR="$HOME/bin"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Get git user name and email from current config
GIT_USER_NAME=$(git config --global user.name || echo "")
GIT_USER_EMAIL=$(git config --global user.email || echo "")

if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
    echo "Warning: Git user.name or user.email not configured globally"
    echo ""
    read -p "Enter your git user.name: " GIT_USER_NAME
    read -p "Enter your git user.email: " GIT_USER_EMAIL
    echo ""
fi

# Build Docker image
echo "Building Docker image with git config:"
echo "  Name:  $GIT_USER_NAME"
echo "  Email: $GIT_USER_EMAIL"
echo ""

docker build \
    --build-arg GIT_USER_NAME="$GIT_USER_NAME" \
    --build-arg GIT_USER_EMAIL="$GIT_USER_EMAIL" \
    -t "$IMAGE_NAME" \
    "$SCRIPT_DIR"

echo ""
echo -e "${GREEN}✓ Docker image built successfully${NC}"
echo ""

# Check if deploy key exists
if [ -f "$DEPLOY_KEY_PATH" ]; then
    echo -e "${GREEN}✓ Deploy key already exists at $DEPLOY_KEY_PATH${NC}"
    echo ""
else
    echo "Deploy key not found at $DEPLOY_KEY_PATH"
    echo ""
    read -p "Generate deploy key for sandbox? [Y/n] " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo "Generating deploy key..."
        ssh-keygen -t ed25519 -f "$DEPLOY_KEY_PATH" -N "" -C "claude-sandbox"
        echo ""
        echo -e "${GREEN}✓ Deploy key generated${NC}"
        echo ""
    else
        echo -e "${YELLOW}Skipping deploy key generation${NC}"
        echo "You'll need to create $DEPLOY_KEY_PATH before using the sandbox"
        echo ""
    fi
fi

# Display public key and GitHub setup instructions if key exists
if [ -f "${DEPLOY_KEY_PATH}.pub" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}GitHub Setup Required (One-Time)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Add this deploy key to your GitHub repository:"
    echo ""
    echo "   Repository → Settings → Deploy keys → Add deploy key"
    echo ""
    echo "   Title: claude-sandbox"
    echo "   Key:"
    echo ""
    cat "${DEPLOY_KEY_PATH}.pub"
    echo ""
    echo "   ✓ Allow write access"
    echo "   ✗ Do NOT check 'Allow this key to push to protected branches'"
    echo ""
    echo "2. Enable branch protection on your main branch:"
    echo ""
    echo "   Repository → Settings → Branches → Add branch protection rule"
    echo ""
    echo "   Branch pattern: main"
    echo "   ✓ Require pull request before merging"
    echo ""
    echo "This ensures Claude can push feature branches but NOT push to main."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

# Install sandbox script
echo "Installing sandbox command..."

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy sandbox script
cp "$SCRIPT_DIR/sandbox" "$INSTALL_DIR/sandbox"
chmod +x "$INSTALL_DIR/sandbox"

echo -e "${GREEN}✓ Sandbox command installed to $INSTALL_DIR/sandbox${NC}"
echo ""

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH${NC}"
    echo ""
    echo "Add this line to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"\$HOME/bin:\$PATH\""
    echo ""
else
    echo -e "${GREEN}✓ $INSTALL_DIR is in your PATH${NC}"
    echo ""
fi

# Installation complete
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Installation Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Usage:"
echo "  sandbox git@github.com:user/repo.git"
echo "  sandbox https://github.com/user/repo.git"
echo ""
echo "Next Steps:"
echo "  1. Complete the GitHub setup above (add deploy key + branch protection)"
echo "  2. Run: sandbox <your-repo-url>"
echo ""
echo "See README.md for detailed documentation and troubleshooting."
echo ""
