#!/bin/bash

# Update ls aliases based on eza installation status
if which eza >/dev/null 2>&1; then
    alias ls='eza --git'
    alias ll='eza -lah --git'
    alias l.='eza -d .* --git'
    alias ld='eza --only-dirs --show-symlinks --git'
    alias lf='eza --only-files --show-symlinks --git'
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

# Alias cd to zoxide if installed
if which zoxide >/dev/null 2>&1; then
  alias cd='z'
fi

alias c='clear && fastfetch'

## get rid of command not found ##
alias cd..='cd ..'

## a quick way to get out of current directory ##
alias ..='cd ..'
alias ...='cd ../../../'
alias ....='cd ../../../../'
alias .....='cd ../../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'

## Colorize the grep command output for ease of use (good for log files)##
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

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
alias vim='/usr/bin/nvim'

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
alias y='yai -c'

# AWS Profile login
alias alo='aws sso login --profile '
