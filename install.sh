#!/usr/bin/env bash
# ============================================================
#   Arch Linux / CachyOS - Faz Bazli Desktop Kurulumu v3
#   Desktop (varsayilan) | Full | Gaming (ayri)
# ============================================================
set -eo pipefail

# --- Constants ---
readonly STATE_DIR="$HOME/.cache/arch-nix-install"
readonly STATE_FILE="$STATE_DIR/state"
readonly LOG_FILE="$STATE_DIR/install.log"
readonly REPO_URL="https://github.com/ozkanaltunboga/arch-nix.git"

# --- Profile ---
INSTALL_PROFILE="${INSTALL_PROFILE:-desktop}"
INSTALL_GAMING="${INSTALL_GAMING:-0}"
INSTALL_OPTIONAL_APPS="${INSTALL_OPTIONAL_APPS:-0}"
INSTALL_DEV_TOOLS="${INSTALL_DEV_TOOLS:-0}"

if [[ "$INSTALL_PROFILE" == "full" ]]; then
    INSTALL_OPTIONAL_APPS=1
    INSTALL_DEV_TOOLS=1
fi

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# --- State & Logging ---
mkdir -p "$STATE_DIR"
if [[ ! -f "$STATE_FILE" ]]; then
    : > "$LOG_FILE"
fi

exec 3>&2
exec > >(tee -a "$LOG_FILE") 2>&1

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "\n${BOLD}${CYAN}--- $* ---${NC}"; }

# --- Globals ---
CURRENT_PHASE="init"
SUDO_KEEPALIVE_PID=""
AUR_CMD=""
AUR_HELPER=""
IS_VM=false
VM_TYPE=""
IS_NVIDIA=false
IS_AMD=false
IS_INTEL=false
HAS_BATTERY=false
HAS_WIFI=false
MULTIBIT_OK=true
REPO_DIR=""
BACKUP_DIR=""

# --- Error Trap ---
trap '
    exit_code=$?
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} Kurulum basarisiz (faz: $CURRENT_PHASE, satir: $LINENO)" >&3
        echo -e "${RED}[ERROR]${NC} Log dosyasi: $LOG_FILE" >&3
        echo "" >&3
        echo "Son 40 log satiri:" >&3
        tail -40 "$LOG_FILE" >&3 2>/dev/null || true
    fi
' EXIT

# --- Root Guard ---
[[ $EUID -eq 0 ]] && { log_error "Bu scripti root olarak calistirmayin! (sudo kullanmayin)"; exit 1; }

# --- Sudo Keepalive ---
sudo -v || { log_error "sudo yetkisi alinamadi"; exit 1; }
(while true; do sudo -n true; sleep 60; done) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

# --- Checkpoint ---
phase_completed() { grep -qx "$1" "$STATE_FILE" 2>/dev/null; }
complete_phase() { echo "$1" >> "$STATE_FILE"; }

run_phase() {
    local phase="$1"
    local func="$2"
    local optional="${3:-false}"

    if phase_completed "$phase"; then
        log_info "$phase fasi daha once tamamlanmis, atlaniyor."
        return 0
    fi

    CURRENT_PHASE="$phase"
    log_step "$phase fasi baslatiliyor"

    if "$func"; then
        complete_phase "$phase"
        log_info "$phase fasi tamamlandi."
    elif [[ "$optional" == "true" ]]; then
        log_warn "$phase fasi tamamlanamadi (opsiyonel), devam ediliyor..."
    else
        log_error "$phase fasi basarisiz oldu."
        return 1
    fi
}

# --- Package Helpers ---
pkg_is_installed() { pacman -Qi "$1" &>/dev/null; }
pkg_in_repo() { pacman -Si "$1" &>/dev/null; }
aur_is_installed() { ${AUR_HELPER:-paru} -Qi "$1" &>/dev/null; }
aur_in_repo() { ${AUR_HELPER:-paru} -Si "$1" &>/dev/null; }

install_pacman_required() {
    local phase="$1"; shift
    local pkgs=("$@")
    local to_install=() not_found=()

    for pkg in "${pkgs[@]}"; do
        if pkg_is_installed "$pkg"; then
            log_info "$pkg paketi zaten kurulu, atlaniyor."
        elif pkg_in_repo "$pkg"; then
            log_info "$pkg paketi kurulu degil, kuruluyor..."
            to_install+=("$pkg")
        else
            not_found+=("$pkg")
        fi
    done

    if [[ ${#not_found[@]} -gt 0 ]]; then
        for pkg in "${not_found[@]}"; do
            log_error "$pkg paketi depoda bulunamadi, bu zorunlu paket oldugu icin kurulum durduruldu."
        done
        return 1
    fi

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "[$phase] ${#to_install[@]} paket kuruluyor..."
        if ! sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
            log_error "[$phase] Pacman paket kurulumu basarisiz"
            return 1
        fi
    fi
}

install_pacman_optional() {
    local phase="$1"; shift
    local pkgs=("$@")
    local to_install=()

    for pkg in "${pkgs[@]}"; do
        if pkg_is_installed "$pkg"; then
            log_info "$pkg paketi zaten kurulu, atlaniyor."
        elif pkg_in_repo "$pkg"; then
            log_info "$pkg paketi kurulu degil, kuruluyor..."
            to_install+=("$pkg")
        else
            log_warn "$pkg paketi depoda bulunamadi, opsiyonel oldugu icin atlaniyor."
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "[$phase] ${#to_install[@]} opsiyonel paket kuruluyor..."
        sudo pacman -S --needed --noconfirm "${to_install[@]}" || log_warn "[$phase] Bazi opsiyonel paketler kurulamadi"
    fi
}

install_aur_required() {
    local phase="$1"; shift
    local pkgs=("$@")
    local to_install=() not_found=()

    for pkg in "${pkgs[@]}"; do
        if aur_is_installed "$pkg"; then
            log_info "$pkg paketi zaten kurulu, atlaniyor."
        elif aur_in_repo "$pkg"; then
            log_info "$pkg paketi AUR'da bulundu, kuruluyor..."
            to_install+=("$pkg")
        else
            not_found+=("$pkg")
        fi
    done

    if [[ ${#not_found[@]} -gt 0 ]]; then
        for pkg in "${not_found[@]}"; do
            log_error "$pkg paketi AUR'da bulunamadi, bu zorunlu paket oldugu icin kurulum durduruldu."
        done
        return 1
    fi

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "[$phase] ${#to_install[@]} AUR paketi kuruluyor..."
        if ! $AUR_CMD "${to_install[@]}"; then
            log_error "[$phase] AUR paket kurulumu basarisiz"
            return 1
        fi
    fi
}

install_aur_optional() {
    local phase="$1"; shift
    local pkgs=("$@")
    local to_install=()

    for pkg in "${pkgs[@]}"; do
        if aur_is_installed "$pkg"; then
            log_info "$pkg paketi zaten kurulu, atlaniyor."
        elif aur_in_repo "$pkg"; then
            log_info "$pkg paketi AUR'da bulundu, kuruluyor..."
            to_install+=("$pkg")
        else
            log_warn "$pkg paketi AUR'da bulunamadi, opsiyonel oldugu icin atlaniyor."
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        log_info "[$phase] ${#to_install[@]} opsiyonel AUR paketi kuruluyor..."
        $AUR_CMD "${to_install[@]}" || log_warn "[$phase] Bazi opsiyonel AUR paketleri kurulamadi"
    fi
}

# --- Deploy Helper ---
deploy() {
    local src="$1"
    local dst="$2"
    if [ ! -e "$src" ]; then
        log_warn "Kaynak bulunamadi, atlaniyor: $src"
        return 0
    fi
    if [ -e "$dst" ]; then
        if diff -rq "$src" "$dst" >/dev/null 2>&1; then
            log_info "Degisiklik yok, atlaniyor: $dst"
            return 0
        fi
        mv "$dst" "$BACKUP_DIR/$(basename "$dst")-$(date +%s)"
        log_info "Yedeklendi: $dst"
    fi
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    log_info "Kopyalandi: $dst"
}

# ============================================================
# CONTEXT: Her run'da calisir (checkpoint'ten bagimsiz)
# ============================================================
detect_hardware() {
    log_step "Donanim algilaniyor"

    sudo pacman -S --needed --noconfirm pciutils iw 2>/dev/null || true

    local GPU_RAW
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
        log_info "Sanal makine algilandi: $VM_TYPE (VM fix'leri uygulanacak)"
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
        log_info "Sanal makine algilandi (VM fix'leri uygulanacak)"
    fi

    if echo "$GPU_RAW" | grep -qi "nvidia"; then
        IS_NVIDIA=true; log_info "NVIDIA GPU algilandi"
    elif echo "$GPU_RAW" | grep -qi "amd\|radeon"; then
        IS_AMD=true; log_info "AMD GPU algilandi"
    elif echo "$GPU_RAW" | grep -qi "intel"; then
        IS_INTEL=true; log_info "Intel GPU algilandi"
    fi

    if ls /sys/class/power_supply/BAT* 1>/dev/null 2>&1; then
        HAS_BATTERY=true; log_info "Batarya algilandi (Laptop)"
    else
        log_info "Batarya yok (Masaustu/VM)"
    fi

    if ls /sys/class/net/w* 1>/dev/null 2>&1 || iw dev 2>/dev/null | grep -q Interface; then
        HAS_WIFI=true; log_info "Wi-Fi algilandi"
    else
        log_info "Wi-Fi yok (Ethernet/VM)"
    fi
}

resolve_repo_dir() {
    local CLONE_DIR="$HOME/.hyprland-dots"
    if [ -f "$(pwd)/install.sh" ] && [ -d "$(pwd)/config" ]; then
        REPO_DIR="$(pwd)"
        log_info "Yerel repodan calisiliyor: $REPO_DIR"
    elif [ -d "$CLONE_DIR" ]; then
        REPO_DIR="$CLONE_DIR"
        log_info "Mevcut repo dizini: $REPO_DIR"
    else
        REPO_DIR="$CLONE_DIR"
        log_info "Repo dizini (klonlanacak): $REPO_DIR"
    fi
}

ensure_multilib() {
    if [[ "$INSTALL_GAMING" != "1" ]]; then
        return 0
    fi
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        log_step "Multilib etkinlestiriliyor (gaming icin)"
        if sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf; then
            sudo pacman -Sy --noconfirm
            log_info "Multilib etkinlestirildi"
        else
            log_warn "Multilib etkinlestirilemedi, gaming fasi atlanacak"
            MULTIBIT_OK=false
        fi
    else
        log_info "Multilib zaten etkin"
    fi
}

ensure_aur_helper() {
    if [[ -n "$AUR_CMD" ]]; then
        return 0
    fi
    if command -v paru &>/dev/null; then
        AUR_CMD="paru -S --needed --noconfirm --skipreview --removemake --cleanafter"
        AUR_HELPER="paru"
    elif command -v yay &>/dev/null; then
        AUR_CMD="yay -S --needed --noconfirm --removemake --cleanafter"
        AUR_HELPER="yay"
    else
        AUR_CMD=""
        AUR_HELPER=""
    fi
}

# ============================================================
# PHASE: preflight
# ============================================================
phase_preflight() {
    log_step "Pacman mirror ayarlari yenileniyor"
    sudo cp /etc/pacman.d/mirrorlist "/etc/pacman.d/mirrorlist.backup-$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    local MIRRORLIST_URL="https://archlinux.org/mirrorlist/?country=TR&country=DE&country=NL&country=FR&protocol=https&ip_version=4&use_mirror_status=on"
    if curl -fsSL "$MIRRORLIST_URL" | sed 's/^#Server/Server/' | sudo tee /etc/pacman.d/mirrorlist > /dev/null; then
        log_info "Mirrorlist guncellendi (TR/DE/NL/FR HTTPS)"
    else
        log_warn "Mirrorlist indirilemedi; mevcut mirrorlist kullanilacak"
    fi

    sudo sed -i \
        -e '/^#\?ParallelDownloads[[:space:]]*=/d' \
        -e '/^DisableDownloadTimeout$/d' \
        /etc/pacman.conf
    sudo sed -i '/^\[options\]/a DisableDownloadTimeout\nParallelDownloads = 8' /etc/pacman.conf
    sudo pacman -Syy --noconfirm
}

# ============================================================
# PHASE: aur-helper
# ============================================================
phase_aur_helper() {
    if [[ -n "$AUR_CMD" ]]; then
        log_info "AUR helper zaten hazir: $AUR_HELPER"
        return 0
    fi
    log_info "paru kuruluyor..."
    sudo pacman -S --needed --noconfirm git base-devel cargo || { log_error "base-devel/cargo kurulamadi"; return 1; }
    local local_tmp
    local_tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$local_tmp/paru" || { log_error "paru clone basarisiz"; return 1; }
    sudo -v
    (cd "$local_tmp/paru" && makepkg -si --noconfirm) || { log_error "paru derlenemedi"; return 1; }
    rm -rf "$local_tmp"
    AUR_CMD="paru -S --needed --noconfirm --skipreview --removemake --cleanafter"
    AUR_HELPER="paru"
}

# ============================================================
# PHASE: pacman-core
# ============================================================
phase_pacman_core() {
    local pkgs=(
        wget file git psmisc fzf bc jq socat unzip pciutils
        python python-pip python-websockets
        zsh libnotify
        networkmanager bluez bluez-utils blueman iw
        pipewire pipewire-alsa pipewire-pulse wireplumber libpulse
        alsa-utils pamixer brightnessctl
        openssh cups acpi
        ufw fail2ban
        zram-generator earlyoom pacman-contrib
        flatpak
        noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation ttf-jetbrains-mono
        breeze
    )
    install_pacman_required "pacman-core" "${pkgs[@]}"
}

# ============================================================
# PHASE: pacman-desktop
# ============================================================
phase_pacman_desktop() {
    local pkgs=(
        hyprland xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
        wl-clipboard cliphist
        hyprlock hypridle
        kitty neovim firefox
        rofi-wayland pavucontrol nautilus
        nwg-dock-hyprland
        cava
        gtk3 inotify-tools
        qt5-wayland qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects
        qt6-wayland qt6-multimedia qt6-multimedia-ffmpeg qt6-5compat qt6-websockets qt6ct
        power-profiles-daemon
        sddm
        papirus-icon-theme hicolor-icon-theme adwaita-icon-theme desktop-file-utils
        plymouth libva-utils
        fastfetch grim slurp swappy playerctl imagemagick
        ripgrep fd
        p7zip mpv
        zoxide bat duf ncdu lazygit rsync tmux
        direnv ffmpeg tree
    )
    install_pacman_required "pacman-desktop" "${pkgs[@]}"
}

# ============================================================
# PHASE: pacman-hardware
# ============================================================
phase_pacman_hardware() {
    local pkgs=()

    if [[ "$IS_NVIDIA" == true ]]; then
        pkgs+=(nvidia nvidia-utils nvidia-prime)
    fi
    if [[ "$IS_AMD" == true ]]; then
        pkgs+=(mesa vulkan-radeon libva-mesa-driver)
    fi
    if [[ "$IS_INTEL" == true ]]; then
        pkgs+=(mesa vulkan-intel intel-media-driver)
    fi
    if [[ "$IS_VM" == true ]]; then
        pkgs+=(mesa)
        case "$VM_TYPE" in
            vmware)             pkgs+=(open-vm-tools gtkmm3) ;;
            oracle|virtualbox)  pkgs+=(virtualbox-guest-utils) ;;
            qemu|kvm|bochs)     pkgs+=(qemu-guest-agent spice-vdagent) ;;
            *)                  pkgs+=(open-vm-tools gtkmm3 qemu-guest-agent spice-vdagent) ;;
        esac
    fi

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        install_pacman_optional "pacman-hardware" "${pkgs[@]}"
    else
        log_info "Donanima ozel paket yok, atlaniyor."
    fi
}

# ============================================================
# PHASE: pacman-optional (INSTALL_OPTIONAL_APPS=1)
# ============================================================
phase_pacman_optional() {
    local pkgs=(
        obs-studio
        easyeffects ladspa lsp-plugins-ladspa lsp-plugins-lv2
        qbittorrent wmctrl
        nmap traceroute mtr bandwhich speedtest-cli
        android-tools
        lua-language-server pyright
        hunspell hunspell-en_us
        telegram-desktop
        syncthing
        lm_sensors fortune-mod go-yq
        profile-sync-daemon
    )
    install_pacman_optional "pacman-optional" "${pkgs[@]}"
}

# ============================================================
# PHASE: pacman-dev (INSTALL_DEV_TOOLS=1)
# ============================================================
phase_pacman_dev() {
    local pkgs=(
        docker docker-compose
        virt-manager libvirt qemu-desktop dnsmasq dmidecode edk2-ovmf swtpm
        nodejs npm go pyenv rustup
    )
    install_pacman_optional "pacman-dev" "${pkgs[@]}"
}

# ============================================================
# PHASE: pacman-gaming (INSTALL_GAMING=1 only)
# ============================================================
phase_pacman_gaming() {
    if [[ "$IS_VM" == true ]]; then
        log_info "VM algilandi, gaming fasi atlaniyor."
        return 0
    fi
    if [[ "$MULTIBIT_OK" != true ]]; then
        log_warn "Multilib aktif degil, gaming fasi atlaniyor."
        return 0
    fi

    local pkgs=(
        steam gamemode lib32-gamemode
        lib32-glibc lib32-libx11 lib32-libxcomposite lib32-libxcursor
        lib32-libxi lib32-libxrandr lib32-libxtst lib32-libxinerama
        lib32-mesa lib32-libva lib32-libvdpau lib32-sdl2 lib32-sdl_image
        lib32-libpng lib32-libjpeg-turbo lib32-freetype2 lib32-fontconfig
        lib32-gtk3 lib32-gst-plugins-base lib32-gst-plugins-good
        lib32-openal lib32-libpulse lib32-alsa-plugins
        lib32-libcurl-gnutls lib32-nss lib32-nspr lib32-dbus lib32-libdrm
        lib32-libxss lib32-libgcrypt
        steam-devices
        mangohud lib32-mangohud gamescope vkbasalt lib32-vkbasalt
    )

    if [[ "$IS_NVIDIA" == true ]]; then
        pkgs+=(lib32-nvidia-utils)
    fi
    if [[ "$IS_AMD" == true ]]; then
        pkgs+=(lib32-vulkan-radeon)
    fi
    if [[ "$IS_INTEL" == true ]]; then
        pkgs+=(lib32-vulkan-intel)
    fi

    install_pacman_optional "pacman-gaming" "${pkgs[@]}"
}

# ============================================================
# PHASE: aur-core-critical (quickshell + matugen)
# ============================================================
phase_aur_core_critical() {
    local pkgs=(
        quickshell-git
        matugen-bin
    )
    install_aur_required "aur-core-critical" "${pkgs[@]}"
}

# ============================================================
# PHASE: aur-core-optional (swww, swayosd, swaync, wlogout)
# ============================================================
phase_aur_core_optional() {
    local pkgs=(
        swww awww
        swayosd-git swaync wlogout
    )
    install_aur_optional "aur-core-optional" "${pkgs[@]}"
}

# ============================================================
# PHASE: aur-optional (INSTALL_OPTIONAL_APPS=1)
# ============================================================
phase_aur_optional() {
    local pkgs=(
        sddm-sugar-candy-git
        ttf-udev-gothic ttf-iosevka-nerd
        adw-gtk-theme
        mpvpaper networkmanager-dmenu-git
        onlyoffice-bin
        visual-studio-code-bin
        google-chrome
        notion-app-electron
        spotify
        timeshift
        bottles
        intellij-idea-community-edition
        discord
    )
    install_aur_optional "aur-optional" "${pkgs[@]}"
}

# ============================================================
# PHASE: aur-gaming (INSTALL_GAMING=1 only)
# ============================================================
phase_aur_gaming() {
    if [[ "$IS_VM" == true ]]; then
        log_info "VM algilandi, aur-gaming fasi atlaniyor."
        return 0
    fi

    local pkgs=(
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
    install_aur_optional "aur-gaming" "${pkgs[@]}"
}

# ============================================================
# PHASE: dotfiles
# ============================================================
phase_dotfiles() {
    log_step "Dotfiles reposu hazirlaniyor"

    local TARGET_CONFIG="$HOME/.config"
    BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"

    if [ ! -d "$REPO_DIR" ]; then
        log_info "Repo klonlaniyor: $REPO_URL -> $REPO_DIR"
        git clone "$REPO_URL" "$REPO_DIR" || { log_error "Repo klonlamasi basarisiz"; return 1; }
    else
        log_info "Mevcut repo guncelleniyor: $REPO_DIR"
        git -C "$REPO_DIR" pull 2>/dev/null || true
    fi

    log_step "Config dosyalari yerlestiriliyor"
    mkdir -p "$TARGET_CONFIG" "$BACKUP_DIR"

    deploy "$REPO_DIR/config/programs/kitty"      "$TARGET_CONFIG/kitty"
    deploy "$REPO_DIR/config/programs/rofi"       "$TARGET_CONFIG/rofi"
    deploy "$REPO_DIR/config/programs/matugen"    "$TARGET_CONFIG/matugen"
    deploy "$REPO_DIR/config/programs/swaync"     "$TARGET_CONFIG/swaync"
    deploy "$REPO_DIR/config/programs/swayosd"    "$TARGET_CONFIG/swayosd"
    if [ ! -d "$TARGET_CONFIG/swayosd" ]; then
        mkdir -p "$TARGET_CONFIG/swayosd"
        log_info "swayosd dizini olusturuldu (fallback)"
    fi
    deploy "$REPO_DIR/config/programs/wlogout"    "$TARGET_CONFIG/wlogout"
    deploy "$REPO_DIR/config/programs/nwg-dock-hyprland" "$TARGET_CONFIG/nwg-dock-hyprland"
    chmod +x "$TARGET_CONFIG/nwg-dock-hyprland/launch.sh" 2>/dev/null || true
    deploy "$REPO_DIR/config/programs/neovim/nvim" "$TARGET_CONFIG/nvim"
    deploy "$REPO_DIR/config/sessions/hyprland"    "$TARGET_CONFIG/hypr"
    find "$TARGET_CONFIG/hypr/scripts" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} + 2>/dev/null || true

    if [ -d "$REPO_DIR/config/programs/plymouth" ]; then
        sudo mkdir -p /usr/share/plymouth/themes
        sudo cp -r "$REPO_DIR/config/programs/plymouth/simple" /usr/share/plymouth/themes/
        sudo plymouth-set-default-theme -R simple 2>/dev/null || true
        log_info "Plymouth boot splash kuruldu"
    fi

    if [ -d "$REPO_DIR/config/media/easyeffects" ]; then
        mkdir -p "$HOME/.config/easyeffects/input" "$HOME/.config/easyeffects/output"
        cp "$REPO_DIR/config/media/easyeffects/default-preset.json" "$HOME/.config/easyeffects/output/"
        log_info "EasyEffects preset'leri kuruldu"
    fi

    deploy "$REPO_DIR/config/programs/cava/config" "$TARGET_CONFIG/cava/config_base"

    local CHROME_FLAGS="$HOME/.config/chrome-flags.conf"
    if command -v google-chrome-stable >/dev/null 2>&1 || command -v google-chrome >/dev/null 2>&1; then
        touch "$CHROME_FLAGS"
        grep -qxF -- "--enable-features=UseOzonePlatform" "$CHROME_FLAGS" 2>/dev/null || echo "--enable-features=UseOzonePlatform" >> "$CHROME_FLAGS"
        grep -qxF -- "--ozone-platform=wayland" "$CHROME_FLAGS" 2>/dev/null || echo "--ozone-platform=wayland" >> "$CHROME_FLAGS"
        log_info "Chrome Wayland flag'leri ayarlandi"
    fi

    deploy "$REPO_DIR/config/programs/firefox/chrome" "$TARGET_CONFIG/firefox-chrome"
    local FIREFOX_PROFILE_DIR=""
    if [ -d "$HOME/.mozilla/firefox" ]; then
        FIREFOX_PROFILE_DIR="$(find "$HOME/.mozilla/firefox" -maxdepth 1 -name '*.default*' -type d 2>/dev/null | head -n1 || true)"
    fi
    if [ -n "$FIREFOX_PROFILE_DIR" ]; then
        deploy "$REPO_DIR/config/programs/firefox/chrome" "$FIREFOX_PROFILE_DIR/chrome"
        if [ -d "$TARGET_CONFIG/firefox-chrome" ]; then
            cp -r "$TARGET_CONFIG/firefox-chrome/." "$FIREFOX_PROFILE_DIR/chrome/" 2>/dev/null || true
        fi
        log_info "Firefox chrome temalari profile uygulandi"
    else
        log_info "Firefox profili bulunamadi. Ilk Firefox acilisinda chrome temalari ~/.config/firefox-chrome'dan kopyalanacak."
    fi

    # --- Hyprland Config Adaptasyonu ---
    log_step "Hyprland config sisteme uyarlaniyor"
    local HYPR_CONF="$TARGET_CONFIG/hypr/hyprland.conf"

    if [ -f "$HYPR_CONF" ]; then
        sed -i "s/^ *kb_layout =.*/    kb_layout = tr/" "$HYPR_CONF"
        log_info "Klavye duzeni: Turkce Q"

        sed -i "s|^env = WALLPAPER_DIR,.*|env = WALLPAPER_DIR,$HOME/Pictures/Wallpapers|" "$HYPR_CONF"
        sed -i '/^env = SCRIPT_DIR,/d' "$HYPR_CONF"
        sed -i '/^env = QT_QUICK_BACKEND,/d' "$HYPR_CONF"
        sed -i '/^env = WLR_RENDERER_ALLOW_SOFTWARE,/d' "$HYPR_CONF"
        sed -i '/^env = LIBGL_ALWAYS_SOFTWARE,/d' "$HYPR_CONF"
        log_info "Ortam degiskenleri guncellendi"

        if [[ "$IS_VM" == true ]]; then
            sed -i '/^env = QML_XHR_ALLOW_FILE_READ,1/a env = QT_QUICK_BACKEND,software\nenv = WLR_RENDERER_ALLOW_SOFTWARE,1\nenv = LIBGL_ALWAYS_SOFTWARE,1' "$HYPR_CONF"
            local vm_env vm_key
            for vm_env in WLR_RENDERER_ALLOW_SOFTWARE=1 LIBGL_ALWAYS_SOFTWARE=1; do
                vm_key="${vm_env%%=*}"
                if grep -q "^${vm_key}=" /etc/environment 2>/dev/null; then
                    sudo sed -i "s|^${vm_key}=.*|${vm_env}|" /etc/environment
                else
                    echo "$vm_env" | sudo tee -a /etc/environment > /dev/null
                fi
            done
            sed -i 's|^\$terminal = kitty|$terminal = env LIBGL_ALWAYS_SOFTWARE=1 kitty|' "$HYPR_CONF"
            sed -i 's|^\$terminal = env LIBGL_ALWAYS_SOFTWARE=1 env LIBGL_ALWAYS_SOFTWARE=1|$terminal = env LIBGL_ALWAYS_SOFTWARE=1|' "$HYPR_CONF"
            log_info "VM GPU fix'leri uygulandi (software rendering env'leri aktif)"
        fi

        if [[ "$IS_NVIDIA" == true ]]; then
            sed -i '/^env = WALLPAPER_DIR,/a env = LIBVA_DRIVER_NAME,nvidia\nenv = XDG_SESSION_TYPE,wayland\nenv = GBM_BACKEND,nvidia-drm\nenv = __GLX_VENDOR_LIBRARY_NAME,nvidia\nenv = WLR_NO_HARDWARE_CURSORS,1' "$HYPR_CONF"
            log_info "NVIDIA Wayland env'leri eklendi"
        fi
    fi

    # Desktop/Laptop adaptasyonu
    local QS_BAT_DIR="$TARGET_CONFIG/hypr/scripts/quickshell/battery"
    local REPO_BAT_DIR="$REPO_DIR/config/sessions/hyprland/scripts/quickshell/battery"
    if [[ "$HAS_BATTERY" == false ]] && [ -f "$REPO_BAT_DIR/BatteryPopupAlt.qml" ]; then
        cp -f "$REPO_BAT_DIR/BatteryPopupAlt.qml" "$QS_BAT_DIR/BatteryPopup.qml" 2>/dev/null || true
        log_info "Masaustu: Batarya widget'i -> Sistem Monitor widget'ina donusturuldu"
    fi

    local QS_NET_DIR="$TARGET_CONFIG/hypr/scripts/quickshell/network"
    local REPO_NET_DIR="$REPO_DIR/config/sessions/hyprland/scripts/quickshell/network"
    if [[ "$HAS_WIFI" == false ]] && [ -f "$REPO_NET_DIR/NetworkPopupAlt.qml" ]; then
        cp -f "$REPO_NET_DIR/NetworkPopupAlt.qml" "$QS_NET_DIR/NetworkPopup.qml" 2>/dev/null || true
        log_info "Masaustu/VM: Wi-Fi widget'i -> Ethernet widget'ina donusturuldu"
    fi

    # --- Zsh ---
    log_step "Zsh yapilandiriliyor"
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Oh My Zsh kuruluyor..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] && \
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] && \
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

    local ZSH_RC="$HOME/.zshrc"
    local SAVED_ALIASES="$HOME/.zshrc.aliases.bak"
    if [ -f "$ZSH_RC" ]; then
        grep "^alias " "$ZSH_RC" > "$SAVED_ALIASES" 2>/dev/null || true
    fi

    deploy "$REPO_DIR/config/programs/zsh" "$TARGET_CONFIG/zsh"
    deploy "$REPO_DIR/config/programs/zsh/.zshrc" "$HOME/.zshrc"

    if [ -f "$SAVED_ALIASES" ] && [ -s "$SAVED_ALIASES" ]; then
        mkdir -p "$TARGET_CONFIG/zsh"
        cp "$SAVED_ALIASES" "$TARGET_CONFIG/zsh/user_aliases.zsh"
        rm -f "$SAVED_ALIASES"
        if ! grep -q "source $TARGET_CONFIG/zsh/user_aliases.zsh" "$HOME/.zshrc" 2>/dev/null; then
            echo -e "\n# User Aliases" >> "$HOME/.zshrc"
            echo "source $TARGET_CONFIG/zsh/user_aliases.zsh" >> "$HOME/.zshrc"
        fi
        log_info "Kullanici alias'lari korundu"
    fi

    if [[ "$SHELL" != "$(which zsh)" ]]; then
        chsh -s "$(which zsh)"
        log_info "Varsayilan shell: zsh"
    fi

    # --- Neovim lazy.nvim ---
    log_step "Neovim plugin manager kuruluyor"
    local LAZY_PATH="$HOME/.local/share/nvim/lazy/lazy.nvim"
    if [[ ! -d "$LAZY_PATH" ]]; then
        git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
            --branch=stable "$LAZY_PATH"
        log_info "lazy.nvim kuruldu"
    else
        log_info "lazy.nvim zaten kurulu"
    fi
}

# ============================================================
# PHASE: wallpapers
# ============================================================
phase_wallpapers() {
    log_step "Wallpaper'lar kuruluyor"
    local WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
    local REPO_WALLPAPER_DIR="$REPO_DIR/config/wallpapers"
    mkdir -p "$WALLPAPER_DIR"

    if [ -d "$REPO_WALLPAPER_DIR" ]; then
        local copied_wallpapers=0
        while IFS= read -r -d '' wallpaper; do
            local target_wallpaper="$WALLPAPER_DIR/$(basename "$wallpaper")"
            if [ ! -e "$target_wallpaper" ]; then
                cp "$wallpaper" "$target_wallpaper"
                copied_wallpapers=$((copied_wallpapers + 1))
            fi
        done < <(find "$REPO_WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0)
        log_info "Repo wallpaper'lari hazirlandi: $WALLPAPER_DIR ($copied_wallpapers yeni dosya)"
    else
        log_warn "Repo wallpaper klasoru bulunamadi: $REPO_WALLPAPER_DIR"
    fi

    if ! find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | grep -q .; then
        log_warn "Wallpaper bulunamadi. Lutfen kendi wallpaper'larinizi $WALLPAPER_DIR altina yerlestirin."
    fi
}

# ============================================================
# PHASE: fonts
# ============================================================
phase_fonts() {
    log_step "Fontlar kuruluyor"
    local TARGET_FONTS="$HOME/.local/share/fonts"
    local REPO_FONTS="$REPO_DIR/config/fonts"
    mkdir -p "$TARGET_FONTS"

    if [ -d "$REPO_FONTS" ]; then
        cp -r "$REPO_FONTS/"* "$TARGET_FONTS/" 2>/dev/null || true
    fi

    if fc-match "Iosevka Nerd Font" 2>/dev/null | grep -qi "Iosevka"; then
        log_info "Iosevka Nerd Font sistemde mevcut"
    elif [ -d "$TARGET_FONTS/IosevkaNerdFont" ] && [ "$(ls -A "$TARGET_FONTS/IosevkaNerdFont" 2>/dev/null | grep -i '\.ttf')" ]; then
        log_info "Iosevka Nerd Font zaten kurulu"
    else
        log_warn "Iosevka Nerd Font bulunamadi; AUR font kurulumu basarisiz olmus olabilir"
    fi

    find "$TARGET_FONTS" -type f -exec chmod 644 {} \; 2>/dev/null
    find "$TARGET_FONTS" -type d -exec chmod 755 {} \; 2>/dev/null
    fc-cache -f "$TARGET_FONTS" 2>/dev/null || true
    log_info "Font cache guncellendi"
}

# ============================================================
# PHASE: services
# ============================================================
phase_services() {
    log_step "Sistem servisleri etkinlestiriliyor"

    local svc
    for svc in systemd-networkd systemd-networkd-wait-online iwd dhcpcd wpa_supplicant; do
        sudo systemctl disable --now "$svc" 2>/dev/null || true
    done
    log_info "NetworkManager disindaki ag yoneticileri devre disi birakildi"

    sudo systemctl enable --now NetworkManager
    sudo systemctl enable --now bluetooth
    sudo systemctl enable --now cups
    sudo systemctl enable --now sshd
    sudo systemctl enable --now power-profiles-daemon

    if [[ "$INSTALL_DEV_TOOLS" == "1" ]]; then
        sudo systemctl enable --now libvirtd 2>/dev/null || log_warn "libvirtd etkinlestirilemedi"
        sudo systemctl enable --now docker 2>/dev/null || log_warn "docker etkinlestirilemedi"
        sudo virsh net-autostart default 2>/dev/null || true
        sudo virsh net-start default 2>/dev/null || true
    fi

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
        log_info "VM guest araclari yapilandirildi: $VM_TYPE"
    fi

    sudo systemctl --global enable pipewire wireplumber pipewire-pulse 2>/dev/null || true
    if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
        systemctl --user start pipewire wireplumber pipewire-pulse 2>/dev/null || true
        log_info "Pipewire baslatildi"
    else
        log_info "Pipewire enable edildi (ilk login'de baslayacak)"
    fi

    sudo systemctl enable --now swayosd-libinput-backend.service 2>/dev/null || true
    local SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
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
    log_info "SwayOSD servisi yapilandirildi"

    local grp
    for grp in network wheel video; do
        sudo usermod -aG "$grp" "$USER" 2>/dev/null || log_warn "Grup bulunamadi: $grp"
    done
    if [[ "$INSTALL_DEV_TOOLS" == "1" ]]; then
        sudo usermod -aG libvirt "$USER" 2>/dev/null || log_warn "Grup bulunamadi: libvirt"
        sudo usermod -aG docker "$USER" 2>/dev/null || log_warn "Grup bulunamadi: docker"
    fi
    log_info "Kullanici gruplari guncellendi"
}

# ============================================================
# PHASE: sddm
# ============================================================
phase_sddm() {
    log_step "SDDM yapilandiriliyor"

    sudo systemctl disable gdm.service lightdm.service ly.service 2>/dev/null || true
    if ! systemctl list-unit-files sddm.service >/dev/null 2>&1; then
        log_warn "sddm.service bulunamadi; SDDM paketi tekrar kuruluyor..."
        sudo pacman -S --needed --noconfirm sddm
        sudo systemctl daemon-reload
    fi
    systemctl list-unit-files sddm.service >/dev/null 2>&1 || { log_error "sddm.service halen bulunamadi."; return 1; }
    sudo systemctl enable sddm.service -f
    sudo systemctl set-default graphical.target
    log_info "SDDM etkinlestirildi"

    sudo mkdir -p /etc/sddm.conf.d
    cat <<EOF | sudo tee /etc/sddm.conf.d/10-wayland.conf > /dev/null
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
EOF

    local SUGAR_CANDY_DIR="/usr/share/sddm/themes/sugar-candy"
    if [ -d "$SUGAR_CANDY_DIR" ]; then
        sudo mkdir -p "$SUGAR_CANDY_DIR/Backgrounds"
        local SDDM_BG_SRC
        SDDM_BG_SRC="$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -n 1 || true)"
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
        log_info "SDDM Sugar Candy temasi yapilandirildi"
    fi

    if [ ! -d "$SUGAR_CANDY_DIR" ] && [ -d "$REPO_DIR/config/programs/sddm/themes/matugen-minimal" ]; then
        sudo mkdir -p /usr/share/sddm/themes/matugen-minimal
        sudo cp -r "$REPO_DIR/config/programs/sddm/themes/matugen-minimal/"* /usr/share/sddm/themes/matugen-minimal/

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
        log_info "SDDM temasi yapilandirildi (matugen-minimal fallback)"
    fi

    if [[ "$IS_VM" == true ]]; then
        sudo sed -i 's/^DisplayServer=.*/DisplayServer=x11-user/' /etc/sddm.conf.d/10-wayland.conf
        sudo sed -i 's/^GreeterEnvironment=.*/GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1,QT_QUICK_BACKEND=software/' /etc/sddm.conf.d/10-wayland.conf
        log_info "SDDM VM fix uygulandi (x11-user greeter + software rendering)"
    fi

    sudo systemctl start sddm.service 2>/dev/null || log_warn "SDDM hemen baslatilamadi; reboot sonrasi graphical.target ile tekrar denenecek."
}

# ============================================================
# PHASE: gaming-config (INSTALL_GAMING=1 only)
# ============================================================
phase_gaming_config() {
    if [[ "$IS_VM" == true ]]; then
        log_info "VM algilandi, gaming-config fasi atlaniyor."
        return 0
    fi

    if [[ -z "$REPO_DIR" || ! -d "$REPO_DIR" ]]; then
        log_error "REPO_DIR bulunamadi, gaming-config atlaniyor."
        return 1
    fi

    log_step "Gaming yapilandiriliyor"

    if [ -f "$REPO_DIR/config/gaming/gamemode.ini" ]; then
        mkdir -p "$HOME/.config"
        cp "$REPO_DIR/config/gaming/gamemode.ini" "$HOME/.config/gamemode.ini"
        log_info "GameMode config kuruldu"
    fi

    if [ -f "$REPO_DIR/config/gaming/MangoHud.conf" ]; then
        mkdir -p "$HOME/.config/MangoHud"
        cp "$REPO_DIR/config/gaming/MangoHud.conf" "$HOME/.config/MangoHud/MangoHud.conf"
        log_info "MangoHud config kuruldu"
    fi

    if [ -f "$REPO_DIR/config/gaming/hyprland-gaming.conf" ]; then
        mkdir -p "$HOME/.config/hypr"
        cp "$REPO_DIR/config/gaming/hyprland-gaming.conf" "$HOME/.config/hypr/gaming-rules.conf"
        log_info "Gaming Hyprland kurallari: ~/.config/hypr/gaming-rules.conf"
    fi

    if [ -f "$REPO_DIR/utils/bin/gaming-optimizer" ]; then
        cp "$REPO_DIR/utils/bin/gaming-optimizer" "$HOME/.local/bin/gaming-optimizer"
        chmod +x "$HOME/.local/bin/gaming-optimizer"
        log_info "Gaming optimizer kuruldu: gaming-optimizer"
    fi

    if ! grep -q "steam-mango" "$HOME/.zshrc" 2>/dev/null; then
        cat <<'STEAMHELP' >> "$HOME/.zshrc"

# Gaming aliases
alias steam-mango='MANGOHUD=1 gamemoderun %command%'
alias steam-gamemode='gamemoderun %command%'
alias steam-vulkan='MANGOHUD=1 DXVK_HUD=1 gamemoderun %command%'
STEAMHELP
    fi

    sudo usermod -aG gamemode "$USER" 2>/dev/null || true

    if command -v gamescope &>/dev/null; then
        log_info "gamescope kuruldu - Steam'de 'gamescope -- %command%' kullanabilirsiniz"
    fi

    log_info "Gaming araclari: Steam, Lutris, Heroic, ProtonUp-Qt, MangoHud, GameScope"
}

# ============================================================
# PHASE: postflight
# ============================================================
phase_postflight() {
    # --- Locale ---
    log_step "Locale ayarlaniyor"
    if ! locale 2>/dev/null | grep -q 'UTF-8'; then
        sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        sudo sed -i 's/^#tr_TR.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen
        sudo locale-gen
        echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf
        log_info "Locale: en_US.UTF-8 + tr_TR.UTF-8"
    fi

    # --- Network (BBR) ---
    log_step "Ag optimizasyonlari"
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
    log_info "BBR TCP etkinlestirildi"

    # --- NVIDIA ---
    if [[ "$IS_NVIDIA" == true ]]; then
        log_step "NVIDIA yapilandirmasi"
        cat <<'EOF' | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
options nvidia NVreg_DynamicPowerManagement=0x02
options nvidia-drm modeset=1
EOF
        log_info "NVIDIA modprobe ayarlari yapilandirildi"
    fi

    # --- Flatpak ---
    log_step "Flatpak yapilandiriliyor"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    log_info "Flathub deposu eklendi"

    # --- Utility Scripts ---
    mkdir -p "$HOME/.local/bin"
    local util
    for util in cava ssh-keygen-helper runtime-installer system-cleanup; do
        if [ -f "$REPO_DIR/utils/bin/$util" ]; then
            cp "$REPO_DIR/utils/bin/$util" "$HOME/.local/bin/$util"
            chmod +x "$HOME/.local/bin/$util"
            log_info "$util utility kuruldu"
        fi
    done

    # --- Security ---
    log_step "Guvenlik yapilandiriliyor"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw --force enable
    sudo systemctl enable --now ufw
    log_info "UFW firewall aktif (SSH izinli)"

    sudo systemctl enable --now fail2ban
    if [ -f "$REPO_DIR/config/security/jail.local" ]; then
        sudo cp "$REPO_DIR/config/security/jail.local" /etc/fail2ban/jail.local
        sudo systemctl restart fail2ban
        log_info "fail2ban yapilandirildi"
    fi

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
    log_info "Haftalik otomatik guncelleme zamanlandi"

    # --- System Health ---
    log_step "Sistem sagligi yapilandiriliyor"
    sudo mkdir -p /etc/systemd
    cat <<'EOF' | sudo tee /etc/systemd/zram-generator.conf > /dev/null
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now systemd-zram-setup@zram0.service
    log_info "zram-generator aktif (RAM sikistirma, zstd, RAM/2)"

    sudo systemctl enable --now earlyoom
    log_info "earlyoom aktif (OOM korumasi)"

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
    log_info "Aylik pacman cache temizligi zamanlandi"

    sudo mkdir -p /etc/systemd/journald.conf.d
    cat <<'EOF' | sudo tee /etc/systemd/journald.conf.d/size-limit.conf > /dev/null
[Journal]
SystemMaxUse=500M
MaxRetentionSec=1month
EOF
    sudo systemctl restart systemd-journald
    log_info "Journal boyut limiti: 500MB / 1 ay"

    local ORPHANS
    ORPHANS=$(pacman -Qtdq 2>/dev/null || true)
    if [ -n "$ORPHANS" ]; then
        sudo pacman -Rns $ORPHANS 2>/dev/null || log_warn "Orphan paketler kaldirilamadi"
        log_info "Orphan paketler temizlendi"
    else
        log_info "Orphan paket yok"
    fi

    # --- Performance ---
    log_step "Performans optimizasyonlari"
    if command -v preload &>/dev/null; then
        sudo systemctl enable --now preload
        log_info "preload aktif (uygulama onyukleme)"
    fi

    mkdir -p "$HOME/.config/psd"
    cat <<'EOF' > "$HOME/.config/psd/psd.conf"
USE_OVERLAYFS="yes"
BROWSERS="firefox chromium google-chrome"
EOF
    if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
        systemctl --user enable --now psd 2>/dev/null || true
        log_info "profile-sync-daemon aktif (browser RAM cache)"
    else
        systemctl --user enable psd 2>/dev/null || true
        log_info "profile-sync-daemon enable edildi (ilk login'de baslayacak)"
    fi

    if [[ "$IS_INTEL" == true ]]; then
        export LIBVA_DRIVER_NAME=iHD
        if ! grep -q "LIBVA_DRIVER_NAME=iHD" "$HOME/.zshrc" 2>/dev/null; then
            echo 'export LIBVA_DRIVER_NAME=iHD' >> "$HOME/.zshrc"
        fi
        log_info "VA-API: Intel iHD driver"
    elif [[ "$IS_AMD" == true ]]; then
        export LIBVA_DRIVER_NAME=radeonsi
        if ! grep -q "LIBVA_DRIVER_NAME=radeonsi" "$HOME/.zshrc" 2>/dev/null; then
            echo 'export LIBVA_DRIVER_NAME=radeonsi' >> "$HOME/.zshrc"
        fi
        log_info "VA-API: AMD radeonsi driver"
    fi

    if command -v plymouth &>/dev/null; then
        if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub; then
            if ! grep -q "splash" /etc/default/grub; then
                sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash quiet"/' /etc/default/grub
                sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
                log_info "Plymouth kernel parameter eklendi"
            fi
        fi
    fi

    # --- Developer Runtimes (INSTALL_DEV_TOOLS=1) ---
    if [[ "$INSTALL_DEV_TOOLS" == "1" ]]; then
        log_step "Developer runtime'lar yapilandiriliyor"

        # nvm (AUR'dan kurulmussa)
        export NVM_DIR="$HOME/.nvm"
        if [ -s "/usr/share/nvm/nvm.sh" ]; then
            source /usr/share/nvm/nvm.sh
            nvm install --lts || log_warn "Node.js LTS kurulamadi"
            nvm use --lts 2>/dev/null || true
            nvm alias default lts/* 2>/dev/null || true
            log_info "Node.js LTS kuruldu (nvm ile): $(node --version 2>/dev/null || echo 'kuruluyor...')"
        elif command -v node &>/dev/null; then
            log_info "Node.js pacman'dan kuruldu: $(node --version)"
        fi

        if ! grep -q 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null; then
            cat <<'EOF' >> "$HOME/.zshrc"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/share/nvm/nvm.sh" ] && \. "/usr/share/nvm/nvm.sh"
[ -s "/usr/share/nvm/bash_completion" ] && \. "/usr/share/nvm/bash_completion"
EOF
        fi

        # Python (pyenv)
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        if command -v pyenv &>/dev/null; then
            eval "$(pyenv init --path)"
            eval "$(pyenv init -)"
            pyenv install 3.12.0 2>/dev/null || true
            pyenv global 3.12.0 2>/dev/null || true
            log_info "Python 3.12 kuruldu (pyenv ile)"
        fi

        if ! grep -q "pyenv" "$HOME/.zshrc" 2>/dev/null; then
            cat <<'EOF' >> "$HOME/.zshrc"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
EOF
        fi

        # Rust (rustup)
        if command -v rustup &>/dev/null; then
            rustup default stable || log_warn "Rust stable kurulamadi"
            log_info "Rust stable kuruldu (rustup ile)"
        fi

        # Go
        if command -v go &>/dev/null; then
            mkdir -p "$HOME/go/bin"
            if ! grep -q "GOPATH" "$HOME/.zshrc" 2>/dev/null; then
                cat <<'EOF' >> "$HOME/.zshrc"

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
EOF
            fi
            log_info "Go yapilandirildi"
        fi

        # OpenAI Codex CLI
        if command -v npm &>/dev/null; then
            npm install -g @openai/codex 2>/dev/null && log_info "OpenAI Codex CLI kuruldu" || log_warn "Codex CLI kurulamadi"
        fi
    fi

    # --- Syncthing ---
    if command -v syncthing >/dev/null 2>&1 || systemctl list-unit-files 'syncthing@.service' >/dev/null 2>&1; then
        log_step "Syncthing yapilandiriliyor"
        sudo systemctl enable --now syncthing@$USER.service || log_warn "Syncthing etkinlestirilemedi"
        log_info "Syncthing aktif (http://localhost:8384)"
    else
        log_info "Syncthing kurulu degil, opsiyonel oldugu icin yapilandirma atlaniyor."
    fi

    # --- Git & direnv ---
    log_step "Developer araclari yapilandiriliyor"
    if [ -f "$REPO_DIR/config/dev/gitconfig" ]; then
        cp "$REPO_DIR/config/dev/gitconfig" "$HOME/.gitconfig"
        log_info "Git global config kuruldu"
    fi

    if ! grep -q "direnv" "$HOME/.zshrc" 2>/dev/null; then
        echo 'eval "$(direnv hook zsh)"' >> "$HOME/.zshrc"
        log_info "direnv hook eklendi"
    fi

    # --- Documentation ---
    log_step "Dokumantasyon kuruluyor"
    if [ -d "$REPO_DIR/docs" ]; then
        mkdir -p "$HOME/Documents/arch-nix-docs"
        cp -r "$REPO_DIR/docs/"* "$HOME/Documents/arch-nix-docs/" 2>/dev/null || true
        log_info "Dokumantasyon: ~/Documents/arch-nix-docs/"
    fi
}

# ============================================================
# MAIN
# ============================================================
main() {
    log_step "Arch Linux / CachyOS Desktop Kurulumu v3"
    log_info "Profil: $INSTALL_PROFILE | Gaming: $INSTALL_GAMING | Optional: $INSTALL_OPTIONAL_APPS | DevTools: $INSTALL_DEV_TOOLS"

    if [[ -f "$STATE_FILE" ]]; then
        log_info "Mevcut checkpoint bulundu, tamamlanmayan fazlardan devam ediliyor..."
    fi

    # --- Context (her run'da calisir, checkpoint'ten bagimsiz) ---
    detect_hardware
    resolve_repo_dir
    ensure_multilib
    ensure_aur_helper

    # --- Desktop fazlari (her zaman calisir) ---
    run_phase "preflight"       phase_preflight
    run_phase "aur-helper"      phase_aur_helper
    run_phase "pacman-core"     phase_pacman_core
    run_phase "pacman-desktop"  phase_pacman_desktop
    run_phase "pacman-hardware" phase_pacman_hardware
    run_phase "aur-core-critical" phase_aur_core_critical
    run_phase "aur-core-optional" phase_aur_core_optional "true"

    # --- Opsiyonel fazlar ---
    if [[ "$INSTALL_OPTIONAL_APPS" == "1" ]]; then
        run_phase "pacman-optional" phase_pacman_optional "true"
        run_phase "aur-optional"    phase_aur_optional "true"
    else
        log_info "pacman-optional ve aur-optional fazlari atlaniyor (INSTALL_OPTIONAL_APPS=0)"
    fi

    # --- Dev tools ---
    if [[ "$INSTALL_DEV_TOOLS" == "1" ]]; then
        run_phase "pacman-dev" phase_pacman_dev "true"
    else
        log_info "pacman-dev fasi atlaniyor (INSTALL_DEV_TOOLS=0)"
    fi

    # --- Dotfiles & config ---
    run_phase "dotfiles"   phase_dotfiles
    run_phase "wallpapers" phase_wallpapers
    run_phase "fonts"      phase_fonts
    run_phase "services"   phase_services
    run_phase "sddm"       phase_sddm
    run_phase "postflight" phase_postflight

    # --- Gaming (sadece INSTALL_GAMING=1) ---
    if [[ "$INSTALL_GAMING" == "1" ]]; then
        run_phase "pacman-gaming"  phase_pacman_gaming "true"
        run_phase "aur-gaming"     phase_aur_gaming "true"
        run_phase "gaming-config"  phase_gaming_config "true"
    fi

    # --- Tamamlandi ---
    echo ""
    echo -e "${BOLD}${GREEN}=============================================================${NC}"
    echo -e "${BOLD}${GREEN}  Kurulum tamamlandi!${NC}"
    echo -e "${BOLD}${GREEN}=============================================================${NC}"
    echo ""
    echo -e "  Config yedegi: ${CYAN}$BACKUP_DIR${NC}"
    echo -e "  Wallpaper'lar: ${CYAN}$HOME/Pictures/Wallpapers${NC}"
    echo -e "  Log dosyasi:   ${CYAN}$LOG_FILE${NC}"
    echo ""
    if [[ "$IS_VM" == true ]]; then
        echo -e "  ${YELLOW}VM algilandi - Software rendering aktif${NC}"
        echo ""
    fi

    if [[ "$INSTALL_GAMING" != "1" ]]; then
        echo -e "  ${BOLD}Gaming kurulumu icin:${NC}"
        echo -e "  ${CYAN}INSTALL_GAMING=1 bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/ozkanaltunboga/arch-nix/main/install.sh)\"${NC}"
        echo ""
    fi

    echo -e "  ${BOLD}Sistemi yeniden baslatin:${NC} sudo reboot"
    echo ""
}

main "$@"
