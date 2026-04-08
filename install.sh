#!/usr/bin/env bash
# ============================================================
# CachyOS / Arch Linux kurulum scripti
# configuration.nix'in Arch/CachyOS karşılığı
# ============================================================
set -e

# --- Renkler ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ $EUID -eq 0 ]] && error "Bu scripti root olarak çalıştırmayın!"

# ============================================================
# 1. PARU (AUR helper)
# ============================================================
install_paru() {
    if command -v paru &>/dev/null; then
        info "paru zaten kurulu, atlanıyor."
        return
    fi
    info "paru kuruluyor..."
    sudo pacman -S --needed --noconfirm git base-devel
    local tmp; tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

# ============================================================
# 2. Multilib (Steam için gerekli)
# ============================================================
enable_multilib() {
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        info "multilib zaten etkin."
        return
    fi
    info "multilib etkinleştiriliyor..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    sudo pacman -Sy
}

# ============================================================
# 3. Pacman paketleri
# ============================================================
PACMAN_PKGS=(
    # Temel araçlar
    wget file git psmisc btop fzf direnv ffmpeg bc tree jq socat

    # Python
    python python-pip

    # Editör & terminal
    neovim kitty

    # Tarayıcı & iletişim
    firefox telegram-desktop

    # Ofis & not
    libreoffice-qt6 hunspell hunspell-en_us hunspell-ru obsidian

    # Media
    obs-studio p7zip mpv

    # Geliştirici araçlar
    fastfetch grim slurp swappy playerctl imagemagick
    ripgrep fd lua-language-server pyright
    jdk8-openjdk wmctrl qbittorrent

    # Wayland / Masaüstü
    hyprland xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    wl-clipboard cliphist rofi-wayland pavucontrol
    alsa-utils pamixer brightnessctl acpi iw
    gtk3 cava

    # Qt6
    qt6-multimedia qt6-5compat qt6-websockets qt6ct

    # Ses
    pipewire pipewire-alsa pipewire-pulse wireplumber easyeffects
    ladspa ladspa-host

    # Bluetooth & ağ
    bluez bluez-utils blueman networkmanager

    # Güç yönetimi
    power-profiles-daemon

    # Uygulama çerçevesi
    flatpak

    # Sanallaştırma
    virt-manager libvirt qemu-desktop

    # Android geliştirme
    android-tools

    # Sistem
    cups openssh zsh lm_sensors fortune-mod libnotify
    go-yq

    # Fontlar
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation ttf-jetbrains-mono

    # GPU: NVIDIA (PRIME offload)
    nvidia nvidia-utils lib32-nvidia-utils nvidia-prime

    # GPU: AMD (iGPU)
    mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon

    # Steam & oyun
    steam gamemode lib32-gamemode
)

# ============================================================
# 4. AUR paketleri
# ============================================================
AUR_PKGS=(
    matugen
    quickshell-git
    satty
    swww
    mpvpaper
    networkmanager-dmenu-git
    swayosd-git
    swaynotificationcenter
    eww
    bottles
    intellij-idea-community-edition
    mingw-w64-gcc
    ttf-udev-gothic-nerd
    iosevka-nerd-font
    adw-gtk3
)

# ============================================================
# 5. Kurulum
# ============================================================
install_paru
enable_multilib

info "Pacman paketleri kuruluyor..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

info "AUR paketleri kuruluyor..."
paru -S --needed --noconfirm "${AUR_PKGS[@]}"

# ============================================================
# 6. Sistem servisleri
# ============================================================
info "Sistem servisleri etkinleştiriliyor..."

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now cups
sudo systemctl enable --now sshd
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable --now libvirtd

# Kullanıcı servisleri
systemctl --user enable --now pipewire pipewire-pulse wireplumber
systemctl --user enable --now easyeffects

# ============================================================
# 7. Kullanıcı grupları
# ============================================================
info "Kullanıcı grupları ayarlanıyor..."
sudo usermod -aG networkmanager,wheel,video,adbusers,libvirt "$USER"

# ============================================================
# 8. Zsh varsayılan shell
# ============================================================
if [[ "$SHELL" != "$(which zsh)" ]]; then
    info "Varsayılan shell zsh olarak ayarlanıyor..."
    chsh -s "$(which zsh)"
fi

# ============================================================
# 9. Kernel parametreleri (BBR + AMD pstate)
# ============================================================
info "Kernel parametreleri systemd-boot ile ayarlanıyor..."
BOOT_ENTRY=$(sudo find /boot/loader/entries -name "*.conf" | head -1)

if [[ -n "$BOOT_ENTRY" ]]; then
    PARAMS="quiet splash loglevel=3 amd_pstate=active tsc=reliable asus_wmi net.ifnames=0"
    if ! sudo grep -q "amd_pstate" "$BOOT_ENTRY"; then
        sudo sed -i "/^options/ s/$/ $PARAMS/" "$BOOT_ENTRY"
        info "Kernel parametreleri eklendi: $BOOT_ENTRY"
    fi
fi

# BBR TCP sysctl
cat <<'EOF' | sudo tee /etc/sysctl.d/99-bbr.conf
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.core.wmem_max = 1073741824
net.core.rmem_max = 1073741824
net.ipv4.tcp_rmem = 4096 87380 1073741824
net.ipv4.tcp_wmem = 4096 87380 1073741824
EOF
sudo modprobe tcp_bbr
sudo sysctl --system

# ============================================================
# 10. CPU governor (performans modu)
# ============================================================
info "CPU governor 'performance' olarak ayarlanıyor..."
cat <<'EOF' | sudo tee /etc/tmpfiles.d/cpu-governor.conf
w /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor - - - - performance
EOF

# ============================================================
# 11. NVIDIA PRIME ayarları
# ============================================================
info "NVIDIA PRIME yapılandırması..."
cat <<'EOF' | sudo tee /etc/modprobe.d/nvidia.conf
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia-drm modeset=1
EOF

# ============================================================
# 12. Flatpak uzak deposu
# ============================================================
info "Flatpak Flathub deposu ekleniyor..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# ============================================================
# 13. Oh My Zsh
# ============================================================
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Oh My Zsh kuruluyor..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Zsh pluginleri
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# ============================================================
info "Kurulum tamamlandı! Sistemi yeniden başlatın: sudo reboot"
