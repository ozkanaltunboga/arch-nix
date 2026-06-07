# Arch-Nix Customization Guide

## Tema ve Renk Özelleştirme

### Matugen ile Renk Paleti

Matugen, wallpaper'dan otomatik renk paleti üretir. Manuel tetikleme:

```bash
# Wallpaper'dan renk üret
matugen image ~/Pictures/Wallpapers/my-wallpaper.jpg

# Spesifik renk indeksinden üret
matugen image ~/Pictures/Wallpapers/my-wallpaper.jpg --source-color-index 0

# Hex renkten palet üret
matugen color hex "#cba6f7"
```

### Renk Template'leri

Matugen template'leri `~/.config/matugen/templates/` altında:

```bash
# Mevcut template'leri listele
ls ~/.config/matugen/templates/

# Yeni template ekle
nano ~/.config/matugen/templates/my-app.conf.template
```

Template örneği:
```
[colors]
background = {{colors.base.default.hex}}
foreground = {{colors.text.default.hex}}
accent = {{colors.primary.default.hex}}
```

### Manuel Renk Override

`~/.config/matugen/config.toml` dosyasını düzenle:

```toml
[config]
reload_apps = true

[templates.my-app]
input_path = "~/.config/matugen/templates/my-app.conf.template"
output_path = "~/.config/my-app/config.conf"
```

## Widget Özelleştirme

### Quickshell Widget'ları

Widget'lar `~/.config/hypr/scripts/quickshell/` altında:

```
quickshell/
├── Main.qml              # Ana widget container
├── TopBar.qml            # Üst bar
├── WindowRegistry.js     # Widget boyut/pozisyon
├── calendar/             # Takvim widget
├── music/                # Müzik widget
├── network/              # Ağ widget
├── volume/               # Ses widget
└── ...
```

### Yeni Widget Ekleme

1. Widget dizini oluştur:
```bash
mkdir -p ~/.config/hypr/scripts/quickshell/mywidget
```

2. QML dosyası oluştur:
```qml
// MyWidget.qml
import QtQuick
import Quickshell
import "../"

Item {
    id: window
    
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }
    
    MatugenColors { id: _theme }
    
    Rectangle {
        anchors.fill: parent
        radius: s(20)
        color: _theme.base
        
        Text {
            anchors.centerIn: parent
            text: "My Widget"
            font.family: "JetBrains Mono"
            font.pixelSize: s(24)
            color: _theme.text
        }
    }
}
```

3. WindowRegistry.js'e ekle:
```javascript
"mywidget": { w: s(600, scale), h: s(400, scale), rx: Math.floor((mw/2)-(s(600, scale)/2)), ry: Math.floor((mh/2)-(s(400, scale)/2)), comp: "mywidget/MyWidget.qml" },
```

4. qs_manager.sh'a toggle ekle:
```bash
bind = $mainMod, Y, exec, bash ~/.config/hypr/scripts/qs_manager.sh toggle mywidget
```

### Widget Boyutlarını Değiştirme

`WindowRegistry.js` dosyasını düzenle:

```javascript
function getLayout(name, mx, my, mw, mh) {
    let scale = getScale(mw);
    
    let base = {
        "calendar":  { w: s(1450, scale), h: s(750, scale), ... },
        "music":     { w: s(700, scale), h: s(620, scale), ... },
        // Boyutları değiştir
    };
}
```

## Hyprland Özelleştirme

### Animasyonlar

`~/.config/hypr/hyprland.conf` dosyasında:

```ini
animations {
    enabled = yes
    
    # Bezier eğrileri
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    bezier = smoothBezier, 0.25, 0.1, 0.25, 1.0
    
    # Animasyonlar
    animation = windows, 1, 5, myBezier, popin 80%
    animation = workspaces, 1, 5, smoothBezier, slide
}
```

### Window Rules

```ini
# Float belirli pencereler
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(blueman-manager)$

# Boyut ayarla
windowrule = size 800 600, ^(pavucontrol)$

# Workspace'e ata
windowrule = workspace 2, ^(firefox)$
windowrule = workspace 3, ^(code)$
```

### Monitor Ayarları

```ini
# Tek monitor
monitor = , preferred, auto, 1

# Çoklu monitor
monitor = HDMI-A-1, 1920x1080@144, 0x0, 1
monitor = DP-1, 2560x1440@165, 1920x0, 1

# Scale
monitor = eDP-1, 1920x1080@60, 0x0, 1.25
```

## Rofi Özelleştirme

### Tema Değiştirme

`~/.config/rofi/theme.rasi` dosyasını düzenle:

```css
* {
    background-color: rgba(30, 30, 46, 0.95);
    text-color: #cdd6f4;
    accent-color: #cba6f7;
}

window {
    border-radius: 16px;
    padding: 20px;
}

element selected {
    background-color: @accent-color;
    text-color: #1e1e2e;
}
```

### Rofi Modları

```bash
# Uygulama başlatıcı
rofi -show drun

# Pencere değiştirici
rofi -show window

# Emoji seçici (rofi-emoji kuruluysa)
rofi -show emoji

# Hesap makinesi (rofi-calc kuruluysa)
rofi -show calc
```

## Zsh Özelleştirme

### Yeni Alias Ekleme

`~/.config/zsh/user_aliases.zsh` dosyasına ekle:

```bash
alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'

# Docker aliases
alias dps='docker ps'
alias dcp='docker-compose'
alias dexec='docker exec -it'
```

### Yeni Plugin Ekleme

`~/.zshrc` dosyasını düzenle:

```bash
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    docker
    kubectl
)
```

## Neovim Özelleştirme

### Yeni Plugin Ekleme

`~/.config/nvim/init.lua` dosyasında:

```lua
require("lazy").setup({
    -- Mevcut plugin'ler
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
    
    -- Yeni plugin ekle
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {},
    },
})
```

### LSP Sunucusu Ekleme

```lua
setup_server("tsserver", {
    settings = {
        typescript = {
            inlayHints = {
                includeInlayParameterNameHints = "all",
            },
        },
    },
})
```

### Keybinding Ekleme

```lua
vim.keymap.set('n', '<leader>t', ':TroubleToggle<CR>', { desc = 'Toggle Trouble' })
vim.keymap.set('n', '<leader>r', ':lua vim.lsp.buf.rename()<CR>', { desc = 'Rename Symbol' })
```

## Swaync (Bildirimler) Özelleştirme

### Bildirim Kuralları

`~/.config/swaync/config.json` dosyasına ekle:

```json
{
  "scripts": {
    "on-arrival": {
      "exec": "notify-send 'New notification'"
    }
  },
  "notification-visibility": {
    "ignore-spotify": {
      "state": "ignored",
      "app-name": "Spotify"
    }
  }
}
```

### Stil Değiştirme

`~/.config/swaync/style.css` dosyasını düzenle (Matugen tarafından otomatik oluşturulur).

## Dock (nwg-dock) Özelleştirme

### Stil Değiştirme

`~/.config/nwg-dock-hyprland/style.css` dosyasını düzenle:

```css
window {
    background: rgba(30, 30, 46, 0.85);
    border-radius: 16px;
}

button {
    border-radius: 12px;
    margin: 4px;
}

button:hover {
    background: rgba(203, 166, 247, 0.2);
}
```

## Wallpaper Yönetimi

### Yeni Wallpaper Ekleme

```bash
# Wallpaper'ı kopyala
cp ~/Downloads/new-wallpaper.jpg ~/Pictures/Wallpapers/

# Matugen'ı çalıştır
matugen image ~/Pictures/Wallpapers/new-wallpaper.jpg

# Wallpaper'ı ayarla
awww img ~/Pictures/Wallpapers/new-wallpaper.jpg --transition-type any
```

### Otomatik Wallpaper Değiştirme

Cron job ekle:

```bash
crontab -e

# Her saat değiştir
0 * * * * WALLPAPER=$(find ~/Pictures/Wallpapers -type f | shuf -n 1) && awww img "$WALLPAPER" && matugen image "$WALLPAPER"
```

## Performans İyileştirmeleri

### Startup Süresini Azaltma

```bash
# Boot süresini analiz et
systemd-analyze

# En yavaş servisleri göster
systemd-analyze blame

# Gereksiz servisleri devre dışı bırak
sudo systemctl disable unnecessary-service
```

### RAM Kullanımını Azaltma

```bash
# En çok RAM kullanan process'leri göster
ps aux --sort=-%mem | head -20

# Zram'ı kontrol et
zramctl

# Swap kullanımını kontrol et
free -h
```

## İpuçları ve Püf Noktaları

### Hızlı Erişim

```bash
# Dotfiles'ı düzenle
edconf

# Install script'i düzenle
edinstall

# Config dizinine git
cd $programs

# Dotfiles dizinine git
cd $DOTFILES
```

### Backup ve Restore

```bash
# Config backup
tar -czf ~/config-backup-$(date +%Y%m%d).tar.gz ~/.config

# Restore
tar -xzf ~/config-backup-20260607.tar.gz -C ~/
```

### Multi-Monitor Setup

```bash
# Monitor'ları listele
hyprctl monitors

# Workspace'leri monitor'lara ata
hyprctl keyword workspace 1,monitor:HDMI-A-1
hyprctl keyword workspace 2,monitor:DP-1
```
