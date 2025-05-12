## Colorize the ls output ##
alias ls='ls --color=auto'

## Use a long listing format ##
alias ll='ls -lah --color=auto'

## Show hidden files ##
alias l.='ls -d .* --color=auto'

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

# Replace standard cat command
alias ocat='/usr/bin/cat'
alias cat='batcat'
