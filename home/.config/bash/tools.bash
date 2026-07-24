# shellcheck shell=bash
# ~/.config/bash/tools.bash - external tool integrations (mirrors zsh/plugins.zsh).

# --- NVM (node version manager) ------------------------------------------
# nvm itself is now loaded for BOTH shells from shell/interactive.sh (which runs
# before this file); only the bash-specific completion remains here.
if [ -n "${NVM_DIR:-}" ]; then
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
fi

# --- Azure CLI (optional local install; PATH is handled in shell/env.sh) --
if [ -f "$HOME/.local/app/azure-cli/bin/activate" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.local/app/azure-cli/bin/activate"
fi
