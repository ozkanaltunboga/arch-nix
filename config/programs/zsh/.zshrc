# ============================================================
# .zshrc — CachyOS / Arch Linux
# zsh/default.nix Home Manager modülünden dönüştürüldü
# ============================================================

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# ─── Geçmiş ─────────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS

# ─── Tamamlama ───────────────────────────────────────────────
autoload -Uz compinit && compinit

# ─── Ortam değişkenleri ──────────────────────────────────────
export DOTFILES="$HOME/dotfiles"
export hypr="$HOME/.config/hypr"
export programs="$HOME/.config"
export EDITOR="nvim"
export VISUAL="nvim"
export PATH="$HOME/.local/bin:$PATH"

# Wayland
export NIXOS_OZONE_WL=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland,x11

# ─── Aliases ─────────────────────────────────────────────────
alias edit='sudo -E nvim -n'
alias update='paru -Syu'
alias stop='shutdown now'
alias out='loginctl terminate-user $USER'

# Dotfiles düzenleme
alias edconf='$EDITOR $DOTFILES/config/sessions/hyprland/hyprland.conf'
alias edinstall='$EDITOR $DOTFILES/install.sh'

# SSH key (kendi anahtar yolunuzu güncelleyin)
alias gitavail='ssh-add $HOME/Documents/keys/github_key'

# ─── Ek fonksiyonlar ─────────────────────────────────────────
source "$HOME/.config/hypr/../../../dotfiles/config/programs/zsh/zsh-init.sh" 2>/dev/null \
    || source "${DOTFILES:-$HOME/dotfiles}/config/programs/zsh/zsh-init.sh" 2>/dev/null \
    || true
