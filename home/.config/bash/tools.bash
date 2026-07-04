# shellcheck shell=bash
# ~/.config/bash/tools.bash - external tool integrations (mirrors zsh/plugins.zsh).

# --- NVM (node version manager) ------------------------------------------
# Prefer the distro-packaged init; otherwise use the standard ~/.nvm layout.
if [ -f /usr/share/nvm/init-nvm.sh ]; then
    # shellcheck source=/dev/null
    . /usr/share/nvm/init-nvm.sh
elif [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
fi

# --- Azure CLI (optional local install; PATH is handled in shell/env.sh) --
if [ -f "$HOME/.local/app/azure-cli/bin/activate" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.local/app/azure-cli/bin/activate"
fi
