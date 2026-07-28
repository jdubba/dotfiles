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
# walker seam. Only plain hex is emitted: several colours are alpha(<c>, a)
# forms, which are not a single measurable value.
_wk() {
  awk -v k="$2" '$1=="@define-color" && $2==k && $3 ~ /^#/ {gsub(/;/,"",$3); print $3}' \
    "$1/.config/walker/colors.css"
}

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

@test "every theme's power-menu glyph badge is legible" {
  # The power panel's glyph badge (.menus-powerstate .item-image-text in
  # profiles/hyprland/.config/walker/themes/*/style.css) is an opaque inverted
  # chip: @theme_fg_color behind a @window_bg_color glyph. A glyph is large
  # text, so the target is 3:1.
  #
  # Unlike the tests above, this one does NOT skip themes whose walker seam is
  # pinned by tools/theme-overrides/. Those tests hold the *emitter* to a
  # guarantee, and an override is outside its reach. This rule instead lives in
  # the shared stylesheet every theme is rendered through, so an override that
  # makes the badge unreadable is a real defect in the UI, not intentional
  # divergence -- 10 of the 40 themes pin this seam.
  #
  # Opaque is load-bearing. The @quick_* pair looks like the obvious choice --
  # it is the existing in-row badge pair -- but the emitter defaults it to
  # alpha(<colour>, 0.25), so it composites against whichever row it lands on:
  # measured over all 40 palettes that put the glyph at 2.72:1 on
  # catppuccin-mocha's unselected rows and made the chip vanish into that
  # theme's selected row entirely (rgb_dist 0).
  _load_emitter
  local bad=() d n checked=0
  for d in "$DF_SRC_REPO"/themes/*/; do
    n=$(basename "$d")
    [[ $n == auto ]] && continue
    [[ -f "$d/.config/walker/colors.css" ]] || continue
    local ink chip
    ink=$(_wk "$d" window_bg_color)
    chip=$(_wk "$d" theme_fg_color)
    [[ -n $ink && -n $chip ]] || continue
    checked=$((checked + 1))
    _check "$d" "power badge" "$ink" "$chip" 3000
  done
  # _wk skips alpha() forms, so guard against the loop silently measuring
  # almost nothing and passing.
  [ "$checked" -ge 35 ] || { echo "only measured $checked themes"; false; }
  [ ${#bad[@]} -eq 0 ] || { printf '%s\n' "${bad[@]}"; false; }
}

@test "style_root does not draw a hardcoded ANSI colour" {
  # It was fg:yellow, which is invisible wherever os_bg is light or a mid
  # accent. It must come from the palette so the emitter can measure it.
  run grep -h '^style_root' "$DF_SRC_REPO/home/.config/starship.toml"
  [ "$status" -eq 0 ]
  [[ "$output" == *color_root_fg* ]]
}
