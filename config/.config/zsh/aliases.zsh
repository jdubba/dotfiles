if which eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias ll='eza -lah --git --icons'
    alias l.='eza -d .* --git --icons'
    alias ld='eza --only-dirs --show-symlinks --git --icons'
    alias lf='eza --only-files --show-symlinks --git --icons'
else 
  ## Colorize the ls output ##
  alias ls='ls --color=auto'

  ## Use a long listing format ##
  alias ll='ls -lah --color=auto'

  ## Show hidden files ##
  alias l.='ls -d .* --color=auto'

  ## Show only directories
  alias ld='echo "eza not installed"'
  alias lf='echo "eza not installed"'
fi

alias tree='eza --tree --icons'

# Reuse ls completions for eza
compdef eza=ls

# Alias cd to zoxide if installed
if which zoxide >/dev/null 2>&1; then
  alias cd='z'
fi

alias c='clear && fastfetch'

## get rid of command not found ##
alias cd..='cd ..'

## a quick way to get out of current directory ##
alias ..='cd ..'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../../'

## Colorize the grep command output for ease of use (good for log files)##
alias grep='rg --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias df='df -h'

# Stop after sending count ECHO_REQUEST packets #
alias ping='ping -c 5'

# Do not wait interval 1 second, go fast #
alias fastping='ping -c 100 -s.2'

# Easy kubectl
alias k=kubectl

# Kitten ssh for remote support of kitty term
alias kssh="kitten ssh"

# Git related aliases
alias gst='git status'
alias ga='git add'
alias gaa='git add .'
alias gco='git checkout'
alias gcm='git commit -m'

# Redirect vim to nvim
alias vim='nvim'

# Replace standard cat command
alias ocat='/usr/bin/cat'

# TODO:  Update install process to install/build latest bat with bat bin naming and remove this
#        alias logic caused by older bin name on current ubuntu based distros
if which bat &> /dev/null; then
    alias cat='bat'
else
    alias cat='batcat'
fi

# Simple AI chat
alias y='claude --prompt'

# XDG Open
alias x='xdg-open'

# AWS Profile login
alias alo='aws sso login --profile '

alias es='equery list -p '
