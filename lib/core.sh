# shellcheck shell=bash
#
# core.sh - Logging, colour, and small shared helpers.
#
# This file is sourced by bin/dotfiles and the command modules. It never
# mutates the filesystem; it only provides output helpers and tiny utilities.

# Guard against double-sourcing.
[[ -n "${_DF_CORE_SOURCED:-}" ]] && return 0
_DF_CORE_SOURCED=1

# ---------------------------------------------------------------------------
# Colour handling. Respect NO_COLOR and non-tty output.
# ---------------------------------------------------------------------------
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  DF_C_RESET=$'\033[0m'
  DF_C_DIM=$'\033[2m'
  DF_C_RED=$'\033[31m'
  DF_C_GREEN=$'\033[32m'
  DF_C_YELLOW=$'\033[33m'
  DF_C_BLUE=$'\033[34m'
else
  DF_C_RESET='' DF_C_DIM='' DF_C_RED='' DF_C_GREEN='' DF_C_YELLOW='' DF_C_BLUE=''
fi

# ---------------------------------------------------------------------------
# Logging helpers. All diagnostics go to stderr so stdout stays parseable.
# ---------------------------------------------------------------------------
df_log()   { printf '%s\n' "$*" >&2; }
df_info()  { printf '%s%s%s\n' "$DF_C_BLUE" "$*" "$DF_C_RESET" >&2; }
df_ok()    { printf '%s%s%s\n' "$DF_C_GREEN" "$*" "$DF_C_RESET" >&2; }
df_warn()  { printf '%swarning:%s %s\n' "$DF_C_YELLOW" "$DF_C_RESET" "$*" >&2; }
df_error() { printf '%serror:%s %s\n' "$DF_C_RED" "$DF_C_RESET" "$*" >&2; }
df_dim()   { printf '%s%s%s\n' "$DF_C_DIM" "$*" "$DF_C_RESET" >&2; }

df_debug() {
  [[ -n "${DF_DEBUG:-}" ]] || return 0
  printf '%sdebug:%s %s\n' "$DF_C_DIM" "$DF_C_RESET" "$*" >&2
}

# Print an error and exit non-zero.
df_die() {
  df_error "$*"
  exit 1
}

# ---------------------------------------------------------------------------
# Small path utilities.
# ---------------------------------------------------------------------------

# Strip a leading "./" and any trailing slash from a relative path.
df_clean_rel() {
  local p=$1
  p=${p#./}
  p=${p%/}
  printf '%s' "$p"
}

# Join $HOME-relative path onto the target root, avoiding a trailing slash
# when the relative part is empty (i.e. the root itself).
df_target_path() {
  local rel=$1
  if [[ -z "$rel" ]]; then
    printf '%s' "$DF_TARGET"
  else
    printf '%s/%s' "$DF_TARGET" "$rel"
  fi
}

# True if $1 is a symlink whose resolved location is inside the repository.
df_is_repo_link() {
  local path=$1 dest
  [[ -L "$path" ]] || return 1
  dest=$(readlink -f -- "$path" 2>/dev/null) || return 1
  [[ "$dest" == "$DF_REPO"/* ]]
}

# True if the symlink at $1 resolves to exactly $2.
df_link_points_to() {
  local path=$1 want=$2 got
  [[ -L "$path" ]] || return 1
  got=$(readlink -f -- "$path" 2>/dev/null) || return 1
  [[ "$got" == "$(readlink -f -- "$want" 2>/dev/null)" ]]
}
