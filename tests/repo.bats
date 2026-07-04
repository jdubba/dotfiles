#!/usr/bin/env bats
# repo.bats - sanity checks on the repository's own shipped content.

setup() { load test_helper; }

@test "home layer exists with expected structure" {
  [ -d "$DF_SRC_REPO/home" ]
  [ -d "$DF_SRC_REPO/home/.config" ]
  [ -f "$DF_SRC_REPO/home/.gitconfig" ]
}

@test "shipped bash configuration files are syntactically valid" {
  bash -n "$DF_SRC_REPO/home/.bashrc"
  bash -n "$DF_SRC_REPO/home/.bash_profile"
  local f
  for f in "$DF_SRC_REPO"/home/.config/bash/*.bash; do bash -n "$f"; done
}

@test "shared POSIX shell files are syntactically valid" {
  local f
  for f in "$DF_SRC_REPO"/home/.profile "$DF_SRC_REPO"/home/.config/shell/*.sh; do
    sh -n "$f"
  done
}

@test "zsh files are syntactically valid (when zsh is available)" {
  command -v zsh >/dev/null 2>&1 || skip "zsh not installed"
  local f
  zsh -n "$DF_SRC_REPO/home/.zshenv"
  zsh -n "$DF_SRC_REPO/home/.zshrc"
  for f in "$DF_SRC_REPO"/home/.config/zsh/*.zsh; do zsh -n "$f"; done
}

@test "tool library files are syntactically valid" {
  local f
  for f in "$DF_SRC_REPO"/lib/*.sh "$DF_SRC_REPO"/lib/commands/*.sh; do
    bash -n "$f"
  done
}

@test "bin/dotfiles is executable and reports its version" {
  [ -x "$DF_SRC_REPO/bin/dotfiles" ]
  run "$DF_SRC_REPO/bin/dotfiles" version
  [ "$status" -eq 0 ]
}

@test "no tracked backup cruft remains in the home layer" {
  [ ! -e "$DF_SRC_REPO/home/.config/hypr/hyprland.conf.bak" ]
  [ ! -e "$DF_SRC_REPO/home/.config/waybar/config.jsonc.bak" ]
  [ ! -e "$DF_SRC_REPO/home/.config/waybar/config.jsonc.fix.bak" ]
}
