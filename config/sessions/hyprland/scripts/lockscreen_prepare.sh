#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="$HOME/.cache/arch-nix/lockscreen"
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
LOCK_BG="/tmp/lock_bg.png"

mkdir -p "$CACHE_DIR"

source_image=""
if [ -f "$LOCK_BG" ]; then
    source_image="$LOCK_BG"
else
    source_image="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1 || true)"
fi

if [ -z "$source_image" ] || [ ! -f "$source_image" ]; then
    magick -size 1920x1080 gradient:"#11111b-#1e1e2e" "$CACHE_DIR/blurred_wallpaper.png"
    magick -size 520x520 gradient:"#1e1e2e-#313244" "$CACHE_DIR/square_wallpaper.png"
    exit 0
fi

magick "$source_image" \
    -auto-orient \
    -resize "1920x1080^" \
    -gravity center \
    -extent 1920x1080 \
    -blur 0x18 \
    -modulate 88,82,100 \
    -fill "#05070c" -colorize 20 \
    "$CACHE_DIR/blurred_wallpaper.png"

magick "$source_image" \
    -auto-orient \
    -resize "520x520^" \
    -gravity center \
    -extent 520x520 \
    -modulate 104,104,100 \
    "$CACHE_DIR/square_wallpaper.png"
