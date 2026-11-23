#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v python3 >/dev/null; then
    deps=0
    preview=0
    approve=0
    for flag in "$@"; do
        case "$flag" in
            --deps|--install|-i) deps=1 ;;
            --no-deps) deps=0 ;;
            --dry-run|--rollback|--help|-h) preview=1 ;;
            --yes|-y) approve=1 ;;
        esac
    done
    if (( EUID == 0 || ! deps || preview )) || [[ ! -f /etc/arch-release ]] ||
        ! command -v pacman >/dev/null || ! command -v sudo >/dev/null; then
        printf 'Python 3 is required to run the installer. Install it using your package manager.\n' >&2
        exit 1
    fi
    if (( ! approve )); then
        if [[ ! -t 0 ]]; then
            printf 'Install Python 3 first or pass --yes to approve installing it.\n' >&2
            exit 1
        fi
        read -r -p 'Install Python 3 to start the Dynamic You installer? [y/N] ' answer
        [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]] || exit 1
    fi
    sudo pacman -S --needed python
fi
exec python3 "$root/scripts/install.py" "$@"
