# shellcheck shell=bash
#
# env command - manage machine-specific environment variables.
#
#   dotfiles env [status]         show per-host state of all declared vars
#   dotfiles env set VAR VALUE    set VAR for this host
#   dotfiles env skip VAR         mark VAR not-relevant here (@skip)
#   dotfiles env add VAR [desc]   declare a new machine-specific var (registry)
#   dotfiles env unset VAR        remove VAR from this host's values

# --- mutations ------------------------------------------------------------

_df_env_add_registry() {
  local var=$1 desc=$2 reg; reg=$(df_menv_registry)
  mkdir -p -- "$(dirname -- "$reg")"
  if df_menv_is_registered "$var"; then return 0; fi
  [[ -f "$reg" ]] || printf '# Machine-specific environment variables (registry). Format: VARNAME: description\n' >"$reg"
  printf '%s: %s\n' "$var" "${desc:-machine-specific}" >>"$reg"
}

# Write/update or remove (val="") a KEY in this host's machine-env file.
_df_env_write() {
  local var=$1 val=$2 remove=${3:-0} file line k found=0 tmp
  file=$(df_menv_host_file)
  mkdir -p -- "$(dirname -- "$file")"
  tmp=$(mktemp)
  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      k=${line%%=*}
      if [[ "$line" != \#* && "$k" == "$var" ]]; then
        found=1
        (( remove )) || printf '%s=%s\n' "$var" "$val" >>"$tmp"
      else
        printf '%s\n' "$line" >>"$tmp"
      fi
    done <"$file"
  else
    printf '# Machine-specific env values for %s.\n# KEY=VALUE, one per line; @skip = not relevant here. Managed by '\''dotfiles env'\''.\n' "$(df_hostname)" >>"$tmp"
  fi
  (( found || remove )) || printf '%s=%s\n' "$var" "$val" >>"$tmp"
  mv -- "$tmp" "$file"
}

_df_env_apply_hint() {
  df_dim "run 'dotfiles link' (first value on a host creates the ~/.config/shell/machine-env link), open a new shell, then commit"
}

# --- subcommands ----------------------------------------------------------

_df_env_valid_name() {
  case "$1" in [A-Za-z_]*) : ;; *) return 1 ;; esac
  case "$1" in *[!A-Za-z0-9_]*) return 1 ;; esac
  return 0
}

df_env_status() {
  local host; host=$(df_hostname)
  df_info "machine-specific env - $host"
  if [[ ! -f "$(df_menv_registry)" ]]; then
    df_dim "  no registry yet; declare a var with 'dotfiles env add VAR [description]'"
    return 0
  fi
  local var state desc nconf=0 had=0 hf h hv other
  while IFS= read -r var; do
    [[ -n "$var" ]] || continue
    had=1
    state=$(df_menv_state "$var" "$host")
    desc=$(df_menv_desc "$var")
    case "$state" in
      set:*) printf '  %s%-20s%s = %s\n'      "$DF_C_GREEN"  "$var" "$DF_C_RESET" "${state#set:}" >&2 ;;
      skip)  printf '  %s%-20s skipped here%s\n' "$DF_C_DIM" "$var" "$DF_C_RESET" >&2 ;;
      unset) printf '  %s%-20s UNSET%s  %s%s%s\n' "$DF_C_YELLOW" "$var" "$DF_C_RESET" "$DF_C_DIM" "$desc" "$DF_C_RESET" >&2; nconf=$((nconf+1)) ;;
    esac
    other=""
    while IFS= read -r hf; do
      [[ -n "$hf" ]] || continue
      h=$(df_menv_file_host "$hf"); [[ "$h" == "$host" ]] && continue
      if hv=$(df_menv_file_value "$hf" "$var"); then other+=" $h=$hv"; fi
    done < <(df_menv_host_files)
    [[ -n "$other" ]] && printf '      %sother hosts:%s%s\n' "$DF_C_DIM" "$DF_C_RESET" "$other" >&2
  done < <(df_menv_vars)
  (( had )) || df_dim "  (no vars declared)"
  if (( nconf > 0 )); then
    df_warn "$nconf unset - 'dotfiles env set VAR VALUE' or 'dotfiles env skip VAR'"
    return 1
  fi
  return 0
}

df_env_set() {
  [[ $# -ge 2 ]] || df_die "usage: dotfiles env set VAR VALUE"
  local var=$1 val=$2
  _df_env_valid_name "$var" || df_die "env: invalid variable name '$var'"
  df_menv_is_registered "$var" || { df_warn "'$var' not declared; adding it to the registry"; _df_env_add_registry "$var" ""; }
  _df_env_write "$var" "$val"
  df_ok "set $var=$val for $(df_hostname)"
  _df_env_apply_hint
}

df_env_skip() {
  [[ $# -ge 1 ]] || df_die "usage: dotfiles env skip VAR"
  local var=$1
  _df_env_valid_name "$var" || df_die "env: invalid variable name '$var'"
  df_menv_is_registered "$var" || { df_warn "'$var' not declared; adding it to the registry"; _df_env_add_registry "$var" ""; }
  _df_env_write "$var" "$DF_MENV_SKIP"
  df_ok "marked $var as not-relevant (@skip) for $(df_hostname)"
  _df_env_apply_hint
}

df_env_add() {
  [[ $# -ge 1 ]] || df_die "usage: dotfiles env add VAR [description]"
  local var=$1; shift
  _df_env_valid_name "$var" || df_die "env: invalid variable name '$var'"
  if df_menv_is_registered "$var"; then df_ok "$var already declared"; return 0; fi
  _df_env_add_registry "$var" "$*"
  df_ok "declared $var in the registry (set a value with 'dotfiles env set $var VALUE')"
}

df_env_unset() {
  [[ $# -ge 1 ]] || df_die "usage: dotfiles env unset VAR"
  local var=$1
  _df_env_write "$var" "" 1
  df_ok "removed $var from $(df_hostname)'s values"
  _df_env_apply_hint
}

df_cmd_env() {
  local sub=${1:-status}
  [[ $# -gt 0 ]] && shift || true
  case "$sub" in
    status|show) df_env_status ;;
    set)         df_env_set "$@" ;;
    skip)        df_env_skip "$@" ;;
    add)         df_env_add "$@" ;;
    unset|rm)    df_env_unset "$@" ;;
    *)           df_die "env: unknown subcommand '$sub' (status|set|skip|add|unset)" ;;
  esac
}
