#!/usr/bin/env bash

bash ~/.config/hypr/scripts/lockscreen_prepare.sh
pidof hyprlock >/dev/null || hyprlock
