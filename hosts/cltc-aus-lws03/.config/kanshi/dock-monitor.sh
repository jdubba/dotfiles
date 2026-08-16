#!/usr/bin/env bash
# Watch Hyprland monitor events and apply the LG TV dock layout when both TVs are
# present. This mirrors stationzebra's workaround for LG TVs with fake serials.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LG_DESC="LG TV SSCR2"
SETTLE_SECONDS=2
VERIFY_SECONDS=2
MAX_APPLY_ATTEMPTS=3

# Resolve the *live* Hyprland instance; sets HYPR_SOCKET and re-exports
# HYPRLAND_INSTANCE_SIGNATURE.  Returns non-zero when no instance is up.
#
# The inherited HYPRLAND_INSTANCE_SIGNATURE is captured once, when this service
# starts, and is never refreshed afterwards.  hyprland-session.target stays
# active across a compositor restart, so PartOf= does not bounce this unit and
# the variable goes stale the moment Hyprland restarts.  A dead instance leaves
# its /run/user/$UID/hypr/<sig>/ directory — .socket2.sock inode included —
# behind, so a stale signature still "finds" a socket: every connect fails
# instantly and the daemon spins on reconnect forever without ever seeing a
# monitor event.  Diagnosed on stationzebra 2026-08-16, where it had been
# wedged for ten days without the unit ever failing; this host carried the same
# code.
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

lg_count() {
    hyprctl monitors -j 2>/dev/null \
    | python3 -c "
import json, sys
mons = json.load(sys.stdin)
print(sum(1 for m in mons if '${LG_DESC}' in m.get('description', '')))
" 2>/dev/null || echo 0
}

lg_connector_key() {
    hyprctl monitors -j 2>/dev/null \
    | python3 -c "
import json, sys
mons = json.load(sys.stdin)
names = sorted(m['name'] for m in mons if '${LG_DESC}' in m.get('description', ''))
print(','.join(names))
" 2>/dev/null || true
}

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
    and lg[0].get('width') == 3840
    and lg[0].get('height') == 2160
    and abs(float(lg[0].get('refreshRate', 0)) - 30.0) < 0.1
    and lg[0].get('x') == 0
    and lg[0].get('y') == 0
    and lg[1].get('width') == 3840
    and lg[1].get('height') == 2160
    and abs(float(lg[1].get('refreshRate', 0)) - 30.0) < 0.1
    and lg[1].get('x') == 3840
    and lg[1].get('y') == 0
    and internal is not None
    and internal.get('x') == 7680
    and internal.get('y') == 0
)
sys.exit(0 if ok else 1)
" >/dev/null 2>&1
}

apply_layout_when_ready() {
    local reason="$1"
    local attempt connector_key count

    connector_key=$(lg_connector_key)
    if [[ -n "$layout_applied_for" && "$layout_applied_for" == "$connector_key" ]] \
        && layout_is_applied; then
        echo "dock-monitor: layout already applied (${reason})"
        return 0
    fi

    echo "dock-monitor: waiting ${SETTLE_SECONDS}s for dock outputs to settle (${reason})"
    sleep "$SETTLE_SECONDS"

    for ((attempt = 1; attempt <= MAX_APPLY_ATTEMPTS; attempt++)); do
        count=$(lg_count)
        if [[ "$count" -lt 2 ]]; then
            echo "dock-monitor: dock changed while settling; found ${count} LG TV(s)" >&2
            return 1
        fi

        connector_key=$(lg_connector_key)

        echo "dock-monitor: applying dock layout (${reason}, attempt ${attempt}/${MAX_APPLY_ATTEMPTS})"
        if ! "$SCRIPT_DIR/dock-layout.sh"; then
            echo "dock-monitor: dock-layout.sh failed (${reason}, attempt ${attempt})" >&2
        fi

        sleep "$VERIFY_SECONDS"
        if layout_is_applied; then
            layout_applied_for="$connector_key"
            echo "dock-monitor: dock layout verified (${reason})"
            return 0
        fi

        echo "dock-monitor: layout did not remain applied; retrying" >&2
    done

    # A long-running kanshi can retain stale output-management state after a
    # dock swap even though no profile matches. Restart it only after ordinary
    # retries fail, then make one final attempt with a fresh connection.
    if systemctl --user is-active --quiet kanshi.service; then
        echo "dock-monitor: restarting kanshi after repeated layout failures" >&2
        if systemctl --user restart kanshi.service; then
            sleep "$VERIFY_SECONDS"
            count=$(lg_count)
            if [[ "$count" -ge 2 ]]; then
                connector_key=$(lg_connector_key)
                echo "dock-monitor: applying dock layout after kanshi restart"
                if "$SCRIPT_DIR/dock-layout.sh"; then
                    sleep "$VERIFY_SECONDS"
                    if layout_is_applied; then
                        layout_applied_for="$connector_key"
                        echo "dock-monitor: dock layout verified after kanshi restart"
                        return 0
                    fi
                fi
            fi
        fi
    fi

    echo "dock-monitor: dock layout failed verification after ${MAX_APPLY_ATTEMPTS} attempts" >&2
    return 1
}

echo "dock-monitor: starting"

startup_done_for=""
layout_applied_for=""

# Consecutive reconnects that died almost immediately.  A healthy connection
# lives until Hyprland exits; a run of instant exits means we are talking to
# something that is not a working event socket, so back off instead of hammering
# it every 2s.
fast_exits=0

while true; do
    wait_for_socket
    sock="$HYPR_SOCKET"
    echo "dock-monitor: connected to $sock"

    if [[ "$startup_done_for" != "$sock" ]]; then
        startup_done_for="$sock"
        count=$(lg_count)
        echo "dock-monitor: startup check - ${count} LG TV(s) connected"
        if [[ "$count" -ge 2 ]]; then
            apply_layout_when_ready "startup" || true
        fi
    fi

    connected_at=$SECONDS
    while IFS= read -r line; do
        event="${line%%>>*}"
        case "$event" in
            monitoradded|monitoraddedv2)
                count=$(lg_count)
                echo "dock-monitor: ${event} - ${count} LG TV(s) connected"
                if [[ "$count" -ge 2 ]]; then
                    apply_layout_when_ready "${event}" || true
                fi
                ;;
            monitorremoved|monitorremovedv2)
                layout_applied_for=""
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

    echo "dock-monitor: socket closed, waiting for Hyprland to restart (retry in ${backoff}s)"
    sleep "$backoff"
done
