#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CONSTANTS & ARGUMENTS
# -----------------------------------------------------------------------------
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
BT_SCAN_LOG="$HOME/.cache/bt_scan.log"
SRC_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
THUMB_DIR="$HOME/.cache/wallpaper_picker/thumbs"

IPC_FILE="/tmp/qs_widget_state"
NETWORK_MODE_FILE="/tmp/qs_network_mode"

ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# -----------------------------------------------------------------------------
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    echo "close" > "$IPC_FILE" # Tell QML to hide the widget natively
    
    CMD="workspace $WORKSPACE_NUM"
    [[ "$2" == "move" ]] && CMD="movetoworkspace $WORKSPACE_NUM"
    hyprctl --batch "dispatch $CMD" >/dev/null 2>&1
    exit 0
fi

# -----------------------------------------------------------------------------
# PREP FUNCTIONS (Untouched)
# -----------------------------------------------------------------------------
handle_wallpaper_prep() {
    mkdir -p "$THUMB_DIR"
    (
        for thumb in "$THUMB_DIR"/*; do
            [ -e "$thumb" ] || continue
            filename=$(basename "$thumb")
            clean_name="${filename#000_}"
            if [ ! -f "$SRC_DIR/$clean_name" ]; then rm -f "$thumb"; fi
        done

        for img in "$SRC_DIR"/*.{jpg,jpeg,png,webp,gif,mp4,mkv,mov,webm}; do
            [ -e "$img" ] || continue
            filename=$(basename "$img")
            extension="${filename##*.}"

            if [[ "${extension,,}" == "webp" ]]; then
                new_img="${img%.*}.jpg"
                magick "$img" "$new_img"
                rm -f "$img"
                img="$new_img"
                filename=$(basename "$img")
                extension="jpg"
            fi

            if [[ "${extension,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
                thumb="$THUMB_DIR/000_$filename"
                [ -f "$THUMB_DIR/$filename" ] && rm -f "$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                     ffmpeg -y -ss 00:00:05 -i "$img" -vframes 1 -f image2 -q:v 2 "$thumb" > /dev/null 2>&1
                fi
            else
                thumb="$THUMB_DIR/$filename"
                if [ ! -f "$thumb" ]; then
                    magick "$img" -resize x420 -quality 70 "$thumb"
                fi
            fi
        done
    ) &

    TARGET_THUMB=""
    CURRENT_SRC=""

    if pgrep -a "mpvpaper" > /dev/null; then
        CURRENT_SRC=$(pgrep -a mpvpaper | grep -o "$SRC_DIR/[^' ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -z "$CURRENT_SRC" ] && command -v awww >/dev/null; then
        CURRENT_SRC=$(awww query 2>/dev/null | grep -o "$SRC_DIR/[^ ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -z "$CURRENT_SRC" ] && command -v swww >/dev/null; then
        CURRENT_SRC=$(swww query 2>/dev/null | grep -o "$SRC_DIR/[^ ]*" | head -n1)
        CURRENT_SRC=$(basename "$CURRENT_SRC")
    fi

    if [ -n "$CURRENT_SRC" ]; then
        EXT="${CURRENT_SRC##*.}"
        if [[ "${EXT,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
            TARGET_THUMB="000_$CURRENT_SRC"
        else
            TARGET_THUMB="$CURRENT_SRC"
        fi
    fi
    
    export WALLPAPER_THUMB="$TARGET_THUMB"
}

handle_network_prep() {
    echo "" > "$BT_SCAN_LOG"
    { echo "scan on"; sleep infinity; } | stdbuf -oL bluetoothctl > "$BT_SCAN_LOG" 2>&1 &
    echo $! > "$BT_PID_FILE"
    (nmcli device wifi rescan) &
}

resolve_wayland_display() {
    local runtime_dir="$1"
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        printf '%s\n' "$WAYLAND_DISPLAY"
        return
    fi

    find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' 2>/dev/null | sort | head -n1
}

resolve_hyprland_signature() {
    local runtime_dir="$1"
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        printf '%s\n' "$HYPRLAND_INSTANCE_SIGNATURE"
        return
    fi

    find "$runtime_dir/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | head -n1
}

launch_quickshell() {
    local qml_path="$1"
    local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    local dbus_addr="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${runtime_dir}/bus}"
    local wayland_display
    local hypr_signature
    local -a launch_env

    wayland_display="$(resolve_wayland_display "$runtime_dir")"
    hypr_signature="$(resolve_hyprland_signature "$runtime_dir")"

    launch_env=(
        env
        "XDG_RUNTIME_DIR=$runtime_dir"
        "DBUS_SESSION_BUS_ADDRESS=$dbus_addr"
        "QT_QPA_PLATFORM=wayland"
        "WALLPAPER_DIR=$SRC_DIR"
    )

    [[ -n "$wayland_display" ]] && launch_env+=("WAYLAND_DISPLAY=$wayland_display")
    [[ -n "$hypr_signature" ]] && launch_env+=("HYPRLAND_INSTANCE_SIGNATURE=$hypr_signature")

    if command -v systemd-detect-virt >/dev/null && [[ "$(systemd-detect-virt 2>/dev/null || true)" == "vmware" ]]; then
        launch_env+=("QT_QUICK_BACKEND=${QT_QUICK_BACKEND:-software}")
    elif [[ -n "${QT_QUICK_BACKEND:-}" ]]; then
        launch_env+=("QT_QUICK_BACKEND=$QT_QUICK_BACKEND")
    fi

    "${launch_env[@]}" quickshell -p "$qml_path" >/dev/null 2>&1 &
    disown
}

# -----------------------------------------------------------------------------
# ZOMBIE WATCHDOG
# -----------------------------------------------------------------------------
MAIN_QML_PATH="$HOME/.config/hypr/scripts/quickshell/Main.qml"
BAR_QML_PATH="$HOME/.config/hypr/scripts/quickshell/TopBar.qml"

if ! pgrep -f "quickshell.*Main\.qml" >/dev/null; then
    launch_quickshell "$MAIN_QML_PATH"
fi

if ! pgrep -f "quickshell.*TopBar\.qml" >/dev/null; then
    launch_quickshell "$BAR_QML_PATH"
fi

# -----------------------------------------------------------------------------
# IPC ROUTING (No hyprctl focus/move commands needed!)
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "close" ]]; then
    echo "close" > "$IPC_FILE"
    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        if [ -f "$BT_PID_FILE" ]; then
            kill $(cat "$BT_PID_FILE") 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
        (bluetoothctl scan off > /dev/null 2>&1) &
    fi
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then
    ACTIVE_WIDGET=$(cat /tmp/qs_active_widget 2>/dev/null)
    CURRENT_MODE=$(cat "$NETWORK_MODE_FILE" 2>/dev/null)

    if [[ "$TARGET" == "network" ]]; then
        if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "network" ]]; then
            if [[ -n "$SUBTARGET" ]]; then
                if [[ "$CURRENT_MODE" == "$SUBTARGET" ]]; then
                    echo "close" > "$IPC_FILE"
                else
                    echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
                    echo "$TARGET" > "$IPC_FILE"
                fi
            else
                echo "close" > "$IPC_FILE"
            fi
        else
            handle_network_prep
            [[ -n "$SUBTARGET" ]] && echo "$SUBTARGET" > "$NETWORK_MODE_FILE"
            echo "$TARGET" > "$IPC_FILE"
        fi
        exit 0
    fi

    if [[ "$ACTION" == "toggle" && "$ACTIVE_WIDGET" == "$TARGET" ]]; then
        echo "close" > "$IPC_FILE"
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        handle_wallpaper_prep
        echo "$TARGET:$WALLPAPER_THUMB" > "$IPC_FILE"
    else
        echo "$TARGET" > "$IPC_FILE"
    fi
    exit 0
fi
