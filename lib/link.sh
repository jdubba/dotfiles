# shellcheck shell=bash
#
# link.sh - The safe linker.
#
# Responsibilities:
#   * Compute a PLAN of link actions from the active layers (never mutating
#     anything during planning).
#   * Enforce the safety guarantees:
#       - Container directories are never folded into a symlink.
#       - Real files/dirs the repo does not own are never clobbered or
#         adopted; they are reported as CONFLICTs instead.
#       - Directories solely owned by one layer are folded; directories with
#         contributions from multiple layers auto-unfold to file links.
#   * Apply the plan idempotently.
#
# Plan file format: tab-separated  ACTION <TAB> REL <TAB> SRC <TAB> NOTE
# Actions: LINK REPAIR MKDIR OK CONFLICT

[[ -n "${_DF_LINK_SOURCED:-}" ]] && return 0
_DF_LINK_SOURCED=1

DF_PLAN_FILE=""

# List immediate child basenames across all active layers for a given
# $HOME-relative directory, deduplicated and sorted, skipping ignored names.
df_layer_children() {
  local rel=$1
  # Run in a subshell so nullglob/dotglob are isolated and never need to be
  # saved/restored (shopt -p returns non-zero when an option is off, which
  # interacts badly with `set -e`).
  (
    shopt -s nullglob dotglob
    local layer dir path name
    for layer in "${DF_LAYERS[@]}"; do
      dir="$layer"; [[ -n "$rel" ]] && dir="$layer/$rel"
      [[ -d "$dir" && ! -L "$dir" ]] || continue
      for path in "$dir"/*; do
        name=${path##*/}
        df_is_ignored_name "$name" && continue
        printf '%s\n' "$name"
      done
    done
  ) | sort -u
}

df_plan_emit() {
  # action rel src note
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "${3:--}" "${4:-}" >>"$DF_PLAN_FILE"
}

_df_dir_is_empty() {
  [[ -z "$(ls -A -- "$1" 2>/dev/null)" ]]
}

# Plan the creation of a real directory at rel (container / unfold point).
df_plan_mkdir() {
  local rel=$1 target; target=$(df_target_path "$rel")
  [[ -z "$rel" ]] && return 0                     # target root always exists
  if [[ -d "$target" && ! -L "$target" ]]; then
    return 0                                       # already a real directory
  fi
  if df_is_repo_link "$target"; then
    # A previous fold created this symlink; it must now become a real dir so
    # sibling layers can contribute. Safe: we own the link.
    df_plan_emit MKDIR "$rel" - "convert managed symlink to real directory"
  elif [[ -L "$target" ]]; then
    df_plan_emit CONFLICT "$rel" - "foreign symlink where a directory is required"
  elif [[ -e "$target" ]]; then
    df_plan_emit CONFLICT "$rel" - "file exists where a directory is required"
  else
    df_plan_emit MKDIR "$rel" - "create directory"
  fi
}

# Plan a symlink at rel -> src. kind is "dir" or "file".
df_plan_symlink() {
  local rel=$1 src=$2 kind=$3 target; target=$(df_target_path "$rel")
  if df_link_points_to "$target" "$src"; then
    df_plan_emit OK "$rel" "$src" "already linked"
    return 0
  fi
  if df_is_repo_link "$target"; then
    df_plan_emit REPAIR "$rel" "$src" "relink (was pointing elsewhere in repo)"
    return 0
  fi
  if [[ -L "$target" ]]; then
    df_plan_emit CONFLICT "$rel" "$src" "foreign symlink in the way"
    return 0
  fi
  if [[ ! -e "$target" ]]; then
    df_plan_emit LINK "$rel" "$src" "$kind"
    return 0
  fi
  # A real file or directory the repo does not own is present.
  if [[ "$kind" == "dir" && -d "$target" ]]; then
    if _df_dir_is_empty "$target"; then
      df_plan_emit LINK "$rel" "$src" "dir (replacing empty directory)"
    else
      df_plan_emit CONFLICT "$rel" "$src" "directory exists with unmanaged contents (use 'dotfiles add' to adopt)"
    fi
    return 0
  fi
  df_plan_emit CONFLICT "$rel" "$src" "file exists (use 'dotfiles add' to adopt)"
}

# Recursively plan the tree rooted at rel ("" == target root).
df_plan_tree() {
  local rel=$1 layer src sole="" winning="" n=0 has_dir=0 has_file=0
  for layer in "${DF_LAYERS[@]}"; do
    src="$layer"; [[ -n "$rel" ]] && src="$layer/$rel"
    if [[ -e "$src" || -L "$src" ]]; then
      n=$((n + 1)); sole="$src"; winning="$src"
      if [[ -d "$src" && ! -L "$src" ]]; then has_dir=1; else has_file=1; fi
    fi
  done
  (( n == 0 )) && return 0

  if (( has_dir && has_file )); then
    df_plan_emit CONFLICT "$rel" - "layers disagree on type (file vs directory)"
    return 0
  fi

  if (( has_dir )); then
    if [[ -z "$rel" ]] || df_is_container "$rel" || df_contains_container "$rel" || (( n > 1 )); then
      # UNFOLD: keep as a real directory and descend.
      df_plan_mkdir "$rel"
      local child
      while IFS= read -r child; do
        [[ -z "$child" ]] && continue
        if [[ -z "$rel" ]]; then df_plan_tree "$child"; else df_plan_tree "$rel/$child"; fi
      done < <(df_layer_children "$rel")
    else
      # FOLD: solely owned, non-container directory.
      df_plan_symlink "$rel" "$sole" "dir"
    fi
  else
    # FILE (or a symlink committed inside the repo): last layer wins.
    df_plan_symlink "$rel" "$winning" "file"
  fi
}

# Build the plan into DF_PLAN_FILE. Requires DF_LAYERS to be resolved.
df_build_plan() {
  DF_PLAN_FILE=$(mktemp "${TMPDIR:-/tmp}/dotfiles-plan.XXXXXX")
  : >"$DF_PLAN_FILE"
  if [[ ${#DF_LAYERS[@]} -eq 0 ]]; then
    df_warn "no layers resolved; nothing to link"
    return 0
  fi
  df_plan_tree ""
}

df_plan_count() {
  # $1 = action. grep -c prints a count (0 when none) but exits 1 on no match,
  # so guard against `set -e`.
  local n
  n=$(grep -c "^$1"$'\t' "$DF_PLAN_FILE" 2>/dev/null || true)
  [[ -n "$n" ]] || n=0
  printf '%s' "$n"
}

df_plan_has_conflicts() {
  [[ "$(df_plan_count CONFLICT)" -gt 0 ]]
}

# Human-readable rendering of the plan. $1=show_ok (1/0)
df_print_plan() {
  local show_ok=${1:-0} action rel src note label
  while IFS=$'\t' read -r action rel src note; do
    case "$action" in
      OK) (( show_ok )) || continue; label="${DF_C_DIM}ok     ${DF_C_RESET}" ;;
      LINK)     label="${DF_C_GREEN}link   ${DF_C_RESET}" ;;
      REPAIR)   label="${DF_C_YELLOW}relink ${DF_C_RESET}" ;;
      MKDIR)    label="${DF_C_BLUE}mkdir  ${DF_C_RESET}" ;;
      CONFLICT) label="${DF_C_RED}CONFLICT${DF_C_RESET}" ;;
      *)        label="$action" ;;
    esac
    printf '  %s ~/%s' "$label" "$rel" >&2
    [[ "$action" == "CONFLICT" ]] && printf ' %s(%s)%s' "$DF_C_DIM" "$note" "$DF_C_RESET" >&2
    printf '\n' >&2
  done <"$DF_PLAN_FILE"
}

# Create a symlink at target -> src, safely removing only things we own.
_df_place_symlink() {
  local src=$1 target=$2
  if [[ -L "$target" ]]; then
    rm -f -- "$target"
  elif [[ -d "$target" && ! -L "$target" ]]; then
    rmdir -- "$target" || { df_error "refusing to remove non-empty directory: $target"; return 1; }
  fi
  mkdir -p -- "$(dirname -- "$target")"
  ln -s -- "$src" "$target"
}

# Apply the plan. Returns non-zero if any conflicts were present.
df_apply_plan() {
  local action rel src note target
  local n_link=0 n_repair=0 n_mkdir=0 n_conflict=0
  while IFS=$'\t' read -r action rel src note; do
    target=$(df_target_path "$rel")
    case "$action" in
      LINK|REPAIR)
        if _df_place_symlink "$src" "$target"; then
          [[ "$action" == LINK ]] && n_link=$((n_link+1)) || n_repair=$((n_repair+1))
        fi
        ;;
      MKDIR)
        if df_is_repo_link "$target"; then rm -f -- "$target"; fi
        mkdir -p -- "$target" && n_mkdir=$((n_mkdir+1))
        ;;
      CONFLICT)
        n_conflict=$((n_conflict+1))
        df_error "conflict: ~/$rel - $note"
        ;;
      OK) : ;;
    esac
  done <"$DF_PLAN_FILE"

  df_ok "linked $n_link, relinked $n_repair, created $n_mkdir directories"
  if (( n_conflict > 0 )); then
    df_warn "$n_conflict conflict(s) left untouched (nothing was overwritten or adopted)"
    return 1
  fi
  return 0
}

df_cleanup_plan() {
  [[ -n "$DF_PLAN_FILE" && -f "$DF_PLAN_FILE" ]] && rm -f -- "$DF_PLAN_FILE"
  DF_PLAN_FILE=""
}
