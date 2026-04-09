#!/usr/bin/env bash
# ============================================================
#   Arch Linux / CachyOS - Tek Komutla Tam Kurulum
#   https://github.com/ozkanaltunboga/arch-nix
#
#   Kullanım:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/ozkanaltunboga/arch-nix/main/install.sh)"
# ============================================================
set -e

# --- Renkler ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${NC}"; }

[[ $EUID -eq 0 ]] && error "Bu scripti root olarak çalıştırmayın! (sudo kullanmayın)"

# ============================================================
# 0. DONANIM ALGILAMA
# ============================================================
step "Donanım algılanıyor"

GPU_RAW=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)
IS_VM=false
IS_NVIDIA=false
IS_AMD=false
IS_INTEL=false
HAS_BATTERY=false
HAS_WIFI=false

if echo "$GPU_RAW" | grep -qi "vmware\|virtualbox\|qxl\|virtio\|bochs\|hyper-v\|parallels"; then
    IS_VM=true
    info "Sanal makine algılandı (VM GPU fix'leri uygulanacak)"
elif echo "$GPU_RAW" | grep -qi "nvidia"; then
    IS_NVIDIA=true
    info "NVIDIA GPU algılandı"
elif echo "$GPU_RAW" | grep -qi "amd\|radeon"; then
    IS_AMD=true
    info "AMD GPU algılandı"
elif echo "$GPU_RAW" | grep -qi "intel"; then
    IS_INTEL=true
    info "Intel GPU algılandı"
fi

if ls /sys/class/power_supply/BAT* 1>/dev/null 2>&1; then
    HAS_BATTERY=true
    info "Batarya algılandı (Laptop)"
else
    info "Batarya yok (Masaüstü/VM)"
fi

if ls /sys/class/net/w* 1>/dev/null 2>&1 || iw dev 2>/dev/null | grep -q Interface; then
    HAS_WIFI=true
    info "Wi-Fi algılandı"
else
    info "Wi-Fi yok (Ethernet/VM)"
fi

# ============================================================
# 1. AUR HELPER (paru veya yay)
# ============================================================
step "AUR helper kuruluyor"

if command -v paru &>/dev/null; then
    info "paru zaten kurulu"
    AUR_CMD="paru -S --needed --noconfirm"
elif command -v yay &>/dev/null; then
    info "yay zaten kurulu"
    AUR_CMD="yay -S --needed --noconfirm"
else
    info "paru kuruluyor..."
    sudo pacman -S --needed --noconfirm git base-devel
    local_tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$local_tmp/paru"
    (cd "$local_tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$local_tmp"
    AUR_CMD="paru -S --needed --noconfirm"
fi

# ============================================================
# 2. MULTILIB
# ============================================================
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    step "Multilib etkinleştiriliyor"
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    sudo pacman -Sy --noconfirm
else
    info "Multilib zaten etkin"
fi

# ============================================================
# 3. PAKET LİSTELERİ
# ============================================================
PACMAN_PKGS=(
    # Temel araçlar
    wget file git psmisc btop fzf direnv ffmpeg bc tree jq socat unzip

    # Python
    python python-pip python-websockets

    # Editör & terminal
    neovim kitty

    # Tarayıcı & iletişim
    firefox telegram-desktop

    # Ofis & not
    hunspell hunspell-en_us obsidian

    # Media
    obs-studio p7zip mpv

    # Geliştirici araçlar
    fastfetch grim slurp swappy playerctl imagemagick
    ripgrep fd lua-language-server pyright
    jdk8-openjdk wmctrl qbittorrent

    # Wayland / Masaüstü
    hyprland xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    wl-clipboard cliphist rofi-wayland pavucontrol nautilus
    alsa-utils pamixer brightnessctl acpi iw
    gtk3 cava inotify-tools

    # Qt5/Qt6 (SDDM + Quickshell)
    qt5-wayland qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects
    qt6-wayland qt6-multimedia qt6-5compat qt6-websockets qt6ct

    # Ses
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
    easyeffects ladspa lsp-plugins libpulse

    # Bluetooth & ağ
    bluez bluez-utils blueman networkmanager

    # Güç yönetimi
    power-profiles-daemon

    # Uygulama çerçevesi
    flatpak

    # Sanallaştırma (KVM)
    virt-manager libvirt qemu-desktop dnsmasq dmidecode edk2-ovmf swtpm

    # Container
    docker docker-compose

    # Ağ araçları
    nmap traceroute wireshark-qt mtr bandwhich

    # Modern CLI araçlar
    zoxide bat duf ncdu lazygit rsync tmux speedtest-cli

    # Android geliştirme
    android-tools

    # Sistem
    cups openssh zsh lm_sensors fortune-mod libnotify go-yq

    # Fontlar
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation ttf-jetbrains-mono

    # SDDM
    sddm
)

# GPU'ya göre sürücü paketleri ekle
if [[ "$IS_NVIDIA" == true ]]; then
    PACMAN_PKGS+=(nvidia nvidia-utils lib32-nvidia-utils nvidia-prime)
fi
if [[ "$IS_AMD" == true ]]; then
    PACMAN_PKGS+=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon)
fi
if [[ "$IS_INTEL" == true ]]; then
    PACMAN_PKGS+=(mesa lib32-mesa vulkan-intel lib32-vulkan-intel)
fi
if [[ "$IS_VM" == true ]]; then
    PACMAN_PKGS+=(mesa)
fi

# Steam sadece gerçek donanımda
if [[ "$IS_VM" == false ]]; then
    PACMAN_PKGS+=(steam gamemode lib32-gamemode)
fi

AUR_PKGS=(
    # Quickshell & Hyprland bileşenleri
    quickshell-git
    matugen-bin
    satty
    swww
    awww
    mpvpaper
    networkmanager-dmenu-git
    swayosd-git
    swaync
    eww

    # Fontlar
    ttf-udev-gothic
    ttf-iosevka-nerd

    # Tema
    adw-gtk-theme

    # Ofis
    onlyoffice-bin

    # Uygulamalar
    visual-studio-code-bin
    google-chrome
    acestream-engine
    notion-app-electron
    openai-codex
    spotify
    timeshift
    bottles
    intellij-idea-community-edition
)

# ============================================================
# 4. PAKET KURULUMU
# ============================================================
step "Pacman paketleri kuruluyor"
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

step "AUR paketleri kuruluyor"
$AUR_CMD "${AUR_PKGS[@]}" || warn "Bazı AUR paketleri kurulamadı, devam ediliyor..."

# ============================================================
# 5. REPO KLONLAMA & CONFIG DEPLOYMENT
# ============================================================
step "Dotfiles reposu klonlanıyor"

REPO_URL="https://github.com/ozkanaltunboga/arch-nix.git"
CLONE_DIR="$HOME/.hyprland-dots"
TARGET_CONFIG="$HOME/.config"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"

if [ -f "$(pwd)/install.sh" ] && [ -d "$(pwd)/.config" ]; then
    REPO_DIR="$(pwd)"
    info "Yerel repodan çalışılıyor: $REPO_DIR"
else
    if [ -d "$CLONE_DIR" ]; then
        info "Mevcut repo güncelleniyor..."
        git -C "$CLONE_DIR" pull || true
    else
        git clone "$REPO_URL" "$CLONE_DIR"
    fi
    REPO_DIR="$CLONE_DIR"
fi

# --- Config dosyalarını deploy et ---
step "Config dosyaları yerleştiriliyor"

CONFIG_FOLDERS=("cava" "hypr" "kitty" "rofi" "swaync" "matugen" "zsh" "swayosd" "nvim")
mkdir -p "$TARGET_CONFIG" "$BACKUP_DIR"

for folder in "${CONFIG_FOLDERS[@]}"; do
    SOURCE_PATH="$REPO_DIR/.config/$folder"
    TARGET_PATH="$TARGET_CONFIG/$folder"

    if [ -d "$SOURCE_PATH" ]; then
        # Mevcut config'i yedekle
        if [ -e "$TARGET_PATH" ]; then
            mv "$TARGET_PATH" "$BACKUP_DIR/$folder"
            info "Yedeklendi: $folder -> $BACKUP_DIR/$folder"
        fi
        cp -r "$SOURCE_PATH" "$TARGET_PATH"
        info "Kopyalandı: $folder"
    fi
done

# --- Wallpaper indir ---
step "Wallpaper'lar indiriliyor"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
mkdir -p "$WALLPAPER_DIR"

if [ "$(ls -A "$WALLPAPER_DIR" 2>/dev/null | grep -iE '\.(jpg|png|jpeg|webp)$')" ]; then
    info "Wallpaper'lar zaten mevcut, atlanıyor"
else
    WALLPAPER_REPO="https://github.com/ilyamiro/shell-wallpapers.git"
    WALLPAPER_TMP="/tmp/shell-wallpapers"
    rm -rf "$WALLPAPER_TMP"
    info "Wallpaper'lar indiriliyor..."
    git clone --depth 1 "$WALLPAPER_REPO" "$WALLPAPER_TMP" 2>/dev/null
    if [ -d "$WALLPAPER_TMP/images" ]; then
        cp -r "$WALLPAPER_TMP/images/"* "$WALLPAPER_DIR/" 2>/dev/null || true
    else
        cp -r "$WALLPAPER_TMP/"*.{jpg,png,jpeg,webp} "$WALLPAPER_DIR/" 2>/dev/null || true
    fi
    rm -rf "$WALLPAPER_TMP"
    info "Wallpaper'lar indirildi: $WALLPAPER_DIR"
fi

# ============================================================
# 6. HYPRLAND CONFIG ADAPTASYONU
# ============================================================
step "Hyprland config sisteme uyarlanıyor"

HYPR_CONF="$TARGET_CONFIG/hypr/hyprland.conf"

if [ -f "$HYPR_CONF" ]; then
    # --- Klavye: Türkçe Q ---
    sed -i "s/^ *kb_layout =.*/    kb_layout = tr/" "$HYPR_CONF"
    info "Klavye düzeni: Türkçe Q"

    # --- Environment Variables ---
    # Mevcut env satırlarını temizle (duplikasyon önleme)
    sed -i '/^env = WALLPAPER_DIR,/d' "$HYPR_CONF"
    sed -i '/^env = SCRIPT_DIR,/d' "$HYPR_CONF"
    sed -i '/^env = QML_XHR_ALLOW_FILE_READ,/d' "$HYPR_CONF"
    sed -i '/^env = QT_QUICK_BACKEND,/d' "$HYPR_CONF"

    # Temel env'ler ekle
    sed -i "/^env = NIXOS_OZONE_WL,1/a env = WALLPAPER_DIR,$WALLPAPER_DIR\nenv = SCRIPT_DIR,$HOME/.config/hypr/scripts\nenv = QML_XHR_ALLOW_FILE_READ,1" "$HYPR_CONF"
    info "Ortam değişkenleri eklendi"

    # --- VM GPU Fix ---
    if [[ "$IS_VM" == true ]]; then
        sed -i "/^env = QML_XHR_ALLOW_FILE_READ,1/a env = QT_QUICK_BACKEND,software" "$HYPR_CONF"
        # Kitty software rendering
        sed -i 's|^\$terminal = kitty|$terminal = env LIBGL_ALWAYS_SOFTWARE=1 kitty|' "$HYPR_CONF"
        sed -i 's|^\$terminal = env LIBGL_ALWAYS_SOFTWARE=1 env LIBGL_ALWAYS_SOFTWARE=1|$terminal = env LIBGL_ALWAYS_SOFTWARE=1|' "$HYPR_CONF"
        info "VM GPU fix'leri uygulandı (QT_QUICK_BACKEND=software, LIBGL_ALWAYS_SOFTWARE=1)"
    fi

    # --- NVIDIA env'leri ---
    if [[ "$IS_NVIDIA" == true ]]; then
        sed -i '/^env = NIXOS_OZONE_WL,1/a env = LIBVA_DRIVER_NAME,nvidia\nenv = XDG_SESSION_TYPE,wayland\nenv = GBM_BACKEND,nvidia-drm\nenv = __GLX_VENDOR_LIBRARY_NAME,nvidia\nenv = WLR_NO_HARDWARE_CURSORS,1' "$HYPR_CONF"
        info "NVIDIA Wayland env'leri eklendi"
    fi
fi

# --- Quickshell requestActivate fix ---
MAIN_QML="$TARGET_CONFIG/hypr/scripts/quickshell/Main.qml"
if [ -f "$MAIN_QML" ]; then
    sed -i 's|if (isVisible) masterWindow.requestActivate();|if (isVisible \&\& typeof masterWindow.requestActivate === "function") masterWindow.requestActivate();|' "$MAIN_QML"
    info "Quickshell requestActivate fix uygulandı"
fi

# --- swww -> awww patch ---
if [ -d "$TARGET_CONFIG/hypr/scripts" ]; then
    find "$TARGET_CONFIG/hypr/scripts" -type f -exec sed -i 's/swww/awww/g' {} +
    info "swww -> awww patch uygulandı"
fi

# --- Desktop/Laptop adaptasyonu ---
QS_BAT_DIR="$TARGET_CONFIG/hypr/scripts/quickshell/battery"
REPO_BAT_DIR="$REPO_DIR/.config/hypr/scripts/quickshell/battery"
if [[ "$HAS_BATTERY" == false ]] && [ -f "$REPO_BAT_DIR/BatteryPopupAlt.qml" ]; then
    cp -f "$REPO_BAT_DIR/BatteryPopupAlt.qml" "$QS_BAT_DIR/BatteryPopup.qml" 2>/dev/null || true
    info "Masaüstü: Batarya widget'ı -> Sistem Monitör widget'ına dönüştürüldü"
fi

QS_NET_DIR="$TARGET_CONFIG/hypr/scripts/quickshell/network"
REPO_NET_DIR="$REPO_DIR/.config/hypr/scripts/quickshell/network"
if [[ "$HAS_WIFI" == false ]] && [ -f "$REPO_NET_DIR/NetworkPopupAlt.qml" ]; then
    cp -f "$REPO_NET_DIR/NetworkPopupAlt.qml" "$QS_NET_DIR/NetworkPopup.qml" 2>/dev/null || true
    info "Masaüstü/VM: Wi-Fi widget'ı -> Ethernet widget'ına dönüştürüldü"
fi

# ============================================================
# 7. FONTLAR
# ============================================================
step "Fontlar kuruluyor"

TARGET_FONTS="$HOME/.local/share/fonts"
REPO_FONTS="$REPO_DIR/.local/share/fonts"
mkdir -p "$TARGET_FONTS"

# Repo'daki fontları kopyala
if [ -d "$REPO_FONTS" ]; then
    cp -r "$REPO_FONTS/"* "$TARGET_FONTS/" 2>/dev/null || true
fi

# Iosevka Nerd Font indir
if [ -d "$TARGET_FONTS/IosevkaNerdFont" ] && [ "$(ls -A "$TARGET_FONTS/IosevkaNerdFont" 2>/dev/null | grep -i '\.ttf')" ]; then
    info "Iosevka Nerd Font zaten kurulu"
else
    info "Iosevka Nerd Font indiriliyor..."
    mkdir -p /tmp/iosevka-pack
    curl -fLo /tmp/iosevka-pack/Iosevka.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip
    unzip -q /tmp/iosevka-pack/Iosevka.zip -d /tmp/iosevka-pack/
    mkdir -p "$TARGET_FONTS/IosevkaNerdFont"
    mv /tmp/iosevka-pack/*.ttf "$TARGET_FONTS/IosevkaNerdFont/"
    sudo cp -r "$TARGET_FONTS/IosevkaNerdFont" /usr/share/fonts/
    rm -rf /tmp/iosevka-pack
    info "Iosevka Nerd Font kuruldu"
fi

find "$TARGET_FONTS" -type f -exec chmod 644 {} \; 2>/dev/null
find "$TARGET_FONTS" -type d -exec chmod 755 {} \; 2>/dev/null
fc-cache -f "$TARGET_FONTS" 2>/dev/null || true
info "Font cache güncellendi"

# ============================================================
# 8. ZSH KURULUMU
# ============================================================
step "Zsh yapılandırılıyor"

# Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Oh My Zsh kuruluyor..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Pluginler
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] && \
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# .zshrc deploy
ZSH_RC="$HOME/.zshrc"
if [ -f "$TARGET_CONFIG/zsh/.zshrc" ]; then
    # Mevcut alias'ları yedekle
    if [ -f "$ZSH_RC" ]; then
        mkdir -p "$TARGET_CONFIG/zsh"
        grep "^alias " "$ZSH_RC" > "$TARGET_CONFIG/zsh/user_aliases.zsh" 2>/dev/null || true
    fi
    cp "$TARGET_CONFIG/zsh/.zshrc" "$ZSH_RC"
    # Dinamik path'ler ekle
    echo -e "\n# Dynamic System Paths" >> "$ZSH_RC"
    echo "export WALLPAPER_DIR=\"$WALLPAPER_DIR\"" >> "$ZSH_RC"
    echo "export SCRIPT_DIR=\"$HOME/.config/hypr/scripts\"" >> "$ZSH_RC"
    # Eski alias'ları geri yükle
    if [ -s "$TARGET_CONFIG/zsh/user_aliases.zsh" ]; then
        echo -e "\n# User Aliases" >> "$ZSH_RC"
        echo "source $TARGET_CONFIG/zsh/user_aliases.zsh" >> "$ZSH_RC"
    fi
fi

if [[ "$SHELL" != "$(which zsh)" ]]; then
    chsh -s "$(which zsh)"
    info "Varsayılan shell: zsh"
fi

# ============================================================
# 9. SİSTEM SERVİSLERİ
# ============================================================
step "Sistem servisleri etkinleştiriliyor"

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now cups
sudo systemctl enable --now sshd
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable --now libvirtd
sudo systemctl enable --now docker
sudo virsh net-autostart default 2>/dev/null || true
sudo virsh net-start default 2>/dev/null || true

# Pipewire (global - TTY'den çalışsa bile)
sudo systemctl --global enable pipewire wireplumber pipewire-pulse 2>/dev/null || true
systemctl --user start pipewire wireplumber pipewire-pulse 2>/dev/null || true

# SwayOSD
sudo systemctl enable --now swayosd-libinput-backend.service 2>/dev/null || true
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
cat <<EOF > "$SYSTEMD_USER_DIR/swayosd.service"
[Unit]
Description=SwayOSD Service
PartBy=graphical-session.target
After=graphical-session.target
ConditionEnvironment=WAYLAND_DISPLAY

[Service]
Type=simple
ExecStart=/usr/bin/swayosd-server --top-margin 0.9 --style \${HOME}/.config/swayosd/style.css
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable swayosd.service 2>/dev/null || true
info "SwayOSD servisi yapılandırıldı"

# Kullanıcı grupları
for grp in NetworkManager wheel video libvirt docker wireshark; do
    sudo usermod -aG "$grp" "$USER" 2>/dev/null || warn "Grup bulunamadı: $grp"
done
info "Kullanıcı grupları güncellendi"

# ============================================================
# 10. SDDM (Display Manager)
# ============================================================
step "SDDM yapılandırılıyor"

# SDDM'i etkinleştir (varsa diğer DM'leri devre dışı bırak)
sudo systemctl disable gdm.service lightdm.service ly.service 2>/dev/null || true
sudo systemctl enable sddm.service -f
info "SDDM etkinleştirildi"

# SDDM Wayland config
sudo mkdir -p /etc/sddm.conf.d
cat <<EOF | sudo tee /etc/sddm.conf.d/10-wayland.conf > /dev/null
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF

# SDDM tema (repo'da varsa)
if [ -d "$REPO_DIR/.config/sddm/themes/matugen-minimal" ]; then
    sudo mkdir -p /usr/share/sddm/themes/matugen-minimal
    sudo cp -r "$REPO_DIR/.config/sddm/themes/matugen-minimal/"* /usr/share/sddm/themes/matugen-minimal/

    # Fallback Colors.qml
    cat <<'QMLEOF' | sudo tee /usr/share/sddm/themes/matugen-minimal/Colors.qml > /dev/null
pragma Singleton
import QtQuick
QtObject {
    readonly property color base: "#1e1e2e"
    readonly property color crust: "#11111b"
    readonly property color mantle: "#181825"
    readonly property color text: "#cdd6f4"
    readonly property color subtext0: "#a6adc8"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color mauve: "#cba6f7"
    readonly property color red: "#f38ba8"
    readonly property color peach: "#fab387"
    readonly property color blue: "#89b4fa"
    readonly property color green: "#a6e3a1"
}
QMLEOF

    cat <<EOF | sudo tee /etc/sddm.conf.d/10-wayland.conf > /dev/null
[Theme]
Current=matugen-minimal

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF
    info "SDDM teması yapılandırıldı"
fi

# VM ise SDDM'e de software rendering ekle
if [[ "$IS_VM" == true ]]; then
    sudo sed -i 's/^GreeterEnvironment=.*/GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1,QT_QUICK_BACKEND=software/' /etc/sddm.conf.d/10-wayland.conf
    info "SDDM VM fix uygulandı"
fi

# ============================================================
# 11. LOCALE (UTF-8)
# ============================================================
step "Locale ayarlanıyor"

if ! locale 2>/dev/null | grep -q 'UTF-8'; then
    sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    sudo sed -i 's/^#tr_TR.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen
    echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf
    info "Locale: en_US.UTF-8 + tr_TR.UTF-8"
fi

# ============================================================
# 12. NETWORK SYSCTL (BBR)
# ============================================================
step "Ağ optimizasyonları"

cat <<'EOF' | sudo tee /etc/sysctl.d/99-bbr.conf > /dev/null
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.core.wmem_max = 1073741824
net.core.rmem_max = 1073741824
net.ipv4.tcp_rmem = 4096 87380 1073741824
net.ipv4.tcp_wmem = 4096 87380 1073741824
EOF
sudo modprobe tcp_bbr 2>/dev/null || true
sudo sysctl --system > /dev/null 2>&1
info "BBR TCP etkinleştirildi"

# ============================================================
# 13. NVIDIA AYARLARI (sadece NVIDIA varsa)
# ============================================================
if [[ "$IS_NVIDIA" == true ]]; then
    step "NVIDIA yapılandırması"
    cat <<'EOF' | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia-drm modeset=1
EOF
    info "NVIDIA modprobe ayarları yapılandırıldı"
fi

# ============================================================
# 14. FLATPAK
# ============================================================
step "Flatpak yapılandırılıyor"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
info "Flathub deposu eklendi"

# ============================================================
# 15. CAVA WRAPPER
# ============================================================
mkdir -p "$HOME/.local/bin"
if [ -f "$REPO_DIR/utils/bin/cava" ]; then
    cp "$REPO_DIR/utils/bin/cava" "$HOME/.local/bin/cava"
    chmod +x "$HOME/.local/bin/cava"
    info "Cava wrapper kuruldu"
fi

# ============================================================
# TAMAMLANDI
# ============================================================
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  ✓ Kurulum tamamlandı!${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Config yedeği: ${CYAN}$BACKUP_DIR${NC}"
echo -e "  Wallpaper'lar: ${CYAN}$WALLPAPER_DIR${NC}"
echo ""
if [[ "$IS_VM" == true ]]; then
    echo -e "  ${YELLOW}VM algılandı - Software rendering aktif${NC}"
fi
echo ""
echo -e "  ${BOLD}Sistemi yeniden başlatın:${NC} sudo reboot"
echo ""
