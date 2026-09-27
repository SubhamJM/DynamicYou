#!/usr/bin/env bash
# Voice Dictation Launcher wrapper: ensures dedicated venv or uv is used
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PY="$HOME/.cache/quickshell/venv_dictation/bin/python3"

if [ -x "$VENV_PY" ]; then
    exec "$VENV_PY" "$DIR/voice_dictation_core.py" "$@"
elif command -v uv >/dev/null 2>&1; then
    exec uv run --with faster-whisper python3 "$DIR/voice_dictation_core.py" "$@"
else
    exec python3 "$DIR/voice_dictation_core.py" "$@"
fi
