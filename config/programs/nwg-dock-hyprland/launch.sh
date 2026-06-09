#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/nwg-dock-hyprland"
SETTINGS_DIR="$CONFIG_DIR/settings"
DEFAULT_THEME="mojave"
DEFAULT_ICON_SIZE="48"
DEFAULT_MARGIN_BOTTOM="8"
DEFAULT_HIDE_DELAY="60"

if ! command -v nwg-dock-hyprland >/dev/null 2>&1; then
  echo "nwg-dock-hyprland is not installed" >&2
  exit 0
fi

mkdir -p "$SETTINGS_DIR"

theme="$DEFAULT_THEME"
if [ -f "$SETTINGS_DIR/dock-theme" ]; then
  theme="$(tr -d '[:space:]' < "$SETTINGS_DIR/dock-theme")"
fi

icon_size="$DEFAULT_ICON_SIZE"
if [ -f "$SETTINGS_DIR/dock-icon-size" ]; then
  icon_size="$(tr -cd '0-9' < "$SETTINGS_DIR/dock-icon-size")"
  icon_size="${icon_size:-$DEFAULT_ICON_SIZE}"
fi

margin_bottom="$DEFAULT_MARGIN_BOTTOM"
if [ -f "$SETTINGS_DIR/dock-margin-bottom" ]; then
  margin_bottom="$(tr -cd '0-9' < "$SETTINGS_DIR/dock-margin-bottom")"
  margin_bottom="${margin_bottom:-$DEFAULT_MARGIN_BOTTOM}"
fi

hide_delay="$DEFAULT_HIDE_DELAY"
if [ -f "$SETTINGS_DIR/dock-hide-delay" ]; then
  hide_delay="$(tr -cd '0-9' < "$SETTINGS_DIR/dock-hide-delay")"
  hide_delay="${hide_delay:-$DEFAULT_HIDE_DELAY}"
fi

style_file="$CONFIG_DIR/themes/$theme/style.css"
if [ ! -f "$style_file" ]; then
  echo "Dock theme '$theme' not found, falling back to $DEFAULT_THEME" >&2
  theme="$DEFAULT_THEME"
  style_file="$CONFIG_DIR/themes/$theme/style.css"
fi

while IFS= read -r pid; do
  [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
done < <(pgrep -f '(^|/)nwg-dock-hyprland([[:space:]]|$)' || true)
sleep 0.2

if [ -f "$SETTINGS_DIR/dock-disabled" ]; then
  echo "Dock disabled by $SETTINGS_DIR/dock-disabled"
  exit 0
fi

cd "$CONFIG_DIR"

args=(
  -p bottom
  -a center
  -i "$icon_size"
  -mb "$margin_bottom"
  -c "bash $HOME/.config/hypr/scripts/rofi_show.sh drun"
  -ico view-app-grid-symbolic
  -s "$style_file"
)

if [ -f "$SETTINGS_DIR/dock-autohide" ]; then
  args=(-d -hd "$hide_delay" "${args[@]}")
fi

exec nwg-dock-hyprland "${args[@]}"
