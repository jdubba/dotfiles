#!/usr/bin/env bats
# swaync.bats - the generated-config seam for the notification daemon.
#
# swaync has no include mechanism and no runtime command to change its preferred
# output, so the monitor pin has to live in its config file -- and on the
# twin-LG dock that value is only knowable at runtime. The repo therefore ships
# a TEMPLATE and swaync-config.sh renders the real config into machine-local
# state, so a redock never writes into the repo. These tests pin that contract.

setup() { load test_helper; }

GEN() { printf '%s' "$DF_SRC_REPO/profiles/hyprland/.config/swaync/swaync-config.sh"; }
TPL() { printf '%s' "$DF_SRC_REPO/profiles/hyprland/.config/swaync/config.json.in"; }

# Run the generator against a throwaway HOME with the template linked in the
# place it expects, mirroring the real layout.
_gen_env() {
  DF_TMP="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/swaync.XXXXXX")"
  mkdir -p "$DF_TMP/.config/swaync"
  cp "$(TPL)" "$DF_TMP/.config/swaync/config.json.in"
  export HOME="$DF_TMP"
  export XDG_CONFIG_HOME="$DF_TMP/.config"
  export XDG_STATE_HOME="$DF_TMP/.local/state"
}

teardown() {
  [[ -n "${DF_TMP:-}" && -d "$DF_TMP" ]] && rm -rf "$DF_TMP"
  return 0
}

@test "swaync generator and template are present and executable" {
  [ -x "$(GEN)" ]
  [ -f "$(TPL)" ]
  bash -n "$(GEN)"
}

@test "the template keeps its placeholder rather than a hardcoded output" {
  # A hardcoded connector here would silently defeat the whole generated-config
  # design: the pin would come from the repo and a redock would fight it.
  grep -q '@DF_NOTIFY_OUTPUT@' "$(TPL)"
  ! grep -qE '"(notification-window|control-center)-preferred-output"[[:space:]]*:[[:space:]]*"(DP|eDP|HDMI)' \
    "$(TPL)"
}

@test "generator substitutes the pin from machine-local state" {
  _gen_env
  mkdir -p "$XDG_STATE_HOME/dotfiles/swaync"
  printf 'DP-7\n' >"$XDG_STATE_HOME/dotfiles/swaync/output"
  run "$(GEN)" --print
  [ "$status" -eq 0 ]
  [[ $output == *'"notification-window-preferred-output": "DP-7"'* ]]
  [[ $output == *'"control-center-preferred-output": "DP-7"'* ]]
  [[ $output != *'@DF_NOTIFY_OUTPUT@'* ]]
}

@test "no pin yields an empty output, which means 'compositor picks'" {
  # This is the fresh-machine and single-display case: valid config, unset pin.
  _gen_env
  run "$(GEN)" --print
  [ "$status" -eq 0 ]
  [[ $output == *'"notification-window-preferred-output": ""'* ]]
  [[ $output != *'@DF_NOTIFY_OUTPUT@'* ]]
}

@test "an implausible pin degrades to unset instead of corrupting the config" {
  # The value is interpolated into JSON and into a sed replacement, so a stray
  # quote would produce an unparseable config and a shell metacharacter would be
  # worse. Reject anything that is not a connector-shaped name.
  _gen_env
  mkdir -p "$XDG_STATE_HOME/dotfiles/swaync"
  printf '%s\n' 'DP-1"; rm -rf /' >"$XDG_STATE_HOME/dotfiles/swaync/output"
  run "$(GEN)" --print
  [ "$status" -eq 0 ]
  [[ $output == *'"notification-window-preferred-output": ""'* ]]
  [[ $output != *'rm -rf'* ]]
}

@test "generator writes the config into machine-local state, not the repo" {
  _gen_env
  run "$(GEN)"
  [ "$status" -eq 0 ]
  [ -f "$XDG_STATE_HOME/dotfiles/swaync/config.json" ]
  # Nothing may be written beside the template.
  [ ! -e "$XDG_CONFIG_HOME/swaync/config.json" ]
}

@test "generator fails loudly when the template is missing" {
  _gen_env
  rm "$XDG_CONFIG_HOME/swaync/config.json.in"
  run "$(GEN)" --print
  [ "$status" -ne 0 ]
  [[ $output == *"template not found"* ]]
}

@test "the swaync drop-in clears ExecStart before resetting it" {
  # A Type=dbus unit with two ExecStart= lines refuses to start, and systemd
  # APPENDS unless the list is cleared first -- so the bare `ExecStart=` is
  # load-bearing, not decoration.
  local d="$DF_SRC_REPO/profiles/hyprland/.config/systemd/user/swaync.service.d/dotfiles-config.conf"
  [ -f "$d" ]
  grep -qx 'ExecStart=' "$d"
  grep -q 'ExecStart=/usr/bin/swaync -c ' "$d"
  # and it must point at the generated file, not at ~/.config
  grep -q 'ExecStart=/usr/bin/swaync -c %S/dotfiles/swaync/config.json' "$d"
  # Guard-free: the dual-session condition belongs in the Fedora host layer.
  # Anchor to a real directive -- the comment in this file discusses
  # ConditionEnvironment by name, so an unanchored match hits the prose.
  ! grep -qE '^[[:space:]]*ConditionEnvironment=' "$d"
}

@test "swaync's stylesheet imports the waybar seam relatively" {
  # An absolute path here would embed one machine's home directory. GTK resolves
  # @import against the importing file's own path, and it does NOT canonicalise
  # the symlink, so a relative path reaches ~/.config/waybar/colors.css.
  local css="$DF_SRC_REPO/profiles/hyprland/.config/swaync/style.css"
  [ -f "$css" ]
  grep -q '@import url("../waybar/colors.css")' "$css"
  ! grep -qE '@import url\("(/home/|/root/)' "$css"
}

@test "swaync's stylesheet only uses colours the waybar seam defines" {
  # Same hazard as the waybar/walker seam tests: GTK silently DROPS a rule that
  # references an undefined @colour, so a typo here does not error -- it just
  # removes the styling. Check against a theme's real palette.
  local css="$DF_SRC_REPO/profiles/hyprland/.config/swaync/style.css"
  local seam="$DF_SRC_REPO/themes/nord/.config/waybar/colors.css"
  [ -f "$seam" ]
  local refs colour missing=""
  refs=$(grep -ho '@[a-z0-9-]*' "$css" | sed 's/^@//' \
         | grep -vxE 'import|define-color|keyframes|media|supports' | sort -u)
  [ -n "$refs" ]
  for colour in $refs; do
    grep -q "^@define-color[[:space:]]\+$colour[[:space:]]" "$seam" \
      || missing+=" $colour"
  done
  [ -z "$missing" ] || { echo "undefined in waybar seam:$missing"; false; }
}
