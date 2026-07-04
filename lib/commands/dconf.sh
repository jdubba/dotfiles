# shellcheck shell=bash
#
# dconf command - manage GNOME/dconf settings, which are not files and so
# cannot be symlinked. Keeps a plain-text keyfile in the repo that can be
# dumped from / loaded into the live dconf database.
#
#   dotfiles dconf dump [keyfile]   # snapshot live settings -> keyfile
#   dotfiles dconf load [keyfile]   # apply keyfile -> live settings
#
# Default keyfile: profiles/gnome/dconf/user.ini

df_cmd_dconf() {
  local sub=${1:-}
  [[ $# -gt 0 ]] && shift || true

  command -v dconf >/dev/null 2>&1 || df_die "dconf not found (GNOME/dconf systems only)"

  local default_file="$DF_REPO/$DF_PROFILES_DIR/gnome/dconf/user.ini"
  local file=${1:-$default_file}
  local dir=${DF_DCONF_DIR:-/}

  case "$sub" in
    dump)
      mkdir -p -- "$(dirname -- "$file")"
      dconf dump "$dir" >"$file"
      df_ok "dumped dconf $dir -> ${file/#$DF_REPO\//}"
      df_dim "review, then commit the keyfile"
      ;;
    load)
      [[ -f "$file" ]] || df_die "no such keyfile: $file"
      dconf load "$dir" <"$file"
      df_ok "loaded ${file/#$DF_REPO\//} -> dconf $dir"
      ;;
    *)
      df_die "usage: dotfiles dconf dump|load [keyfile]"
      ;;
  esac
}
