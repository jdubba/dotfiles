#!/usr/bin/env bash
# Apply the dual-LG-TV dock layout for cltc-aus-lws03.
#
# Both LG TVs report the same fake serial, so their descriptions cannot identify
# left vs right. The dock enumerates the physical ports in connector-name order,
# so sort the matching DP connectors and lay them out left-to-right.

set -euo pipefail

LG_DESC="LG TV SSCR2"
LEFT_WORKSPACES=(1 2 3)
RIGHT_WORKSPACES=(4 5 6)

ensure_backlight_visible() {
    local current

    command -v brightnessctl >/dev/null 2>&1 || return 0
    current=$(brightnessctl -d intel_backlight get 2>/dev/null || true)
    [[ "$current" == 0 ]] || return 0

    brightnessctl -d intel_backlight set 50% >/dev/null 2>&1 || true
}

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
    echo "dock-layout: expected 2 LG TV monitors, found ${#lg_monitors[@]}" >&2
    exit 1
fi

left="${lg_monitors[0]}"
right="${lg_monitors[1]}"

echo "dock-layout: left=$left right=$right"

hyprctl keyword monitor "$left,3840x2160@30,0x0,1"
hyprctl keyword monitor "$right,3840x2160@30,3840x0,1"
hyprctl keyword monitor "eDP-1,1920x1200@60,7680x0,1"
ensure_backlight_visible

hyprctl --batch "keyword workspace 1, monitor:$left, persistent:true; keyword workspace 2, monitor:$left, persistent:true; keyword workspace 3, monitor:$left, persistent:true; keyword workspace 4, monitor:$right, persistent:true; keyword workspace 5, monitor:$right, persistent:true; keyword workspace 6, monitor:$right, persistent:true"

"$(dirname "$0")/move-workspaces.sh" "$left" "${LEFT_WORKSPACES[@]}"
"$(dirname "$0")/move-workspaces.sh" "$right" "${RIGHT_WORKSPACES[@]}"

echo "dock-layout: done"

{ sleep 1 && systemctl --user restart waybar.service; } &
