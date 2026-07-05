# shellcheck shell=sh
# ~/.config/shell/path.d/00-core.sh - core PATH additions (shared, universal).
#
# Sourced by env.sh, which defines _pathadd (append IFF the dir exists and is
# not already present). Keep entries additive and idempotent. Add per-platform
# or per-machine directories by dropping another *.sh fragment here from a
# profile or host layer, e.g. hosts/<hostname>/.config/shell/path.d/<name>.sh
# or profiles/<name>/.config/shell/path.d/<name>.sh - they merge into
# ~/.config/shell/path.d/ and are sourced in filename order.

_pathadd "$XDG_BIN_HOME"
_pathadd "$HOME/.local/bin"
_pathadd "$HOME/.cargo/bin"
_pathadd "$HOME/go/bin"
_pathadd "$HOME/.opencode/bin"
_pathadd "$HOME/.local/app/azure-cli/bin"
