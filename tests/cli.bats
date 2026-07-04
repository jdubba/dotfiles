#!/usr/bin/env bats
# cli.bats - command dispatch, profiles, status, and info.

setup() { load test_helper; setup_sandbox; }
teardown() { teardown_sandbox; }

@test "version prints a version string" {
  run "$DOTFILES" version
  [ "$status" -eq 0 ]
  [[ "$output" == *"dotfiles"* ]]
}

@test "help is shown for --help and with no args" {
  run "$DOTFILES" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"layered symlink manager"* ]]
  run "$DOTFILES"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown command exits non-zero" {
  run "$DOTFILES" definitely-not-a-command
  [ "$status" -ne 0 ]
}

@test "info reports the detected hostname and layers" {
  mk_home ".bashrc"
  run "$DOTFILES" info
  [ "$status" -eq 0 ]
  [[ "$output" == *"hostname"* ]]
  [[ "$output" == *"home"* ]]
}

@test "status is read-only and reports pending links" {
  mk_home ".config/nvim/init.lua"
  run "$DOTFILES" status
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.config/nvim" ]   # nothing created
  [[ "$output" == *"link"* ]]
}

@test "status reports in sync after linking" {
  mk_home ".config/nvim/init.lua"
  "$DOTFILES" link
  run "$DOTFILES" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"in sync"* ]]
}

@test "an explicitly enabled profile becomes active and is applied" {
  mk_profile work ".config/work-app/conf"
  run "$DOTFILES" profile enable work
  [ "$status" -eq 0 ]
  run "$DOTFILES" info
  [[ "$output" == *"work"* ]]
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  [ -L "$HOME/.config/work-app" ]
}

@test "profile disable removes an explicit profile" {
  mk_profile work ".config/work-app/conf"
  "$DOTFILES" profile enable work
  run "$DOTFILES" profile disable work
  [ "$status" -eq 0 ]
  run "$DOTFILES" profile list
  [[ "$output" != *"work (active)"* ]]
}

@test "host layer overrides shared file of the same name" {
  mk_home ".config/app/conf" "SHARED"
  mk_host ".config/app/conf" "HOSTWINS"
  run "$DOTFILES" link
  [ "$status" -eq 0 ]
  grep -q HOSTWINS "$HOME/.config/app/conf"
}

@test "hook install creates a post-merge hook" {
  git -C "$DF_TEST_REPO" init -q
  run "$DOTFILES" hook install
  [ "$status" -eq 0 ]
  [ -L "$DF_TEST_REPO/.git/hooks/post-merge" ] || [ -f "$DF_TEST_REPO/.git/hooks/post-merge" ]
}
