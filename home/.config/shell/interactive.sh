# shellcheck shell=sh
# ~/.config/shell/interactive.sh - shared setup for INTERACTIVE shells only.
#
# Sourced from .bashrc and .zshrc (not from env.sh / .zshenv), so scripts and
# non-interactive shells never pay for it.

# External IP, exported for the starship [custom.externalip] module, whose
# command is `printf $EXTERNAL_IP`. Exporting it here (rather than only in
# bash, as before) is what makes the module render under zsh too.
#
# --max-time keeps a down network from hanging shell startup.
export EXTERNAL_IP
if command -v curl >/dev/null 2>&1; then
    EXTERNAL_IP=$(curl -s --max-time 2 https://ipinfo.io/ip)
    [ -n "$EXTERNAL_IP" ] || EXTERNAL_IP="unknown"
else
    EXTERNAL_IP="unknown"
fi

# --- NVM (node version manager) ------------------------------------------
# Both shells load nvm here: bash's own copy in .config/bash/tools.bash predates
# this file and zsh had none at all. It belongs in an interactive-only file --
# nvm.sh defines ~20 functions and prepends to PATH, which env.sh must not do
# because .zshenv sources it for EVERY zsh, including scripts.
# Prefer the distro-packaged init; otherwise use the standard ~/.nvm layout.
if [ -f /usr/share/nvm/init-nvm.sh ]; then
    # shellcheck source=/dev/null
    . /usr/share/nvm/init-nvm.sh
elif [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi

# OpenCode copies selections with OSC 52. Inside tmux it wraps the sequence in
# passthrough, so permit that only in the pane and only while OpenCode runs.
opencode() (
    if [ -z "${TMUX-}" ] || [ -z "${TMUX_PANE-}" ]; then
        command opencode "$@"
        return
    fi

    _oc_pane=$TMUX_PANE
    _oc_prior=$(command tmux show-options -p -v -t "$_oc_pane" \
        allow-passthrough) || return

    _oc_restore_passthrough() {
        if [ -n "$_oc_prior" ]; then
            command tmux set-option -p -t "$_oc_pane" \
                allow-passthrough "$_oc_prior"
        else
            command tmux set-option -p -u -t "$_oc_pane" allow-passthrough
        fi
    }

    command tmux set-option -p -t "$_oc_pane" allow-passthrough on || return

    trap '_oc_restore_passthrough' 0
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 131' QUIT
    trap 'exit 143' TERM

    command opencode "$@"
    _oc_status=$?

    trap - 0 HUP INT QUIT TERM
    _oc_restore_passthrough
    return "$_oc_status"
)
