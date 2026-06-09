#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/nwg-dock-hyprland"

if ! command -v nwg-dock-hyprland >/dev/null 2>&1; then
  echo "nwg-dock-hyprland is not installed" >&2
  exit 0
fi

while IFS= read -r pid; do
  [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
done < <(pgrep -f '(^|/)nwg-dock-hyprland([[:space:]]|$)' || true)
sleep 0.2

cd "$CONFIG_DIR"

exec nwg-dock-hyprland \
  -p bottom \
  -a center \
  -i 48 \
  -mb 8 \
  -c "bash $HOME/.config/hypr/scripts/rofi_show.sh drun" \
  -ico view-app-grid-symbolic \
  -s style.css
