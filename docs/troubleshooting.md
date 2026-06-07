# Arch-Nix Troubleshooting Guide

## Yaygın Sorunlar ve Çözümleri

### Hyprland Başlamıyor / Siyah Ekran

**Sorun:** SDDM'den sonra Hyprland açılmıyor veya siyah ekran gösteriyor.

**Çözümler:**
```bash
# 1. Hyprland loglarını kontrol et
journalctl --user -u hyprland -n 50

# 2. GPU sürücülerini kontrol et
lspci -k | grep -A 2 -E "(VGA|3D)"

# 3. NVIDIA ise modprobe ayarlarını kontrol et
cat /etc/modprobe.d/nvidia.conf

# 4. VM ise software rendering aktif mi?
echo $WLR_RENDERER_ALLOW_SOFTWARE
echo $LIBGL_ALWAYS_SOFTWARE

# 5. Manuel başlatmayı dene (TTY'den)
Hyprland
```

### Quickshell Widget'ları Açılmıyor

**Sorun:** Super+W, Super+S gibi kısayollar çalışmıyor.

**Çözümler:**
```bash
# 1. Quickshell process'ini kontrol et
pgrep -a quickshell

# 2. Manuel başlat
quickshell -p ~/.config/hypr/scripts/quickshell/Main.qml &
quickshell -p ~/.config/hypr/scripts/quickshell/TopBar.qml &

# 3. IPC dosyasını kontrol et
cat /tmp/qs_widget_state

# 4. qs_manager.sh'ı test et
~/.config/hypr/scripts/qs_manager.sh toggle calendar
```

### Wallpaper Değişmiyor / Matugen Çalışmıyor

**Sorun:** Wallpaper seçtikten sonra renkler güncellenmiyor.

**Çözümler:**
```bash
# 1. Matugen'ı manuel çalıştır
matugen image ~/Pictures/Wallpapers/default.jpg

# 2. awww-daemon'ı kontrol et
pgrep -a awww

# 3. Manuel wallpaper değiştir
awww img ~/Pictures/Wallpapers/default.jpg --transition-type any

# 4. Template'leri kontrol et
ls ~/.config/matugen/templates/

# 5. Reload script'ini çalıştır
bash ~/.config/hypr/scripts/quickshell/wallpaper/matugen_reload.sh
```

### Ses Çalışmıyor

**Sorun:** Ses çıkmıyor veya kontrol edilemiyor.

**Çözümler:**
```bash
# 1. PipeWire servislerini kontrol et
systemctl --user status pipewire wireplumber pipewire-pulse

# 2. Yeniden başlat
systemctl --user restart pipewire wireplumber pipewire-pulse

# 3. Ses cihazlarını listele
wpctl status

# 4. Varsayılan cihazı ayarla
wpctl set-default @DEFAULT_AUDIO_SINK@

# 5. EasyEffects'i kontrol et
systemctl --user status easyeffects
```

### Bluetooth Cihaz Bağlanmıyor

**Sorun:** Bluetooth cihaz keşfedilemiyor veya bağlanamıyor.

**Çözümler:**
```bash
# 1. Bluetooth servisini kontrol et
sudo systemctl status bluetooth

# 2. Yeniden başlat
sudo systemctl restart bluetooth

# 3. Manuel tarama
bluetoothctl
> power on
> scan on
> pair XX:XX:XX:XX:XX:XX
> connect XX:XX:XX:XX:XX:XX

# 4. Blueman'ı aç
blueman-manager
```

### Neovim Plugin'leri Yüklenmiyor

**Sorun:** Neovim açıldığında plugin hataları veriyor.

**Çözümler:**
```bash
# 1. lazy.nvim'yi kontrol et
ls ~/.local/share/nvim/lazy/lazy.nvim

# 2. Manuel kur
nvim --headless "+Lazy! sync" +qa

# 3. Treesitter parser'ları kur
nvim --headless "+TSUpdateSync" +qa

# 4. LSP sunucularını kontrol et
nvim --headless "+LspInfo" +qa

# 5. Config'i yeniden yükle
nvim --headless "+source $MYVIMRC" +qa
```

### SDDM Teması Görünmüyor

**Sorun:** SDDM login ekranı varsayılan temada görünüyor.

**Çözümler:**
```bash
# 1. Sugar Candy temasını kontrol et
ls /usr/share/sddm/themes/sugar-candy

# 2. SDDM config'ini kontrol et
cat /etc/sddm.conf.d/10-wayland.conf

# 3. Manuel tema ayarla
sudo nano /etc/sddm.conf.d/10-wayland.conf
# [Theme]
# Current=sugar-candy

# 4. SDDM'i yeniden başlat
sudo systemctl restart sddm
```

### Syncthing Erişilemiyor

**Sorun:** http://localhost:8384 açılmıyor.

**Çözümler:**
```bash
# 1. Servisi kontrol et
systemctl --user status syncthing

# 2. Yeniden başlat
systemctl --user restart syncthing

# 3. Port'u kontrol et
ss -tlnp | grep 8384

# 4. Firewall'da izin ver
sudo ufw allow 8384/tcp
sudo ufw allow 22000/tcp
sudo ufw allow 22000/udp
sudo ufw allow 21027/udp
```

### Docker Permission Hatası

**Sorun:** `docker` komutları permission denied veriyor.

**Çözümler:**
```bash
# 1. Kullanıcıyı docker grubuna ekle
sudo usermod -aG docker $USER

# 2. Oturumu yenile (veya reboot)
newgrp docker

# 3. Docker servisini kontrol et
sudo systemctl status docker

# 4. Test et
docker run hello-world
```

### Zram Çalışmıyor

**Sorun:** `zramctl` boş çıktı veriyor.

**Çözümler:**
```bash
# 1. Servisi kontrol et
systemctl status zramd

# 2. Yeniden başlat
sudo systemctl restart zramd

# 3. Manuel kontrol
zramctl
cat /proc/swaps

# 4. Boyut ayarla
sudo nano /etc/zramd.conf
# SIZE=4G
```

### Earlyoom Sürekli Process Öldürüyor

**Sorun:** Earlyoom çok agresif çalışıyor.

**Çözümler:**
```bash
# 1. Logları kontrol et
journalctl -u earlyoom -n 50

# 2. Threshold'u ayarla
sudo nano /etc/default/earlyoom
# EARLYOOM_ARGS="-m 5 -r 60 --avoid '(firefox|chrome|nvim)'"

# 3. Yeniden başlat
sudo systemctl restart earlyoom
```

### Ekran Kilidi (Hyprlock) Çalışmıyor

**Sorun:** Super+L ile ekran kilitlenmiyor.

**Çözümler:**
```bash
# 1. Hyprlock'u manuel çalıştır
hyprlock

# 2. Prepare script'ini kontrol et
bash ~/.config/hypr/scripts/lockscreen_prepare.sh

# 3. Cache dizinini kontrol et
ls ~/.cache/arch-nix/lockscreen/

# 4. Config'i kontrol et
cat ~/.config/hypr/hyprlock.conf
```

### Plymouth Boot Splash Görünmüyor

**Sorun:** Boot sırasında Plymouth animasyonu görünmüyor.

**Çözümler:**
```bash
# 1. Plymouth paketini kur (eksikse)
sudo pacman -S plymouth

# 2. Kernel parameter ekle
sudo nano /etc/default/grub
# GRUB_CMDLINE_LINUX_DEFAULT="... splash quiet"

# 3. GRUB'u güncelle
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 4. Temayı ayarla
sudo plymouth-set-default-theme -R simple

# 5. Test et
sudo plymouthd
plymouth --show-splash
sleep 5
plymouth --quit
```

## Log Dosyaları

```bash
# Hyprland logları
journalctl --user -u hyprland -n 100

# Quickshell logları
journalctl --user -u quickshell -n 100

# Sistem logları
journalctl -xe

# Xorg/Wayland logları
cat ~/.local/share/xorg/Xorg.0.log
cat /tmp/hypr/hyprland.log
```

## Yararlı Komutlar

```bash
# Tüm servisleri listele
systemctl --user list-units --type=service

# Başarısız servisleri göster
systemctl --user --failed

# Disk kullanımını göster
duf

# RAM kullanımını göster
btop

# Ağ bağlantılarını göster
bandwhich

# Sistem bilgisi
fastfetch
```

## Yardım Alma

- Hyprland Wiki: https://wiki.hyprland.org/
- Arch Wiki: https://wiki.archlinux.org/
- Quickshell Docs: https://quickshell.outfoxxed.me/
- GitHub Issues: https://github.com/ozkanaltunboga/arch-nix/issues
