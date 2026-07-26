#!/usr/bin/env bats
# theme-contrast.bats - the emitter must produce legible text pairs.
#
# The emitter assigns colours by palette slot, which reliably produces
# unreadable pairs on some palettes: a sweep before these guarantees existed
# found 91 failures across 625 pairs, including waybar pills at 4.37:1 (no ink
# reaches AA on a mid-luminance accent unless the surface moves), starship
# separators at 1.48:1, and a root-shell warning drawn in ANSI yellow on a cream
# os segment at 1.11:1.
#
# Targets follow the structural-vs-content rule: 4.5:1 for text, 3.0:1 for
# chrome that is meant to recede. The IP-row separators are chrome; the clock
# and IP beside them are content.
#
# Themes whose seam is pinned by tools/theme-overrides/ are skipped for that
# seam -- an override is a deliberate choice to hand-maintain the file and is
# outside the emitter's reach, so holding it to the emitter's guarantee would
# be reconciling intentional divergence.

setup() { load test_helper; }

_wb() { awk -v k="$2" '$2==k {gsub(/;/,"",$3); print $3}' "$1/.config/waybar/colors.css"; }
_st() { awk -F"'" -v k="$2" '$1 ~ ("^"k" = ") {print $2}' "$1/.config/starship.toml"; }

_load_emitter() {
  DF_REPO="$DF_SRC_REPO"
  export DF_REPO
  source "$DF_SRC_REPO/lib/core.sh"
  source "$DF_SRC_REPO/lib/config.sh"
  source "$DF_SRC_REPO/lib/theme-auto.sh"
}

# _check <theme-dir> <label> <fg> <bg> <target-x1000>; appends to $bad
_check() {
  local d=$1 label=$2 f=$3 b=$4 target=$5 r
  [[ -n $f && -n $b ]] || return 0
  r=$(_dfa_contrast "$f" "$b")
  if (( r < target )); then
    bad+=("$(basename "$d") $label: $f on $b = $((r/1000)).$(printf '%02d' $(((r%1000)/10))):1 (need $((target/1000)).$(((target%1000)/100)))")
  fi
}

@test "every generated theme's waybar pills clear AA" {
  _load_emitter
  local bad=() d n
  for d in "$DF_SRC_REPO"/themes/*/; do
    n=$(basename "$d")
    [[ $n == auto ]] && continue
    [[ -f "$DF_SRC_REPO/tools/theme-overrides/$n/.config/waybar/colors.css" ]] && continue
    [[ -f "$d/.config/waybar/colors.css" ]] || continue
    local p
    for p in brand stats ctrl theme; do
      _check "$d" "pill-$p" "$(_wb "$d" "pill-$p-fg")" "$(_wb "$d" "pill-$p-bg")" 4500
    done
  done
  [ ${#bad[@]} -eq 0 ] || { printf '%s\n' "${bad[@]}"; false; }
}

@test "every generated theme's starship IP row is legible on the terminal background" {
  _load_emitter
  local bad=() d n bg
  for d in "$DF_SRC_REPO"/themes/*/; do
    n=$(basename "$d")
    [[ $n == auto ]] && continue
    [[ -f "$DF_SRC_REPO/tools/theme-overrides/$n/.config/starship.toml" ]] && continue
    [[ -f "$d/.config/starship.toml" ]] || continue
    bg=$(awk -F'[ #]+' '/^background/ {print "#"$2}' "$d/.config/kitty/current-theme.conf" | head -1)
    [[ -n $bg ]] || continue
    # separators are chrome (3:1); the clock and IP are content (4.5:1)
    _check "$d" "separators" "$(_st "$d" color_fg_sep)" "$bg" 3000
    _check "$d" "time/ip" "$(_st "$d" color_fg_right)" "$bg" 4500
  done
  [ ${#bad[@]} -eq 0 ] || { printf '%s\n' "${bad[@]}"; false; }
}

@test "every generated theme's root-shell warning is legible on the os segment" {
  _load_emitter
  local bad=() d n
  for d in "$DF_SRC_REPO"/themes/*/; do
    n=$(basename "$d")
    [[ $n == auto ]] && continue
    [[ -f "$DF_SRC_REPO/tools/theme-overrides/$n/.config/starship.toml" ]] && continue
    [[ -f "$d/.config/starship.toml" ]] || continue
    _check "$d" "root user" "$(_st "$d" color_root_fg)" "$(_st "$d" color_os_bg)" 4500
  done
  [ ${#bad[@]} -eq 0 ] || { printf '%s\n' "${bad[@]}"; false; }
}

@test "style_root does not draw a hardcoded ANSI colour" {
  # It was fg:yellow, which is invisible wherever os_bg is light or a mid
  # accent. It must come from the palette so the emitter can measure it.
  run grep -h '^style_root' "$DF_SRC_REPO/home/.config/starship.toml"
  [ "$status" -eq 0 ]
  [[ "$output" == *color_root_fg* ]]
}
