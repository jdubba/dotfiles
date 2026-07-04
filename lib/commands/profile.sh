# shellcheck shell=bash
#
# profile command - manage machine-local profile selection.
#
# Profiles are activated automatically when their name matches the distro id,
# distro family, or desktop; additional ones can be enabled explicitly here.
# The explicit list is stored per-machine and never committed.

_df_available_profiles() {
  (
    shopt -s nullglob
    local d
    for d in "$DF_REPO/$DF_PROFILES_DIR"/*/; do
      [[ -d "$d" ]] && basename -- "$d"
    done
  )
}

df_cmd_profile() {
  local sub=${1:-show}
  [[ $# -gt 0 ]] && shift || true

  case "$sub" in
    list|show)
      df_info "available profiles:"
      local p active
      active=$(df_active_profiles | tr '\n' ' ')
      while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        if [[ " $active " == *" $p "* ]]; then
          printf '  %s* %s%s (active)\n' "$DF_C_GREEN" "$p" "$DF_C_RESET" >&2
        else
          printf '  %s  %s%s\n' "$DF_C_DIM" "$p" "$DF_C_RESET" >&2
        fi
      done < <(_df_available_profiles)
      df_dim "explicitly enabled: $(df_read_enabled_profiles | tr '\n' ' ')"
      ;;
    enable)
      local name=${1:-}; [[ -n "$name" ]] || df_die "profile enable: name required"
      if [[ ! -d "$DF_REPO/$DF_PROFILES_DIR/$name" ]]; then
        df_warn "no profiles/$name directory yet; enabling anyway (create it to add config)"
      fi
      mkdir -p -- "$DF_STATE_DIR"
      local f; f=$(df_state_profiles_file)
      if grep -qxF "$name" "$f" 2>/dev/null; then
        df_ok "profile '$name' already enabled"
      else
        printf '%s\n' "$name" >>"$f"
        df_ok "enabled profile '$name' (run 'dotfiles link' to apply)"
      fi
      ;;
    disable)
      local name=${1:-}; [[ -n "$name" ]] || df_die "profile disable: name required"
      local f; f=$(df_state_profiles_file)
      [[ -f "$f" ]] || { df_warn "no profiles enabled"; return 0; }
      local tmp; tmp=$(mktemp)
      grep -vxF "$name" "$f" >"$tmp" 2>/dev/null || true
      mv -- "$tmp" "$f"
      df_ok "disabled profile '$name' (run 'dotfiles link'; note: auto-detected profiles stay active)"
      ;;
    *)
      df_die "profile: unknown subcommand '$sub' (use list|enable|disable)"
      ;;
  esac
}
