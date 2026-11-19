#!/usr/bin/env bash
# Hotspot CLI Wrapper for DynamicYou
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/../quickshell/scripts/hotspot_manager.py"

if [ -f "$PYTHON_SCRIPT" ]; then
    exec python3 "$PYTHON_SCRIPT" "$@"
elif [ -f "${HOME}/.config/quickshell/scripts/hotspot_manager.py" ]; then
    exec python3 "${HOME}/.config/quickshell/scripts/hotspot_manager.py" "$@"
else
    echo "Error: hotspot_manager.py not found." >&2
    exit 1
fi
