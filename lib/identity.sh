# shellcheck shell=bash
#
# identity.sh - Detect this machine's identity and resolve the ordered set of
# layers that apply to it.
#
# Layer application order (later layers override / add to earlier ones):
#   1. home/                       always
#   2. profiles/<name>/            each active profile, in a stable order
#   3. hosts/<hostname>/           this machine, if the directory exists
#
# A profile is "active" when it is either auto-detected (its name matches the
# distro id, the distro family, or the current desktop) or explicitly enabled
# in machine state - AND a directory of that name exists under profiles/.

[[ -n "${_DF_IDENTITY_SOURCED:-}" ]] && return 0
_DF_IDENTITY_SOURCED=1

# Short hostname, lowercased, domain stripped.
df_hostname() {
  local h
  h=$(hostname 2>/dev/null || uname -n 2>/dev/null || printf 'unknown')
  h=${h%%.*}
  printf '%s' "${h,,}"
}

# os-release ID (e.g. "fedora", "gentoo"). Empty if undetectable.
df_distro_id() {
  local id=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    id=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}") || id=""
  fi
  printf '%s' "${id,,}"
}

# os-release ID_LIKE tokens (e.g. "rhel fedora"). Space separated, lowercased.
df_distro_like() {
  local like=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    like=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID_LIKE:-}") || like=""
  fi
  printf '%s' "${like,,}"
}

# Current desktop tokens from XDG_CURRENT_DESKTOP (colon separated), lowercased.
df_desktop() {
  local d=${XDG_CURRENT_DESKTOP:-}
  printf '%s' "${d,,}" | tr ':' ' '
}

# Print the auto-detected candidate profile names (may not all exist as dirs).
df_auto_profile_candidates() {
  local tok
  df_distro_id
  printf '\n'
  for tok in $(df_distro_like); do printf '%s\n' "$tok"; done
  for tok in $(df_desktop); do printf '%s\n' "$tok"; done
}

# Print the active profile names, one per line, deduplicated, in order:
# auto-detected first, then explicitly enabled. Only names with an existing
# profiles/<name>/ directory are emitted.
df_active_profiles() {
  local seen=" " name
  {
    df_auto_profile_candidates
    df_read_enabled_profiles
  } | while IFS= read -r name; do
    name=$(df_clean_rel "$name")
    [[ -z "$name" ]] && continue
    # Deduplicate.
    [[ "$seen" == *" $name "* ]] && continue
    seen+="$name "
    # Must correspond to a real profile directory.
    if [[ -d "$DF_REPO/$DF_PROFILES_DIR/$name" ]]; then
      printf '%s\n' "$name"
    fi
  done
}

# Print the ordered list of absolute layer directories that exist.
df_layers() {
  local host; host=$(df_hostname)
  local p

  [[ -d "$DF_REPO/$DF_HOME_LAYER" ]] && printf '%s\n' "$DF_REPO/$DF_HOME_LAYER"

  while IFS= read -r p; do
    [[ -n "$p" ]] && printf '%s\n' "$DF_REPO/$DF_PROFILES_DIR/$p"
  done < <(df_active_profiles)

  [[ -d "$DF_REPO/$DF_HOSTS_DIR/$host" ]] && printf '%s\n' "$DF_REPO/$DF_HOSTS_DIR/$host"
}

# Populate the global array DF_LAYERS with the ordered layer directories.
df_resolve_layers() {
  DF_LAYERS=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && DF_LAYERS+=("$line")
  done < <(df_layers)
  df_debug "resolved layers: ${DF_LAYERS[*]:-<none>}"
}
