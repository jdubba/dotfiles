# shellcheck shell=sh
# ~/.config/shell/aliases.sh - aliases shared by bash and zsh.
#
# POSIX alias syntax only, so both shells (and sh) can source it. Tool-specific
# aliases are guarded with `command -v`. Shell-specific completion tweaks (e.g.
# zsh's `compdef`) live in the per-shell config, not here.

# --- ls / eza -------------------------------------------------------------
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias ll='eza -lah --git --icons'
    alias l.='eza -d .* --git --icons'
    alias ld='eza --only-dirs --show-symlinks --git --icons'
    alias lf='eza --only-files --show-symlinks --git --icons'
    alias tree='eza --tree --icons'
else
    alias ls='ls --color=auto'
    alias ll='ls -lah --color=auto'
    alias l.='ls -d .* --color=auto'
    alias ld='echo "eza not installed"'
    alias lf='echo "eza not installed"'
fi

# --- cd / navigation ------------------------------------------------------
command -v zoxide >/dev/null 2>&1 && alias cd='z'
alias c='clear && fastfetch'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../../'

# --- grep / disk ----------------------------------------------------------
if command -v rg >/dev/null 2>&1; then
    alias grep='rg --color=auto'
else
    alias grep='grep --color=auto'
fi
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias df='df -h'

# --- ping -----------------------------------------------------------------
alias ping='ping -c 5'
alias fastping='ping -c 100 -s.2'

# --- tools ----------------------------------------------------------------
alias k='kubectl'
alias kssh='kitten ssh'
alias vim='nvim'
alias y='claude --prompt'
alias x='xdg-open'
alias alo='aws sso login --profile '
alias es='equery list -p '

# --- git ------------------------------------------------------------------
alias gst='git status'
alias ga='git add'
alias gaa='git add .'
alias gco='git checkout'
alias gcm='git commit -m'

# --- cat / bat ------------------------------------------------------------
alias ocat='/usr/bin/cat'
if command -v bat >/dev/null 2>&1; then
    alias cat='bat'
elif command -v batcat >/dev/null 2>&1; then
    alias cat='batcat'
fi

# --- hypr ---
alias hc='hyprctl'
alias hp='hyprctl hyprpaper'
alias hl='hyprlock'
