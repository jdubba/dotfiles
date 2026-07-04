#!/usr/bin/env bash
# ~/.bashrc - interactive bash configuration.
#
# Structure mirrors ~/.zshrc. Environment lives in ~/.config/shell/env.sh and
# aliases/EXTERNAL_IP in ~/.config/shell/*, shared with zsh. Bash-specific
# pieces live in ~/.config/bash/*.bash.

# If not running interactively, don't do anything.
case $- in
    *i*) ;;
      *) return;;
esac

# ========================================
# ble.sh  (must load near the top; attached at the very end)
# ========================================
if [ -f "$HOME/.local/share/blesh/ble.sh" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.local/share/blesh/ble.sh" --noattach
fi

# ========================================
# Environment (shared with zsh)
# ========================================
# shellcheck source=/dev/null
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"

# ========================================
# History
# ========================================
HISTCONTROL=ignoreboth
HISTSIZE=100000
HISTFILESIZE=200000
shopt -s histappend

# ========================================
# Shell Behavior
# ========================================
shopt -s checkwinsize
shopt -s globstar

# ========================================
# Completion
# ========================================
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        # shellcheck source=/dev/null
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        # shellcheck source=/dev/null
        . /etc/bash_completion
    fi
fi
# shellcheck source=/dev/null
[ -f "$HOME/.git-completion.bash" ] && . "$HOME/.git-completion.bash"
command -v aws_completer >/dev/null 2>&1 && complete -C aws_completer aws

# ========================================
# Init Zoxide
# ========================================
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

# ========================================
# Fuzzy Finder keybindings
# ========================================
# shellcheck source=/dev/null
[ -f /usr/share/fzf/key-bindings.bash ] && . /usr/share/fzf/key-bindings.bash
# shellcheck source=/dev/null
[ -f /usr/share/fzf/completion.bash ] && . /usr/share/fzf/completion.bash

# ========================================
# Modular Config Files (shared core + bash-specific)
# ========================================
for _df_mod in \
    "$HOME/.config/shell/aliases.sh" \
    "$HOME/.config/shell/interactive.sh" \
    "$HOME/.config/bash/fzf.bash" \
    "$HOME/.config/bash/bindings.bash" \
    "$HOME/.config/bash/tools.bash" \
    "$HOME/.config/bash/prompt.bash"; do
    # shellcheck source=/dev/null
    [ -f "$_df_mod" ] && . "$_df_mod"
done
unset _df_mod

# ========================================
# Startup
# ========================================
cd ~ || return
clear && fastfetch

# ========================================
# Attach ble.sh (must be the last thing)
# ========================================
[[ ${BLE_VERSION-} ]] && ble-attach
