# shellcheck shell=bash
#
# theme.sh - Theme resolution.
#
# A theme is a layer directory under themes/<name>/ that mirrors $HOME and
# ships color-coordinated variants of config files. The active theme is
# determined by:
#   0. Machine-local auto-theming flag (wallpaper-derived): themes/auto
#   1. Per-host override: hosts/<hostname>/.config/dotfiles/theme
#   2. Repo default:      themes/default
#   3. Hardcoded fallback: $DF_THEME_FALLBACK (catppuccin-mocha)

[[ -n "${_DF_THEME_SOURCED:-}" ]] && return 0
_DF_THEME_SOURCED=1

# Name of the resolved theme: reads the first available source.
df_theme_name() {
  local host override_file default_file name

  # Machine-local auto-theming wins when enabled (never committed).
  if df_autotheme_enabled; then
    printf '%s' "$DF_AUTO_THEME_NAME"
    return 0
  fi

  host=$(df_hostname)
  override_file="$DF_REPO/$DF_HOSTS_DIR/$host/.config/dotfiles/theme"
  default_file="$DF_REPO/$DF_THEMES_DIR/default"

  if [[ -f "$override_file" ]]; then
    name=$(head -1 "$override_file" 2>/dev/null || true)
    name=$(printf '%s' "$name" | tr -d '[:space:]')
    [[ -n "$name" ]] && { printf '%s' "$name"; return 0; }
  fi

  if [[ -f "$default_file" ]]; then
    name=$(head -1 "$default_file" 2>/dev/null || true)
    name=$(printf '%s' "$name" | tr -d '[:space:]')
    [[ -n "$name" ]] && { printf '%s' "$name"; return 0; }
  fi

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
