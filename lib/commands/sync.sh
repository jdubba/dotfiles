# shellcheck shell=bash
#
# sync command - fast-forward pull, then link. The everyday "apply upstream".

df_cmd_sync() {
  local do_link=1 arg
  for arg in "$@"; do
    case "$arg" in
      --no-link) do_link=0 ;;
      *) df_die "sync: unknown option '$arg'" ;;
    esac
  done

  if [[ ! -d "$DF_REPO/.git" ]]; then
    df_die "sync: $DF_REPO is not a git repository"
  fi

  if [[ -n "$(git -C "$DF_REPO" status --porcelain 2>/dev/null)" ]]; then
    df_warn "repository has uncommitted changes; pulling with --ff-only anyway"
  fi

  df_info "pulling latest changes (fast-forward only)..."
  if ! git -C "$DF_REPO" pull --ff-only; then
    df_die "sync: git pull failed (resolve manually; not forcing)"
  fi

  if (( do_link )); then
    source "$DF_LIB/commands/link.sh"
    df_cmd_link
  else
    df_ok "pulled; skipping link (--no-link)"
  fi
}
