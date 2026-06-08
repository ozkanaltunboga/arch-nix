#!/usr/bin/env bash
# ============================================================
#   Arch Linux / CachyOS - Tek Komutla Tam Kurulum
# ============================================================
set -eo pipefail

# --- Renkler ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()  { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${NC}"; }

[[ $EUID -eq 0 ]] && error "Bu scripti root olarak çalıştırmayın! (sudo kullanmayın)"

# --- Sudo keepalive ---
# Şifreyi başta bir kez sor, sonra arka planda sürekli yenile
sudo -v || error "sudo yetkisi alınamadı"
(while true; do sudo -n true; sleep 50; done) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null; echo -e "\n${RED}[HATA]${NC} Kurulum sırasında bir hata oluştu (satır $LINENO). Detay için yukarıdaki çıktıyı kontrol edin." >&2' EXIT

# Minimal kurulumlarda donanım algılama araçları eksik olabilir.
sudo pacman -S --needed --noconfirm pciutils iw || error "pciutils/iw kurulamadı (donanım algılama için gerekli)"

# ============================================================
# 0. DONANIM ALGILAMA
# ============================================================
step "Donanım algılanıyor"

GPU_RAW=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true)
IS_VM=false
VM_TYPE="$(systemd-detect-virt --vm 2>/dev/null || true)"
IS_NVIDIA=false
IS_AMD=false
IS_INTEL=false
HAS_BATTERY=false
HAS_WIFI=false

if [[ -n "$VM_TYPE" && "$VM_TYPE" != "none" ]]; then
    IS_VM=true
    info "Sanal makine algılandı: $VM_TYPE (VM fix'leri uygulanacak)"
elif echo "$GPU_RAW" | grep -qi "vmware\|virtualbox\|qxl\|virtio\|bochs\|hyper-v\|parallels"; then
    IS_VM=true
    if echo "$GPU_RAW" | grep -qi "vmware"; then
        VM_TYPE="vmware"
    elif echo "$GPU_RAW" | grep -qi "virtualbox"; then
        VM_TYPE="oracle"
    elif echo "$GPU_RAW" | grep -qi "qxl\|virtio\|bochs"; then
        VM_TYPE="qemu"
    else
        VM_TYPE="generic"
    fi
    info "Sanal makine algılandı (VM fix'leri uygulanacak)"
fi

if echo "$GPU_RAW" | grep -qi "nvidia"; then
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
    sudo pacman -S --needed --noconfirm git base-devel cargo || error "base-devel/cargo kurulamadı"
    local_tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$local_tmp/paru" || error "paru clone başarısız"
    sudo -v
    (cd "$local_tmp/paru" && makepkg -si --noconfirm) || error "paru derlenemedi"
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
# 2.1 PACMAN MIRROR & DOWNLOAD AYARLARI
# ============================================================
step "Pacman mirror ayarları yenileniyor"

sudo cp /etc/pacman.d/mirrorlist "/etc/pacman.d/mirrorlist.backup-$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
MIRRORLIST_URL="https://archlinux.org/mirrorlist/?country=TR&country=DE&country=NL&country=FR&protocol=https&ip_version=4&use_mirror_status=on"
if curl -fsSL "$MIRRORLIST_URL" | sed 's/^#Server/Server/' | sudo tee /etc/pacman.d/mirrorlist > /dev/null; then
    info "Mirrorlist güncellendi (TR/DE/NL/FR HTTPS)"
else
    warn "Mirrorlist indirilemedi; mevcut mirrorlist kullanılacak"
fi

sudo sed -i \
    -e '/^#\?ParallelDownloads[[:space:]]*=/d' \
    -e '/^DisableDownloadTimeout$/d' \
    /etc/pacman.conf
sudo sed -i '/^\[options\]/a DisableDownloadTimeout\nParallelDownloads = 8' /etc/pacman.conf

sudo pacman -Syy --noconfirm

# ============================================================
# 3. PAKET LİSTELERİ
# ============================================================
PACMAN_PKGS=(
    # Temel araçlar
    wget file git psmisc btop fzf direnv ffmpeg bc tree jq socat unzip pciutils

    # Python
    python python-pip python-websockets

    # Editör & terminal
    neovim kitty

    # Tarayıcı & iletişim
    firefox telegram-desktop

    # Ofis & not
    hunspell hunspell-en_us

    # Media
    obs-studio p7zip mpv

    # Geliştirici araçlar
    fastfetch grim slurp swappy playerctl imagemagick
    ripgrep fd lua-language-server pyright
    wmctrl qbittorrent

    # Wayland / Masaüstü
    hyprland xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    wl-clipboard cliphist rofi-wayland pavucontrol nautilus
    alsa-utils pamixer brightnessctl acpi iw     hyprlock
    hypridle
    gtk3 cava inotify-tools

    # Dock & ikon temaları
    nwg-dock-hyprland papirus-icon-theme hicolor-icon-theme adwaita-icon-theme
    desktop-file-utils

    # Qt5/Qt6 (SDDM + Quickshell)
    qt5-wayland qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects
    qt6-wayland qt6-multimedia qt6-multimedia-ffmpeg qt6-5compat qt6-websockets qt6ct

    # Ses
    pipewire pipewire-alsa pipewire-pulse wireplumber
    easyeffects ladspa lsp-plugins-ladspa lsp-plugins-lv2 libpulse

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
    nmap traceroute mtr bandwhich

    # Modern CLI araçlar
    zoxide bat duf ncdu lazygit rsync tmux speedtest-cli

    # Android geliştirme
    android-tools

    # Sistem
    cups openssh zsh lm_sensors fortune-mod libnotify go-yq

    # Güvenlik
    ufw fail2ban

    # Sistem sağlığı
    zram-generator earlyoom pacman-contrib

    # Performans
    libva-utils profile-sync-daemon plymouth

    # Developer runtime'lar
    nodejs npm go pyenv

    # Senkronizasyon
    syncthing

    # Fontlar
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation ttf-jetbrains-mono

    # Cursor tema
    breeze

    # SDDM
    sddm
)

# GPU'ya göre sürücü paketleri ekle
if [[ "$IS_NVIDIA" == true ]]; then
    PACMAN_PKGS+=(nvidia nvidia-utils lib32-nvidia-utils nvidia-prime)
fi
if [[ "$IS_AMD" == true ]]; then
    PACMAN_PKGS+=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver)
fi
if [[ "$IS_INTEL" == true ]]; then
    PACMAN_PKGS+=(mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver)
fi
if [[ "$IS_VM" == true ]]; then
    PACMAN_PKGS+=(mesa)
    case "$VM_TYPE" in
        vmware)
            PACMAN_PKGS+=(open-vm-tools gtkmm3)
            ;;
        oracle|virtualbox)
            PACMAN_PKGS+=(virtualbox-guest-utils)
            ;;
        qemu|kvm|bochs)
            PACMAN_PKGS+=(qemu-guest-agent spice-vdagent)
            ;;
        *)
            PACMAN_PKGS+=(open-vm-tools gtkmm3 qemu-guest-agent spice-vdagent)
            ;;
    esac
fi

# Steam ve gaming sadece gerçek donanımda
if [[ "$IS_VM" == false ]]; then
    PACMAN_PKGS+=(
        steam
        gamemode
        lib32-gamemode
        
        # 32-bit kütüphaneler (oyunlar için kritik)
        lib32-glibc
        lib32-libx11
        lib32-libxcomposite
        lib32-libxcursor
        lib32-libxi
        lib32-libxrandr
        lib32-libxtst
        lib32-libxinerama
        lib32-mesa
        lib32-libva
        lib32-libvdpau
        lib32-sdl2
        lib32-sdl_image
        lib32-libpng
        lib32-libjpeg-turbo
        lib32-freetype2
        lib32-fontconfig
        lib32-gtk3
        lib32-gst-plugins-base
        lib32-gst-plugins-good
        lib32-openal
        lib32-libpulse
        lib32-alsa-plugins
        lib32-libcurl-gnutls
        lib32-nss
        lib32-nspr
        lib32-dbus
        lib32-libdrm
        lib32-libxss
        lib32-libgcrypt
        
        # Controller desteği
        steam-devices
        
        # Gaming araçları
        mangohud
        lib32-mangohud
        gamescope
        vkbasalt
        lib32-vkbasalt
    )
    
    # GPU-specific 32-bit Vulkan
    if [[ "$IS_NVIDIA" == true ]]; then
        PACMAN_PKGS+=(lib32-nvidia-utils)
    fi
    if [[ "$IS_AMD" == true ]]; then
        PACMAN_PKGS+=(lib32-vulkan-radeon)
    fi
    if [[ "$IS_INTEL" == true ]]; then
        PACMAN_PKGS+=(lib32-vulkan-intel)
    fi
fi

AUR_PKGS=(
    # Quickshell & Hyprland bileşenleri
    quickshell-git
    matugen-bin
    swww
    awww
    mpvpaper
    networkmanager-dmenu-git
    swayosd-git
    swaync
    wlogout
    sddm-sugar-candy-git

    # Fontlar
    ttf-udev-gothic
    ttf-iosevka-nerd

    # Developer araçlar
    nvm

    # Tema
    adw-gtk-theme

    # Ofis
    onlyoffice-bin

    # Uygulamalar
    visual-studio-code-bin
    google-chrome
    notion-app-electron
    spotify
    timeshift
    bottles
    intellij-idea-community-edition
    
    # Gaming (sadece non-VM)
    discord
)

# Gaming AUR paketleri (sadece gerçek donanım)
if [[ "$IS_VM" == false ]]; then
    AUR_PKGS+=(
        lutris
        protonup-qt
        heroic-games-launcher-bin
        wine-staging
        dxvk-bin
        vkd3d-proton-bin
        lib32-gnutls
        lib32-libldap
        lib32-libgpg-error
        lib32-libxml2
        lib32-sdl2_image
        lib32-sdl2_mixer
        lib32-sdl2_ttf
    )
fi

# ============================================================
# 4. PAKET KURULUMU
# ============================================================
step "Pacman paketleri kuruluyor"
if ! sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"; then
    error "Pacman paketleri kurulamadı. Yukarıdaki hata mesajını kontrol edin."
fi

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

if [ -f "$(pwd)/install.sh" ] && [ -d "$(pwd)/config" ]; then
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

# --- Config dosyalarını deploy et (copy + timestamp backup) ---
step "Config dosyaları yerleştiriliyor"

mkdir -p "$TARGET_CONFIG" "$BACKUP_DIR"

deploy() {
    local src="$1"
    local dst="$2"
    if [ ! -e "$src" ]; then
        warn "Kaynak bulunamadı, atlanıyor: $src"
        return 0
    fi
    if [ -e "$dst" ]; then
        if diff -rq "$src" "$dst" >/dev/null 2>&1; then
            info "Değişiklik yok, atlanıyor: $dst"
            return 0
        fi
        mv "$dst" "$BACKUP_DIR/$(basename "$dst")-$(date +%s)"
        info "Yedeklendi: $dst"
    fi
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    info "Kopyalandı: $dst"
}

# Mappings from config/ -> ~/.config
deploy "$REPO_DIR/config/programs/kitty"      "$TARGET_CONFIG/kitty"
deploy "$REPO_DIR/config/programs/rofi"       "$TARGET_CONFIG/rofi"
deploy "$REPO_DIR/config/programs/matugen"    "$TARGET_CONFIG/matugen"
deploy "$REPO_DIR/config/programs/swaync"     "$TARGET_CONFIG/swaync"
deploy "$REPO_DIR/config/programs/swayosd"    "$TARGET_CONFIG/swayosd"
if [ ! -d "$TARGET_CONFIG/swayosd" ]; then
    mkdir -p "$TARGET_CONFIG/swayosd"
    info "swayosd dizini oluşturuldu (fallback)"
fi
deploy "$REPO_DIR/config/programs/wlogout"    "$TARGET_CONFIG/wlogout"
deploy "$REPO_DIR/config/programs/nwg-dock-hyprland" "$TARGET_CONFIG/nwg-dock-hyprland"
chmod +x "$TARGET_CONFIG/nwg-dock-hyprland/launch.sh" 2>/dev/null || true
deploy "$REPO_DIR/config/programs/neovim/nvim" "$TARGET_CONFIG/nvim"
deploy "$REPO_DIR/config/sessions/hyprland"    "$TARGET_CONFIG/hypr"
find "$TARGET_CONFIG/hypr/scripts" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} + 2>/dev/null || true

# Plymouth deploy
if [ -d "$REPO_DIR/config/programs/plymouth" ]; then
    sudo mkdir -p /usr/share/plymouth/themes
    sudo cp -r "$REPO_DIR/config/programs/plymouth/simple" /usr/share/plymouth/themes/
    sudo plymouth-set-default-theme -R simple 2>/dev/null || true
    info "Plymouth boot splash kuruldu"
fi

# EasyEffects presets deploy
if [ -d "$REPO_DIR/config/media/easyeffects" ]; then
    mkdir -p "$HOME/.config/easyeffects/input" "$HOME/.config/easyeffects/output"
    cp "$REPO_DIR/config/media/easyeffects/default-preset.json" "$HOME/.config/easyeffects/output/"
    info "EasyEffects preset'leri kuruldu"
fi

# Cava: config_base
deploy "$REPO_DIR/config/programs/cava/config" "$TARGET_CONFIG/cava/config_base"

# Firefox chrome (fallback to ~/.config/firefox-chrome if profile not found)
deploy "$REPO_DIR/config/programs/firefox/chrome" "$TARGET_CONFIG/firefox-chrome"
if [ -d "$HOME/.mozilla/firefox" ]; then
    FIREFOX_PROFILE_DIR="$(find "$HOME/.mozilla/firefox" -maxdepth 1 -name '*.default*' -type d 2>/dev/null | head -n1 || true)"
else
    FIREFOX_PROFILE_DIR=""
fi
if [ -n "$FIREFOX_PROFILE_DIR" ]; then
    deploy "$REPO_DIR/config/programs/firefox/chrome" "$FIREFOX_PROFILE_DIR/chrome"
    if [ -d "$TARGET_CONFIG/firefox-chrome" ]; then
        cp -r "$TARGET_CONFIG/firefox-chrome/." "$FIREFOX_PROFILE_DIR/chrome/" 2>/dev/null || true
    fi
    info "Firefox chrome temaları profile uygulandı"
else
    info "Firefox profili bulunamadı. İlk Firefox açılışında chrome temaları ~/.config/firefox-chrome'dan kopyalanacak."
fi

# --- Wallpaper kurulumu ---
step "Wallpaper'lar kuruluyor"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
REPO_WALLPAPER_DIR="$REPO_DIR/config/wallpapers"
mkdir -p "$WALLPAPER_DIR"

if [ -d "$REPO_WALLPAPER_DIR" ]; then
    copied_wallpapers=0
    while IFS= read -r -d '' wallpaper; do
        target_wallpaper="$WALLPAPER_DIR/$(basename "$wallpaper")"
        if [ ! -e "$target_wallpaper" ]; then
            cp "$wallpaper" "$target_wallpaper"
            copied_wallpapers=$((copied_wallpapers + 1))
        fi
    done < <(find "$REPO_WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0)
    info "Repo wallpaper'ları hazırlandı: $WALLPAPER_DIR ($copied_wallpapers yeni dosya)"
else
    warn "Repo wallpaper klasörü bulunamadı: $REPO_WALLPAPER_DIR"
fi

if ! find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | grep -q .; then
    warn "Wallpaper bulunamadı. Lütfen kendi wallpaper'larınızı $WALLPAPER_DIR altına yerleştirin."
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
    sed -i "s|^env = WALLPAPER_DIR,.*|env = WALLPAPER_DIR,$WALLPAPER_DIR|" "$HYPR_CONF"
    sed -i '/^env = SCRIPT_DIR,/d' "$HYPR_CONF"
    sed -i '/^env = QT_QUICK_BACKEND,/d' "$HYPR_CONF"
    sed -i '/^env = WLR_RENDERER_ALLOW_SOFTWARE,/d' "$HYPR_CONF"
    sed -i '/^env = LIBGL_ALWAYS_SOFTWARE,/d' "$HYPR_CONF"
    info "Ortam değişkenleri güncellendi"

    # --- VM GPU Fix ---
    if [[ "$IS_VM" == true ]]; then
        sed -i '/^env = QML_XHR_ALLOW_FILE_READ,1/a env = QT_QUICK_BACKEND,software\nenv = WLR_RENDERER_ALLOW_SOFTWARE,1\nenv = LIBGL_ALWAYS_SOFTWARE,1' "$HYPR_CONF"
        for vm_env in WLR_RENDERER_ALLOW_SOFTWARE=1 LIBGL_ALWAYS_SOFTWARE=1; do
            vm_key="${vm_env%%=*}"
            if grep -q "^${vm_key}=" /etc/environment 2>/dev/null; then
                sudo sed -i "s|^${vm_key}=.*|${vm_env}|" /etc/environment
            else
                echo "$vm_env" | sudo tee -a /etc/environment > /dev/null
            fi
        done
        # Kitty software rendering
        sed -i 's|^\$terminal = kitty|$terminal = env LIBGL_ALWAYS_SOFTWARE=1 kitty|' "$HYPR_CONF"
        sed -i 's|^\$terminal = env LIBGL_ALWAYS_SOFTWARE=1 env LIBGL_ALWAYS_SOFTWARE=1|$terminal = env LIBGL_ALWAYS_SOFTWARE=1|' "$HYPR_CONF"
        info "VM GPU fix'leri uygulandı (software rendering env'leri aktif)"
    fi

    # --- NVIDIA env'leri ---
    if [[ "$IS_NVIDIA" == true ]]; then
        sed -i '/^env = WALLPAPER_DIR,/a env = LIBVA_DRIVER_NAME,nvidia\nenv = XDG_SESSION_TYPE,wayland\nenv = GBM_BACKEND,nvidia-drm\nenv = __GLX_VENDOR_LIBRARY_NAME,nvidia\nenv = WLR_NO_HARDWARE_CURSORS,1' "$HYPR_CONF"
        info "NVIDIA Wayland env'leri eklendi"
    fi
fi

# --- Desktop/Laptop adaptasyonu ---
QS_BAT_DIR="$TARGET_CONFIG/hypr/scripts/quickshell/battery"
REPO_BAT_DIR="$REPO_DIR/config/sessions/hyprland/scripts/quickshell/battery"
if [[ "$HAS_BATTERY" == false ]] && [ -f "$REPO_BAT_DIR/BatteryPopupAlt.qml" ]; then
    cp -f "$REPO_BAT_DIR/BatteryPopupAlt.qml" "$QS_BAT_DIR/BatteryPopup.qml" 2>/dev/null || true
    info "Masaüstü: Batarya widget'ı -> Sistem Monitör widget'ına dönüştürüldü"
fi

QS_NET_DIR="$TARGET_CONFIG/hypr/scripts/quickshell/network"
REPO_NET_DIR="$REPO_DIR/config/sessions/hyprland/scripts/quickshell/network"
if [[ "$HAS_WIFI" == false ]] && [ -f "$REPO_NET_DIR/NetworkPopupAlt.qml" ]; then
    cp -f "$REPO_NET_DIR/NetworkPopupAlt.qml" "$QS_NET_DIR/NetworkPopup.qml" 2>/dev/null || true
    info "Masaüstü/VM: Wi-Fi widget'ı -> Ethernet widget'ına dönüştürüldü"
fi

# ============================================================
# 7. FONTLAR
# ============================================================
step "Fontlar kuruluyor"

TARGET_FONTS="$HOME/.local/share/fonts"
REPO_FONTS="$REPO_DIR/config/fonts"
mkdir -p "$TARGET_FONTS"

# Repo'daki fontları kopyala
if [ -d "$REPO_FONTS" ]; then
    cp -r "$REPO_FONTS/"* "$TARGET_FONTS/" 2>/dev/null || true
fi

# Iosevka AUR paketi sistem fontu olarak gelmişse tekrar indirme.
if fc-match "Iosevka Nerd Font" 2>/dev/null | grep -qi "Iosevka"; then
    info "Iosevka Nerd Font sistemde mevcut"
elif [ -d "$TARGET_FONTS/IosevkaNerdFont" ] && [ "$(ls -A "$TARGET_FONTS/IosevkaNerdFont" 2>/dev/null | grep -i '\.ttf')" ]; then
    info "Iosevka Nerd Font zaten kurulu"
else
    warn "Iosevka Nerd Font bulunamadı; AUR font kurulumu başarısız olmuş olabilir"
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

# .zshrc alias restore (deploy'dan önce alias'ları kaydet)
ZSH_RC="$HOME/.zshrc"
SAVED_ALIASES="$HOME/.zshrc.aliases.bak"
if [ -f "$ZSH_RC" ]; then
    grep "^alias " "$ZSH_RC" > "$SAVED_ALIASES" 2>/dev/null || true
fi

deploy "$REPO_DIR/config/programs/zsh" "$TARGET_CONFIG/zsh"
deploy "$REPO_DIR/config/programs/zsh/.zshrc" "$HOME/.zshrc"

# Alias'ları geri yükle
if [ -f "$SAVED_ALIASES" ] && [ -s "$SAVED_ALIASES" ]; then
    mkdir -p "$TARGET_CONFIG/zsh"
    cp "$SAVED_ALIASES" "$TARGET_CONFIG/zsh/user_aliases.zsh"
    rm -f "$SAVED_ALIASES"
    if ! grep -q "source $TARGET_CONFIG/zsh/user_aliases.zsh" "$HOME/.zshrc" 2>/dev/null; then
        echo -e "\n# User Aliases" >> "$HOME/.zshrc"
        echo "source $TARGET_CONFIG/zsh/user_aliases.zsh" >> "$HOME/.zshrc"
    fi
    info "Kullanıcı alias'ları korundu"
fi

if [[ "$SHELL" != "$(which zsh)" ]]; then
    chsh -s "$(which zsh)"
    info "Varsayılan shell: zsh"
fi

# ============================================================
# 8.1 NEOVIM PLUGINS (lazy.nvim)
# ============================================================
step "Neovim plugin manager kuruluyor"

LAZY_PATH="$HOME/.local/share/nvim/lazy/lazy.nvim"
if [[ ! -d "$LAZY_PATH" ]]; then
    git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
        --branch=stable "$LAZY_PATH"
    info "lazy.nvim kuruldu"
else
    info "lazy.nvim zaten kurulu"
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

# VM guest araçları
if [[ "$IS_VM" == true ]]; then
    case "$VM_TYPE" in
        vmware)
            sudo systemctl enable --now vmtoolsd.service 2>/dev/null || true
            sudo systemctl enable --now vmware-vmblock-fuse.service 2>/dev/null || true
            ;;
        oracle|virtualbox)
            sudo systemctl enable --now vboxservice.service 2>/dev/null || true
            ;;
        qemu|kvm|bochs)
            sudo systemctl enable --now qemu-guest-agent.service 2>/dev/null || true
            sudo systemctl enable --now spice-vdagentd.service 2>/dev/null || true
            ;;
        *)
            sudo systemctl enable --now vmtoolsd.service 2>/dev/null || true
            sudo systemctl enable --now vmware-vmblock-fuse.service 2>/dev/null || true
            sudo systemctl enable --now qemu-guest-agent.service 2>/dev/null || true
            sudo systemctl enable --now spice-vdagentd.service 2>/dev/null || true
            sudo systemctl enable --now vboxservice.service 2>/dev/null || true
            ;;
    esac
    info "VM guest araçları yapılandırıldı: $VM_TYPE"
fi

# Pipewire (global - TTY'den çalışsa bile)
sudo systemctl --global enable pipewire wireplumber pipewire-pulse 2>/dev/null || true
if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
    systemctl --user start pipewire wireplumber pipewire-pulse 2>/dev/null || true
    info "Pipewire başlatıldı"
else
    info "Pipewire enable edildi (ilk login'de başlayacak)"
fi

# SwayOSD
sudo systemctl enable --now swayosd-libinput-backend.service 2>/dev/null || true
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
cat <<EOF > "$SYSTEMD_USER_DIR/swayosd.service"
[Unit]
Description=SwayOSD Service
PartOf=graphical-session.target
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
for grp in network wheel video libvirt docker; do
    sudo usermod -aG "$grp" "$USER" 2>/dev/null || warn "Grup bulunamadı: $grp"
done
info "Kullanıcı grupları güncellendi"

# ============================================================
# 10. SDDM (Display Manager)
# ============================================================
step "SDDM yapılandırılıyor"

# SDDM'i etkinleştir (varsa diğer DM'leri devre dışı bırak)
sudo systemctl disable gdm.service lightdm.service ly.service 2>/dev/null || true
if ! systemctl list-unit-files sddm.service >/dev/null 2>&1; then
    warn "sddm.service bulunamadı; SDDM paketi tekrar kuruluyor..."
    sudo pacman -S --needed --noconfirm sddm
    sudo systemctl daemon-reload
fi
systemctl list-unit-files sddm.service >/dev/null 2>&1 || error "sddm.service hâlâ bulunamadı. SDDM paketi kurulumu kontrol edilmeli."
sudo systemctl enable sddm.service -f
sudo systemctl set-default graphical.target
info "SDDM etkinleştirildi"

# SDDM Wayland config
sudo mkdir -p /etc/sddm.conf.d
cat <<EOF | sudo tee /etc/sddm.conf.d/10-wayland.conf > /dev/null
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF

# Sugar Candy SDDM theme
SUGAR_CANDY_DIR="/usr/share/sddm/themes/sugar-candy"
if [ -d "$SUGAR_CANDY_DIR" ]; then
    sudo mkdir -p "$SUGAR_CANDY_DIR/Backgrounds"
    SDDM_BG_SRC="$WALLPAPER_DIR/default.jpg"
    if [ ! -f "$SDDM_BG_SRC" ]; then
        SDDM_BG_SRC="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -n 1 || true)"
    fi
    if [ -n "$SDDM_BG_SRC" ] && [ -f "$SDDM_BG_SRC" ]; then
        sudo cp "$SDDM_BG_SRC" "$SUGAR_CANDY_DIR/Backgrounds/arch-nix-wallpaper.jpg"
    fi
    cat <<EOF | sudo tee "$SUGAR_CANDY_DIR/theme.conf.user" > /dev/null
[General]
Background="Backgrounds/arch-nix-wallpaper.jpg"
DimBackgroundImage="0.25"
ScreenWidth="1920"
ScreenHeight="1080"
FullBlur="true"
PartialBlur="false"
HaveFormBackground="false"
ForceLastUser="true"
ForcePasswordFocus="true"
ForceHideCompletePassword="true"
ForceHideVirtualKeyboardButton="true"
HeaderText="Welcome"
EOF
    cat <<EOF | sudo tee /etc/sddm.conf.d/10-wayland.conf > /dev/null
[Theme]
Current=sugar-candy

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF
    info "SDDM Sugar Candy teması yapılandırıldı"
fi

# SDDM tema fallback'i (Sugar Candy yoksa repo temasını kullan)
if [ ! -d "$SUGAR_CANDY_DIR" ] && [ -d "$REPO_DIR/config/programs/sddm/themes/matugen-minimal" ]; then
    sudo mkdir -p /usr/share/sddm/themes/matugen-minimal
    sudo cp -r "$REPO_DIR/config/programs/sddm/themes/matugen-minimal/"* /usr/share/sddm/themes/matugen-minimal/

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
    sudo sed -i 's/^DisplayServer=.*/DisplayServer=x11-user/' /etc/sddm.conf.d/10-wayland.conf
    sudo sed -i 's/^GreeterEnvironment=.*/GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1,QT_QUICK_BACKEND=software/' /etc/sddm.conf.d/10-wayland.conf
    info "SDDM VM fix uygulandı (x11-user greeter + software rendering)"
fi

sudo systemctl start sddm.service 2>/dev/null || warn "SDDM hemen başlatılamadı; reboot sonrası graphical.target ile tekrar denenecek."

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
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
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

# Utility script'leri deploy
if [ -f "$REPO_DIR/utils/bin/ssh-keygen-helper" ]; then
    cp "$REPO_DIR/utils/bin/ssh-keygen-helper" "$HOME/.local/bin/ssh-keygen-helper"
    chmod +x "$HOME/.local/bin/ssh-keygen-helper"
    info "SSH key helper kuruldu"
fi

if [ -f "$REPO_DIR/utils/bin/runtime-installer" ]; then
    cp "$REPO_DIR/utils/bin/runtime-installer" "$HOME/.local/bin/runtime-installer"
    chmod +x "$HOME/.local/bin/runtime-installer"
    info "Runtime installer kuruldu"
fi

if [ -f "$REPO_DIR/utils/bin/system-cleanup" ]; then
    cp "$REPO_DIR/utils/bin/system-cleanup" "$HOME/.local/bin/system-cleanup"
    chmod +x "$HOME/.local/bin/system-cleanup"
    info "System cleanup kuruldu"
fi

# ============================================================
# 16. GÜVENLIK YAPILANDIRMASI
# ============================================================
step "Güvenlik yapılandırılıyor"

# UFW Firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable
sudo systemctl enable --now ufw
info "UFW firewall aktif (SSH izinli)"

# fail2ban
sudo systemctl enable --now fail2ban
if [ -f "$REPO_DIR/config/security/jail.local" ]; then
    sudo cp "$REPO_DIR/config/security/jail.local" /etc/fail2ban/jail.local
    sudo systemctl restart fail2ban
    info "fail2ban yapılandırıldı"
fi

# Otomatik güvenlik güncellemeleri (pacman-contrib ile)
cat <<'EOF' | sudo tee /etc/systemd/system/pacman-auto-update.service > /dev/null
[Unit]
Description=Automatic Pacman Security Updates
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman -Syu --noconfirm
EOF

cat <<'EOF' | sudo tee /etc/systemd/system/pacman-auto-update.timer > /dev/null
[Unit]
Description=Run Pacman Security Updates Weekly

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable --now pacman-auto-update.timer
info "Haftalık otomatik güncelleme zamanlandı"

# ============================================================
# 17. SISTEM SAGLIGI
# ============================================================
step "Sistem sağlığı yapılandırılıyor"

# zram (RAM sıkıştırma)
sudo mkdir -p /etc/systemd
cat <<'EOF' | sudo tee /etc/systemd/zram-generator.conf > /dev/null
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now systemd-zram-setup@zram0.service
info "zram-generator aktif (RAM sıkıştırma, zstd, RAM/2)"

# earlyoom (out-of-memory killer)
sudo systemctl enable --now earlyoom
info "earlyoom aktif (OOM koruması)"

# Otomatik temizlik timer'ları
cat <<'EOF' | sudo tee /etc/systemd/system/pacman-cache-clean.service > /dev/null
[Unit]
Description=Clean Pacman Cache Monthly

[Service]
Type=oneshot
ExecStart=/usr/bin/paccache -r -k 2
EOF

cat <<'EOF' | sudo tee /etc/systemd/system/pacman-cache-clean.timer > /dev/null
[Unit]
Description=Monthly Pacman Cache Cleanup

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable --now pacman-cache-clean.timer
info "Aylık pacman cache temizliği zamanlandı"

# Journal boyut limiti
sudo mkdir -p /etc/systemd/journald.conf.d
cat <<'EOF' | sudo tee /etc/systemd/journald.conf.d/size-limit.conf > /dev/null
[Journal]
SystemMaxUse=500M
MaxRetentionSec=1month
EOF
sudo systemctl restart systemd-journald
info "Journal boyut limiti: 500MB / 1 ay"

# Orphan paket temizliği
ORPHANS=$(pacman -Qtdq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    sudo pacman -Rns $ORPHANS 2>/dev/null || warn "Orphan paketler kaldırılamadı"
    info "Orphan paketler temizlendi"
else
    info "Orphan paket yok"
fi

# ============================================================
# 18. PERFORMANS OPTIMIZASYONLARI
# ============================================================
step "Performans optimizasyonları"

# preload (sık kullanılan uygulamaları önceden yükle)
if command -v preload &>/dev/null; then
    sudo systemctl enable --now preload
    info "preload aktif (uygulama önyükleme)"
fi

# profile-sync-daemon (browser profile'ları RAM'e taşı)
mkdir -p "$HOME/.config/psd"
cat <<'EOF' > "$HOME/.config/psd/psd.conf"
USE_OVERLAYFS="yes"
BROWSERS="firefox chromium google-chrome"
EOF
if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
    systemctl --user enable --now psd 2>/dev/null || true
    info "profile-sync-daemon aktif (browser RAM cache)"
else
    systemctl --user enable psd 2>/dev/null || true
    info "profile-sync-daemon enable edildi (ilk login'de başlayacak)"
fi

# VA-API yapılandırması
if [[ "$IS_INTEL" == true ]]; then
    export LIBVA_DRIVER_NAME=iHD
    echo 'export LIBVA_DRIVER_NAME=iHD' >> "$HOME/.zshrc"
    info "VA-API: Intel iHD driver"
elif [[ "$IS_AMD" == true ]]; then
    export LIBVA_DRIVER_NAME=radeonsi
    echo 'export LIBVA_DRIVER_NAME=radeonsi' >> "$HOME/.zshrc"
    info "VA-API: AMD radeonsi driver"
fi

# Plymouth kernel parameter ekle
if command -v plymouth &>/dev/null; then
    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
        if ! grep -q "splash" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash quiet"/' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
            info "Plymouth kernel parameter eklendi"
        fi
    fi
fi

# ============================================================
# 19. DEVELOPER RUNTIME'LAR
# ============================================================
step "Developer runtime'lar yapılandırılıyor"

# Node.js (nvm ile version management)
export NVM_DIR="$HOME/.nvm"
if [ -s "/usr/share/nvm/nvm.sh" ]; then
    source /usr/share/nvm/nvm.sh
    nvm install --lts || warn "Node.js LTS kurulamadı"
    nvm use --lts 2>/dev/null || true
    nvm alias default lts/* 2>/dev/null || true
    info "Node.js LTS kuruldu (nvm ile): $(node --version 2>/dev/null || echo 'kuruluyor...')"

    if ! grep -q 'NVM_DIR' "$HOME/.zshrc"; then
        cat <<'EOF' >> "$HOME/.zshrc"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/share/nvm/nvm.sh" ] && \. "/usr/share/nvm/nvm.sh"
[ -s "/usr/share/nvm/bash_completion" ] && \. "/usr/share/nvm/bash_completion"
EOF
    fi
elif command -v node &>/dev/null; then
    info "Node.js pacman'dan kuruldu: $(node --version)"
fi

# Python (pyenv ile version management)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    pyenv install 3.12.0 2>/dev/null || true
    pyenv global 3.12.0 2>/dev/null || true
    info "Python 3.12 kuruldu (pyenv ile)"

    if ! grep -q "pyenv" "$HOME/.zshrc"; then
        cat <<'EOF' >> "$HOME/.zshrc"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
EOF
    fi
fi

# Rust (rustup ile)
if command -v rustup &>/dev/null; then
    rustup default stable || warn "Rust stable kurulamadı"
    info "Rust stable kuruldu (rustup ile)"
elif pacman -Q rust &>/dev/null; then
    info "pacman rust paketi bulundu, rustup'a geçiş yapılıyor..."
    sudo pacman -Rns rust --noconfirm || warn "rust kaldırılamadı"
    sudo pacman -S --needed --noconfirm rustup || warn "rustup kurulamadı"
    rustup default stable || warn "Rust stable kurulamadı"
    info "Rust stable kuruldu (rustup ile)"
else
    sudo pacman -S --needed --noconfirm rustup || warn "rustup kurulamadı"
    rustup default stable 2>/dev/null || warn "Rust stable kurulamadı"
    info "Rust stable kuruldu (rustup ile)"
fi

# Go
if command -v go &>/dev/null; then
    mkdir -p "$HOME/go/bin"
    if ! grep -q "GOPATH" "$HOME/.zshrc"; then
        cat <<'EOF' >> "$HOME/.zshrc"

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
EOF
    fi
    info "Go yapılandırıldı"
fi

# OpenAI Codex CLI (npm ile)
if command -v npm &>/dev/null; then
    npm install -g @openai/codex 2>/dev/null && info "OpenAI Codex CLI kuruldu" || warn "Codex CLI kurulamadı (API key gerekebilir)"
fi

# ============================================================
# 20. SENKRONIZASYON
# ============================================================
step "Syncthing yapılandırılıyor"

sudo systemctl enable --now syncthing@$USER.service
info "Syncthing aktif (http://localhost:8384)"

# ============================================================
# 21. DEVELOPER ARAÇLARI
# ============================================================
step "Developer araçları yapılandırılıyor"

# Git global config
if [ -f "$REPO_DIR/config/dev/gitconfig" ]; then
    cp "$REPO_DIR/config/dev/gitconfig" "$HOME/.gitconfig"
    info "Git global config kuruldu"
fi

# direnv hook
if ! grep -q "direnv" "$HOME/.zshrc"; then
    echo 'eval "$(direnv hook zsh)"' >> "$HOME/.zshrc"
    info "direnv hook eklendi"
fi

# ============================================================
# 22. DOKUMANTASYON
# ============================================================
step "Dokümantasyon kuruluyor"

if [ -d "$REPO_DIR/docs" ]; then
    mkdir -p "$HOME/Documents/arch-nix-docs"
    cp -r "$REPO_DIR/docs/"* "$HOME/Documents/arch-nix-docs/" 2>/dev/null || true
    info "Dokümantasyon: ~/Documents/arch-nix-docs/"
fi

# ============================================================
# 23. GAMING YAPILANDIRMASI (sadece gerçek donanım)
# ============================================================
if [[ "$IS_VM" == false ]]; then
    step "Gaming yapılandırılıyor"

    # GameMode config
    if [ -f "$REPO_DIR/config/gaming/gamemode.ini" ]; then
        mkdir -p "$HOME/.config"
        cp "$REPO_DIR/config/gaming/gamemode.ini" "$HOME/.config/gamemode.ini"
        info "GameMode config kuruldu"
    fi

    # MangoHud config
    if [ -f "$REPO_DIR/config/gaming/MangoHud.conf" ]; then
        mkdir -p "$HOME/.config/MangoHud"
        cp "$REPO_DIR/config/gaming/MangoHud.conf" "$HOME/.config/MangoHud/MangoHud.conf"
        info "MangoHud config kuruldu"
    fi

    # Gaming Hyprland rules (ek bilgi olarak)
    if [ -f "$REPO_DIR/config/gaming/hyprland-gaming.conf" ]; then
        mkdir -p "$HOME/.config/hypr"
        cp "$REPO_DIR/config/gaming/hyprland-gaming.conf" "$HOME/.config/hypr/gaming-rules.conf"
        info "Gaming Hyprland kuralları: ~/.config/hypr/gaming-rules.conf"
        info "  Bu dosyayı hyprland.conf'a include edin veya kuralları manuel ekleyin"
    fi

    # Gaming optimizer script
    if [ -f "$REPO_DIR/utils/bin/gaming-optimizer" ]; then
        cp "$REPO_DIR/utils/bin/gaming-optimizer" "$HOME/.local/bin/gaming-optimizer"
        chmod +x "$HOME/.local/bin/gaming-optimizer"
        info "Gaming optimizer kuruldu: gaming-optimizer"
    fi

    # Steam launch options helper
    cat <<'STEAMHELP' >> "$HOME/.zshrc"

# Gaming aliases
alias steam-mango='MANGOHUD=1 gamemoderun %command%'
alias steam-gamemode='gamemoderun %command%'
alias steam-vulkan='MANGOHUD=1 DXVK_HUD=1 gamemoderun %command%'
STEAMHELP

    # Kullanıcıyı gamemode grubuna ekle
    sudo usermod -aG gamemode "$USER" 2>/dev/null || true

    # Gamescope Wayland socket izinleri
    if command -v gamescope &>/dev/null; then
        info "gamescope kuruldu - Steam'de 'gamescope -- %command%' kullanabilirsiniz"
    fi

    info "Gaming araçları: Steam, Lutris, Heroic, ProtonUp-Qt, MangoHud, GOverlay, GameScope"
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
