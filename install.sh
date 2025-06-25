#!/bin/bash
PLUGIN_NAME="unraid-security"
PLUGIN_DIR="/usr/local/emhttp/plugins/$PLUGIN_NAME"

# Create plugin directory
mkdir -p "$PLUGIN_DIR"

# Copy individual files explicitly
cp files/index.php "$PLUGIN_DIR/"
cp files/unraid-security.page "$PLUGIN_DIR/"
cp files/security-checks.sh "$PLUGIN_DIR/"

# Set executable flag on the script
chmod +x "$PLUGIN_DIR/security-checks.sh"
