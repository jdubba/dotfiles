# shellcheck shell=bash
#
# link command - create/repair symlinks for this machine's active layers.

df_cmd_link() {
  local dry_run=0 verbose=0 arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run|-n) dry_run=1 ;;
      -v|--verbose) verbose=1 ;;
      *) df_die "link: unknown option '$arg'" ;;
    esac
  done

  df_resolve_layers
  if [[ ${#DF_LAYERS[@]} -eq 0 ]]; then
    df_die "no layers found (expected at least '$DF_HOME_LAYER/' in the repo)"
  fi

  df_build_plan
  trap df_cleanup_plan RETURN

  local n_change
  n_change=$(( $(df_plan_count LINK) + $(df_plan_count REPAIR) + $(df_plan_count MKDIR) ))

  if (( dry_run )); then
    df_info "plan (dry run) - no changes will be made:"
    df_print_plan "$verbose"
    if df_plan_has_conflicts; then
      df_warn "$(df_plan_count CONFLICT) conflict(s) would be skipped"
      return 1
    fi
    (( n_change == 0 )) && df_ok "everything already linked"
    return 0
  fi

  if (( n_change == 0 )) && ! df_plan_has_conflicts; then
    df_ok "everything already linked"
    return 0
  fi

  df_print_plan "$verbose"
  df_apply_plan
}
