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

PIN() { printf '%s' "$DF_SRC_REPO/profiles/hyprland/.config/swaync/swaync-pin.sh"; }

# swaync-pin.sh deliberately no-ops when swaync-client is absent, so a host that
# has not installed swaync does not fail its dock script. CI has no swaync, so
# stub the client (and put the real generator + template where it expects them).
_pin_env() {
  _gen_env
  cp "$(GEN)" "$XDG_CONFIG_HOME/swaync/swaync-config.sh"
  chmod +x "$XDG_CONFIG_HOME/swaync/swaync-config.sh"
  mkdir -p "$DF_TMP/bin"
  printf '#!/bin/sh\nexit 0\n' >"$DF_TMP/bin/swaync-client"
  chmod +x "$DF_TMP/bin/swaync-client"
  export PATH="$DF_TMP/bin:$PATH"
}

@test "swaync-pin.sh records a connector and renders the config" {
  _pin_env
  run "$(PIN)" DP-6
  [ "$status" -eq 0 ]
  [ "$(cat "$XDG_STATE_HOME/dotfiles/swaync/output")" = "DP-6" ]
  grep -q '"notification-window-preferred-output": "DP-6"' \
    "$XDG_STATE_HOME/dotfiles/swaync/config.json"
}

@test "swaync-pin.sh --clear unsets the pin" {
  _pin_env
  "$(PIN)" DP-6
  run "$(PIN)" --clear
  [ "$status" -eq 0 ]
  grep -q '"notification-window-preferred-output": ""' \
    "$XDG_STATE_HOME/dotfiles/swaync/config.json"
}

@test "swaync-pin.sh rejects a descriptor or empty target loudly" {
  # A caller passing a description ("Dell Inc. DELL P2422H ...") or an unset
  # variable should fail visibly, not silently leave notifications unpinned.
  _pin_env
  run "$(PIN)" "Dell Inc. DELL P2422H JQ5X7M3"
  [ "$status" -ne 0 ]
  [[ $output == *"implausible connector"* ]]
  run "$(PIN)"
  [ "$status" -ne 0 ]
  [[ $output == *"usage"* ]]
}

@test "swaync-pin.sh is a silent no-op where swaync is not installed" {
  # A host that has not installed swaync must not fail its dock script.
  # This has to be a HERMETIC path: simply prepending an empty dir and keeping
  # /usr/bin still finds the real swaync-client on a machine that has it (which
  # is exactly how this test first passed for the wrong reason). Populate a
  # sandbox bin with only the tools the script needs.
  _gen_env
  cp "$(GEN)" "$XDG_CONFIG_HOME/swaync/swaync-config.sh"
  chmod +x "$XDG_CONFIG_HOME/swaync/swaync-config.sh"
  mkdir -p "$DF_TMP/bin"
  local t
  # bash included because the shebang is `#!/usr/bin/env bash`.
  for t in bash sh mkdir sed mktemp mv rm cat env; do
    ln -sf "$(command -v "$t")" "$DF_TMP/bin/$t"
  done
  [ ! -e "$DF_TMP/bin/swaync-client" ]

  PATH="$DF_TMP/bin" run "$(PIN)" DP-6
  [ "$status" -eq 0 ]
  [ ! -e "$XDG_STATE_HOME/dotfiles/swaync/output" ]
}

@test "every dock path pins notifications through the shared helper" {
  # The pin logic must not be duplicated per host: three callers need it
  # (stationzebra's TV dock, cltc's TV dock, cltc's office kanshi profile).
  local f
  for f in "$DF_SRC_REPO/hosts/stationzebra/.config/kanshi/dock-layout.sh" \
           "$DF_SRC_REPO/hosts/cltc-aus-lws03/.config/kanshi/dock-layout.sh"; do
    grep -q 'swaync/swaync-pin.sh' "$f" || { echo "$f does not use the helper"; false; }
    # and must not have re-grown an inline copy
    ! grep -q 'dotfiles/swaync/output' "$f"
  done
}

@test "cltc's office dock pins the middle Dell by serial, not by description" {
  # swaync composes its descriptor from GDK as "manufacturer model description",
  # which is not kanshi's "make model serial" and is not known to carry the
  # serial -- two identical P2422H panels would collide and try_get_monitor would
  # return whichever came first. Resolve the serial to a connector instead.
  local s="$DF_SRC_REPO/hosts/cltc-aus-lws03/.config/kanshi/office-notifications.sh"
  local k="$DF_SRC_REPO/hosts/cltc-aus-lws03/.config/kanshi/config"
  [ -x "$s" ]
  bash -n "$s"
  # the middle external's serial, per the kanshi profile's own comments
  grep -q 'MIDDLE_SERIAL="JQ5X7M3"' "$s"
  grep -q "m.get('serial')" "$s"
  grep -q 'swaync/swaync-pin.sh' "$s"
  # wired into the office profile, and the laptop-only profile clears the pin
  grep -q 'exec ~/.config/kanshi/office-notifications.sh' "$k"
  grep -q 'exec ~/.config/swaync/swaync-pin.sh --clear' "$k"
}

@test "a .service.d owned by both a profile and the host links both children" {
  # swaync.service.d was the first drop-in directory in this repo owned by two
  # layers: profiles/hyprland contributes the generated-config -c override and
  # the Fedora hosts add the dual-session guard. waybar.service.d is now the
  # second (profile restart pacing + host guard). A single-owner *.service.d is
  # FOLDED into one symlink, so the two-owner case is the one worth pinning: if
  # it folded, one layer's drop-in would silently disappear and the unit would
  # lose either its override or its guard.
  setup_sandbox
  mk_repo_conf 'DF_CONTAINER_DIRS+=(".config/systemd" ".config/systemd/user")'
  mk_profile hypr-test .config/systemd/user/swaync.service.d/dotfiles-config.conf 'x'
  mk_host .config/systemd/user/swaync.service.d/hyprland-only.conf 'y'
  run "$DOTFILES" profile enable hypr-test
  [ "$status" -eq 0 ]
  run "$DOTFILES" link
  [ "$status" -eq 0 ]

  local d="$DF_TEST_TARGET/.config/systemd/user/swaync.service.d"
  # The directory must stay real, not become a symlink into either layer.
  [ -d "$d" ]
  [ ! -L "$d" ]
  # ...and BOTH drop-ins must be present.
  [ -L "$d/dotfiles-config.conf" ]
  [ -L "$d/hyprland-only.conf" ]
  [ "$(cat "$d/dotfiles-config.conf")" = "x" ]
  [ "$(cat "$d/hyprland-only.conf")" = "y" ]
  teardown_sandbox
}

@test "both Fedora hosts guard swaync to the Hyprland session" {
  # GNOME provides org.freedesktop.Notifications itself, so an unguarded swaync
  # on a dual-session box races GNOME's daemon for the bus name. The packaged
  # unit's ExecCondition only checks WAYLAND_DISPLAY, which GNOME satisfies too.
  local h g
  for h in fedora cltc-aus-lws03; do
    g="$DF_SRC_REPO/hosts/$h/.config/systemd/user/swaync.service.d/hyprland-only.conf"
    [ -f "$g" ] || { echo "missing swaync guard for host $h"; false; }
    grep -qE '^[[:space:]]*ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland' "$g"
  done
  # The shared drop-in must NOT carry the guard -- stationzebra has no GNOME.
  ! grep -qE '^[[:space:]]*ConditionEnvironment=' \
    "$DF_SRC_REPO/profiles/hyprland/.config/systemd/user/swaync.service.d/dotfiles-config.conf"
}

@test "the restart drop-ins keep session services alive across a compositor restart" {
  # hyprpaper exits 0 when wl_display_connect fails, so Restart=on-failure reads
  # a failed start as success and never retries; waybar exits non-zero but at the
  # 100ms default spends the 5-per-10s budget in about a second and is abandoned
  # as start-limit-hit. Both leave a dead unit after a mid-session Hyprland
  # restart, so both need pacing AND the limiter off -- pacing alone still ends
  # in start-limit-hit, and the limiter alone still gives up on hyprpaper's
  # zero exit.
  local d="$DF_SRC_REPO/profiles/hyprland/.config/systemd/user"

  grep -qE '^[[:space:]]*Restart=always' "$d/hyprpaper.service.d/dotfiles-restart.conf"
  grep -qE '^[[:space:]]*RestartSec=' "$d/hyprpaper.service.d/dotfiles-restart.conf"
  grep -qE '^[[:space:]]*RestartSec=' "$d/waybar.service.d/dotfiles-restart.conf"

  local f
  for f in hyprpaper waybar; do
    grep -qE '^[[:space:]]*StartLimitIntervalSec=0' "$d/$f.service.d/dotfiles-restart.conf"
    # StartLimitIntervalSec is a [Unit] option; in [Service] systemd ignores it
    # and the limiter silently stays on -- the exact failure being fixed.
    grep -qE '^\[Unit\]' "$d/$f.service.d/dotfiles-restart.conf"
    # Guard-free, like the shared kanshi.service: stationzebra has no GNOME.
    ! grep -qE '^[[:space:]]*ConditionEnvironment=' "$d/$f.service.d/dotfiles-restart.conf"
  done
}

@test "waybar.service.d is the second two-layer drop-in dir" {
  # Both Fedora hosts guard waybar, and the profile now contributes the restart
  # pacing, so waybar.service.d must not be treated as single-owner/foldable.
  local h
  for h in fedora cltc-aus-lws03; do
    [ -f "$DF_SRC_REPO/hosts/$h/.config/systemd/user/waybar.service.d/hyprland-only.conf" ] \
      || { echo "missing waybar guard for host $h"; false; }
  done
  [ -f "$DF_SRC_REPO/profiles/hyprland/.config/systemd/user/waybar.service.d/dotfiles-restart.conf" ]
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
