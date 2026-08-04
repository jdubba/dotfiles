#!/usr/bin/env bash
# swaync-pin.sh — point swaync's notifications at a given output.
#
# The generic half of the monitor pin: record the connector in machine-local
# state, re-render the config from the tracked template, and tell swaync to
# re-read it. WHICH monitor to pin is per-host data and belongs to the caller —
# a dock script that has just worked out its layout, or a kanshi profile `exec`.
#
# Extracted because three callers need it: stationzebra's TV dock,
# cltc-aus-lws03's TV dock, and cltc-aus-lws03's office (Dell) kanshi profile.
#
# Usage:
#   swaync-pin.sh <connector>   pin to that output, e.g. DP-6, eDP-1
#   swaync-pin.sh --clear       unset the pin (compositor picks)
#
# Exits 0 and does nothing when swaync is not installed, so a host that has not
# adopted it — or a machine mid-install — does not fail its dock script.
#
# swaync-client -R is sufficient to move an ALREADY RUNNING daemon:
# notificationWindow.vala nulls its cached static monitor_name whenever the
# preferred output changes. Without that reset it would keep using the connector
# it first landed on.

set -euo pipefail

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"

STATE_DIR="$XDG_STATE_HOME/dotfiles/swaync"
GENERATOR="$XDG_CONFIG_HOME/swaync/swaync-config.sh"

die() { printf 'swaync-pin: %s\n' "$1" >&2; exit 1; }

target=${1-}
[[ -n $target ]] || die "usage: swaync-pin.sh <connector>|--clear"

if [[ $target == --clear ]]; then
    target=""
elif [[ ! $target =~ ^[A-Za-z0-9_-]+$ ]]; then
    # Reject early with a clear message rather than letting the generator
    # silently fall back to "unset" — a dock script passing a descriptor or an
    # empty variable by mistake should be loud, not mysteriously unpinned.
    die "implausible connector: ${target}"
fi

# Nothing to do if swaync is not on this machine.
command -v swaync-client >/dev/null 2>&1 || exit 0
[[ -x $GENERATOR ]] || exit 0

mkdir -p "$STATE_DIR"
printf '%s\n' "$target" >"$STATE_DIR/output"

"$GENERATOR" >/dev/null || die "generator failed"

printf 'swaync-pin: notifications pinned to %s\n' \
    "${target:-<compositor picks>}"

# Best-effort: the daemon may not be running yet (a dock script can fire before
# the session is fully up), in which case the ExecStartPre render will pick the
# new value up anyway.
swaync-client -R -sw >/dev/null 2>&1 || true
