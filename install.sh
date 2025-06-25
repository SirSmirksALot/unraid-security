```bash
#!/bin/bash
PLUGIN_NAME="unraid-security"
PLUGIN_DIR="/usr/local/emhttp/plugins/$PLUGIN_NAME"
CONFIG_DIR="/boot/config/plugins/$PLUGIN_NAME"

# Create directories
mkdir -p "$PLUGIN_DIR"
mkdir -p "$CONFIG_DIR"

# Copy plugin files
cp -r files/* "$PLUGIN_DIR/"

# Optional: permissions
chmod +x "$PLUGIN_DIR/security-checks.sh"
```
