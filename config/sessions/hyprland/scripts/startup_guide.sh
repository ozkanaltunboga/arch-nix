#!/usr/bin/env bash
set -euo pipefail

SETTINGS_DIR="$HOME/.config/hypr/settings"
SETTING_FILE="$SETTINGS_DIR/guide-on-startup"
SESSION_MARK="${XDG_RUNTIME_DIR:-/tmp}/arch-nix-guide-shown"
QS_MANAGER="$HOME/.config/hypr/scripts/qs_manager.sh"

mkdir -p "$SETTINGS_DIR"
if [ ! -f "$SETTING_FILE" ]; then
    echo "1" > "$SETTING_FILE"
fi

setting="$(tr '[:upper:]' '[:lower:]' < "$SETTING_FILE" | tr -d '[:space:]')"
case "$setting" in
    0|false|off|no|disabled)
        exit 0
        ;;
esac

if [ -f "$SESSION_MARK" ]; then
    exit 0
fi
touch "$SESSION_MARK"

for _ in $(seq 1 40); do
    if pgrep -f 'quickshell.*Main\.qml' >/dev/null 2>&1; then
        break
    fi
    sleep 0.25
done

sleep 1.0

if [ -x "$QS_MANAGER" ]; then
    bash "$QS_MANAGER" open guide
fi
