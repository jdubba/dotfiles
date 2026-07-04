# shellcheck shell=bash
#
# config.sh - Defaults, repository config loading, and machine-local state.
#
# Two kinds of configuration exist:
#   * Repository config (dotfiles.conf at the repo root, committed) - shared
#     settings such as the container-directory set and ignore globs.
#   * Machine state (untracked, under XDG_STATE_HOME) - per-machine choices
#     such as which profiles are enabled. Never written into the repo.

[[ -n "${_DF_CONFIG_SOURCED:-}" ]] && return 0
_DF_CONFIG_SOURCED=1

# ---------------------------------------------------------------------------
# Defaults. May be overridden by dotfiles.conf or the environment.
# ---------------------------------------------------------------------------

# Where links are created. Overridable mainly so tests can target a temp dir.
: "${DF_TARGET:=$HOME}"

# Layer directory names within the repository.
: "${DF_HOME_LAYER:=home}"
: "${DF_PROFILES_DIR:=profiles}"
: "${DF_HOSTS_DIR:=hosts}"

# Machine-local state directory (never committed).
: "${DF_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles}"

# THE SAFETY LINCHPIN.
#
# Container directories are shared, high-traffic directories that many
# independent applications write into. They are NEVER replaced by a symlink:
# the tool always materialises them as real directories and only links the
# specific children the repository manages. This makes the classic failure
# mode - folding ~/.config into a single symlink and thereby capturing every
# application's writes into the repo - structurally impossible.
#
# Paths are relative to DF_TARGET ($HOME). Extend via dotfiles.conf.
DF_CONTAINER_DIRS=(
  ".config"
  ".local"
  ".local/bin"
  ".local/lib"
  ".local/share"
  ".local/state"
  ".cache"
  ".ssh"
  ".gnupg"
  ".pki"
  ".mozilla"
  ".thunderbird"
  ".config/systemd"
  ".config/systemd/user"
)

# Names never treated as managed content in any layer (VCS metadata, tool
# markers, editor cruft). Matched against the basename of each entry.
DF_IGNORE_NAMES=(
  ".git"
  ".gitignore"
  ".gitkeep"
  ".keep"
  ".stow-local-ignore"
  ".DS_Store"
  ".dotfiles-nofold"
)

# ---------------------------------------------------------------------------
# Load repository config, if present. dotfiles.conf is a sourced shell
# fragment; it may append to DF_CONTAINER_DIRS / DF_IGNORE_NAMES or set
# scalars. It is the user's own repo, so sourcing it is acceptable.
# ---------------------------------------------------------------------------
df_load_repo_config() {
  local conf="$DF_REPO/dotfiles.conf"
  if [[ -f "$conf" ]]; then
    df_debug "loading repo config: $conf"
    # shellcheck source=/dev/null
    source "$conf"
  fi
}

# True if $1 (a basename) should be ignored in any layer.
df_is_ignored_name() {
  local name=$1 ig
  for ig in "${DF_IGNORE_NAMES[@]}"; do
    [[ "$name" == "$ig" ]] && return 0
  done
  return 1
}

# True if the given $HOME-relative path is a protected container directory.
df_is_container() {
  local rel; rel=$(df_clean_rel "$1")
  # The target root itself is always a container.
  [[ -z "$rel" ]] && return 0
  local c
  for c in "${DF_CONTAINER_DIRS[@]}"; do
    [[ "$rel" == "$c" ]] && return 0
  done
  return 1
}

# True if any container directory is a strict descendant of $1. Such a
# directory can never be folded, because folding it would bypass the
# container protection for the nested path.
df_contains_container() {
  local rel; rel=$(df_clean_rel "$1")
  [[ -z "$rel" ]] && return 0
  local c
  for c in "${DF_CONTAINER_DIRS[@]}"; do
    [[ "$c" == "$rel"/* ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Machine-local state: enabled profiles (one per line).
# ---------------------------------------------------------------------------
df_state_profiles_file() { printf '%s/profiles' "$DF_STATE_DIR"; }

df_read_enabled_profiles() {
  local f; f=$(df_state_profiles_file)
  [[ -f "$f" ]] || return 0
  # Ignore blank lines and comments.
  grep -vE '^\s*(#|$)' "$f" 2>/dev/null || true
}
