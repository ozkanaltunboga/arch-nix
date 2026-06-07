# Arch-Nix Gaming Guide

## Kurulan Gaming Paketleri

### Temel
- **Steam** - Ana oyun platformu
- **Lutris** - Çoklu platform oyun yöneticisi
- **Heroic Games Launcher** - Epic Games & GOG launcher
- **ProtonUp-Qt** - Proton versiyon yönetimi

### Performans
- **GameMode** - Otomatik oyun optimizasyonları
- **MangoHud** - FPS ve sistem bilgisi overlay
- **GOverlay** - MangoHud GUI yapılandırması
- **GameScope** - Micro-compositor (input lag azaltma)
- **vkBasalt** - Post-processing efektleri

### Uyumluluk
- **Wine-staging** - Windows uygulama çalıştırma
- **DXVK** - DirectX 9/10/11 → Vulkan
- **VKD3D-Proton** - DirectX 12 → Vulkan
- **32-bit kütüphaneler** - Eski oyunlar için gerekli

### Controller
- **xboxdrv** - Xbox controller desteği
- **steam-devices** - Steam controller udev kuralları

## Steam Yapılandırması

### Proton Etkinleştirme
1. Steam → Settings → Compatibility
2. "Enable Steam Play for all other titles" işaretle
3. Proton Experimental veya Proton GE seç

### Proton GE Kurulumu (Önerilen)
```bash
# ProtonUp-Qt ile
protonup-qt

# Veya manuel
mkdir -p ~/.steam/root/compatibilitytools.d
# https://github.com/GloriousEggroll/proton-ge-custom/releases
# İndir ve çıkar
```

### Launch Options Örnekleri

**MangoHud + GameMode:**
```
MANGOHUD=1 gamemoderun %command%
```

**DXVK HUD + MangoHud:**
```
MANGOHUD=1 DXVK_HUD=1 gamemoderun %command%
```

**GameScope ile (düşük input lag):**
```
gamescope -W 1920 -H 1080 -f -- %command%
```

**vkBasalt efektleri:**
```
ENABLE_VKBASALT=1 gamemoderun %command%
```

**Tam optimizasyon:**
```
MANGOHUD=1 gamemoderun gamescope -W 1920 -H 1080 -f -- %command%
```

## Lutris Yapılandırması

### İlk Kurulum
```bash
lutris
```

### Wine Runner Kurulumu
1. Lutris → Preferences → Runners
2. Wine → Install
3. wine-ge-custom veya wine-tkg önerilir

### Oyun Ekleme
- **Epic Games:** Heroic Games Launcher kullan
- **GOG:** Lutris veya Heroic
- **Standalone:** Lutris → Add Game → Wine

## MangoHud Kullanımı

### Toggle
- **F12** - HUD göster/gizle
- **F11** - Logging başlat/durdur

### Özelleştirme
```bash
# GUI ile
goverlay

# Manuel
nano ~/.config/MangoHud/MangoHud.conf
```

### Per-Game Config
```bash
# Steam launch option
MANGOHUD_CONFIG="gpu_stats,cpu_stats,fps" %command%
```

## GameMode Kullanımı

### Manuel Aktivasyon
```bash
# Oyun başlat
gamemoderun ./game_executable

# Steam'de
gamemoderun %command%
```

### Durum Kontrolü
```bash
gamemoded -t
```

### Özelleştirme
```bash
nano ~/.config/gamemode.ini
```

## Gaming Optimizer

### Kullanım
```bash
# Tüm optimizasyonları uygula
gaming-optimizer

# Sadece CPU governor
gaming-optimizer 1

# Varsayılana dön
gaming-optimizer restore
```

### Yaptığı Optimizasyonlar
1. **CPU Governor** → performance
2. **Kernel Parametreleri** → düşük latency
3. **Swappiness** → 10 (daha az swap)
4. **I/O Scheduler** → NVMe: none, SATA: mq-deadline
5. **GPU Power Profile** → high performance

## Hyprland Gaming Kuralları

### Otomatik Ekleme
```bash
# gaming-rules.conf'u include et
echo 'source = ~/.config/hypr/gaming-rules.conf' >> ~/.config/hypr/hyprland.conf
hyprctl reload
```

### Manuel Ekleme
```bash
# hyprland.conf'a ekle
windowrule = fullscreen, class:^(cs2)$
windowrule = immediate, class:^(cs2)$
```

## Performans İpuçları

### Kernel
```bash
# Zen kernel (gaming optimized)
sudo pacman -S linux-zen linux-zen-headers
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### CPU
```bash
# CPU frequency scaling
sudo cpupower frequency-set -g performance

# Disable CPU turbo (stability için)
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
```

### GPU (NVIDIA)
```bash
# Force performance mode
nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1"

# Overclock (dikkatli!)
nvidia-settings -a "[gpu:0]/GPUGraphicsClockOffset[3]=100"
```

### GPU (AMD)
```bash
# Performance mode
echo "high" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level

# Overclock
echo "manual" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
# Sonra pp_od_clk_voltage düzenle
```

### RAM
```bash
# XMP/DOCP profil (BIOS'tan)
# Swap'i azalt
echo 10 | sudo tee /proc/sys/vm/swappiness
```

## Sorun Giderme

### Steam Açılmıyor
```bash
# 32-bit kütüphaneleri kontrol et
ldd ~/.steam/steam/ubuntu12_32/steam | grep "not found"

# Eksik kütüphaneleri kur
sudo pacman -S lib32-glibc lib32-libx11
```

### Oyun Çöktü
```bash
# Logları kontrol et
~/.steam/steam/logs/

# Proton log
PROTON_LOG=1 %command%
# ~/steam-*.log
```

### Düşük FPS
```bash
# GameMode aktif mi?
gamemoded -t

# MangoHud ile monitoring
MANGOHUD=1 %command%

# CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# GPU kullanımı
watch -n 1 "nvidia-smi"  # NVIDIA
watch -n 1 "radeontop"   # AMD
```

### Controller Çalışmıyor
```bash
# Controller'ı kontrol et
ls /dev/input/js*

# Steam controller udev kuralları
sudo systemctl restart systemd-udevd

# xboxdrv ile
sudo xboxdrv --daemon
```

### Wine/Proton Sorunları
```bash
# Wine prefix temizle
rm -rf ~/.wine

# Yeni prefix
WINEPREFIX=~/.wine-new winecfg

# DXVK kur
dxvk-setup i -d  # Direct3D 9
dxvk-setup i -d3d10
dxvk-setup i -d3d11
```

### Audio Crackling
```bash
# PipeWire latency
export PIPEWIRE_LATENCY=128/48000

# PulseAudio
export PULSE_LATENCY_MSEC=60
```

## Önerilen Oyunlar (Linux Native)

### AAA
- Counter-Strike 2
- Dota 2
- Team Fortress 2
- Left 4 Dead 2
- Portal 2

### Indie
- Stardew Valley
- Hollow Knight
- Celeste
- Dead Cells
- Hades

### Proton ile Mükemmel Çalışan
- Elden Ring
- Cyberpunk 2077
- Red Dead Redemption 2
- The Witcher 3
- GTA V

## Yararlı Linkler

- **ProtonDB:** https://www.protondb.com/ (oyun uyumluluk)
- **Are We Anti-Cheat Yet:** https://areweanticheatyet.com/
- **Linux Gaming Wiki:** https://linux-gaming.kwindu.eu/
- **GamingOnLinux:** https://www.gamingonlinux.com/

## Hızlı Komutlar

```bash
# Steam'i MangoHud + GameMode ile başlat
MANGOHUD=1 gamemoderun steam

# Lutris'i başlat
lutris

# Heroic'i başlat
heroic

# ProtonUp-Qt'yi aç
protonup-qt

# GOverlay'i aç
goverlay

# Gaming optimizasyonları
gaming-optimizer

# FPS overlay toggle (oyun içinde)
F12

# Gaming optimizasyonlarını geri al
gaming-optimizer restore
```

## Benchmark ve Test

```bash
# glxgears (basit)
glxgears

# Unigine Heaven
yay -S unigine-heaven
unigine-heaven

# 3DMark (Proton ile)
# Steam'den kur, Proton ile çalıştır
```

## Multi-Monitor Gaming

```bash
# GameScope ile belirli monitörde çalıştır
gamescope -W 1920 -H 1080 -f -O HDMI-A-1 -- %command%

# Hyprland workspace'e zorla
windowrule = workspace 5, class:^(cs2)$
```

## Recording ve Streaming

```bash
# OBS Studio (zaten kurulu)
obs

# GPU encoding (NVIDIA)
# OBS → Settings → Output → Encoder: NVIDIA NVENC H.264

# GPU encoding (AMD)
# OBS → Settings → Output → Encoder: VAAPI H.264
```

## Son İpuçları

1. **Proton GE kullan** - Daha iyi uyumluluk
2. **GameMode her zaman aktif** - `gamemoderun %command%`
3. **MangoHud ile monitoring** - Performans sorunlarını tespit et
4. **Gaming optimizer** - Oyun öncesi çalıştır
5. **Zen kernel** - Düşük latency için
6. **SSD kullan** - Yükleme süreleri için kritik
7. **16GB+ RAM** - Modern oyunlar için minimum
8. **Swap'i azalt** - `vm.swappiness=10`
9. **CPU governor: performance** - Stabil FPS için
10. **Proton logları** - Sorun giderme için `PROTON_LOG=1`

İyi oyunlar! 🎮
