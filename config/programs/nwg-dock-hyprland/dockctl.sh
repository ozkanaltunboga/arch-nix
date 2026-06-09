#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/nwg-dock-hyprland"
SETTINGS_DIR="$CONFIG_DIR/settings"
mkdir -p "$SETTINGS_DIR"

usage() {
  cat <<'EOF'
Usage:
  dockctl.sh status
  dockctl.sh restart
  dockctl.sh enable
  dockctl.sh disable
  dockctl.sh autohide on|off
  dockctl.sh theme mojave|glass|modern|transparent
  dockctl.sh icon-size NUMBER
  dockctl.sh margin-bottom NUMBER
EOF
}

restart_dock() {
  nohup bash "$CONFIG_DIR/launch.sh" >/dev/null 2>&1 &
}

cmd="${1:-status}"
case "$cmd" in
  status)
    echo "Theme: $(cat "$SETTINGS_DIR/dock-theme" 2>/dev/null || echo mojave)"
    [ -f "$SETTINGS_DIR/dock-disabled" ] && echo "Enabled: no" || echo "Enabled: yes"
    [ -f "$SETTINGS_DIR/dock-autohide" ] && echo "Autohide: yes" || echo "Autohide: no"
    ;;
  restart)
    restart_dock
    ;;
  enable)
    rm -f "$SETTINGS_DIR/dock-disabled"
    restart_dock
    ;;
  disable)
    touch "$SETTINGS_DIR/dock-disabled"
    restart_dock
    ;;
  autohide)
    case "${2:-}" in
      on) touch "$SETTINGS_DIR/dock-autohide" ;;
      off) rm -f "$SETTINGS_DIR/dock-autohide" ;;
      *) usage; exit 1 ;;
    esac
    restart_dock
    ;;
  theme)
    theme="${2:-}"
    if [ ! -f "$CONFIG_DIR/themes/$theme/style.css" ]; then
      echo "Unknown theme: $theme" >&2
      usage
      exit 1
    fi
    echo "$theme" > "$SETTINGS_DIR/dock-theme"
    restart_dock
    ;;
  icon-size)
    value="$(printf '%s' "${2:-}" | tr -cd '0-9')"
    [ -n "$value" ] || { usage; exit 1; }
    echo "$value" > "$SETTINGS_DIR/dock-icon-size"
    restart_dock
    ;;
  margin-bottom)
    value="$(printf '%s' "${2:-}" | tr -cd '0-9')"
    [ -n "$value" ] || { usage; exit 1; }
    echo "$value" > "$SETTINGS_DIR/dock-margin-bottom"
    restart_dock
    ;;
  *)
    usage
    exit 1
    ;;
esac
