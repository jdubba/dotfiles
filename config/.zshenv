# ----- XDG BASE DIRECTORIES -----
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_BIN_HOME="$HOME/.local/bin"

# ----- ZSH -----
export ZDOTFILES="$XDG_CONFIG_HOME/zsh"

# ----- EDITOR -----
export EDITOR="nvim"
export VISUAL="nvim"

# ----- GPG -----
export GPG_TTY=$(tty)

# ----- PATH -----
# User bin installs
export PATH=$PATH:$XDG_BIN_HOME:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.opencode/bin:$HOME/.local/app/azure-cli/bin

# ----- PAGER -----
if command -v bat >/dev/null 2>&1;then
    export MANPAGER="bat -l man -p"
elif comman -v batcat >/dev/null 2>&1; then
    export MANPAGER="batcat -l man -p"
fi
