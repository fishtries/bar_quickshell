#!/bin/bash
# install.sh - Easy installer for bar_quickshell and aside

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==>${NC} Welcome to the bar_quickshell installer!"

# 1. Check for Quickshell
if ! command -v quickshell &> /dev/null; then
    echo -e "${RED}Warning: quickshell is not installed or not in PATH.${NC}"
    echo "You must install quickshell to use this configuration."
    echo "Visit: https://git.outfoxxed.me/outfoxxed/quickshell"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 2. Check system dependencies for aside
echo -e "${BLUE}==>${NC} Checking system dependencies for aside..."
if command -v pacman &> /dev/null; then
    echo "Arch Linux detected. Attempting to install required system packages..."
    sudo pacman -S --needed --noconfirm gtk4 gtk4-layer-shell python-gobject
else
    echo "Please ensure you have the following installed:"
    echo "- python 3.11+"
    echo "- gtk4"
    echo "- gtk4-layer-shell"
    echo "- python-gobject"
    echo ""
fi

# 3. Ensure we are in ~/.config/quickshell
TARGET_DIR="$HOME/.config/quickshell"
CURRENT_DIR=$(pwd)

if [ "$CURRENT_DIR" != "$TARGET_DIR" ]; then
    echo -e "${BLUE}==>${NC} Project is not in $TARGET_DIR."
    echo "Moving project to $TARGET_DIR..."
    mkdir -p "$TARGET_DIR"
    cp -r "$CURRENT_DIR"/* "$TARGET_DIR/"
    cp -r "$CURRENT_DIR"/.[!.]* "$TARGET_DIR/" 2>/dev/null || true
    
    echo -e "${GREEN}Project moved successfully. Switching to $TARGET_DIR...${NC}"
    cd "$TARGET_DIR"
fi

# 4. Install aside
echo -e "${BLUE}==>${NC} Building and installing aside..."
cd aside || { echo -e "${RED}Error: aside directory not found.${NC}"; exit 1; }

# Use make install to set up aside in a virtual environment, handles all setups properly according to Makefile
make install

cd ..

echo -e "${GREEN}==> Installation complete!${NC}"
echo "You can now run 'quickshell' in your terminal or configure it to start with your compositor."
