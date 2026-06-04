#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/nwg-dock-hyprland"

pkill -f "nwg-dock-hyprland" 2>/dev/null || true
sleep 0.2

cd "$CONFIG_DIR"

exec nwg-dock-hyprland \
  -d \
  -p bottom \
  -a center \
  -i 48 \
  -mb 8 \
  -c "bash $HOME/.config/hypr/scripts/rofi_show.sh drun" \
  -ico view-app-grid-symbolic \
  -s style.css
