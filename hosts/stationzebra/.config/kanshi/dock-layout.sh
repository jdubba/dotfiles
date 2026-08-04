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
# Left TV -> 1,2,3   middle TV -> 4,5,6   eDP-1 (far right) -> 7,8,9,10.
LEFT_WORKSPACES=(1 2 3)
RIGHT_WORKSPACES=(4 5 6)
# Workspaces 7-10 are pinned to eDP-1 via persistent Hyprland workspace rules in
# local.conf (stable connector name); no runtime move needed here.

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

# --- apply monitor geometry (eDP-1 sits to the right of both TVs) ---
# Hyprland currently keeps eDP-1 anchored at 0x0 despite accepting a positive
# runtime position.  Anchor the equivalent layout there and place the TVs left
# of it instead.
hyprctl keyword monitor "$left,3840x2160@30,-7680x0,1"
hyprctl keyword monitor "$right,3840x2160@30,-3840x0,1"

# --- pin the TV workspaces (mirrors the persistent rules local.conf uses for
#     eDP-1; the TVs need the runtime connector names, see header) ---
pin_workspaces() {
    local target="$1"
    shift
    local cmds="" ws
    for ws in "$@"; do
        cmds="${cmds}keyword workspace ${ws}, monitor:${target}, persistent:true;"
    done
    hyprctl --batch "$cmds"
}

pin_workspaces "$left"  "${LEFT_WORKSPACES[@]}"
pin_workspaces "$right" "${RIGHT_WORKSPACES[@]}"

# --- pin notifications to the left TV (the primary screen for this dock) ---
# swaync has no runtime output command and no include mechanism, so the
# preferred output lives in its config file. This cannot be a static config
# value for the same reason the workspace pins above cannot: both TVs ship one
# EDID with a placeholder serial, so only the live connector name can name them.
#
# Write the connector to machine-local state and let swaync-config.sh render the
# tracked template over it, rather than editing a config in place. The config
# swaync actually reads lives under $XDG_STATE_HOME, so a redock never touches
# the repo -- which it would if the config were a symlink into it.
#
# swaync-client -R is enough to pick it up: notificationWindow.vala nulls its
# cached static monitor_name whenever the preferred output changes.
pin_notifications() {
    local target="$1"
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/swaync"
    local generator="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/swaync-config.sh"

    command -v swaync-client >/dev/null 2>&1 || return 0
    [[ -x $generator ]] || return 0

    mkdir -p "$state_dir"
    printf '%s\n' "$target" >"$state_dir/output"

    "$generator" || return 0
    echo "dock-layout: notifications pinned to $target"
    swaync-client -R -sw >/dev/null 2>&1 || true
}

pin_notifications "$left"

# --- and relocate any that already exist elsewhere ---
"$(dirname "$0")/move-workspaces.sh" "$left"  "${LEFT_WORKSPACES[@]}"
"$(dirname "$0")/move-workspaces.sh" "$right" "${RIGHT_WORKSPACES[@]}"

echo "dock-layout: done"

# Restart waybar so it enumerates all three outputs at their final geometry.
# Without this, waybar starts when monitors are still in their initial
# (potentially wrong-position) state and misses outputs that weren't ready —
# leaving one monitor with no bar.  Brief delay lets the compositor settle
# before waybar queries available outputs.
{ sleep 1 && systemctl --user restart waybar.service; } &
