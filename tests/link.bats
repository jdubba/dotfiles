#!/usr/bin/env bats
# link.bats - the safety guarantees of the linker.

setup() { load test_helper; setup_sandbox; }
teardown() { teardown_sandbox; }

@test "container ~/.config is kept as a real directory, never folded" {
  mk_home ".config/nvim/init.lua"
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -d "$HOME/.config" ]
  [ ! -L "$HOME/.config" ]
}

@test "a solely-owned directory is folded into a single symlink" {
  mk_home ".config/nvim/init.lua"
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/nvim" ]
  [ -f "$HOME/.config/nvim/init.lua" ]
}

@test "a directory contributed by multiple layers auto-unfolds to file links" {
  mk_home ".config/hypr/hyprland.conf"
  mk_host ".config/hypr/monitors.conf"
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -d "$HOME/.config/hypr" ]
  [ ! -L "$HOME/.config/hypr" ]
  [ -L "$HOME/.config/hypr/hyprland.conf" ]
  [ -L "$HOME/.config/hypr/monitors.conf" ]
}

@test "files outside ~/.config are handled identically" {
  mk_home ".gitconfig"
  mk_home ".tmux.conf"
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -L "$HOME/.gitconfig" ]
  [ -L "$HOME/.tmux.conf" ]
}

@test "a pre-existing real file is a CONFLICT and is never overwritten" {
  mk_home ".bashrc" "SHARED"
  printf 'ORIGINAL\n' >"$HOME/.bashrc"
  run "$DOTFILES" link
  [ "$status" -ne 0 ]
  [[ "$output" == *"conflict"* || "$output" == *"CONFLICT"* ]]
  [ ! -L "$HOME/.bashrc" ]
  grep -q ORIGINAL "$HOME/.bashrc"
}

@test "unmanaged files in a container directory are left untouched" {
  mk_home ".config/nvim/init.lua"
  mkdir -p "$HOME/.config"
  printf 'keep me\n' >"$HOME/.config/other-app.conf"
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/other-app.conf" ]
  [ ! -L "$HOME/.config/other-app.conf" ]
  grep -q "keep me" "$HOME/.config/other-app.conf"
}

@test "link is idempotent" {
  mk_home ".config/nvim/init.lua"
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [[ "$output" == *"already linked"* ]]
}

@test "a new file written into a folded directory is captured into the repo" {
  mk_home ".config/nvim/init.lua"
  "$DOTFILES" link
  printf 'plugin\n' >"$HOME/.config/nvim/plugin.lua"
  [ -f "$DF_TEST_REPO/home/.config/nvim/plugin.lua" ]
}

@test "--dry-run makes no changes on disk" {
  mk_home ".config/nvim/init.lua"
  run "$DOTFILES" link --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/nvim" ]
}

@test "DISASTER RECOVERY: doctor --fix restores a container folded into the repo" {
  mk_home ".config/nvim/init.lua"
  # Simulate the exact Stow failure: ~/.config is a symlink into the repo.
  ln -s "$DF_TEST_REPO/home/.config" "$HOME/.config"
  [ -L "$HOME/.config" ]
  run "$DOTFILES" doctor --fix
  [ -d "$HOME/.config" ]
  [ ! -L "$HOME/.config" ]
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/nvim" ]
}

@test "doctor --fix removes a broken managed link" {
  mk_home ".config/foo/bar.conf"
  "$DOTFILES" link
  [ -L "$HOME/.config/foo" ]
  rm -rf "$DF_TEST_REPO/home/.config/foo"   # source gone -> link now broken
  run "$DOTFILES" doctor --fix
  [ ! -L "$HOME/.config/foo" ]
}

@test "MIGRATION: doctor --fix cleans a stale relative symlink into the repo" {
  mk_home ".bashrc" "NEW"
  # Simulate a leftover Stow-style relative link into the old (now-moved) path.
  ln -s "../repo/old-config/.bashrc" "$HOME/.bashrc"
  [ -L "$HOME/.bashrc" ]
  [ ! -e "$HOME/.bashrc" ]                   # dangling
  run "$DOTFILES" doctor --fix
  [ "$status" -ne 0 ]                        # reported an issue
  [ ! -L "$HOME/.bashrc" ]                   # stale link removed
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -L "$HOME/.bashrc" ]
  grep -q NEW "$HOME/.bashrc"
}

@test "a folded directory unfolds cleanly when a new layer adds a sibling" {
  mk_home ".config/app/a.conf" "A"
  "$DOTFILES" link
  [ -L "$HOME/.config/app" ]                                   # folded (home only)
  mk_host ".config/app/b.conf" "B"                             # host adds a sibling
  run "$DOTFILES" link
  [ "$status" -eq 0 ]                                          # no conflicts
  [ -d "$HOME/.config/app" ] && [ ! -L "$HOME/.config/app" ]   # now a real dir
  [ -L "$HOME/.config/app/a.conf" ]                            # home file linked
  [ -L "$HOME/.config/app/b.conf" ]                            # host file linked
  grep -q A "$HOME/.config/app/a.conf"
  grep -q B "$HOME/.config/app/b.conf"
}

@test "a wrong managed symlink is repaired, not treated as a conflict" {
  mk_home ".gitconfig" "REAL"
  # Pre-existing symlink pointing at the wrong place inside the repo.
  mkdir -p "$DF_TEST_REPO/home"
  printf 'stale\n' >"$DF_TEST_REPO/home/.stale"
  ln -s "$DF_TEST_REPO/home/.stale" "$HOME/.gitconfig"
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -L "$HOME/.gitconfig" ]
  grep -q REAL "$HOME/.gitconfig"
}
