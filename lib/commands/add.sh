# shellcheck shell=bash
#
# add command - adopt an existing file/dir into a layer and link it back.
#
# This is the ONLY operation that moves real files into the repository, and it
# is always explicit and per-path. `link`/`sync` never adopt anything.

df_cmd_add() {
  local path="" dest="home" arg
  while [[ $# -gt 0 ]]; do
    arg=$1; shift
    case "$arg" in
      --to)      dest=${1:-}; shift || df_die "add: --to requires a value" ;;
      --host)    dest="host" ;;
      --profile) dest="profile:${1:-}"; shift || df_die "add: --profile requires a name" ;;
      -*)        df_die "add: unknown option '$arg'" ;;
      *)         if [[ -z "$path" ]]; then path=$arg; else df_die "add: unexpected argument '$arg'"; fi ;;
    esac
  done
  [[ -n "$path" ]] || df_die "add: no path given (usage: dotfiles add <path> [--to home|host|profile:<name>])"

  # Resolve destination layer directory.
  local layer_dir host
  host=$(df_hostname)
  case "$dest" in
    home)          layer_dir="$DF_REPO/$DF_HOME_LAYER" ;;
    host)          layer_dir="$DF_REPO/$DF_HOSTS_DIR/$host" ;;
    profile:?*)    layer_dir="$DF_REPO/$DF_PROFILES_DIR/${dest#profile:}" ;;
    *)             df_die "add: invalid destination '$dest' (use home | host | profile:<name>)" ;;
  esac

  # Normalise the source path and verify it lives under the target root.
  local abs; abs=$(realpath -m -- "$path")
  local resolved; resolved=$(realpath -m -- "$abs")
  if [[ "$resolved" == "$DF_REPO"/* ]]; then
    df_ok "already managed (resolves into the repo): $path"
    return 0
  fi
  if [[ "$abs" != "$DF_TARGET"/* ]]; then
    df_die "add: path must be inside $DF_TARGET"
  fi
  [[ -e "$abs" || -L "$abs" ]] || df_die "add: no such file or directory: $path"

  local rel=${abs#"$DF_TARGET"/}

  if df_is_container "$rel"; then
    df_die "add: refusing to adopt container directory ~/$rel (add specific children instead)"
  fi

  local target_dest="$layer_dir/$rel"
  if [[ -e "$target_dest" || -L "$target_dest" ]]; then
    df_die "add: already exists in layer: ${target_dest/#$DF_REPO\//}"
  fi

  df_info "adopting ~/$rel -> ${layer_dir/#$DF_REPO\//}/$rel"
  mkdir -p -- "$(dirname -- "$target_dest")"
  mv -- "$abs" "$target_dest"

  # Link it back into place (fold: dir or file).
  ln -s -- "$target_dest" "$abs"

  df_ok "adopted and linked ~/$rel"
  df_dim "review, then commit: git -C '$DF_REPO' add -A && git -C '$DF_REPO' commit"
}
