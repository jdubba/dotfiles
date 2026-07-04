# shellcheck shell=sh
# ~/.profile - executed for login shells by POSIX sh and by display/login
# managers. (Bash login shells use ~/.bash_profile instead.)

# Shared environment.
# shellcheck source=/dev/null
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"

# If this happens to be bash, load the interactive configuration.
if [ -n "${BASH_VERSION-}" ] && [ -f "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.bashrc"
fi
