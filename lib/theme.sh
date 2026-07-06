# shellcheck shell=bash
#
# theme.sh - Theme resolution.
#
# A theme is a layer directory under themes/<name>/ that mirrors $HOME and
# ships color-coordinated variants of config files. The active theme is
# determined by (first match wins):
#   0. Machine-local auto-theming flag (wallpaper-derived): themes/auto
#   1. Machine-local selection: $XDG_STATE_HOME/dotfiles/theme (set by `theme set`)
#   2. Per-host committed override: hosts/<hostname>/.config/dotfiles/theme
#   3. Repo default:      themes/default
#   4. Hardcoded fallback: $DF_THEME_FALLBACK (catppuccin-mocha)

[[ -n "${_DF_THEME_SOURCED:-}" ]] && return 0
_DF_THEME_SOURCED=1

# Read + trim the first line of a file; print it if non-empty (returns 1 else).
_df_theme_read() {
  local f=$1 name
  [[ -f "$f" ]] || return 1
  name=$(head -1 "$f" 2>/dev/null || true)
  name=$(printf '%s' "$name" | tr -d '[:space:]')
  [[ -n "$name" ]] || return 1
  printf '%s' "$name"
}

# Name of the resolved theme: reads the first available source.
df_theme_name() {
  local host name

  # Machine-local auto-theming wins when enabled (never committed).
  if df_autotheme_enabled; then
    printf '%s' "$DF_AUTO_THEME_NAME"
    return 0
  fi

  # Machine-local selection (never committed; set by `dotfiles theme set`).
  name=$(_df_theme_read "$(df_state_theme_file)") && { printf '%s' "$name"; return 0; }

  # Committed per-host override (optional, synced).
  host=$(df_hostname)
  name=$(_df_theme_read "$DF_REPO/$DF_HOSTS_DIR/$host/.config/dotfiles/theme") \
    && { printf '%s' "$name"; return 0; }

  # Committed repo-wide default.
  name=$(_df_theme_read "$DF_REPO/$DF_THEMES_DIR/default") \
    && { printf '%s' "$name"; return 0; }

  printf '%s' "$DF_THEME_FALLBACK"
}

# Absolute path to the active theme layer directory (empty if missing).
df_theme_dir() {
  local name dir
  name=$(df_theme_name)
  dir="$DF_REPO/$DF_THEMES_DIR/$name"
  [[ -d "$dir" ]] && printf '%s' "$dir" || printf ''
}

# List available themes (themes/* dirs, excluding auto).
df_available_themes() {
  (
    shopt -s nullglob
    local d
    for d in "$DF_REPO/$DF_THEMES_DIR"/*/; do
      local base; base=$(basename -- "$d")
      [[ "$base" == "auto" ]] && continue
      [[ -d "$d" ]] && printf '%s\n' "$base"
    done
  )
}
