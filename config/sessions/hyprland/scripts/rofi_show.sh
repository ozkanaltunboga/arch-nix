#!/usr/bin/env bash

MODE=${1:-drun}
USER_HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
export HOME="${USER_HOME:-$HOME}"
ROFI_CONFIG="$HOME/.config/rofi/config.rasi"

if pgrep -x "rofi" > /dev/null; then
    pkill rofi
else
    rofi -show "$MODE" -config "$ROFI_CONFIG"
fi
