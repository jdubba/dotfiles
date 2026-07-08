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

# Wait for the Hyprland socket to appear (service may start before compositor).
# Prefer HYPRLAND_INSTANCE_SIGNATURE (set in the session env) so we always
# connect to the current session rather than a stale leftover directory.
# Fall back to a glob that takes the last (newest) socket when the env var is
# absent — `head -1` would pick an older stale socket alphabetically first.
wait_for_socket() {
    local sock sig_dir
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

# Count how many LG TV monitors are currently connected
lg_count() {
    hyprctl monitors -j 2>/dev/null \
    | python3 -c "
import json, sys
mons = json.load(sys.stdin)
print(sum(1 for m in mons if '${LG_DESC}' in m.get('description', '')))
" 2>/dev/null || echo 0
}

echo "dock-monitor: starting"

# Track the last socket path for which we ran the startup check.
# hyprctl keyword monitor briefly closes the socket2 connection, which makes
# the python reader exit and causes us to "reconnect" to the same socket path.
# Without this guard that reconnect would re-trigger the startup check, running
# dock-layout.sh again, closing the socket again — an infinite loop.
startup_done_for=""

while true; do
    sock=$(wait_for_socket)
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
    while IFS= read -r line; do
        event="${line%%>>*}"
        # monitoradded fires once per monitor; wait until both LGs are present
        if [[ "$event" == "monitoradded" ]]; then
            count=$(lg_count)
            echo "dock-monitor: monitoradded — ${count} LG TV(s) connected"
            if [[ "$count" -ge 2 ]]; then
                # Brief settle time so both monitors finish initialising
                sleep 0.3
                echo "dock-monitor: applying dock layout"
                "$SCRIPT_DIR/dock-layout.sh" || echo "dock-monitor: dock-layout.sh failed (exit $?)" >&2
            fi
        fi
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

    echo "dock-monitor: socket closed, waiting for Hyprland to restart..."
    sleep 2
done
