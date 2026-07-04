# ~/.zshenv - sourced for every zsh invocation (login, interactive, scripts).

# Shared environment (XDG dirs, EDITOR, PAGER, PATH, ...). Explicit path here
# because XDG_CONFIG_HOME is defined inside it.
[ -f "$HOME/.config/shell/env.sh" ] && source "$HOME/.config/shell/env.sh"

# zsh configuration directory
export ZDOTFILES="$XDG_CONFIG_HOME/zsh"

# Note: PATH additions live in shell/env.sh and are re-asserted from .zshrc,
# because /etc/zprofile -> /etc/profile.env can reset PATH on login shells
# after this file runs.
