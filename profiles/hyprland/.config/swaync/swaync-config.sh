#!/usr/bin/env bash
# swaync-config.sh — generate swaync's machine-local config from the tracked
# template.
#
# Why a generated config at all: swaync has no include mechanism and no runtime
# command to change its preferred output, so the monitor pin has to live in the
# config file. On the twin-LG dock that value is only knowable at runtime (both
# TVs ship one EDID with a placeholder serial, so only their live connector
# names can order them), which means something has to rewrite the config on
# every redock. If the config were a symlink into the repo, each redock would be
# tracked-file churn — so the repo ships a template and this writes the real
# file into machine-local state instead.
#
#   ~/.config/swaync/config.json.in                  template (tracked, layered)
#   $XDG_STATE_HOME/dotfiles/swaync/output           pin, written by dock-layout.sh
#   $XDG_STATE_HOME/dotfiles/swaync/config.json      generated; passed via `-c`
#
# Run by swaync.service's ExecStartPre drop-in, and again by dock-layout.sh
# after a redock (followed by `swaync-client -R`).
#
# Usage: swaync-config.sh [--print]
#   --print  write to stdout instead of the state file (for tests/inspection)

set -euo pipefail

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"

TEMPLATE="$XDG_CONFIG_HOME/swaync/config.json.in"
STATE_DIR="$XDG_STATE_HOME/dotfiles/swaync"
OUTPUT_FILE="$STATE_DIR/output"
CONFIG="$STATE_DIR/config.json"

die() { printf 'swaync-config: %s\n' "$1" >&2; exit 1; }

[[ -f $TEMPLATE ]] || die "template not found: $TEMPLATE"

# The pin is optional. Absent or empty means "let the compositor pick", which is
# correct for a single-display host and is what a fresh machine gets before any
# dock script has run.
notify_output=""
if [[ -r $OUTPUT_FILE ]]; then
    # Trim whitespace; ignore anything that is not a plausible connector name so
    # a corrupt state file degrades to "unset" rather than to an invalid config.
    read -r notify_output <"$OUTPUT_FILE" || true
    if [[ -n $notify_output && ! $notify_output =~ ^[A-Za-z0-9_-]+$ ]]; then
        printf 'swaync-config: ignoring implausible output %q\n' \
            "$notify_output" >&2
        notify_output=""
    fi
fi

# Substitution is a plain literal replace. The value is validated above, so it
# cannot contain a sed metacharacter or a quote that would break the JSON.
render() { sed "s|@DF_NOTIFY_OUTPUT@|${notify_output}|g" "$TEMPLATE"; }

if [[ ${1:-} == --print ]]; then
    render
    exit 0
fi

mkdir -p "$STATE_DIR"
# Write via a temp file in the same directory and rename, so swaync can never
# read a half-written config (it re-reads on SIGHUP/`-R`).
tmp=$(mktemp "$CONFIG.XXXXXX")
trap 'rm -f "$tmp"' EXIT
render >"$tmp"
mv -f "$tmp" "$CONFIG"
trap - EXIT

printf 'swaync-config: wrote %s (output=%s)\n' \
    "$CONFIG" "${notify_output:-<compositor picks>}"
