#!/usr/bin/env bats
# env.bats - machine-specific environment variables.

setup() { load test_helper; setup_sandbox; }
teardown() { teardown_sandbox; }

reg() { printf '%s/home/.config/shell/machine-env.registry' "$DF_TEST_REPO"; }
hostenv() { printf '%s/hosts/%s/.config/shell/machine-env' "$DF_TEST_REPO" "$(df_host)"; }

@test "env add declares a var in the registry" {
  run "$DOTFILES" env add AWS_PROFILE "aws profile"
  [ "$status" -eq 0 ]
  grep -q '^AWS_PROFILE:' "$(reg)"
}

@test "env set writes a host value and status shows it" {
  "$DOTFILES" env add AWS_PROFILE "x"
  run "$DOTFILES" env set AWS_PROFILE idkey
  [ "$status" -eq 0 ]
  grep -qx 'AWS_PROFILE=idkey' "$(hostenv)"
  run "$DOTFILES" env status
  [ "$status" -eq 0 ]
  [[ "$output" == *AWS_PROFILE*idkey* ]]
}

@test "env set auto-declares an unregistered var" {
  run "$DOTFILES" env set NEWVAR val
  [ "$status" -eq 0 ]
  grep -q '^NEWVAR:' "$(reg)"
  grep -qx 'NEWVAR=val' "$(hostenv)"
}

@test "env skip marks a var @skip and counts as configured" {
  "$DOTFILES" env add FOO "foo"
  run "$DOTFILES" env skip FOO
  [ "$status" -eq 0 ]
  grep -qx 'FOO=@skip' "$(hostenv)"
  run "$DOTFILES" env status
  [ "$status" -eq 0 ]
  [[ "$output" == *skip* ]]
}

@test "env unset removes a value" {
  "$DOTFILES" env set FOO bar
  run "$DOTFILES" env unset FOO
  [ "$status" -eq 0 ]
  ! grep -q '^FOO=' "$(hostenv)"
}

@test "doctor flags an unset declared var" {
  "$DOTFILES" env add AWS_PROFILE "needs a value"
  run "$DOTFILES" doctor
  [[ "$output" == *AWS_PROFILE* ]]
}

@test "the shared env.sh loader exports values and honors @skip" {
  local cfg="$DF_TEST_TARGET/.config"
  mkdir -p "$cfg/shell"
  printf 'AWS_PROFILE=idkey\nNOPE=@skip\n' >"$cfg/shell/machine-env"
  run bash -c "export XDG_CONFIG_HOME='$cfg'; . '$DF_SRC_REPO/home/.config/shell/env.sh'; echo \"A=\$AWS_PROFILE N=\${NOPE:-unset}\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"A=idkey"* ]]
  [[ "$output" == *"N=unset"* ]]
}
