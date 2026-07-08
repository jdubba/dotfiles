#!/usr/bin/env bash
# dock-layout.sh — Apply the dual-external-monitor layout for stationzebra.
#
# The dock exposes two LG TV SSCR2 displays via a DP MST hub.  Both TVs have
# identical EDIDs (LG ships 0x01010101 as a placeholder serial), so they cannot
# be told apart by description.  However, the MST hub always enumerates its
# downstream ports in the same physical order, meaning the lower-numbered DP
# connector is always the left TV and the higher-numbered one is always the
# right TV — regardless of what the actual numbers are after a redock.
#
# This script finds those two monitors, sorts by connector name, and applies
# the layout via hyprctl so kanshi (which uses static connector names) is not
# needed for the dock profile.

set -euo pipefail

LG_DESC="LG TV SSCR2"
LEFT_WORKSPACES=(1 2 3)
RIGHT_WORKSPACES=(4 5 6)
# Workspaces 7 and 8 are pinned to eDP-1 via persistent Hyprland workspace
# rules in local.conf; no runtime move needed here.

# --- find the two LG TV connectors, sorted by name (= MST enumeration order) ---
mapfile -t lg_monitors < <(
    hyprctl monitors -j \
    | python3 -c "
import json, sys
mons = json.load(sys.stdin)
lg = [m['name'] for m in mons if '${LG_DESC}' in m.get('description', '')]
lg.sort()
print('\n'.join(lg))
"
)

if [[ ${#lg_monitors[@]} -ne 2 ]]; then
    echo "dock-layout: expected 2 LG TV monitors, found ${#lg_monitors[@]} — skipping" >&2
    exit 1
fi

left="${lg_monitors[0]}"
right="${lg_monitors[1]}"

echo "dock-layout: left=$left  right=$right"

# --- apply monitor geometry ---
hyprctl keyword monitor "$left,3840x2160@30,0x0,1"
hyprctl keyword monitor "$right,3840x2160@30,3840x0,1"
hyprctl keyword monitor "eDP-1,2560x1600@180,7680x0,1"

# --- move workspaces to LG TV outputs (runtime assignment; see local.conf for eDP-1) ---
"$(dirname "$0")/move-workspaces.sh" "$left"  "${LEFT_WORKSPACES[@]}"
"$(dirname "$0")/move-workspaces.sh" "$right" "${RIGHT_WORKSPACES[@]}"

echo "dock-layout: done"

# Restart waybar so it enumerates all three outputs at their final geometry.
# Without this, waybar starts when monitors are still in their initial
# (potentially wrong-position) state and misses outputs that weren't ready —
# leaving one monitor with no bar.  Brief delay lets the compositor settle
# before waybar queries available outputs.
{ sleep 1 && systemctl --user restart waybar.service; } &
