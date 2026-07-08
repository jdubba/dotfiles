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
HISTFILE="$XDG_STATE_HOME/bash/history"
[ -d "${HISTFILE%/*}" ] || mkdir -p "${HISTFILE%/*}"
HISTCONTROL=ignoreboth
HISTSIZE=100000
HISTFILESIZE=200000
shopt -s histappend

# Share history across concurrent sessions (bash equivalent of zsh
# SHARE_HISTORY): flush this session's new lines and import other sessions'
# before each prompt. Hooked via starship's precmd (which owns PROMPT_COMMAND),
# with a PROMPT_COMMAND fallback when starship isn't present.
_df_share_history() { history -a; history -n; }
if command -v starship >/dev/null 2>&1; then
    starship_precmd_user_func="_df_share_history"
else
    PROMPT_COMMAND="_df_share_history${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi

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
# dotfiles CLI completion (shared script; also loaded by zsh via bashcompinit)
# shellcheck source=/dev/null
[ -f "$HOME/.config/shell/completions/dotfiles.bash" ] && . "$HOME/.config/shell/completions/dotfiles.bash"

# ========================================
# Init Zoxide
# ========================================
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

# ========================================
# Fuzzy Finder keybindings
# ========================================
# Prefer `fzf --bash` (fzf >= 0.48 emits key-bindings + completion itself, so
# it's distro-agnostic). Fall back to sourcing the shipped scripts, whose
# location varies by distro (Gentoo/Arch: /usr/share/fzf/; Fedora:
# /usr/share/fzf/shell/; Debian/Ubuntu: /usr/share/doc/fzf/examples/).
if command -v fzf >/dev/null 2>&1; then
    if fzf --bash >/dev/null 2>&1; then
        eval "$(fzf --bash)"
    else
        for _fzf_src in \
            /usr/share/fzf/key-bindings.bash \
            /usr/share/fzf/completion.bash \
            /usr/share/fzf/shell/key-bindings.bash \
            /usr/share/fzf/shell/completion.bash \
            /usr/share/doc/fzf/examples/key-bindings.bash \
            /usr/share/doc/fzf/examples/completion.bash; do
            # shellcheck source=/dev/null
            [ -f "$_fzf_src" ] && . "$_fzf_src"
        done
        unset _fzf_src
    fi
fi

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
