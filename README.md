# Arch Linux - Hyprland Dotfiles

Tek komutla tam Arch Linux / CachyOS masaustu kurulumu. [ilyamiro/imperative-dots](https://github.com/ilyamiro/imperative-dots) temel alinarak ozellestirilmistir.

## Kurulum

Minimal Arch Linux kurulumundan sonra:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ozkanaltunboga/arch-nix/main/install.sh)"
```

> **Root olarak calistirmayin!** Normal kullanici ile calistirin.

## Ozellikler

- **Otomatik donanim algilama** - VM (VMware/VirtualBox), NVIDIA, AMD, Intel GPU otomatik tespit
- **VM destegi** - Sanal makinelerde software rendering otomatik aktif
- **Quickshell widget'lari** - Saat, takvim, hava durumu, muzik, bluetooth, ses, wallpaper secici
- **SDDM** - Wayland display manager otomatik kurulum
- **Hyprland** - Wayland compositor, animasyonlar, workspace'ler
- **Turkce Q klavye** - Varsayilan olarak ayarli

## Dahil Olan Uygulamalar

| Kategori | Uygulamalar |
|----------|-------------|
| Terminal | Kitty, Zsh + Oh My Zsh |
| Tarayici | Firefox, Google Chrome |
| Editorler | Neovim, VS Code |
| Iletisim | Telegram |
| Notlar | Obsidian, Notion |
| Medya | OBS Studio, MPV, Spotify, Cava |
| Ofis | LibreOffice |
| Gelistirici | Docker, Lazygit, IntelliJ IDEA, Codex |
| Sanallastirma | KVM/QEMU (virt-manager) |
| Ag Araclari | Wireshark, Nmap, Traceroute, MTR, Bandwhich |
| CLI Araclari | btop, bat, zoxide, duf, ncdu, fzf, ripgrep |
| Sistem | Timeshift, Flatpak, Bottles |

## Klavye Kisayollari

### Uygulama Acma

| Kisayol | Islev |
|---------|-------|
| `Super + Enter` | Kitty terminal |
| `Super + F` | Firefox |
| `Super + E` | Nautilus (dosya yoneticisi) |
| `Super + D` | Rofi uygulama baslatici |
| `Super + C` | Pano gecmisi (clipboard) |
| `Super + A` | Bildirim merkezi (swaync) |
| `Alt + Tab` | Pencere degistirici |

### Quickshell Widget'lari

| Kisayol | Widget |
|---------|--------|
| `Super + S` | Takvim / Saat / Hava durumu |
| `Super + Q` | Muzik oynatici + Equalizer |
| `Super + W` | Wallpaper secici |
| `Super + V` | Ses kontrolu |
| `Super + N` | Ag / Wi-Fi / Bluetooth |
| `Super + B` | Batarya / Sistem monitor |
| `Super + H` | Kilavuz (Guide) |
| `Super + M` | Monitor ayarlari |
| `Super + Shift + S` | Stewart (AI asistan) |
| `Super + Shift + T` | Focus Time (odak zamanlayici) |

### Pencere Yonetimi

| Kisayol | Islev |
|---------|-------|
| `Alt + F4` | Pencereyi kapat |
| `Super + Shift + F` | Float/Tile gecisi |
| `Super + Yon tuslari` | Pencere odagini degistir |
| `Super + Ctrl + Yon tuslari` | Pencereyi tasi |
| `Super + Shift + Yon tuslari` | Pencereyi boyutlandir |
| `Super + Sol tik surukle` | Pencereyi tasi (fare) |
| `Super + Sag tik surukle` | Pencereyi boyutlandir (fare) |

### Workspace

| Kisayol | Islev |
|---------|-------|
| `Super + 1-0` | Workspace 1-10'a git |
| `Super + Shift + 1-0` | Pencereyi workspace'e tasi |
| 3 parmak yatay kaydirma | Workspace degistir |

### Medya & Sistem

| Kisayol | Islev |
|---------|-------|
| `Super + Space` | Muzik oynat/duraklat |
| `Super + L` | Ekrani kilitle |
| `Print` | Ekran goruntusu (alan secimi) |
| `Super + Print` | Tam ekran goruntusu |
| `Shift + Print` | Ekran goruntusu + duzenle |
| `Caps Lock` | Caps Lock OSD gostergesi |
| Ses tuslari | Ses ac/kapa/kis |
| Parlaklik tuslari | Parlaklik ayari |

## Ekran Goruntuleri

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

## Wallpaper'lar

Tum wallpaper'lar: **[ilyamiro/shell-wallpapers](https://github.com/ilyamiro/shell-wallpapers)**

## Krediler

- Orijinal dotfiles: [ilyamiro](https://github.com/ilyamiro/imperative-dots)
- Fork ve ozellestirme: [ozkanaltunboga](https://github.com/ozkanaltunboga)
