#!/usr/bin/env bats
# opencode-wrapper.bats - targeted tmux passthrough around the OpenCode TUI.

setup() {
  load test_helper
  TEST_ROOT=$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/opencode-wrapper.XXXXXX")
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home"
  export HOME="$TEST_ROOT/home"
  export PATH="$TEST_ROOT/bin:/usr/bin:/bin"
  export FAKE_LOG="$TEST_ROOT/log"
  export INTERACTIVE_SH="$DF_SRC_REPO/home/.config/shell/interactive.sh"

  cat >"$TEST_ROOT/bin/curl" <<'SH'
#!/bin/sh
printf '127.0.0.1\n'
SH

  cat >"$TEST_ROOT/bin/opencode" <<'SH'
#!/bin/sh
printf 'opencode' >>"$FAKE_LOG"
for arg do
  printf ' <%s>' "$arg" >>"$FAKE_LOG"
done
printf '\n' >>"$FAKE_LOG"
exit "${FAKE_OPENCODE_STATUS:-0}"
SH

  cat >"$TEST_ROOT/bin/tmux" <<'SH'
#!/bin/sh
printf 'tmux:%s\n' "$*" >>"$FAKE_LOG"
if [ "$1" = show-options ]; then
  [ "${FAKE_TMUX_QUERY_FAIL:-0}" -eq 0 ] || exit 1
  [ "${FAKE_TMUX_EXPLICIT+x}" = x ] && printf '%s\n' "$FAKE_TMUX_EXPLICIT"
  exit 0
fi
SH

  chmod +x "$TEST_ROOT/bin/curl" "$TEST_ROOT/bin/opencode" \
    "$TEST_ROOT/bin/tmux"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "outside tmux OpenCode runs directly with its arguments and status" {
  unset TMUX TMUX_PANE FAKE_TMUX_EXPLICIT
  export FAKE_OPENCODE_STATUS=23

  run sh -c '. "$1"; shift; opencode "$@"' sh "$INTERACTIVE_SH" \
    "argument with spaces" --flag

  [ "$status" -eq 23 ]
  [ "$(<"$FAKE_LOG")" = "opencode <argument with spaces> <--flag>" ]
}

@test "inside tmux an inherited passthrough option is enabled then unset" {
  export TMUX=/tmp/tmux-test TMUX_PANE=%7 FAKE_OPENCODE_STATUS=17
  unset FAKE_TMUX_EXPLICIT

  run sh -c '. "$1"; shift; opencode "$@"' sh "$INTERACTIVE_SH" copy-test

  [ "$status" -eq 17 ] || {
    printf 'expected status 17, got %s; output: %s\n' "$status" "$output" >&3
    false
  }
  [ "$(<"$FAKE_LOG")" = "$(cat <<'EOF'
tmux:show-options -p -v -t %7 allow-passthrough
tmux:set-option -p -t %7 allow-passthrough on
opencode <copy-test>
tmux:set-option -p -u -t %7 allow-passthrough
EOF
)" ]
}

@test "inside tmux an explicit passthrough value is restored exactly" {
  export TMUX=/tmp/tmux-test TMUX_PANE=%9 FAKE_TMUX_EXPLICIT=off

  run sh -c '. "$1"; opencode' sh "$INTERACTIVE_SH"

  [ "$status" -eq 0 ]
  [ "$(<"$FAKE_LOG")" = "$(cat <<'EOF'
tmux:show-options -p -v -t %9 allow-passthrough
tmux:set-option -p -t %9 allow-passthrough on
opencode
tmux:set-option -p -t %9 allow-passthrough off
EOF
)" ]
}

@test "a tmux query failure does not launch OpenCode" {
  export TMUX=/tmp/tmux-test TMUX_PANE=%3 FAKE_TMUX_QUERY_FAIL=1

  run sh -c '. "$1"; opencode' sh "$INTERACTIVE_SH"

  [ "$status" -ne 0 ]
  [ "$(<"$FAKE_LOG")" = \
    "tmux:show-options -p -v -t %3 allow-passthrough" ]
}
