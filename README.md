# Arch / CachyOS / EndeavourOS Hyprland Dotfiles

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Arch%20Linux-blue)](https://archlinux.org/)
[![Wayland](https://img.shields.io/badge/Wayland-Hyprland-purple)](https://hyprland.org/)
[![Shell](https://img.shields.io/badge/Shell-Zsh-orange)](https://www.zsh.org/)
[![AUR](https://img.shields.io/badge/AUR-paru-green)](https://aur.archlinux.org/packages/paru)

Mevcut Arch tabanlı bir sistem üzerine tek komutla tam masaüstü kurulumu yapar. Tüm yapılandırma dosyaları doğrudan `config/` altından yönetilir.

> **Uyarı:** Bu script bir işletim sistemi kurmaz. Daha önce kurulmuş Arch tabanlı bir sistem üzerinde çalıştırılmalıdır.

## Kurulum

Minimal Arch / CachyOS / EndeavourOS kurulumundan sonra normal kullanici ile calistirin.

### Desktop Kurulumu (Varsayilan)

Hyprland masaustu, SDDM, Quickshell widget'lari, ses, ag, tema, VM duzeltmeleri ve temel uygulamalar kurulur:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ozkanaltunboga/arch-nix/main/install.sh)"
```

### Full Kurulum

Desktop + agir opsiyonel uygulamalar (VS Code, Chrome, Spotify, OnlyOffice, Notion, Bottles, IntelliJ) + developer araclari (Docker, KVM, Node.js, Python, Rust, Go):

```bash
INSTALL_PROFILE=full bash -c "$(curl -fsSL https://raw.githubusercontent.com/ozkanaltunboga/arch-nix/main/install.sh)"
```

### Gaming Kurulumu

Gaming paketleri (Steam, Lutris, Heroic, MangoHud, GameMode, GameScope, DXVK, Wine, 32-bit kutuphaneler) **varsayilan kurulumda yoktur**. Ana masaustu kurulumundan ayr calisir:

```bash
INSTALL_GAMING=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/ozkanaltunboga/arch-nix/main/install.sh)"
```

> Desktop fazlari zaten tamamlanmissa otomatik atlanir, yalnizca gaming fazlari calisir.

### Ortam Degiskenleri

| Degisken | Varsayilan | Aciklama |
|----------|-----------|----------|
| `INSTALL_PROFILE` | `desktop` | `desktop` veya `full` |
| `INSTALL_GAMING` | `0` | `1` = Gaming paketleri kurulur |
| `INSTALL_OPTIONAL_APPS` | `0` | `1` = Agir opsiyonel uygulamalar |
| `INSTALL_DEV_TOOLS` | `0` | `1` = Docker, KVM, dev runtime'lar |

> **Root olarak calistirmayin!** Script kendi icinde `sudo` kullanarak gerekli sistemsel islemleri yapar.

> **Yedekleme:** Mevcut `~/.config` icerigi otomatik olarak `~/.config-backup-<zaman_damgasi>` altina yedeklenir.

> **Resume:** Kurulum yariida kalirsa ayni komutu tekrar calistirin. Tamamlanan fazlar otomatik atlanir.

> **Akilli paket kurulumu:** Installer paketleri tek tek kontrol eder. Kurulu paketleri atlar, depoda/AUR'da bulunan eksikleri otomatik kurar, opsiyonel paket bulunamazsa devam eder ve finalde paket raporu basar. Kritik paketler basarisiz olursa ilgili faz durur.

## Özellikler

### Masaüstü Ortamı
- **Hyprland** - Wayland compositor, animasyonlar, workspace'ler
- **Quickshell widget'ları** - Saat, takvim, hava durumu, müzik, bluetooth, ses, wallpaper seçici
- **macOS/Mojave tarzı dock** - `nwg-dock-hyprland` ile altta ortalı, auto-hide dock
- **Modern login/lock ekranı** - SDDM Sugar Candy, Hyprlock ve wlogout entegrasyonu
- **SDDM** - Wayland display manager otomatik kurulum
- **Hazır wallpaper paketi** - Repo içindeki wallpaper'lar `~/Pictures/Wallpapers` altına kopyalanır
- **Türkçe Q klavye** - Varsayılan olarak ayarlı
- **Dayanıklı installer** - Faz bazlı resume, sudo keepalive, paket çakışması temizliği ve final paket raporu

### Güvenlik
- **UFW Firewall** - Varsayılan deny incoming, SSH izinli
- **fail2ban** - SSH brute-force koruması (24 saat ban)
- **Otomatik güvenlik güncellemeleri** - Haftalık pacman güncellemesi

### Sistem Sağlığı & Performans
- **zram-generator** - RAM sıkıştırma (performans artışı)
- **earlyoom** - Out-of-memory killer (sistem çökmesini önler)
- **Otomatik temizlik** - Aylık pacman cache temizliği (son 2 versiyon)
- **Journal boyut limiti** - 500MB / 1 ay
- **VA-API** - Hardware video acceleration (Intel iHD / AMD radeonsi)
- **preload** - Sık kullanılan uygulamaları önceden yükle
- **profile-sync-daemon** - Browser profile'ları RAM'e taşı
- **Plymouth** - Boot splash animasyonu

### Gaming
- **Steam** + Proton (Windows oyunları çalıştırma)
- **Lutris** + **Heroic** (Epic Games, GOG)
- **MangoHud** (FPS overlay, F12 ile toggle)
- **GameMode** (otomatik CPU/GPU optimizasyonu)
- **GameScope** (düşük input lag micro-compositor)
- **DXVK** + **VKD3D-Proton** (DirectX -> Vulkan)
- **32-bit kütüphaneler** (eski oyunlar için)
- **Controller desteği** (Xbox, PlayStation, Steam Controller)

### Developer Araçları
- **Node.js** - nvm ile version management + LTS kurulumu
- **Python** - pyenv ile version management + 3.12 kurulumu
- **Rust** - rustup ile stable + rustfmt, clippy, rust-analyzer
- **Go** - GOPATH setup + gopls, delve araçları
- **Neovim** - lazy.nvim ile plugin yönetimi, LSP, treesitter

### Senkronizasyon
- **Syncthing** - Cross-machine dosya senkronizasyonu (http://localhost:8384)

### Donanım Desteği
- **Otomatik donanım algılama** - VM (VMware/VirtualBox), NVIDIA, AMD, Intel GPU otomatik tespit
- **VM desteği** - Sanal makinelerde software rendering otomatik aktif
- **VM guest tools** - VMware, VirtualBox ve QEMU/SPICE guest araçları VM tipine göre kurulur

## Dahil Olan Uygulamalar

| Kategori | Uygulamalar |
|----------|-------------|
| Terminal | Kitty, Zsh + Oh My Zsh |
| Tarayıcı | Firefox, Google Chrome |
| Editörler | Neovim, VS Code |
| İletişim | Telegram, Discord |
| Notlar | Notion |
| Medya | OBS Studio, MPV, Spotify, Cava |
| Ofis | LibreOffice |
| Geliştirici | Docker, Lazygit, IntelliJ IDEA, Codex, Node.js, Python, Rust, Go |
| Sanallaştırma | KVM/QEMU (virt-manager) |
| Ağ Araçları | Nmap, Traceroute, MTR, Bandwhich |
| CLI Araçları | btop, bat, zoxide, duf, ncdu, fzf, ripgrep |
| Sistem | Timeshift, Flatpak, Bottles, Syncthing |
| Gaming | Steam, Lutris, Heroic, ProtonUp-Qt, MangoHud, GameMode, GameScope |
| Güvenlik | UFW Firewall, fail2ban |

## Klavye Kısayolları

### Uygulama Açma

| Kısayol | İşlev |
|---------|-------|
| `Super + Enter` | Kitty terminal |
| `Super + F` | Firefox |
| `Super + E` | Nautilus (dosya yöneticisi) |
| `Super + D` | Rofi uygulama başlatıcı |
| `Super + C` | Pano geçmişi (clipboard) |
| `Super + A` | Bildirim merkezi (swaync) |
| `Alt + Tab` | Pencere değiştirici |

### Quickshell Widget'ları

| Kısayol | Widget |
|---------|--------|
| `Super + S` | Takvim / Saat / Hava durumu |
| `Super + Q` | Müzik oynatıcı + Equalizer |
| `Super + W` | Wallpaper seçici |
| `Super + V` | Ses kontrolü |
| `Super + N` | Ağ / Wi-Fi / Bluetooth |
| `Super + B` | Batarya / Sistem monitör |
| `Super + H` | Kılavuz (Guide) |
| `Super + M` | Monitör ayarları |
| `Super + Shift + S` | Stewart (AI asistan) |
| `Super + Shift + T` | Focus Time (odak zamanlayıcı) |

### Pencere Yönetimi

| Kısayol | İşlev |
|---------|-------|
| `Alt + F4` | Pencereyi kapat |
| `Super + Shift + F` | Float/Tile geçişi |
| `Super + Yön tuşları` | Pencere odağını değiştir |
| `Super + Ctrl + Yön tuşları` | Pencereyi taşı |
| `Super + Shift + Yön tuşları` | Pencereyi boyutlandır |
| `Super + Sol tık sürükle` | Pencereyi taşı (fare) |
| `Super + Sağ tık sürükle` | Pencereyi boyutlandır (fare) |

### Workspace

| Kısayol | İşlev |
|---------|-------|
| `Super + 1-0` | Workspace 1-10'a git |
| `Super + Shift + 1-0` | Pencereyi workspace'e taşı |
| 3 parmak yatay kaydırma | Workspace değiştir |

### Medya & Sistem

| Kısayol | İşlev |
|---------|-------|
| `Super + Space` | Müzik oynat/duraklat |
| `Super + L` | Ekranı kilitle |
| `Super + Shift + L` | Güç / çıkış menüsü |
| `Print` | Ekran görüntüsü (alan seçimi) |
| `Super + Print` | Tam ekran görüntüsü |
| `Shift + Print` | Ekran görüntüsü + düzenle |
| `Caps Lock` | Caps Lock OSD göstergesi |
| Ses tuşları | Ses aç/kapa/kıs |
| Parlaklık tuşları | Parlaklık ayarı |

## Ekran Görüntüleri

![preview1](previews/screenshot1.png)
![preview2](previews/screenshot2.png)
![preview6](previews/screenshot6.png)
![preview4](previews/screenshot4.png)
![preview7](previews/screenshot7.png)
![preview5](previews/screenshot5.png)
![preview1_3](previews/screenshot1_3.png)
![preview1_1](previews/screenshot1_1.png)
![preview9](previews/screenshot9.png)
![preview3](previews/screenshot3.png)

## Gaming

Gaming paketleri **varsayilan kurulumda yoktur** ve ayri calistirilir:

```bash
INSTALL_GAMING=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/ozkanaltunboga/arch-nix/main/install.sh)"
```

### Gaming Paketleri
- **Steam** + Proton (Windows oyunları çalıştırma)
- **Lutris** + **Heroic** (Epic Games, GOG)
- **MangoHud** (FPS overlay, F12 ile toggle)
- **GameMode** (otomatik CPU/GPU optimizasyonu)
- **GameScope** (düşük input lag micro-compositor)
- **DXVK** + **VKD3D-Proton** (DirectX -> Vulkan)
- **Wine-staging** (Windows uygulama çalıştırma)
- **ProtonUp-Qt** (Proton versiyon yönetimi)
- **32-bit kütüphaneler** (40+ paket, eski oyunlar için)
- **Controller desteği** (Xbox, PlayStation, Steam Controller)

### Gaming Optimizasyonları
```bash
# Gaming optimizasyonlarını uygula
gaming-optimizer

# Steam'i MangoHud + GameMode ile başlat
MANGOHUD=1 gamemoderun steam

# Varsayılan ayarlara dön
gaming-optimizer restore
```

### Steam Launch Options
```bash
# MangoHud + GameMode
MANGOHUD=1 gamemoderun %command%

# GameScope ile (düşük input lag)
gamescope -W 1920 -H 1080 -f -- %command%

# Tam optimizasyon
MANGOHUD=1 gamemoderun gamescope -W 1920 -H 1080 -f -- %command%
```

Detaylı bilgi için: [docs/gaming.md](docs/gaming.md)

## Yardımcı Araçlar

| Komut | İşlev |
|-------|-------|
| `gaming-optimizer` | Oyun için sistem optimizasyonları (CPU/GPU/kernel/IO) |
| `system-cleanup` | Sistem temizliği (cache, log, orphan paketler) |
| `runtime-installer` | Node.js/Python/Rust/Go kurulumu |
| `ssh-keygen-helper` | İnteraktif SSH key oluşturma (Ed25519/RSA) |
| `fetch` | Matugen renkleriyle sistem bilgisi |
| `qcopy` | fzf ile dosya seç, panoya kopyala (LLM'ye yapıştırma için) |
| `pasteimg` | Panodan görüntüyü dosyaya kaydet |

### Zsh Aliases
```bash
edit          # Neovim'i sudo ile aç
update        # Sistem güncellemesi (paru -Syu)
stop          # Sistemi kapat
out           # Oturumu sonlandır
edconf        # Hyprland config'i düzenle
edinstall     # Install script'i düzenle
gitavail      # SSH key ekle
```

## Dokümantasyon

Detaylı dokümantasyon `docs/` dizininde:

- **[troubleshooting.md](docs/troubleshooting.md)** - Yaygın sorunlar ve çözümler
- **[customization.md](docs/customization.md)** - Tema, widget, Hyprland, Rofi, Zsh, Neovim özelleştirme
- **[update-guide.md](docs/update-guide.md)** - Güvenli güncelleme, rollback, kernel değişikliği
- **[gaming.md](docs/gaming.md)** - Gaming kurulumu, optimizasyonlar, sorun giderme
- **[keyboard-shortcuts.md](docs/keyboard-shortcuts.md)** - Tüm kısayollar (printable)

Kurulum sonrası dokümantasyon `~/Documents/arch-nix-docs/` dizinine kopyalanır.

## Krediler

- Gelistirici: [ozkanaltunboga](https://github.com/ozkanaltunboga)

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.

## Katkıda Bulunma

Katkılarınızı bekliyoruz! Lütfen şu adımları izleyin:

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişikliklerinizi commit edin (`git commit -m 'feat: add amazing feature'`)
4. Branch'inizi push edin (`git push origin feature/amazing-feature`)
5. Pull Request açın

## Sorun Bildirme

Bir sorun bulursanız lütfen [GitHub Issues](https://github.com/ozkanaltunboga/arch-nix/issues) üzerinden bildirin.

---

**Not:** Bu script Arch Linux ve türevleri (CachyOS, EndeavourOS) için tasarlanmıştır. Diğer dağıtımlarda çalışmayabilir.
