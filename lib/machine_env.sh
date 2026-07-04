# shellcheck shell=bash
#
# machine_env.sh - read/analyse machine-specific environment variables.
#
# Two data sources, both in the repo:
#   * Registry (shared):  home/.config/shell/machine-env.registry
#       Declares which env vars vary per machine.  Format: "VARNAME: description"
#   * Per-host values:    hosts/<hostname>/.config/shell/machine-env
#       KEY=VALUE lines; a value of "@skip" means "declared but not relevant
#       on this host" (so it is intentionally left unset).
#
# The shared shell loader (env.sh) exports the current host's values; this
# library powers `dotfiles env`, and the doctor/sync awareness checks.

[[ -n "${_DF_MENV_SOURCED:-}" ]] && return 0
_DF_MENV_SOURCED=1

DF_MENV_SKIP="@skip"

df_menv_registry() { printf '%s/%s/.config/shell/machine-env.registry' "$DF_REPO" "$DF_HOME_LAYER"; }

df_menv_host_file() {
  local host=${1:-}; [[ -n "$host" ]] || host=$(df_hostname)
  printf '%s/%s/%s/.config/shell/machine-env' "$DF_REPO" "$DF_HOSTS_DIR" "$host"
}

# Declared variable names, one per line.
df_menv_vars() {
  local f line var; f=$(df_menv_registry)
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in \#*|'') continue ;; esac
    case "$line" in *:*) : ;; *) continue ;; esac
    var=${line%%:*}
    var=$(printf '%s' "$var" | tr -d '[:space:]')
    [[ -n "$var" ]] && printf '%s\n' "$var"
  done < "$f"
}

# Description for a declared var (empty if none).
df_menv_desc() {
  local f line var=$1 k d; f=$(df_menv_registry)
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in \#*|'') continue ;; esac
    k=${line%%:*}; k=$(printf '%s' "$k" | tr -d '[:space:]')
    [[ "$k" == "$var" ]] || continue
    d=${line#*:}; d=${d# }; printf '%s' "$d"; return 0
  done < "$f"
}

df_menv_is_registered() {
  local var=$1 v
  while IFS= read -r v; do [[ "$v" == "$var" ]] && return 0; done < <(df_menv_vars)
  return 1
}

# Value of VAR in a machine-env FILE. Prints the value and returns 0 if present
# (including "@skip"); returns 1 if the var has no entry.
df_menv_file_value() {
  local file=$1 var=$2 line k out="" found=1
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in \#*|'') continue ;; esac
    k=${line%%=*}
    [[ "$k" == "$var" ]] || continue
    out=${line#*=}; found=0
  done < "$file"
  (( found == 0 )) || return 1
  printf '%s' "$out"
}

# State of VAR on a host: prints "set:VALUE" | "skip" | "unset".
df_menv_state() {
  local var=$1 host=${2:-} val
  if val=$(df_menv_file_value "$(df_menv_host_file "$host")" "$var"); then
    if [[ "$val" == "$DF_MENV_SKIP" ]]; then printf 'skip'; else printf 'set:%s' "$val"; fi
  else
    printf 'unset'
  fi
}

# Declared vars that are unset AND not skipped on the current host.
df_menv_unconfigured() {
  local var
  while IFS= read -r var; do
    [[ -n "$var" ]] || continue
    [[ "$(df_menv_state "$var")" == "unset" ]] && printf '%s\n' "$var"
  done < <(df_menv_vars)
}

# All host machine-env files that exist (absolute paths).
df_menv_host_files() {
  ( shopt -s nullglob
    local d
    for d in "$DF_REPO/$DF_HOSTS_DIR"/*/.config/shell/machine-env; do printf '%s\n' "$d"; done )
}

# Host name owning a machine-env file path.
df_menv_file_host() {
  local f=$1
  f=${f%/.config/shell/machine-env}
  printf '%s' "${f##*/}"
}
