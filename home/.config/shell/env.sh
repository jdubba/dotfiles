# shellcheck shell=sh
# ~/.config/shell/env.sh - environment shared by all shells (bash, zsh, sh).
#
# Sourced early: from .zshenv (every zsh), and from bash's .bash_profile /
# .profile / .bashrc. Keep it POSIX-compatible and free of side effects
# (no network calls, no prompt setup) so it is safe to source anywhere,
# including non-interactive shells and scripts.
#
# It is also intentionally idempotent: PATH is rebuilt with a guard so that
# re-sourcing (e.g. from .zshrc after a login /etc/zprofile resets PATH) does
# not create duplicates.

# --- XDG base directories -------------------------------------------------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"

# --- Editor ---------------------------------------------------------------
export EDITOR="nvim"
export VISUAL="nvim"

# --- GPG ------------------------------------------------------------------
GPG_TTY=$(tty 2>/dev/null) && export GPG_TTY

# --- Pager (prefer bat, fall back to batcat on Debian-ish systems) --------
if command -v bat >/dev/null 2>&1; then
    export MANPAGER="bat -l man -p"
elif command -v batcat >/dev/null 2>&1; then
    export MANPAGER="batcat -l man -p"
fi

# --- Colored GCC diagnostics ----------------------------------------------
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# --- Wayland hint for kitty -----------------------------------------------
export KITTY_ENABLE_WAYLAND=1

# --- PATH (idempotent; append only if the dir exists and is not present) ---
_pathadd() {
    case ":$PATH:" in
        *":$1:"*) : ;;                       # already present
        *) [ -d "$1" ] && PATH="$PATH:$1" ;;
    esac
}
_pathadd "$XDG_BIN_HOME"
_pathadd "$HOME/.local/bin"
_pathadd "$HOME/.cargo/bin"
_pathadd "$HOME/go/bin"
_pathadd "$HOME/.opencode/bin"
_pathadd "$HOME/.local/app/azure-cli/bin"
export PATH
unset -f _pathadd
