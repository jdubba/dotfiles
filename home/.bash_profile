# ~/.bash_profile - executed for LOGIN bash shells.

# Shared environment first (also covers non-interactive login shells, which
# do not read ~/.bashrc).
# shellcheck source=/dev/null
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"

# Then the interactive configuration.
# shellcheck source=/dev/null
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
