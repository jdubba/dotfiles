#!/usr/bin/env bats
# theme.bats - theme layer resolution, CLI, and seam linking.

setup() { load test_helper; setup_sandbox; }
teardown() { teardown_sandbox; }

@test "theme name falls back to catppuccin-mocha with no default file" {
  mk_theme catppuccin-mocha ".config/app/conf"
  run "$DOTFILES" info
  [ "$status" -eq 0 ]
  [[ "$output" == *"theme:"*"catppuccin-mocha"* ]]
}

@test "theme name reads from themes/default" {
  mk_theme_default gruvbox-dark
  mk_theme gruvbox-dark ".config/app/conf"
  run "$DOTFILES" info
  [ "$status" -eq 0 ]
  [[ "$output" == *"theme:"*"gruvbox-dark"* ]]
}

@test "theme set writes host override and re-links" {
  mk_theme catppuccin-mocha ".config/app/conf"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme set catppuccin-mocha --no-reload
  [ "$status" -eq 0 ]
  [[ "$output" == *"set theme to 'catppuccin-mocha'"* ]]
  [[ "$output" == *"linked"* || "$output" == *"everything already"* ]]
}

@test "host override takes precedence over repo default" {
  mk_theme_default catppuccin-mocha
  mk_theme catppuccin-mocha ".config/app/conf"
  mk_theme gruvbox-dark ".config/app/conf"
  # Set per-host override to gruvbox-dark
  mk_host ".config/dotfiles/theme" "gruvbox-dark"
  run "$DOTFILES" info
  [ "$status" -eq 0 ]
  [[ "$output" == *"theme:"*"gruvbox-dark"* ]]
}

@test "theme layer is injected between profiles and host" {
  mk_home ".config/app/shared"
  mk_theme catppuccin-mocha ".config/app/shared"
  mk_profile hyprland ".config/app/profile-only"
  mk_host ".config/app/host-only"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" info
  [ "$status" -eq 0 ]
  # Verify all layers are present
  [[ "$output" == *"home"* ]]
  [[ "$output" == *"profiles/hyprland"* ]]
  [[ "$output" == *"themes/catppuccin-mocha"* ]]
  [[ "$output" == *"hosts"* ]]
}

@test "theme set creates host override file" {
  override="$DF_TEST_REPO/hosts/$(df_host)/.config/dotfiles/theme"
  mk_theme gruvbox-dark ".config/app/conf"
  run "$DOTFILES" theme set gruvbox-dark --no-link --no-reload
  [ "$status" -eq 0 ]
  [ -f "$override" ]
  grep -q "gruvbox-dark" "$override"
}

@test "theme unset removes host override" {
  override="$DF_TEST_REPO/hosts/$(df_host)/.config/dotfiles/theme"
  mk_theme gruvbox-dark ".config/app/conf"
  mk_host ".config/dotfiles/theme" "gruvbox-dark"
  run "$DOTFILES" theme unset
  [ "$status" -eq 0 ]
  [ ! -f "$override" ]
  [[ "$output" == *"removed"* ]]
}

@test "theme list shows available themes" {
  mk_theme catppuccin-mocha ".config/app/conf"
  mk_theme gruvbox-dark ".config/app/conf"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme list
  [ "$status" -eq 0 ]
  [[ "$output" == *"catppuccin-mocha"* ]]
  [[ "$output" == *"gruvbox-dark"* ]]
  # catppuccin-mocha should be marked active
  [[ "$output" == *"* catppuccin-mocha"* ]]
}

@test "theme list --plain prints bare names to stdout (for menus/scripts)" {
  mk_theme catppuccin-mocha ".config/app/conf"
  mk_theme gruvbox-dark ".config/app/conf"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme list --plain
  [ "$status" -eq 0 ]
  # Exactly the theme names, one per line, no decoration.
  [[ "$output" == *"catppuccin-mocha"* ]]
  [[ "$output" == *"gruvbox-dark"* ]]
  [[ "$output" != *"active"* ]]
  [[ "$output" != *"*"* ]]
}

@test "theme name prints the resolved active theme to stdout" {
  mk_theme_default gruvbox-dark
  mk_theme gruvbox-dark ".config/app/conf"
  run "$DOTFILES" theme name
  [ "$status" -eq 0 ]
  [ "$output" = "gruvbox-dark" ]
}

@test "theme status shows source information" {
  mk_theme catppuccin-mocha ".config/app/conf"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme status
  [ "$status" -eq 0 ]
  [[ "$output" == *"theme:"* ]]
  [[ "$output" == *"catppuccin-mocha"* ]]
}

@test "theme layer files are linked correctly" {
  mk_theme catppuccin-mocha ".config/app/theme-file"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  # Theme-only directories get folded (symlinked), so check the dir is a symlink
  # and the file is accessible through it
  [ -L "$HOME/.config/app" ]
  [ -f "$HOME/.config/app/theme-file" ]
}

@test "theme seam overrides home layer file" {
  mk_home ".config/app/theme-file" "home-content"
  mk_theme catppuccin-mocha ".config/app/theme-file" "theme-content"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  grep -q "theme-content" "$HOME/.config/app/theme-file"
}

@test "host layer overrides theme layer" {
  mk_theme catppuccin-mocha ".config/app/theme-file" "theme-content"
  mk_host ".config/app/theme-file" "host-content"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  grep -q "host-content" "$HOME/.config/app/theme-file"
}

@test "theme set with unknown name warns" {
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme set nonexistent --no-link --no-reload
  [ "$status" -eq 0 ]
  [[ "$output" == *"no themes/nonexistent/"* ]]
}

@test "theme set rejects 'auto' as selectable" {
  run "$DOTFILES" theme set auto --no-link --no-reload
  [ "$status" -ne 0 ]
  [[ "$output" == *"theme auto"* ]]
}

@test "theme status shows theme-env seam" {
  mk_theme catppuccin-mocha ".config/shell/theme-env.sh"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme status
  [ "$status" -eq 0 ]
  [[ "$output" == *"theme-env: yes"* ]]
}

@test "theme-env.sh is linked and exports expected variables" {
  mk_theme catppuccin-mocha ".config/shell/theme-env.sh" \
    "export BAT_THEME=\"Catppuccin Mocha\""
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/shell/theme-env.sh" ]
  run bash -c 'source "$HOME/.config/shell/theme-env.sh" && echo "BAT_THEME=$BAT_THEME"'
  [[ "$output" == *"BAT_THEME=Catppuccin Mocha"* ]]
}

@test "theme status shows nvim and starship seams" {
  mk_theme catppuccin-mocha ".config/nvim/lua/dotfiles_theme.lua"
  mk_theme catppuccin-mocha ".config/starship.toml"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme status
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvim: yes"* ]]
  [[ "$output" == *"starship: yes"* ]]
}

@test "nvim dotfiles_theme.lua is linked from the active theme" {
  mk_theme gruvbox-dark ".config/nvim/lua/dotfiles_theme.lua" \
    "return { name = \"gruvbox-dark\", colorscheme = \"gruvbox\" }"
  mk_theme_default gruvbox-dark
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/nvim/lua/dotfiles_theme.lua" ]
  grep -q "gruvbox" "$HOME/.config/nvim/lua/dotfiles_theme.lua"
}

@test "starship.toml is provided by the active theme (full-file swap)" {
  mk_theme catppuccin-mocha ".config/starship.toml" "palette = 'catppuccin_test'"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/starship.toml" ]
  grep -q "catppuccin_test" "$HOME/.config/starship.toml"
}

@test "starship.toml theme layer overrides home fallback" {
  mk_home ".config/starship.toml" "palette = 'home_fallback'"
  mk_theme gruvbox-dark ".config/starship.toml" "palette = 'gruvbox_theme'"
  mk_theme_default gruvbox-dark
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  grep -q "gruvbox_theme" "$HOME/.config/starship.toml"
}

@test "theme status shows opencode seam" {
  mk_theme catppuccin-mocha ".config/opencode/tui.json"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme status
  [ "$status" -eq 0 ]
  [[ "$output" == *"opencode: yes"* ]]
}

@test "opencode tui.json is provided by the active theme" {
  mk_theme gruvbox-dark ".config/opencode/tui.json" "{ \"theme\": \"gruvbox\" }"
  mk_theme_default gruvbox-dark
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/opencode/tui.json" ]
  grep -q "gruvbox" "$HOME/.config/opencode/tui.json"
}

@test "theme status shows wallpaper seam" {
  mk_theme catppuccin-mocha ".config/background" "fake-image-bytes"
  mk_theme_default catppuccin-mocha
  run "$DOTFILES" theme status
  [ "$status" -eq 0 ]
  [[ "$output" == *"wallpaper: yes"* ]]
}

@test "wallpaper is linked to the active theme's background at the stable path" {
  mk_theme gruvbox-dark ".config/background" "gruvbox-image-bytes"
  mk_theme_default gruvbox-dark
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -e "$HOME/.config/background" ]
  grep -q "gruvbox-image-bytes" "$HOME/.config/background"
}
