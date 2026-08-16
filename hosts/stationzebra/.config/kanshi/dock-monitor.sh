#!/usr/bin/env bash
# dock-monitor.sh — Watch the Hyprland IPC event socket and apply the dock
# layout whenever both external LG TV monitors are connected.
#
# Run as a systemd user service (see dock-monitor.service).  Automatically
# reconnects when Hyprland restarts.  Uses python3 for the Unix socket read
# (socat/nc are not guaranteed to be installed).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LG_DESC="LG TV SSCR2"

# Resolve the *live* Hyprland instance; sets HYPR_SOCKET and re-exports
# HYPRLAND_INSTANCE_SIGNATURE.  Returns non-zero when no instance is up.
#
# The inherited HYPRLAND_INSTANCE_SIGNATURE is captured once, when this service
# starts, and is never refreshed afterwards.  `hyprland-session.target` stays
# active across a compositor restart, so `PartOf=` does not bounce this unit and
# the variable goes stale the moment Hyprland restarts.  A dead instance leaves
# its /run/user/$UID/hypr/<sig>/ directory — .socket2.sock inode included —
# behind, so a stale signature still "finds" a socket: every connect fails
# instantly and the daemon spins on reconnect forever without ever seeing a
# monitor event (observed wedged for 10 days, 2026-08-16).
#
# `hyprctl instances` enumerates only *live* instances, so trust it over the
# environment.  Exporting the result matters as much as using it here: every
# other hyprctl call, and dock-layout.sh, resolve their instance from this same
# variable, so all of them would otherwise still target the dead socket.
HYPR_SOCKET=""

resolve_instance() {
    local live sig
    live=$(hyprctl instances -j 2>/dev/null | python3 -c "
import json, sys
try:
    inst = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not inst:
    sys.exit(1)
# Newest first, so the fallback below picks the current session.
inst.sort(key=lambda i: i.get('time', 0), reverse=True)
print('\n'.join(i['instance'] for i in inst))
" 2>/dev/null) || return 1
    [[ -n "$live" ]] || return 1

    # Keep the inherited signature while it is still live; otherwise adopt the
    # newest instance.
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] \
       && grep -qxF "$HYPRLAND_INSTANCE_SIGNATURE" <<<"$live"; then
        sig="$HYPRLAND_INSTANCE_SIGNATURE"
    else
        sig=$(head -1 <<<"$live")
        echo "dock-monitor: instance signature stale or unset — adopting $sig" >&2
    fi

    export HYPRLAND_INSTANCE_SIGNATURE="$sig"
    HYPR_SOCKET="/run/user/${UID}/hypr/${sig}/.socket2.sock"
    [[ -S "$HYPR_SOCKET" ]]
}

# Wait for a live Hyprland instance (service may start before the compositor).
# Exiting on timeout is deliberate: systemd's Restart=on-failure/RestartSec=5
# then retries from a clean slate, which is the right behaviour when the
# compositor is down for longer than this window.
wait_for_socket() {
    for _ in $(seq 1 30); do
        resolve_instance && return 0
        sleep 1
    done
    echo "dock-monitor: timed out waiting for a live Hyprland instance" >&2
    exit 1
}

# Count how many LG TV monitors are currently connected
lg_count() {
    hyprctl monitors -j 2>/dev/null \
    | python3 -c "
import json, sys
mons = json.load(sys.stdin)
print(sum(1 for m in mons if '${LG_DESC}' in m.get('description', '')))
" 2>/dev/null || echo 0
}

# Is the dock layout (left TV, right TV, eDP-1 far right) actually in effect?
# `hyprctl reload` — which `dotfiles theme set` runs on every theme switch —
# re-applies local.conf, whose monitor rules deliberately use `auto` positions,
# so the layout silently reverts to eDP-1-leftmost until it is applied again.
layout_is_applied() {
    hyprctl monitors -j 2>/dev/null \
    | python3 -c "
import json, sys

mons = json.load(sys.stdin)
lg = sorted(
    (m for m in mons if '${LG_DESC}' in m.get('description', '')),
    key=lambda m: m['name'],
)
internal = next((m for m in mons if m.get('name') == 'eDP-1'), None)

ok = (
    len(lg) == 2
    and (lg[0].get('x'), lg[0].get('y')) == (-7680, 0)
    and (lg[1].get('x'), lg[1].get('y')) == (-3840, 0)
    and internal is not None
    and (internal.get('x'), internal.get('y')) == (0, 0)
)
sys.exit(0 if ok else 1)
" >/dev/null 2>&1
}

echo "dock-monitor: starting"

# Track the last socket path for which we ran the startup check.
# hyprctl keyword monitor briefly closes the socket2 connection, which makes
# the python reader exit and causes us to "reconnect" to the same socket path.
# Without this guard that reconnect would re-trigger the startup check, running
# dock-layout.sh again, closing the socket again — an infinite loop.
startup_done_for=""

# Consecutive reconnects that died almost immediately.  A healthy connection
# lives until Hyprland exits; a run of instant exits means we are talking to
# something that is not a working event socket, so back off instead of hammering
# it every 2s.
fast_exits=0

while true; do
    wait_for_socket
    sock="$HYPR_SOCKET"
    echo "dock-monitor: connected to $sock"

    # On the first connection to a given Hyprland session (new socket path),
    # check if both LG TVs are already present — the monitoradded events for
    # them fire before this service starts, so we would otherwise miss them on
    # login.  Skip for reconnections to the same socket (monitor-recfg bounce).
    if [[ "$startup_done_for" != "$sock" ]]; then
        startup_done_for="$sock"
        count=$(lg_count)
        echo "dock-monitor: startup check — ${count} LG TV(s) already connected"
        if [[ "$count" -ge 2 ]]; then
            sleep 0.3
            echo "dock-monitor: applying dock layout (startup)"
            "$SCRIPT_DIR/dock-layout.sh" || echo "dock-monitor: dock-layout.sh failed on startup (exit $?)" >&2
        fi
    fi

    # Read events line by line; python reader exits when the socket closes (Hyprland restart)
    connected_at=$SECONDS
    while IFS= read -r line; do
        event="${line%%>>*}"
        case "$event" in
            # monitoradded fires once per monitor; wait until both LGs are present
            monitoradded)
                count=$(lg_count)
                echo "dock-monitor: monitoradded — ${count} LG TV(s) connected"
                if [[ "$count" -ge 2 ]]; then
                    # Brief settle time so both monitors finish initialising
                    sleep 0.3
                    echo "dock-monitor: applying dock layout"
                    "$SCRIPT_DIR/dock-layout.sh" || echo "dock-monitor: dock-layout.sh failed (exit $?)" >&2
                fi
                ;;
            # A config reload (theme switch, `hyprctl reload`) throws the layout
            # back to local.conf's `auto` positions and drops the runtime
            # workspace pins, so put both back.  dock-layout.sh only issues
            # `keyword` commands, which do NOT emit configreloaded — no loop.
            configreloaded)
                count=$(lg_count)
                if [[ "$count" -ge 2 ]] && ! layout_is_applied; then
                    echo "dock-monitor: configreloaded reset the layout — re-applying"
                    "$SCRIPT_DIR/dock-layout.sh" || echo "dock-monitor: dock-layout.sh failed after reload (exit $?)" >&2
                fi
                ;;
        esac
    done < <(python3 -c "
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('${sock}')
while True:
    data = s.recv(4096)
    if not data:
        break
    sys.stdout.write(data.decode('utf-8', errors='replace'))
    sys.stdout.flush()
" 2>/dev/null || true)

    # Post-increment in (( )) evaluates to the *old* value, so `(( n++ ))` returns
    # status 1 on the first bump and `set -e` would kill the daemon — assign.
    if (( SECONDS - connected_at < 2 )); then
        fast_exits=$(( fast_exits + 1 ))
    else
        fast_exits=0
    fi

    backoff=2
    if (( fast_exits > 3 )); then
        backoff=$(( fast_exits * 5 ))
        if (( backoff > 60 )); then
            backoff=60
        fi
    fi

    echo "dock-monitor: socket closed, waiting for Hyprland to restart (retry in ${backoff}s)..."
    sleep "$backoff"
done
