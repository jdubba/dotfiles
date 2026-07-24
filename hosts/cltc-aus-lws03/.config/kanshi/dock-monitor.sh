#!/usr/bin/env bash
# Watch Hyprland monitor events and apply the LG TV dock layout when both TVs are
# present. This mirrors stationzebra's workaround for LG TVs with fake serials.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LG_DESC="LG TV SSCR2"
SETTLE_SECONDS=2
VERIFY_SECONDS=2
MAX_APPLY_ATTEMPTS=3

wait_for_socket() {
    local sock
    for _ in $(seq 1 30); do
        if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
            sock="/run/user/${UID}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
            [[ -S "$sock" ]] && { echo "$sock"; return; }
        else
            sock=$(ls /run/user/"${UID}"/hypr/*/.socket2.sock 2>/dev/null | sort | tail -1 || true)
            [[ -n "$sock" ]] && { echo "$sock"; return; }
        fi
        sleep 1
    done

    echo "dock-monitor: timed out waiting for Hyprland socket" >&2
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

    echo "dock-monitor: dock layout failed verification after ${MAX_APPLY_ATTEMPTS} attempts" >&2
    return 1
}

echo "dock-monitor: starting"

startup_done_for=""
layout_applied_for=""

while true; do
    sock=$(wait_for_socket)
    echo "dock-monitor: connected to $sock"

    if [[ "$startup_done_for" != "$sock" ]]; then
        startup_done_for="$sock"
        count=$(lg_count)
        echo "dock-monitor: startup check - ${count} LG TV(s) connected"
        if [[ "$count" -ge 2 ]]; then
            apply_layout_when_ready "startup" || true
        fi
    fi

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

    echo "dock-monitor: socket closed, waiting for Hyprland to restart"
    sleep 2
done
