#!/usr/bin/env bash
#
# tools/contrast-sweep.sh - measure the shipped themes' text pairs against WCAG.
#
# Reads themes/*/ as committed (no regeneration) and reports every pair that
# misses its target, using the emitter's own _dfa_contrast so the numbers agree
# with what the generator sees. Targets: 4.5:1 for text, 3.0:1 for dots and
# large/bold. Run before and after an emitter change to see the blast radius.
#
# Usage: tools/contrast-sweep.sh [--all] [name ...]
#          --all   list every pair, not just the failures

set -euo pipefail

DF_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DF_REPO
# shellcheck source=lib/core.sh
source "$DF_REPO/lib/core.sh"
# shellcheck source=lib/config.sh
source "$DF_REPO/lib/config.sh"
# shellcheck source=lib/theme-auto.sh
source "$DF_REPO/lib/theme-auto.sh"

SHOW_ALL=0
ARGS=()
for a in "$@"; do
  case $a in
    --all) SHOW_ALL=1 ;;
    *) ARGS+=("$a") ;;
  esac
done

# waybar @define-color <name> <value>
_wb() { awk -v k="$2" '$2==k {gsub(/;/,"",$3); print $3}' "$1/.config/waybar/colors.css"; }
# starship  key = '<value>'
_st() { awk -F"'" -v k="$2" '$1 ~ ("^"k" = ") {print $2}' "$1/.config/starship.toml"; }

fails=0
total=0

report() { # <theme> <label> <fg> <bg> <target>
  local theme=$1 label=$2 f=$3 b=$4 target=$5 r
  [[ -n "$f" && -n "$b" ]] || return 0
  r=$(_dfa_contrast "$f" "$b")
  total=$(( total + 1 ))
  if (( r < target )); then
    fails=$(( fails + 1 ))
    printf '  %-22s %-26s %s on %s  %d.%02d:1  (need %d.%d)\n' \
      "$theme" "$label" "$f" "$b" $(( r / 1000 )) $(( (r % 1000) / 10 )) \
      $(( target / 1000 )) $(( (target % 1000) / 100 ))
  elif (( SHOW_ALL )); then
    printf '  %-22s %-26s %s on %s  %d.%02d:1  ok\n' \
      "$theme" "$label" "$f" "$b" $(( r / 1000 )) $(( (r % 1000) / 10 ))
  fi
}

names=()
if (( ${#ARGS[@]} )); then names=("${ARGS[@]}"); else
  for d in "$DF_REPO/$DF_THEMES_DIR"/*/; do
    n=$(basename "$d"); [[ $n == auto ]] && continue; names+=("$n")
  done
fi

for n in "${names[@]}"; do
  d="$DF_REPO/$DF_THEMES_DIR/$n"
  [[ -d $d ]] || continue

  # --- waybar -------------------------------------------------------------
  if [[ -f "$d/.config/waybar/colors.css" ]]; then
    bar_bg=$(_wb "$d" bar-bg)
    for pill in brand stats ctrl theme; do
      report "$n" "waybar pill-$pill" "$(_wb "$d" "pill-$pill-fg")" "$(_wb "$d" "pill-$pill-bg")" 4500
    done
    report "$n" "waybar bar text" "$(_wb "$d" bar-fg)" "$bar_bg" 4500
    ws_bg=$(_wb "$d" ws-bg)
    report "$n" "waybar ws dot occupied" "$(_wb "$d" ws-fg-occupied)" "$ws_bg" 3000
    report "$n" "waybar ws dot active" "$(_wb "$d" ws-fg-active)" "$ws_bg" 3000
  fi

  # --- starship -----------------------------------------------------------
  if [[ -f "$d/.config/starship.toml" ]]; then
    s_osbg=$(_st "$d" color_os_bg)
    report "$n" "starship os/user/host" "$(_st "$d" color_os_fg)" "$s_osbg" 4500
    report "$n" "starship dir path" "$(_st "$d" color_dir_fg)" "$(_st "$d" color_dir_bg)" 4500
    report "$n" "starship repo root" "$(_st "$d" color_dir_repo_fg)" "$(_st "$d" color_dir_bg)" 4500
    report "$n" "starship branch" "$(_st "$d" color_repo_fg)" "$(_st "$d" color_repo_bg)" 4500
    report "$n" "starship changes" "$(_st "$d" color_repo_change_fg)" "$(_st "$d" color_repo_change_bg)" 4500
    report "$n" "starship ahead/behind" "$(_st "$d" color_repo_diverge_fg)" "$(_st "$d" color_repo_diverge_bg)" 4500
    # right-hand row and separators draw straight onto the terminal background
    term_bg=$(awk -F'[ #]+' '/^background/ {print "#"$2}' "$d/.config/kitty/current-theme.conf" 2>/dev/null | head -1)
    if [[ -n $term_bg ]]; then
      report "$n" "starship time/ip" "$(_st "$d" color_fg_right)" "$term_bg" 4500
      report "$n" "starship separators" "$(_st "$d" color_fg_sep)" "$term_bg" 3000
      # style_root draws color_root_fg on the os segment; themes whose override
      # pins starship.toml predate the key and still carry the ANSI yellow.
      root_fg=$(_st "$d" color_root_fg); [[ -n $root_fg ]] || root_fg='#ffff00'
      report "$n" "starship root user" "$root_fg" "$s_osbg" 4500
    fi
  fi
done

printf '\n%d/%d pairs below target\n' "$fails" "$total"
