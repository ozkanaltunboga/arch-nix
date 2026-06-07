# Arch-Nix Update & Upgrade Guide

## Güncel Tutma

### Tam Sistem Güncellemesi

```bash
# Pacman + AUR güncellemesi
paru -Syu

# Sadece Pacman
sudo pacman -Syu

# Sadece AUR
paru -Sua
```

### Güvenli Güncelleme Prosedürü

```bash
# 1. Önce backup al
sudo timeshift --create --comments "Pre-update $(date +%Y-%m-%d)"

# 2. Mirror'ları güncelle
sudo reflector --country Turkey,Germany --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# 3. Güncelle
sudo pacman -Syu

# 4. Reboot (gerekirse)
sudo reboot
```

### Otomatik Güncelleme

Sistem zaten haftalık otomatik güncelleme yapıyor. Manuel tetikleme:

```bash
sudo systemctl start pacman-auto-update.service
```

## Paket Yönetimi

### Orphan Paketleri Temizle

```bash
# Orphan paketleri listele
pacman -Qtdq

# Temizle
sudo pacman -Rns $(pacman -Qtdq)
```

### Cache Temizliği

```bash
# Manuel temizlik (son 2 versiyonu tut)
paccache -r -k 2

# Tüm cache'i temizle
paccache -r -k 0

# Otomatik temizlik (aylık)
sudo systemctl start pacman-cache-clean.service
```

### Downgrade (Geri Alma)

```bash
# downgrade kur
sudo pacman -S downgrade

# Spesifik paketi downgrade et
sudo downgrade package-name

# Cache'den eski versiyonu kur
sudo pacman -U /var/cache/pacman/pkg/package-old-version.pkg.tar.zst
```

## Kernel Güncellemesi

### LTS Kernel'e Geçiş

```bash
# LTS kernel kur
sudo pacman -S linux-lts linux-lts-headers

# GRUB'u güncelle
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Reboot ve LTS kernel seç
sudo reboot
```

### Zen Kernel (Performans)

```bash
sudo pacman -S linux-zen linux-zen-headers
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

## NVIDIA Sürücü Güncellemesi

```bash
# Mevcut versiyonu kontrol et
nvidia-smi

# Güncelle
sudo pacman -Syu nvidia nvidia-utils

# DKMS ile kernel güncellemelerinde otomatik rebuild
sudo pacman -S nvidia-dkms
```

## Hyprland Güncellemesi

### Stable vs Git

```bash
# Stable (pacman)
sudo pacman -S hyprland

# Git (AUR - en son özellikler)
paru -S hyprland-git
```

### Config Migration

Hyprland güncellendikten sonra config değişikliklerini kontrol et:

```bash
# Hyprland versiyonu
hyprctl version

# Config'i test et
hyprctl reload
```

## Neovim Güncellemesi

### Plugin Güncellemesi

```bash
# Tüm plugin'leri güncelle
nvim --headless "+Lazy! sync" +qa

# Treesitter parser'ları güncelle
nvim --headless "+TSUpdateSync" +qa

# Mason (LSP) güncelle
nvim --headless "+MasonUpdate" +qa
```

### Neovim Versiyonu

```bash
# Mevcut versiyon
nvim --version

# Nightly (en son)
paru -S neovim-git
```

## Dotfiles Güncellemesi

### Repo'dan Güncelle

```bash
# Dotfiles dizinine git
cd ~/.hyprland-dots

# Pull latest
git pull

# Install script'i çalıştır (sadece yeni dosyalar)
bash install.sh
```

### Manuel Güncelleme

```bash
# Spesifik dosyayı güncelle
cp ~/.hyprland-dots/config/sessions/hyprland/hyprland.conf ~/.config/hypr/

# Reload
hyprctl reload
```

## Rollback (Geri Alma)

### Timeshift ile Restore

```bash
# Snapshot'ları listele
sudo timeshift --list

# Restore et
sudo timeshift --restore

# Spesifik snapshot
sudo timeshift --restore --snapshot '2026-06-07_12-00-00'
```

### Pacman Downgrade

```bash
# Paket history
ls /var/cache/pacman/pkg/ | grep package-name

# Eski versiyonu kur
sudo pacman -U /var/cache/pacman/pkg/package-old.pkg.tar.zst

# Hold (güncelleme engelle)
echo "package-name" | sudo tee -a /etc/pacman.conf
# IgnorePkg = package-name
```

## Sistem Sağlığı Kontrolü

### Güncelleme Sonrası Kontrol

```bash
# Başarısız servisler
systemctl --failed

# Journal hataları
journalctl -p 3 -xb

# Disk alanı
df -h

# RAM kullanımı
free -h
```

### Performans Testi

```bash
# Boot süresi
systemd-analyze

# CPU benchmark
stress-ng --cpu 4 --timeout 10s

# Disk I/O
fio --name=seqread --rw=read --direct=1 --ioengine=libaio --bs=1M --numjobs=4 --size=1G --runtime=10 --group_reporting
```

## Backup Stratejisi

### Timeshift (Sistem)

```bash
# Manuel snapshot
sudo timeshift --create --comments "Manual backup"

# Otomatik (günlük)
sudo timeshift --create --scripted

# Snapshot'ları listele
sudo timeshift --list
```

### Syncthing (Dosyalar)

```bash
# Web UI
http://localhost:8384

# Config dizini
~/.config/syncthing/

# Data dizini
~/Sync/
```

### Git (Dotfiles)

```bash
# Dotfiles'ı commit et
cd ~/.hyprland-dots
git add .
git commit -m "Update config $(date +%Y-%m-%d)"
git push
```

## Sorun Giderme

### Güncelleme Sonrası Hyprland Çöktü

```bash
# TTY'ye geç (Ctrl+Alt+F3)
# Eski config'i restore et
cp ~/.config-backup-LATEST/hypr/hyprland.conf ~/.config/hypr/

# Hyprland'ı yeniden başlat
Hyprland
```

### Pacman Veritabanı Bozuk

```bash
# Veritabanını yeniden oluştur
sudo rm /var/lib/pacman/sync/*
sudo pacman -Syy

# Paket veritabanını kontrol et
sudo pacman -Qkk
```

### Kernel Panic

```bash
# Eski kernel ile boot et (GRUB menüsünden)

# Son kernel'i kaldır
sudo pacman -R linux

# Yeniden kur
sudo pacman -S linux
```

## İleri Seviye

### Custom Repo Ekleme

```bash
# /etc/pacman.conf'a ekle
[myrepo]
Server = https://myrepo.example.com/$arch
SigLevel = Optional TrustAll

# Güncelle
sudo pacman -Syy
```

### AUR Helper Değiştirme

```bash
# paru kaldır
sudo pacman -R paru

# yay kur
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Chroot ile Kurtarma

```bash
# Live USB'den boot et

# Partition'ları mount et
sudo mount /dev/sda2 /mnt
sudo mount /dev/sda1 /mnt/boot

# Chroot
sudo arch-chroot /mnt

# Güncelle
pacman -Syu

# Exit
exit
sudo umount -R /mnt
sudo reboot
```

## Kaynaklar

- Arch Wiki: https://wiki.archlinux.org/title/System_maintenance
- Hyprland Wiki: https://wiki.hyprland.org/
- Pacman Tips: https://wiki.archlinux.org/title/Pacman/Tips_and_tricks
