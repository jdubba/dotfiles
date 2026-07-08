#!/usr/bin/env bats
# completions.bats - the `dotfiles` shell completion function and the
# machine-readable `list --plain` helpers that feed its dynamic candidates.

setup() {
  load test_helper
  setup_sandbox
  # Load the completion definition into this (bash) test shell.
  source "$DF_SRC_REPO/home/.config/shell/completions/dotfiles.bash"
}
teardown() { teardown_sandbox; }

# Drive the completion function: comp <cword> <word>...
# Result is exposed as $reply (space-padded for easy substring matching).
comp() {
  COMP_CWORD=$1; shift
  COMP_WORDS=("$@")
  COMPREPLY=()
  _dotfiles
  reply=" ${COMPREPLY[*]} "
}

# --- static structure -------------------------------------------------------

@test "top-level completion offers the documented commands" {
  comp 1 dotfiles ""
  [[ "$reply" == *" link "* ]]
  [[ "$reply" == *" status "* ]]
  [[ "$reply" == *" theme "* ]]
  [[ "$reply" == *" profile "* ]]
  [[ "$reply" == *" env "* ]]
  [[ "$reply" == *" doctor "* ]]
}

@test "top-level completion filters by the current prefix" {
  comp 1 dotfiles th
  [[ "$reply" == *" theme "* ]]
  [[ "$reply" != *" link "* ]]
}

@test "theme subcommands are completed" {
  comp 2 dotfiles theme ""
  [[ "$reply" == *" status "* ]]
  [[ "$reply" == *" list "* ]]
  [[ "$reply" == *" set "* ]]
  [[ "$reply" == *" unset "* ]]
  [[ "$reply" == *" auto "* ]]
}

@test "theme set completes its flags when the word starts with a dash" {
  comp 3 dotfiles theme set --
  [[ "$reply" == *" --no-link "* ]]
  [[ "$reply" == *" --no-reload "* ]]
}

@test "theme auto subcommands are completed" {
  comp 3 dotfiles theme auto ""
  [[ "$reply" == *" now "* ]]
  [[ "$reply" == *" enable "* ]]
  [[ "$reply" == *" disable "* ]]
  [[ "$reply" == *" status "* ]]
}

@test "env subcommands are completed" {
  comp 2 dotfiles env ""
  [[ "$reply" == *" set "* ]]
  [[ "$reply" == *" skip "* ]]
  [[ "$reply" == *" add "* ]]
  [[ "$reply" == *" unset "* ]]
  [[ "$reply" == *" list "* ]]
}

@test "profile subcommands are completed" {
  comp 2 dotfiles profile ""
  [[ "$reply" == *" enable "* ]]
  [[ "$reply" == *" disable "* ]]
}

@test "add --to completes destination kinds" {
  comp 3 dotfiles add --to ""
  [[ "$reply" == *" home "* ]]
  [[ "$reply" == *" host "* ]]
  [[ "$reply" == *" profile: "* ]]
}

@test "doctor / sync / hook / dconf structural completion" {
  comp 2 dotfiles doctor ""
  [[ "$reply" == *" --fix "* ]]
  comp 2 dotfiles sync ""
  [[ "$reply" == *" --no-link "* ]]
  comp 2 dotfiles hook ""
  [[ "$reply" == *" install "* ]]
  [[ "$reply" == *" uninstall "* ]]
  comp 2 dotfiles dconf ""
  [[ "$reply" == *" dump "* ]]
  [[ "$reply" == *" load "* ]]
}

# --- dynamic candidates (call back into the tool for live repo state) -------

@test "theme set lists the available themes (and excludes auto)" {
  mk_theme catppuccin-mocha ".config/app/conf"
  mk_theme gruvbox-dark ".config/app/conf"
  mk_theme auto ".config/app/conf"           # generated theme, must be hidden
  comp 3 "$DOTFILES" theme set ""
  [[ "$reply" == *" catppuccin-mocha "* ]]
  [[ "$reply" == *" gruvbox-dark "* ]]
  [[ "$reply" != *" auto "* ]]
}

@test "theme set filters theme names by prefix" {
  mk_theme catppuccin-mocha ".config/app/conf"
  mk_theme gruvbox-dark ".config/app/conf"
  comp 3 "$DOTFILES" theme set gru
  [[ "$reply" == *" gruvbox-dark "* ]]
  [[ "$reply" != *" catppuccin-mocha "* ]]
}

@test "profile enable lists available profiles" {
  mk_profile work ".config/work-app/conf"
  comp 3 "$DOTFILES" profile enable ""
  [[ "$reply" == *" work "* ]]
}

@test "env set lists declared machine-env variables" {
  "$DOTFILES" env add MYVAR "a test var"
  comp 3 "$DOTFILES" env set ""
  [[ "$reply" == *" MYVAR "* ]]
}

# --- the machine-readable helpers, independently ----------------------------

@test "profile list --plain prints bare names to stdout" {
  mk_profile work ".config/work-app/conf"
  run "$DOTFILES" profile list --plain
  [ "$status" -eq 0 ]
  [ "$output" = "work" ]
}

@test "theme list --plain prints bare names to stdout" {
  mk_theme catppuccin-mocha ".config/app/conf"
  run "$DOTFILES" theme list --plain
  [ "$status" -eq 0 ]
  [[ "$output" == *"catppuccin-mocha"* ]]
}

@test "env list prints declared variable names to stdout" {
  "$DOTFILES" env add MYVAR "a test var"
  run "$DOTFILES" env list --plain
  [ "$status" -eq 0 ]
  [[ "$output" == *"MYVAR"* ]]
}
