#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

BIN_DIR="${HOME}/bin"
SETUP_BIN="fishx-setup"
LAUNCHER_BIN="fishx"

echo "Building fishx setup CLI..."
moon build cli/fishx --target native -q

BUILD_DIR="${ROOT_DIR}/_build/native/release/build/cli/fishx"
SOURCE_BIN="${BUILD_DIR}/fishx.exe"

if [[ ! -f "${SOURCE_BIN}" ]]; then
  echo "Error: Binary not found at ${SOURCE_BIN}"
  exit 1
fi

mkdir -p "${BIN_DIR}"
cp -f "${SOURCE_BIN}" "${BIN_DIR}/${SETUP_BIN}"
chmod +x "${BIN_DIR}/${SETUP_BIN}"

# Create the main fishx script that does setup + exec
cat > "${BIN_DIR}/${LAUNCHER_BIN}" << 'EOF'
#!/bin/bash
# fishx - Enhanced fish shell with tracing and AI context
#
# This script:
# 1. Ensures shell wrappers and keymaps are installed
# 2. Execs into the enhanced fish shell

FISH_BIN="$HOME/.local/bin/fish"
WRAPPERS="$HOME/.config/fish/conf.d/flow-shell-wrappers.fish"
SETUP_BIN="$HOME/bin/fishx-setup"

# Check if fish exists
if [ ! -x "$FISH_BIN" ]; then
    echo "Error: Fish not found at $FISH_BIN"
    echo "Build your custom fish first."
    exit 1
fi

# Install if needed (silently if already done)
if [ ! -f "$WRAPPERS" ]; then
    echo "First run - installing fishx enhancements..."
    "$SETUP_BIN" install
    echo ""
fi

# Pass through commands to fishx-setup
if [ "$1" = "status" ] || [ "$1" = "s" ]; then
    exec "$SETUP_BIN" status
elif [ "$1" = "context" ] || [ "$1" = "c" ]; then
    exec "$SETUP_BIN" context
elif [ "$1" = "install" ] || [ "$1" = "i" ]; then
    exec "$SETUP_BIN" install
elif [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "fishx - Enhanced fish shell with tracing and AI context"
    echo ""
    echo "USAGE:"
    echo "  fishx              Launch enhanced fish (installs if needed)"
    echo "  fishx status       Show setup status"
    echo "  fishx context      Show AI context JSON"
    echo "  fishx install      Reinstall wrappers and keymaps"
    echo "  fishx help         Show this help"
    echo ""
    echo "FEATURES:"
    echo "  - 10 commands traced: git, npm, pnpm, docker, moon, cargo, kubectl, ssh, curl, make"
    echo "  - Error pattern detection with suggestions"
    echo "  - AI context for Claude/Codex integration"
    echo "  - Custom keybindings for hive agents"
    exit 0
fi

# Default: exec into enhanced fish
exec "$FISH_BIN" "$@"
EOF

chmod +x "${BIN_DIR}/${LAUNCHER_BIN}"

echo ""
echo "Done! fishx is ready."
echo ""
echo "Usage:"
echo "  fishx          # Launch enhanced fish (installs if needed)"
echo "  fishx status   # Show setup status"
echo "  fishx context  # Get AI context JSON"
