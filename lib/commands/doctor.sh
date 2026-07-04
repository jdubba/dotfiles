# shellcheck shell=bash
#
# doctor command - detect (and optionally repair) hazards and broken links.
#
# Primary hazard: a container directory (e.g. ~/.config) that has become a
# symlink into the repo - the exact failure that motivated this rebuild.

# Resolve a symlink's target to an absolute path WITHOUT requiring it to exist
# (so stale/broken links still resolve). Handles relative and absolute targets.
_df_resolve_link_target() {
  local link=$1 lit
  lit=$(readlink -- "$link" 2>/dev/null) || return 1
  if [[ "$lit" == /* ]]; then
    realpath -m -- "$lit" 2>/dev/null
  else
    realpath -m -- "$(dirname -- "$link")/$lit" 2>/dev/null
  fi
}

df_cmd_doctor() {
  local fix=0 arg
  for arg in "$@"; do
    case "$arg" in
      --fix) fix=1 ;;
      *) df_die "doctor: unknown option '$arg'" ;;
    esac
  done

  df_resolve_layers
  local issues=0 fixed=0

  # --- Check 1: container directories must never be symlinks ----------------
  df_info "checking container directories..."
  local rel target
  for rel in "${DF_CONTAINER_DIRS[@]}"; do
    target=$(df_target_path "$rel")
    [[ -e "$target" || -L "$target" ]] || continue
    if [[ -L "$target" ]]; then
      issues=$((issues + 1))
      if df_is_repo_link "$target"; then
        df_error "HAZARD: ~/$rel is a symlink into the repo (folded container)"
        if (( fix )); then
          rm -f -- "$target" && mkdir -p -- "$target" \
            && { df_ok "  fixed: replaced with a real directory"; fixed=$((fixed + 1)); }
        else
          df_dim "  run 'dotfiles doctor --fix' then 'dotfiles link' to repair"
        fi
      else
        df_error "HAZARD: ~/$rel is a symlink (points outside the repo): $(readlink -- "$target")"
        df_dim "  left untouched - resolve manually"
      fi
    fi
  done

  # --- Check 2: broken managed symlinks (repo source removed / moved) -------
  # Catches links left by a previous tool (e.g. Stow's relative links into the
  # old config/ path) that dangle after migration, as long as they resolve
  # into this repo.
  df_info "checking for broken links into the repo..."
  local -a scan_roots=("$DF_TARGET")
  for rel in "${DF_CONTAINER_DIRS[@]}"; do
    [[ -d "$(df_target_path "$rel")" ]] && scan_roots+=("$(df_target_path "$rel")")
  done
  local link resolved root
  while IFS= read -r link; do
    [[ -n "$link" ]] || continue
    resolved=$(_df_resolve_link_target "$link") || continue
    [[ "$resolved" == "$DF_REPO"/* || "$resolved" == "$DF_REPO" ]] || continue
    issues=$((issues + 1))
    df_warn "broken link: ${link/#$DF_TARGET/\~} -> $(readlink -- "$link")"
    if (( fix )); then
      rm -f -- "$link" && { df_ok "  removed"; fixed=$((fixed + 1)); }
    fi
  done < <(
    for root in "${scan_roots[@]}"; do
      find "$root" -maxdepth 2 -xtype l 2>/dev/null || true
    done | sort -u
  )

  # --- Check 3: drift / conflicts via the plan ------------------------------
  if [[ ${#DF_LAYERS[@]} -gt 0 ]]; then
    df_info "checking link state..."
    df_build_plan
    trap df_cleanup_plan RETURN
    local n_change n_conflict
    n_change=$(( $(df_plan_count LINK) + $(df_plan_count REPAIR) + $(df_plan_count MKDIR) ))
    n_conflict=$(df_plan_count CONFLICT)
    if (( n_conflict > 0 )); then
      issues=$((issues + n_conflict))
      df_warn "$n_conflict conflict(s) - see 'dotfiles status'"
    fi
    if (( n_change > 0 )); then
      df_dim "$n_change managed link(s) missing/out-of-date - run 'dotfiles link'"
    fi
  fi

  df_log ""
  if (( issues == 0 )); then
    df_ok "no problems found"
    return 0
  fi
  if (( fix )); then
    df_info "fixed $fixed of $issues issue(s); re-run 'dotfiles link' to finish"
  else
    df_warn "$issues issue(s) found; re-run with --fix to repair what is safe"
  fi
  return 1
}
