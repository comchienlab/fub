#!/bin/bash
# Fub Installer for Ubuntu 24.04+
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/fub}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
REPO_URL="https://github.com/comchienlab/fub.git"

echo -e "${GREEN}Fub Installer for Ubuntu${NC}"
echo ""

# Check Ubuntu
[[ ! -f /etc/lsb-release ]] && echo -e "${RED}Error: Ubuntu only${NC}" && exit 1

# Install/update
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${BLUE}→${NC} Updating..."
    cd "$INSTALL_DIR" && git pull
else
    echo -e "${BLUE}→${NC} Installing to $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Build analyzer
cd "$INSTALL_DIR"
command -v go &>/dev/null || sudo apt-get install -y golang-go
[[ -f scripts/build-analyze.sh ]] && bash scripts/build-analyze.sh 2>/dev/null || true

# Create symlink
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/fub" "$BIN_DIR/fub"

# Add to PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    SHELL_RC="${HOME}/.bashrc"
    echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$SHELL_RC"
    echo -e "${YELLOW}Run: source $SHELL_RC${NC}"
fi

echo -e "${GREEN}✓ Installation complete!${NC}"
echo -e "Run: ${BLUE}fub${NC}"
