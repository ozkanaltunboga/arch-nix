#!/usr/bin/env bash
# ============================================================
# Dotfiles kurulum scripti (home.nix'in Arch/CachyOS karşılığı)
# Bu repo'nun ~/.config altına symlink'lenmesini sağlar
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

# Helper: mevcut dosyayı yedekleyip symlink oluşturur
link() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        warn "Yedekleniyor: $dst → $dst.backup"
        mv "$dst" "$dst.backup"
    fi
    ln -sfn "$src" "$dst"
    info "Bağlandı: $dst → $src"
}

# ============================================================
# Program konfigürasyonları
# ============================================================
link "$DOTFILES_DIR/config/programs/kitty"     "$CONFIG_DIR/kitty"
link "$DOTFILES_DIR/config/programs/rofi"      "$CONFIG_DIR/rofi"
link "$DOTFILES_DIR/config/programs/matugen"   "$CONFIG_DIR/matugen"
link "$DOTFILES_DIR/config/programs/swaync"    "$CONFIG_DIR/swaync"
link "$DOTFILES_DIR/config/programs/neovim/nvim" "$CONFIG_DIR/nvim"
link "$DOTFILES_DIR/config/programs/firefox/chrome" "$CONFIG_DIR/firefox-chrome"

# Cava: config_base symlink (renk dosyasıyla birleştirilir, cava wrapper tarafından)
mkdir -p "$CONFIG_DIR/cava"
link "$DOTFILES_DIR/config/programs/cava/config" "$CONFIG_DIR/cava/config_base"

# Cava wrapper script (NixOS'taki cava-dynamic wrapper'ının karşılığı)
CAVA_BIN_DIR="$HOME/.local/bin"
mkdir -p "$CAVA_BIN_DIR"
cat > "$CAVA_BIN_DIR/cava" <<'CAVA_EOF'
#!/usr/bin/env bash
mkdir -p ~/.config/cava
cat ~/.config/cava/config_base ~/.config/cava/colors > ~/.config/cava/config 2>/dev/null
exec /usr/bin/cava "$@"
CAVA_EOF
chmod +x "$CAVA_BIN_DIR/cava"
info "cava wrapper oluşturuldu: $CAVA_BIN_DIR/cava"

# SwayOSD stil dosyası
if [[ -d "$DOTFILES_DIR/config/programs/swayosd" ]]; then
    link "$DOTFILES_DIR/config/programs/swayosd" "$CONFIG_DIR/swayosd"
fi

# ============================================================
# Hyprland oturumu
# ============================================================
link "$DOTFILES_DIR/config/sessions/hyprland" "$CONFIG_DIR/hypr"

# ============================================================
# Zsh konfigürasyonu
# ============================================================
link "$DOTFILES_DIR/config/programs/zsh/.zshrc" "$HOME/.zshrc"

# ============================================================
# Fontlar
# ============================================================
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
link "$DOTFILES_DIR/config/fonts/JetBrainsMono" "$FONT_DIR/JetBrainsMono"
if [[ -f "$DOTFILES_DIR/config/fonts/iosevka-nerd-font.ttf" ]]; then
    cp -n "$DOTFILES_DIR/config/fonts/iosevka-nerd-font.ttf" "$FONT_DIR/"
fi
fc-cache -f
info "Font önbelleği yenilendi."

# ============================================================
# ArcMidnight imleci
# ============================================================
CURSOR_DIR="$HOME/.local/share/icons"
mkdir -p "$CURSOR_DIR"
if [[ ! -d "$CURSOR_DIR/ArcMidnight-Cursors" ]]; then
    info "ArcMidnight imleci indiriliyor..."
    local tmp; tmp=$(mktemp -d)
    curl -L "https://github.com/yeyushengfan258/ArcMidnight-Cursors/archive/refs/heads/main.zip" \
         -o "$tmp/arcmidnight.zip"
    unzip -q "$tmp/arcmidnight.zip" -d "$tmp"
    mv "$tmp/ArcMidnight-Cursors-main/dist" "$CURSOR_DIR/ArcMidnight-Cursors"
    rm -rf "$tmp"
    info "İmleç kuruldu."
fi

# ============================================================
# GTK teması
# ============================================================
mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"

cat > "$CONFIG_DIR/gtk-3.0/settings.ini" <<'GTK3_EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=adw-gtk3-dark
gtk-cursor-theme-name=ArcMidnight-Cursors
gtk-cursor-theme-size=24
GTK3_EOF

cat > "$CONFIG_DIR/gtk-4.0/settings.ini" <<'GTK4_EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-cursor-theme-name=ArcMidnight-Cursors
gtk-cursor-theme-size=24
GTK4_EOF

# dconf ayarları
if command -v dconf &>/dev/null; then
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    dconf write /org/gnome/desktop/interface/gtk-theme "'adw-gtk3-dark'"
    dconf write /org/gnome/desktop/interface/cursor-theme "'ArcMidnight-Cursors'"
    dconf write /org/gnome/desktop/interface/cursor-size 24
    info "dconf ayarları uygulandı."
fi

# ============================================================
# QT tema
# ============================================================
mkdir -p "$CONFIG_DIR/qt6ct"
if [[ ! -f "$CONFIG_DIR/qt6ct/qt6ct.conf" ]]; then
    cat > "$CONFIG_DIR/qt6ct/qt6ct.conf" <<'QT6CT_EOF'
[Appearance]
style=Fusion
color_scheme_path=
QT6CT_EOF
fi

# ============================================================
# Ortam değişkenleri
# ============================================================
ENV_FILE="$HOME/.config/environment.d/cachyos-env.conf"
mkdir -p "$(dirname "$ENV_FILE")"
cat > "$ENV_FILE" <<EOF
NIXOS_OZONE_WL=1
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
GDK_BACKEND=wayland,x11
XDG_SESSION_TYPE=wayland
EOF
info "Ortam değişkenleri ayarlandı: $ENV_FILE"

# ============================================================
# Hyprland systemd user servisleri
# ============================================================
SYSTEMD_USER="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER"

# SwayOSD servisi
cat > "$SYSTEMD_USER/swayosd.service" <<'SVC_EOF'
[Unit]
Description=SwayOSD server
PartOf=graphical-session.target

[Service]
ExecStart=/usr/bin/swayosd-server

[Install]
WantedBy=graphical-session.target
SVC_EOF

systemctl --user daemon-reload
systemctl --user enable swayosd.service
info "swayosd.service etkinleştirildi."

# ============================================================
info "Dotfiles kurulumu tamamlandı!"
info "Hyprland'ı başlatmak için: Hyprland"
