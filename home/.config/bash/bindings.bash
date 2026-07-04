# shellcheck shell=bash
# ~/.config/bash/bindings.bash - readline keybindings (mirrors zsh/bindings.zsh).
#
# `bind` only affects interactive shells; .bashrc sources this after its
# interactivity guard.

# Up / Down: search history for entries matching the current line prefix.
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Ctrl+Right / Ctrl+Left: move by word.
bind '"\e[1;5C": forward-word'
bind '"\e[1;5D": backward-word'
