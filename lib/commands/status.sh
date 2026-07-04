# shellcheck shell=bash
#
# status command - show what link would do plus a short summary. Read-only.

df_cmd_status() {
  local verbose=0 arg
  for arg in "$@"; do
    case "$arg" in
      -v|--verbose) verbose=1 ;;
      *) df_die "status: unknown option '$arg'" ;;
    esac
  done

  df_resolve_layers
  if [[ ${#DF_LAYERS[@]} -eq 0 ]]; then
    df_die "no layers found (expected at least '$DF_HOME_LAYER/' in the repo)"
  fi

  local host; host=$(df_hostname)
  df_info "machine: $host   distro: $(df_distro_id)   layers: ${#DF_LAYERS[@]}"

  df_build_plan
  trap df_cleanup_plan RETURN

  local n_link n_repair n_mkdir n_conflict n_ok
  n_link=$(df_plan_count LINK)
  n_repair=$(df_plan_count REPAIR)
  n_mkdir=$(df_plan_count MKDIR)
  n_conflict=$(df_plan_count CONFLICT)
  n_ok=$(df_plan_count OK)

  if (( n_link + n_repair + n_mkdir + n_conflict == 0 )); then
    df_ok "in sync ($n_ok links verified)"
    (( verbose )) && df_print_plan 1
    return 0
  fi

  df_print_plan "$verbose"
  df_log ""
  df_info "summary: $n_link to link, $n_repair to relink, $n_mkdir dirs, $n_ok ok, $n_conflict conflict(s)"
  if (( n_conflict > 0 )); then
    df_warn "resolve conflicts with 'dotfiles add <path>' (adopt) or by moving the file aside"
    return 1
  fi
  df_dim "run 'dotfiles link' to apply"
}
