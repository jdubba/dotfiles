#!/usr/bin/env bats
# theme-brave.bats - Brave custom theme color alignment (lib/theme-brave.py and
# the seam parsing / running-browser check in lib/commands/theme.sh).

setup() {
  load test_helper
  setup_sandbox
  command -v python3 &>/dev/null || skip "python3 not installed"
  BRAVE="$HOME/.config/BraveSoftware/Brave-Browser"
  PREFS="$BRAVE/Default/Preferences"
  HELPER="$DF_TEST_REPO/lib/theme-brave.py"
}
teardown() { teardown_sandbox; }

# A Preferences file. The default carries unrelated content that must survive a
# rewrite. (Do not inline JSON as a ${1:-...} default: its first '}' would close
# the expansion.)
mk_prefs() {
  local json=${1:-}
  [[ -n "$json" ]] || json='{"browser":{"theme":{}},"extensions":{"theme":{"id":""}},"profile":{"name":"keep me"}}'
  mkdir -p "$(dirname "$PREFS")"
  printf '%s' "$json" >"$PREFS"
}

# Read a dotted key out of the Preferences JSON.
prefs_get() {
  python3 - "$PREFS" "$1" <<'PY'
import json, sys
node = json.load(open(sys.argv[1]))
for part in sys.argv[2].split("."):
    node = node[part]
print(json.dumps(node))
PY
}

@test "theme-brave.py is valid python" {
  run python3 -m py_compile "$HELPER"
  [ "$status" -eq 0 ]
}

@test "helper writes the signed ARGB SkColor and the dark scheme" {
  mk_prefs
  run python3 "$HELPER" "$PREFS" "#a6e3a1" dark
  [ "$status" -eq 0 ]
  # 0xFFA6E3A1 as a signed 32-bit integer.
  [ "$(prefs_get browser.theme.user_color2)" = "-5839967" ]
  [ "$(prefs_get browser.theme.color_scheme2)" = "2" ]
  [ "$(prefs_get browser.theme.color_variant2)" = "1" ]
  [ "$(prefs_get extensions.theme.id)" = '"user_color_theme_id"' ]
}

@test "a light theme selects the light browser color scheme" {
  mk_prefs
  run python3 "$HELPER" "$PREFS" "#40a02b" light
  [ "$status" -eq 0 ]
  [ "$(prefs_get browser.theme.color_scheme2)" = "1" ]
}

@test "unrelated preferences survive the rewrite" {
  mk_prefs
  python3 "$HELPER" "$PREFS" "#89b4fa" dark
  [ "$(prefs_get profile.name)" = '"keep me"' ]
}

@test "an existing Material color variant is preserved" {
  mk_prefs '{"browser":{"theme":{"color_variant2":3}},"extensions":{"theme":{}}}'
  python3 "$HELPER" "$PREFS" "#89b4fa" dark
  [ "$(prefs_get browser.theme.color_variant2)" = "3" ]
}

@test "an already-aligned profile is left untouched (exit 2, no rewrite)" {
  mk_prefs
  python3 "$HELPER" "$PREFS" "#a6e3a1" dark
  local before after
  before=$(stat -c '%Y %s' "$PREFS")
  run python3 "$HELPER" "$PREFS" "#a6e3a1" dark
  [ "$status" -eq 2 ]
  after=$(stat -c '%Y %s' "$PREFS")
  [ "$before" = "$after" ]
}

@test "the write is atomic and leaves no temp file behind" {
  mk_prefs
  python3 "$HELPER" "$PREFS" "#a6e3a1" dark
  [ ! -e "$PREFS.dotfiles-tmp" ]
}

@test "malformed preferences are reported, not overwritten" {
  mk_prefs 'not json at all'
  run python3 "$HELPER" "$PREFS" "#a6e3a1" dark
  [ "$status" -eq 1 ]
  [ "$(cat "$PREFS")" = "not json at all" ]
}

@test "a bad color is rejected" {
  mk_prefs
  run python3 "$HELPER" "$PREFS" "not-a-color" dark
  [ "$status" -eq 1 ]
}

# --- the shell side ----------------------------------------------------------
#
# _df_theme_brave_apply reads the two seams and refuses to write while a browser
# holds the profile, so exercise it directly against the sandbox HOME.

load_theme_lib() {
  DF_REPO="$DF_TEST_REPO"
  # shellcheck source=../lib/core.sh
  source "$DF_TEST_REPO/lib/core.sh"
  # shellcheck source=../lib/commands/theme.sh
  source "$DF_TEST_REPO/lib/commands/theme.sh"
}

mk_seams() {
  mkdir -p "$HOME/.config/waybar" "$HOME/.config/nvim/lua"
  printf '@define-color bar-bg          #1e1e2e;\n@define-color pill-brand-bg   %s;\n' \
    "${1:-#a6e3a1}" >"$HOME/.config/waybar/colors.css"
  printf 'return { name = "t", colorscheme = "c", background = "%s" }\n' \
    "${2:-dark}" >"$HOME/.config/nvim/lua/dotfiles_theme.lua"
}

@test "apply reads the accent from the waybar seam and the polarity from nvim" {
  load_theme_lib
  mk_prefs
  mk_seams "#89b4fa" light
  run _df_theme_brave_apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"brave: theme color set to #89b4fa"* ]]
  [ "$(prefs_get browser.theme.color_scheme2)" = "1" ]
  # 0xFF89B4FA signed.
  [ "$(prefs_get browser.theme.user_color2)" = "-7752454" ]
}

@test "apply is a no-op when Brave has never run" {
  load_theme_lib
  mk_seams
  run _df_theme_brave_apply
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "apply is a no-op when no theme provides the waybar seam" {
  load_theme_lib
  mk_prefs
  run _df_theme_brave_apply
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$(cat "$PREFS")" != *user_color2* ]]
}

@test "a live SingletonLock stops the write" {
  load_theme_lib
  mk_prefs
  mk_seams
  ln -s "$(hostname)-$$" "$BRAVE/SingletonLock"        # $$ is alive by definition
  run _df_theme_brave_apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"brave: running"* ]]
  [[ "$(cat "$PREFS")" != *user_color2* ]]
}

@test "a stale SingletonLock does not stop the write" {
  load_theme_lib
  mk_prefs
  mk_seams
  # A pid that cannot be running: one past the configured maximum.
  local dead=$(( $(cat /proc/sys/kernel/pid_max) + 1 ))
  ln -s "$(hostname)-$dead" "$BRAVE/SingletonLock"
  run _df_theme_brave_apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"theme color set to"* ]]
}
