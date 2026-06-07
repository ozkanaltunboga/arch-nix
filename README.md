# Arch / CachyOS / EndeavourOS Hyprland Dotfiles

Mevcut Arch tabanlı bir sistem üzerine tek komutla tam masaüstü kurulumu yapar. Tüm yapılandırma dosyaları doğrudan `config/` altından yönetilir.

> **Uyarı:** Bu script bir işletim sistemi kurmaz. Daha önce kurulmuş Arch tabanlı bir sistem üzerinde çalıştırılmalıdır.

Kurulum, [ilyamiro/imperative-dots](https://github.com/ilyamiro/imperative-dots) reposundan ilham alınarak özelleştirilmiştir.

## Kurulum

Minimal Arch / CachyOS / EndeavourOS kurulumundan sonra normal kullanıcı ile çalıştırın:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ozkanaltunboga/arch-nix/main/install.sh)"
```

> **Root olarak çalıştırmayın!** Script kendi içinde `sudo` kullanarak gerekli sistemsel işlemleri yapar.

> **Yedekleme:** Mevcut `~/.config` içeriği otomatik olarak `~/.config-backup-<zaman_damgasi>` altına yedeklenir.

## Özellikler

- **Otomatik donanım algılama** - VM (VMware/VirtualBox), NVIDIA, AMD, Intel GPU otomatik tespit
- **VM desteği** - Sanal makinelerde software rendering otomatik aktif
- **Quickshell widget'ları** - Saat, takvim, hava durumu, müzik, bluetooth, ses, wallpaper seçici
- **Hazır wallpaper paketi** - Repo içindeki wallpaper'lar `~/Pictures/Wallpapers` altına kopyalanır
- **VM guest tools** - VMware, VirtualBox ve QEMU/SPICE guest araçları VM tipine göre kurulur
- **macOS/Mojave tarzı dock** - `nwg-dock-hyprland` ile altta ortalı, auto-hide dock
- **Modern login/lock ekranı** - SDDM Sugar Candy, Hyprlock ve wlogout entegrasyonu
- **SDDM** - Wayland display manager otomatik kurulum
- **Hyprland** - Wayland compositor, animasyonlar, workspace'ler
- **Türkçe Q klavye** - Varsayılan olarak ayarlı

## Dahil Olan Uygulamalar

| Kategori | Uygulamalar |
|----------|-------------|
| Terminal | Kitty, Zsh + Oh My Zsh |
| Tarayıcı | Firefox, Google Chrome |
| Editörler | Neovim, VS Code |
| İletişim | Telegram, Discord |
| Notlar | Obsidian, Notion |
| Medya | OBS Studio, MPV, Spotify, Cava |
| Ofis | LibreOffice |
| Geliştirici | Docker, Lazygit, IntelliJ IDEA, Codex, Node.js, Python, Rust, Go |
| Sanallaştırma | KVM/QEMU (virt-manager) |
| Ağ Araçları | Wireshark, Nmap, Traceroute, MTR, Bandwhich |
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

Sistem, Linux'ta oyun oynamak için tam donanımlı olarak yapılandırılır:

- **Steam** + Proton (Windows oyunları çalıştırma)
- **Lutris** + **Heroic** (Epic Games, GOG)
- **MangoHud** (FPS overlay, F12 ile toggle)
- **GameMode** (otomatik CPU/GPU optimizasyonu)
- **GameScope** (düşük input lag micro-compositor)
- **DXVK** + **VKD3D-Proton** (DirectX → Vulkan)
- **32-bit kütüphaneler** (eski oyunlar için)
- **Controller desteği** (Xbox, PlayStation, Steam Controller)

```bash
# Gaming optimizasyonlarını uygula
gaming-optimizer

# Steam'i MangoHud + GameMode ile başlat
MANGOHUD=1 gamemoderun steam

# Varsayılan ayarlara dön
gaming-optimizer restore
```

Detaylı bilgi için: [docs/gaming.md](docs/gaming.md)

## Yardımcı Araçlar

| Komut | İşlev |
|-------|-------|
| `gaming-optimizer` | Oyun için sistem optimizasyonları |
| `system-cleanup` | Sistem temizliği (cache, log, orphan paketler) |
| `runtime-installer` | Node.js/Python/Rust/Go kurulumu |
| `ssh-keygen-helper` | İnteraktif SSH key oluşturma |
| `fetch` | Matugen renkleriyle sistem bilgisi |
| `qcopy` | fzf ile dosya seç, panoya kopyala |

## Krediler

- Orijinal dotfiles: [ilyamiro/imperative-dots](https://github.com/ilyamiro/imperative-dots)
- Fork ve özelleştirme: [ozkanaltunboga](https://github.com/ozkanaltunboga)
