#!/usr/bin/env bats
# add.bats - explicit adoption of existing files into the repo.

setup() { load test_helper; setup_sandbox; }
teardown() { teardown_sandbox; }

@test "add adopts a file into home/ and links it back" {
  printf 'GITCONFIG\n' >"$HOME/.gitconfig"
  run "$DOTFILES" add "$HOME/.gitconfig"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.gitconfig" ]
  [ -f "$DF_TEST_REPO/home/.gitconfig" ]
  grep -q GITCONFIG "$DF_TEST_REPO/home/.gitconfig"
  grep -q GITCONFIG "$HOME/.gitconfig"
}

@test "add adopts a directory" {
  mkdir -p "$HOME/.config/foot"
  printf 'x\n' >"$HOME/.config/foot/foot.ini"
  run "$DOTFILES" add "$HOME/.config/foot"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/foot" ]
  [ -f "$DF_TEST_REPO/home/.config/foot/foot.ini" ]
}

@test "add --to host places the file in the host layer" {
  mkdir -p "$HOME/.config/hypr"
  printf 'MON\n' >"$HOME/.config/hypr/monitors.conf"
  run "$DOTFILES" add "$HOME/.config/hypr/monitors.conf" --to host
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/hypr/monitors.conf" ]
  [ -f "$DF_TEST_REPO/hosts/$(df_host)/.config/hypr/monitors.conf" ]
}

@test "add --to profile:<name> places the file in a profile layer" {
  printf 'x\n' >"$HOME/.config-x"
  run "$DOTFILES" add "$HOME/.config-x" --to profile:work
  [ "$status" -eq 0 ]
  [ -f "$DF_TEST_REPO/profiles/work/.config-x" ]
}

@test "add refuses to adopt a container directory" {
  mkdir -p "$HOME/.config"
  run "$DOTFILES" add "$HOME/.config"
  [ "$status" -ne 0 ]
}

@test "add refuses a path outside the target root" {
  run "$DOTFILES" add /etc/hostname
  [ "$status" -ne 0 ]
}

@test "add on a missing path errors" {
  run "$DOTFILES" add "$HOME/does-not-exist"
  [ "$status" -ne 0 ]
}

@test "add detects an already-managed path" {
  mk_home ".config/nvim/init.lua"
  "$DOTFILES" link
  run "$DOTFILES" add "$HOME/.config/nvim"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already managed"* ]]
}

@test "add refuses when the destination already exists in the layer" {
  mk_home ".gitconfig" "existing"
  printf 'new\n' >"$HOME/.gitconfig.real"
  mv "$HOME/.gitconfig.real" "$HOME/.gitconfig" 2>/dev/null || true
  # .gitconfig exists in home/ already; adopting the (unlinked) real one must fail.
  rm -f "$HOME/.gitconfig"
  printf 'conflict\n' >"$HOME/.gitconfig"
  run "$DOTFILES" add "$HOME/.gitconfig"
  [ "$status" -ne 0 ]
}
