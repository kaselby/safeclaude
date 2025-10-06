#!/bin/bash

set -e

echo "Installing SafeClaude..."
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
INSTALL_DIR="$HOME/bin"
SAFECLAUDE_DIR="$HOME/.safeclaude"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed${NC}"
    echo ""
    echo "jq is required for SafeClaude to work. Install it with:"
    echo "  macOS:   brew install jq"
    echo "  Linux:   apt-get install jq / yum install jq"
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
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

# Create SafeClaude directory structure
echo "Creating SafeClaude directory structure..."
mkdir -p "$SAFECLAUDE_DIR"
mkdir -p "$SAFECLAUDE_DIR/keys"

# Initialize empty projects.json if it doesn't exist
if [ ! -f "$SAFECLAUDE_DIR/projects.json" ]; then
    echo '{}' > "$SAFECLAUDE_DIR/projects.json"
fi

# Initialize config.json with defaults
if [ ! -f "$SAFECLAUDE_DIR/config.json" ]; then
    cat > "$SAFECLAUDE_DIR/config.json" <<EOF
{
  "default_persist": false,
  "default_network": false,
  "auto_setup_branch_protection": true
}
EOF
fi

echo -e "${GREEN}✓ SafeClaude directory created at $SAFECLAUDE_DIR${NC}"
echo ""

# Install safeclaude script
echo "Installing safeclaude command..."

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy safeclaude script
cp "$SCRIPT_DIR/safeclaude" "$INSTALL_DIR/safeclaude"
chmod +x "$INSTALL_DIR/safeclaude"

# Copy library files
mkdir -p "$INSTALL_DIR/lib"
cp "$SCRIPT_DIR/lib/"*.sh "$INSTALL_DIR/lib/" 2>/dev/null || true

echo -e "${GREEN}✓ SafeClaude command installed to $INSTALL_DIR/safeclaude${NC}"
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

# Check for GitHub CLI
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}Note: GitHub CLI (gh) is not installed${NC}"
    echo ""
    echo "SafeClaude uses the GitHub CLI for automated setup."
    echo "Install it with:"
    echo "  macOS:   brew install gh"
    echo "  Linux:   See https://github.com/cli/cli#installation"
    echo ""
    echo "Then authenticate: gh auth login"
    echo ""
fi

# Installation complete
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Installation Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Quick Start:"
echo "  1. Authenticate with GitHub CLI:"
echo "     gh auth login"
echo ""
echo "  2. Setup your first project:"
echo "     safeclaude setup myrepo git@github.com:user/myrepo.git"
echo ""
echo "  3. Run it:"
echo "     safeclaude run myrepo"
echo ""
echo "For more commands, run:"
echo "  safeclaude --help"
echo ""
echo "See README.md for detailed documentation."
echo ""
