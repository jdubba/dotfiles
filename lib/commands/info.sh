# shellcheck shell=bash
#
# info command - show detected identity and the layers that apply here.

df_cmd_info() {
  df_resolve_layers
  df_info "identity"
  printf '  hostname:      %s\n' "$(df_hostname)" >&2
  printf '  distro id:     %s\n' "$(df_distro_id)" >&2
  printf '  distro family: %s\n' "$(df_distro_like)" >&2
  printf '  desktop:       %s\n' "$(df_desktop)" >&2
  printf '  target root:   %s\n' "$DF_TARGET" >&2
  printf '  theme:         %s\n' "$(df_theme_name)" >&2

  df_log ""
  df_info "active profiles"
  local p had=0
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    printf '  %s\n' "$p" >&2; had=1
  done < <(df_active_profiles)
  (( had )) || df_dim "  (none)"

  df_log ""
  df_info "layers (applied in order)"
  local l
  for l in "${DF_LAYERS[@]}"; do
    printf '  %s\n' "${l/#$DF_REPO\//}" >&2
  done
  [[ ${#DF_LAYERS[@]} -eq 0 ]] && df_dim "  (none)"

  df_log ""
  df_dim "protected container directories: ${#DF_CONTAINER_DIRS[@]} (never folded)"
}
