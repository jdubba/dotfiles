#!/usr/bin/env bats
# theme-auto.bats - wallpaper-derived ("auto") theme: state, generation, CLI.
#
# Palette extraction is stubbed via DF_PALETTE_FILE so these tests need no
# image backend (Pillow/wallust/pywal) and stay deterministic in CI.

setup() { load test_helper; setup_sandbox; }
teardown() { teardown_sandbox; }

# Write a deterministic 16-colour palette and export DF_PALETTE_FILE.
_stub_palette() {
  local f="$DF_TEST_ROOT/palette.txt"
  cat >"$f" <<'PAL'
background=#101012
foreground=#e8e8ea
cursor=#e8e8ea
color0=#1a1a1e
color1=#e05a5a
color2=#5ae05a
color3=#e0e05a
color4=#5a9ae0
color5=#c05ae0
color6=#5ae0d0
color7=#c8c8ce
color8=#4a4a54
color9=#f07a7a
color10=#7af07a
color11=#f0f07a
color12=#7ab0f0
color13=#d07af0
color14=#7af0e0
color15=#f2f2f4
PAL
  export DF_PALETTE_FILE="$f"
}

_autotheme_flag() { printf '%s/dotfiles/auto-theme' "$XDG_STATE_HOME"; }

@test "auto flag makes the resolved theme 'auto'" {
  mkdir -p "$(dirname "$(_autotheme_flag)")"
  printf 'on\n' >"$(_autotheme_flag)"
  run "$DOTFILES" info
  [ "$status" -eq 0 ]
  [[ "$output" == *"theme:"*"auto"* ]]
}

@test "theme auto status reports state and palette backend" {
  run "$DOTFILES" theme auto status
  [ "$status" -eq 0 ]
  [[ "$output" == *"auto-theming: disabled"* ]]
  [[ "$output" == *"palette backend:"* ]]
}

@test "theme set auto is rejected with guidance to use 'theme auto'" {
  run "$DOTFILES" theme set auto
  [ "$status" -ne 0 ]
  [[ "$output" == *"theme auto"* ]]
}

@test "theme set disables auto-theming" {
  mkdir -p "$(dirname "$(_autotheme_flag)")"
  printf 'on\n' >"$(_autotheme_flag)"
  mk_theme_default catppuccin-mocha
  mk_theme catppuccin-mocha ".config/app/conf"
  run "$DOTFILES" theme set catppuccin-mocha --no-link --no-reload
  [ "$status" -eq 0 ]
  [ ! -f "$(_autotheme_flag)" ]
  [[ "$output" == *"disabled auto-theming"* ]]
}

@test "theme auto now generates themes/auto from a stubbed palette and activates it" {
  _stub_palette
  local img="$DF_TEST_ROOT/wall.jpg"; printf 'not-really-an-image' >"$img"
  run "$DOTFILES" theme auto now "$img"
  [ "$status" -eq 0 ]
  # Generated seam files exist with palette colours.
  [ -f "$DF_TEST_REPO/themes/auto/.config/kitty/current-theme.conf" ]
  grep -q "#101012" "$DF_TEST_REPO/themes/auto/.config/kitty/current-theme.conf"
  grep -q "colorscheme = \"base16\"" "$DF_TEST_REPO/themes/auto/.config/nvim/lua/dotfiles_theme.lua"
  grep -q "\"theme\": \"system\"" "$DF_TEST_REPO/themes/auto/.config/opencode/tui.json"
  grep -q "BAT_THEME=\"ansi\"" "$DF_TEST_REPO/themes/auto/.config/shell/theme-env.sh"
  # Waybar section pills are colorful (accent bg + contrast fg), not the dark base.
  grep -q "pill-brand-bg" "$DF_TEST_REPO/themes/auto/.config/waybar/colors.css"
  grep -qE "pill-brand-fg +#(141414|f0f0f0)" "$DF_TEST_REPO/themes/auto/.config/waybar/colors.css"
  # Wallpaper copied into the theme.
  [ -f "$DF_TEST_REPO/themes/auto/.config/background" ]
  # Auto became active and was linked into the target.
  [ -f "$(_autotheme_flag)" ]
  [ -e "$HOME/.config/background" ]
}

@test "theme auto now records the source wallpaper in machine state" {
  _stub_palette
  local img="$DF_TEST_ROOT/wall.jpg"; printf 'x' >"$img"
  run "$DOTFILES" theme auto now "$img"
  [ "$status" -eq 0 ]
  [ -f "$XDG_STATE_HOME/dotfiles/auto-theme.source" ]
  grep -q "$img" "$XDG_STATE_HOME/dotfiles/auto-theme.source"
}

@test "theme auto disable clears the flag and reverts" {
  _stub_palette
  local img="$DF_TEST_ROOT/wall.jpg"; printf 'x' >"$img"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme auto now "$img"
  [ "$status" -eq 0 ]
  [ -f "$(_autotheme_flag)" ]
  run "$DOTFILES" theme auto disable
  [ "$status" -eq 0 ]
  [ ! -f "$(_autotheme_flag)" ]
  [[ "$output" == *"auto-theming disabled"* ]]
}

@test "theme auto now honors DF_WALLPAPER when no image is given" {
  _stub_palette
  local img="$DF_TEST_ROOT/wallA.jpg"; printf 'AAAA' >"$img"
  DF_WALLPAPER="$img" run "$DOTFILES" theme auto now
  [ "$status" -eq 0 ]
  [ -f "$DF_TEST_REPO/themes/auto/.config/kitty/current-theme.conf" ]
  grep -q "wallA.jpg" "$XDG_STATE_HOME/dotfiles/auto-theme.source"
}

@test "watch tick regenerates on change and no-ops when unchanged" {
  _stub_palette
  local a="$DF_TEST_ROOT/a.jpg" b="$DF_TEST_ROOT/b.jpg"
  printf 'AAAA' >"$a"; printf 'BBBB' >"$b"
  DF_WALLPAPER="$a" run "$DOTFILES" theme auto now
  [ "$status" -eq 0 ]
  # Same content -> loop guard skips.
  DF_WALLPAPER="$a" run "$DOTFILES" theme auto watch-tick
  [ "$status" -eq 0 ]
  [[ "$output" == *"unchanged"* ]]
  # Different content -> regenerates.
  DF_WALLPAPER="$b" run "$DOTFILES" theme auto watch-tick
  [ "$status" -eq 0 ]
  [[ "$output" == *"regenerated"* ]]
  grep -q "b.jpg" "$XDG_STATE_HOME/dotfiles/auto-theme.source"
}
