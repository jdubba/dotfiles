# shellcheck shell=bash
#
# hook command - install the git hooks shipped in hooks/ so that a plain
# `git pull` re-links automatically.

df_cmd_hook() {
  local sub=${1:-}
  [[ $# -gt 0 ]] && shift || true

  [[ -d "$DF_REPO/.git" ]] || df_die "hook: $DF_REPO is not a git repository"

  case "$sub" in
    install)
      local hookdir="$DF_REPO/.git/hooks"
      mkdir -p -- "$hookdir"
      chmod +x "$DF_REPO/hooks/post-merge" 2>/dev/null || true
      ln -sf -- "../../hooks/post-merge" "$hookdir/post-merge"
      df_ok "installed post-merge hook ('git pull' will now re-link)"
      ;;
    uninstall)
      rm -f -- "$DF_REPO/.git/hooks/post-merge"
      df_ok "removed post-merge hook"
      ;;
    *)
      df_die "usage: dotfiles hook install|uninstall"
      ;;
  esac
}
