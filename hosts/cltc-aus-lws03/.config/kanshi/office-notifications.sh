#!/usr/bin/env bash
# office-notifications.sh — pin swaync's notifications to the office dock's
# MIDDLE monitor.
#
# Run from the kanshi `docked` profile's exec. The office dock lays out
#   left  Dell P2422H CG4WYF3   at 0,0      workspaces 1-3
#   mid   Dell P2422H JQ5X7M3   at 1920,0   workspaces 4-6
#   eDP-1                       at 3840,0   workspaces 7-9
# and notifications belong on the middle screen here (the TV dock pins its LEFT
# TV instead — see dock-layout.sh).
#
# Why resolve a connector instead of letting swaync match the monitor by
# description: swaync's try_get_monitor() composes its descriptor as
# "manufacturer model description" from GDK, which is NOT the same as kanshi's
# "make model serial" and is not known to carry the serial. Two P2422H panels
# would therefore very likely produce the identical descriptor string and
# try_get_monitor would return whichever came first — silently the wrong screen
# half the time. Hyprland exposes `serial` as its own field, and the serials are
# already the identifiers this dock's kanshi profile trusts, so resolve the
# serial to a live connector and pin that.
# (The GDK reasoning is inference, not something tested on these panels; the
# serial route avoids having to care either way.)

set -euo pipefail

# Middle external, by EDID serial — stable across DP-* renumbering.
MIDDLE_SERIAL="JQ5X7M3"

pin="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/swaync-pin.sh"
[[ -x $pin ]] || exit 0

connector=$(
    hyprctl monitors -j \
    | python3 -c "
import json, sys
want = '${MIDDLE_SERIAL}'
for m in json.load(sys.stdin):
    if m.get('serial') == want:
        print(m['name'])
        break
"
)

if [[ -z $connector ]]; then
    # Not fatal: kanshi may have applied the profile a moment before Hyprland
    # finished bringing the output up, and a missing pin degrades to "compositor
    # picks" rather than to a broken config.
    echo "office-notifications: no monitor with serial $MIDDLE_SERIAL; leaving pin alone" >&2
    exit 0
fi

exec "$pin" "$connector"
