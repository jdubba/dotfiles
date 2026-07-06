#!/usr/bin/env bash
# test_helper.bash - minimal sandbox helpers for the dotfiles test suite.
#
# No external bats libraries are required; tests use plain `run` + bash tests.

# Absolute path to the repository under test (this file lives in <repo>/tests).
DF_SRC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Short, lowercased hostname - must match lib/identity.sh:df_hostname().
df_host() {
  local h
  h=$(hostname 2>/dev/null || uname -n 2>/dev/null || printf 'unknown')
  h=${h%%.*}
  printf '%s' "${h,,}"
}

# Create an isolated sandbox: a throwaway repo (tool + empty layers) and a
# target dir, with HOME/DF_TARGET/XDG_STATE_HOME pointed inside it.
setup_sandbox() {
  DF_TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/df.XXXXXX")"
  DF_TEST_REPO="$DF_TEST_ROOT/repo"
  DF_TEST_TARGET="$DF_TEST_ROOT/target"
  mkdir -p "$DF_TEST_REPO" "$DF_TEST_TARGET"
  cp -r "$DF_SRC_REPO/bin" "$DF_TEST_REPO/"
  cp -r "$DF_SRC_REPO/lib" "$DF_TEST_REPO/"
  DOTFILES="$DF_TEST_REPO/bin/dotfiles"

  export HOME="$DF_TEST_TARGET"
  export DF_TARGET="$DF_TEST_TARGET"
  export XDG_STATE_HOME="$DF_TEST_TARGET/.local/state"
  export NO_COLOR=1
  # The sandbox deliberately sets DF_TARGET==HOME, which would otherwise let
  # theme reloads fire against the developer's live desktop. Suppress them.
  export DF_NO_RELOAD=1
}

teardown_sandbox() {
  [[ -n "${DF_TEST_ROOT:-}" && -d "$DF_TEST_ROOT" ]] && rm -rf "$DF_TEST_ROOT"
  return 0
}

# Author content in a layer: mk_home <relpath> [content]
mk_home() {
  local p="$DF_TEST_REPO/home/$1"
  mkdir -p "$(dirname "$p")"
  printf '%s\n' "${2:-content}" >"$p"
}

# mk_profile <profile> <relpath> [content]
mk_profile() {
  local p="$DF_TEST_REPO/profiles/$1/$2"
  mkdir -p "$(dirname "$p")"
  printf '%s\n' "${3:-content}" >"$p"
}

# mk_host <relpath> [content]  (uses this machine's hostname)
mk_host() {
  local p="$DF_TEST_REPO/hosts/$(df_host)/$1"
  mkdir -p "$(dirname "$p")"
  printf '%s\n' "${2:-content}" >"$p"
}

# mk_theme <name> <relpath> [content]
mk_theme() {
  local p="$DF_TEST_REPO/themes/$1/$2"
  mkdir -p "$(dirname "$p")"
  printf '%s\n' "${3:-content}" >"$p"
}

# mk_theme_default <name>  - set the repo default theme
mk_theme_default() {
  mkdir -p "$DF_TEST_REPO/themes"
  printf '%s\n' "$1" >"$DF_TEST_REPO/themes/default"
}
