# Managed by the dots repo (~/.zshrc symlinks to zsh/.zshrc).
# Secrets go in untracked ~/.zshrc.local, never here.

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

if [ -f "$ZSH/oh-my-zsh.sh" ]; then
    source "$ZSH/oh-my-zsh.sh"
else
    echo "oh-my-zsh not found at $ZSH — install it: https://ohmyz.sh" >&2
fi

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt NO_CLOBBER

export PATH="$HOME/.opencode/bin:$PATH"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

export NVM_DIR="$HOME/.nvm"

# Lazy-load nvm: sourcing it eagerly costs hundreds of ms on every shell
# start. The stubs load the real thing on first use of nvm/node/npm/npx.
if [ -s "$NVM_DIR/nvm.sh" ]; then
    nvm() { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; nvm "$@"; }
    node() { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; node "$@"; }
    npm() { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; npm "$@"; }
    npx() { unset -f nvm node npm npx; source "$NVM_DIR/nvm.sh"; npx "$@"; }
fi
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

auu() {
    echo
    echo "==> Updating Fedora..."

    if command -v dnf >/dev/null 2>&1; then
        sudo dnf upgrade --refresh -y
    fi

    if command -v flatpak >/dev/null 2>&1; then
        echo
        echo "==> Updating Flatpak..."
        flatpak update -y
    fi

    if command -v snap >/dev/null 2>&1; then
        echo
        echo "==> Updating Snap..."
        sudo snap refresh
    fi

    if command -v fwupdmgr >/dev/null 2>&1; then
        echo
        echo "==> Checking firmware..."
        sudo fwupdmgr refresh
        sudo fwupdmgr update
    fi

    echo
    echo "==> System update complete."
}

if command -v envycontrol >/dev/null 2>&1; then
    alias gpu-off='sudo envycontrol -s integrated'
    alias gpu-on='sudo envycontrol -s hyprid'
fi

alias dnfup='sudo dnf upgrade --refresh'
alias remove='sudo dnf remove'
alias search='dnf search'
alias orphans='sudo dnf autoremove'
alias dnfclean='sudo dnf clean all'

alias fpup='flatpak update'
alias fpsearch='flatpak search'
alias fpinstalled='flatpak list'

alias c='clear'

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

mkcd() {
    mkdir -p "$1" && cd "$1"
}

alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

if command -v docker >/dev/null 2>&1; then
    alias dps='docker ps'
    alias dpsa='docker ps -a'
    alias di='docker images'
    alias dex='docker exec -it'
    alias dlogs='docker logs -f'
    alias dclean='docker system prune'

    dcu() {
        docker compose up -d "$@"
    }

    dcd() {
        docker compose down "$@"
    }

    dcl() {
        docker compose logs -f "$@"
    }
fi

if command -v kubectl >/dev/null 2>&1; then
    alias k='kubectl'
fi

alias hreload='hyprctl reload'
alias hmon='hyprctl monitors'
alias hwork='hyprctl workspaces'
alias hlayers='hyprctl layers'

alias ports='sudo ss -tulpn'
alias mem='free -h'
alias disk='df -h'
alias sysfailed='systemctl --failed'
alias syslogs='journalctl -p 3 -xb'
alias sd='sudo shutdown now'
alias re='sudo reboot'

extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi

    case "$1" in
        *.tar.gz|*.tgz)
            tar -xzf "$1"
            ;;
        *.tar.bz2)
            tar -xjf "$1"
            ;;
        *.tar.xz)
            tar -xJf "$1"
            ;;
        *.tar)
            tar -xf "$1"
            ;;
        *.zip)
            unzip "$1"
            ;;
        *.7z)
            7z x "$1"
            ;;
        *.rar)
            # 7z extracts rar; unrar lives in RPM Fusion nonfree, which this
            # repo never requires, so it is not a dependency.
            7z x "$1"
            ;;
        *)
            echo "Unsupported archive: $1"
            return 1
            ;;
    esac
}

alias zshconfig='nvim ~/.zshrc'
alias reloadzsh='source ~/.zshrc'

alias croot='cd /'
alias chome='cd ~'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

if command -v eza >/dev/null 2>&1; then
    alias ls='eza'
    alias ll='eza -lah --icons'
    alias la='eza -a --icons'
    alias lt='eza --tree --level=2 --icons'
fi

if command -v btop >/dev/null 2>&1; then
    alias bt='btop'
fi

if command -v fastfetch >/dev/null 2>&1; then
    alias ff='fastfetch'
fi

if [ -f "$HOME/.zshrc.local" ]; then
    source "$HOME/.zshrc.local"
fi
