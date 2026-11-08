#!/usr/bin/env bash
systemctl --user stop quickshell-session.service 2>/dev/null
pkill -9 -x .quickshell-wra 2>/dev/null
pkill -9 -x quickshell 2>/dev/null
while pgrep -x .quickshell-wra >/dev/null || pgrep -x quickshell >/dev/null; do sleep 0.05; done
systemd-run --user --unit=quickshell-session quickshell
