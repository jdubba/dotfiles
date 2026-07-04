# ========================================
# History
# ========================================
HISTFILE="$XDG_STATE_HOME/zsh/history"
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
# PATH (set here after /etc/zsh/zprofile may have wiped it for login shells)
# ========================================
export PATH="$PATH:$XDG_BIN_HOME:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.opencode/bin:$HOME/.local/app/azure-cli/bin"

# ========================================
# Init Zoxide
# ========================================
eval "$(zoxide init zsh)"


# ========================================
# Completion
# ========================================
autoload -Uz compinit && compinit
autoload -Uz bashcompinit && bashcompinit

compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

if command -v aws_completer >/dev/null 2>&1; then
    complete -C aws_completer aws
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matche-list 'm:{a-z}={A-Za-z}'



# ========================================
# Fuzzy Finder
# ========================================
# source /usr/share/fzf/shell/key-bindings.zsh
source /usr/share/fzf/key-bindings.zsh
source <(fzf --zsh)



# ========================================
# Modular Config Files
# ========================================
source "$XDG_CONFIG_HOME/zsh/fzf.zsh"
source "$XDG_CONFIG_HOME/zsh/aliases.zsh"
source "$XDG_CONFIG_HOME/zsh/bindings.zsh"
source "$XDG_CONFIG_HOME/zsh/plugins.zsh"
source "$XDG_CONFIG_HOME/zsh/prompt.zsh"

cd $HOME 

clear && fastfetch
