# ========================================
# History
# ========================================
HISTFILE="$XDG_STATE_HOME/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"   # ensure history dir (first-run safety)
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS


# ========================================
# Shell Behavior
# ========================================
setopt AUTOCD
setopt NOBEEP
setopt NUMERIC_GLOB_SORT


# ========================================
# PATH / env (re-source shared env because /etc/zprofile may have reset PATH
# for login shells after .zshenv ran; PATH additions in env.sh are idempotent)
# ========================================
[ -f "$HOME/.config/shell/env.sh" ] && source "$HOME/.config/shell/env.sh"

# ========================================
# Init Zoxide
# ========================================
eval "$(zoxide init zsh)"


# ========================================
# Completion
# ========================================
autoload -Uz compinit && compinit
autoload -Uz bashcompinit && bashcompinit

[[ -d "$XDG_CACHE_HOME/zsh" ]] || mkdir -p "$XDG_CACHE_HOME/zsh"   # ensure compdump dir (first-run safety)
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

if command -v aws_completer >/dev/null 2>&1; then
    complete -C aws_completer aws
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matche-list 'm:{a-z}={A-Za-z}'

# Reuse ls completions for eza (the `eza` alias is defined in shell/aliases.sh)
compdef eza=ls



# ========================================
# Fuzzy Finder
# ========================================
# source /usr/share/fzf/shell/key-bindings.zsh
source /usr/share/fzf/key-bindings.zsh
source <(fzf --zsh)



# ========================================
# Modular Config Files
# ========================================
# Shared core (also used by bash)
[ -f "$XDG_CONFIG_HOME/shell/aliases.sh" ]     && source "$XDG_CONFIG_HOME/shell/aliases.sh"
[ -f "$XDG_CONFIG_HOME/shell/interactive.sh" ] && source "$XDG_CONFIG_HOME/shell/interactive.sh"

# zsh-specific
source "$XDG_CONFIG_HOME/zsh/fzf.zsh"
source "$XDG_CONFIG_HOME/zsh/bindings.zsh"
source "$XDG_CONFIG_HOME/zsh/plugins.zsh"
source "$XDG_CONFIG_HOME/zsh/prompt.zsh"

cd $HOME 

clear && fastfetch
