# shellcheck shell=bash
#
# theme-auto.sh - wallpaper-derived ("auto") theme generation.
#
# Sourced lazily by lib/commands/theme.sh for the `theme auto` subcommands.
# The always-sourced bits (df_autotheme_enabled, state-file helpers) live in
# config.sh so df_theme_name() can resolve "auto" without loading this file.
#
# Pipeline:  detect wallpaper -> extract palette -> generate seam files into
# themes/auto/ (gitignored) -> activate (link + reload).
#
# Palette backend preference: wallust -> pywal -> bundled python+Pillow. The
# core dotfiles tool stays dependency-free; auto-theming is the one optional
# feature with an (advertised) external dependency.

# --- Backend detection ------------------------------------------------------

df_autotheme_python_ok() {
  command -v python3 &>/dev/null && python3 -c 'import PIL' &>/dev/null
}

# Print the palette backend that would be used: wallust|pywal|python|none.
df_autotheme_backend() {
  if command -v wallust &>/dev/null; then printf 'wallust'
  elif command -v wal &>/dev/null; then printf 'pywal'
  elif df_autotheme_python_ok; then printf 'python'
  else printf 'none'; fi
}

# Advise about wallust whenever a lesser backend is in use (per the plan: the
# option and the need to install it must be surfaced, not silent).
df_autotheme_backend_notice() {
  case "$(df_autotheme_backend)" in
    wallust) df_dim "palette backend: wallust" ;;
    pywal)   df_warn "palette backend: pywal - install 'wallust' (e.g. 'cargo install wallust') for better palettes; it is used automatically once on PATH" ;;
    python)  df_warn "palette backend: bundled python+Pillow (fallback) - for noticeably better palettes install 'wallust' (recommended: 'cargo install wallust') or 'pywal'; it is picked up automatically once on PATH" ;;
    none)    : ;;
  esac
}

# --- Palette extraction -----------------------------------------------------

# A palette is valid if it carries a background and all 16 ANSI slots.
_df_palette_valid() { [[ "$1" == *background=* && "$1" == *color15=* ]]; }

# pywal: generate, then read ~/.cache/wal/colors.json (stable, documented).
_df_palette_pywal() {
  local img=$1 cache="${XDG_CACHE_HOME:-$HOME/.cache}/wal/colors.json"
  command -v python3 &>/dev/null || return 1
  wal -i "$img" -n -q -e -s -t &>/dev/null || return 1
  [[ -f "$cache" ]] || return 1
  python3 - "$cache" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
s = d.get("special", {}); c = d.get("colors", {})
print("background=" + s.get("background", "#000000"))
print("foreground=" + s.get("foreground", "#ffffff"))
print("cursor=" + s.get("cursor", s.get("foreground", "#ffffff")))
for i in range(16):
    print("color%d=%s" % (i, c.get("color%d" % i, "#000000")))
PY
}

# wallust (>=3): render our normalized palette via wallust's own templating
# into an isolated temp config dir. -s skips terminal sequences and -n skips
# the cache, so the user's real wallust state/terminal are left untouched.
_df_palette_wallust() {
  local img=$1 dir out
  dir=$(mktemp -d) || return 1
  mkdir -p "$dir/templates"
  cat >"$dir/templates/palette.tpl" <<'TPL'
background={{background}}
foreground={{foreground}}
cursor={{cursor}}
color0={{color0}}
color1={{color1}}
color2={{color2}}
color3={{color3}}
color4={{color4}}
color5={{color5}}
color6={{color6}}
color7={{color7}}
color8={{color8}}
color9={{color9}}
color10={{color10}}
color11={{color11}}
color12={{color12}}
color13={{color13}}
color14={{color14}}
color15={{color15}}
TPL
  cat >"$dir/wallust.toml" <<CFG
[templates]
palette = { template = "palette.tpl", target = "$dir/out.palette" }
CFG
  out=1
  if wallust run "$img" -q -s -n -k -d "$dir" &>/dev/null && [[ -f "$dir/out.palette" ]]; then
    tr 'A-F' 'a-f' <"$dir/out.palette"
    out=0
  fi
  rm -rf "$dir"
  return "$out"
}

# Emit normalized KEY=#hex lines for <image>, trying backends in order.
df_palette_extract() {
  local img=$1 out=""
  # Override hook: a caller (or the test suite) may supply a ready palette,
  # bypassing backend detection entirely.
  if [[ -n "${DF_PALETTE_FILE:-}" && -f "$DF_PALETTE_FILE" ]]; then
    cat -- "$DF_PALETTE_FILE"
    return 0
  fi
  if command -v wallust &>/dev/null; then
    out=$(_df_palette_wallust "$img" 2>/dev/null) || true
    _df_palette_valid "$out" && { printf '%s\n' "$out"; return 0; }
    df_warn "wallust palette extraction failed; falling back"
  fi
  if command -v wal &>/dev/null; then
    out=$(_df_palette_pywal "$img" 2>/dev/null) || true
    _df_palette_valid "$out" && { printf '%s\n' "$out"; return 0; }
    df_warn "pywal palette extraction failed; falling back"
  fi
  if df_autotheme_python_ok; then
    out=$(python3 "$DF_REPO/lib/theme-auto/palette.py" "$img" 2>/dev/null) || true
    _df_palette_valid "$out" && { printf '%s\n' "$out"; return 0; }
  fi
  df_die "palette extraction failed; install 'wallust', 'pywal', or python3 + Pillow"
}

# --- Wallpaper detection (DE-specific; hyprland+hyprpaper for now) -----------
# Extension point for GNOME/KDE - see docs/auto-theming.md. Honor an explicit
# override ($DF_WALLPAPER) first, so unsupported DEs (and tests) can point at a
# known image without any detector.
df_autotheme_current_wallpaper() {
  if [[ -n "${DF_WALLPAPER:-}" && -f "$DF_WALLPAPER" ]]; then
    readlink -f -- "$DF_WALLPAPER" 2>/dev/null && return 0
  fi
  if command -v hyprctl &>/dev/null && pgrep -x hyprpaper &>/dev/null; then
    local line path
    line=$(hyprctl hyprpaper listactive 2>/dev/null | head -1)
    path=${line#*: }
    path=${path# }
    if [[ -n "$path" ]]; then
      readlink -f -- "$path" 2>/dev/null && return 0
    fi
  fi
  return 1
}

# --- Generation -------------------------------------------------------------

# Emit "$name = rgb(hex)" + "$nameAlpha = hex" for the hypr/hyprlock var set.
_dfa_hypr_var() {
  local n=$1 h=${2#\#}
  printf '$%s = rgb(%s)\n$%sAlpha = %s\n' "$n" "$h" "$n" "$h"
}

# Rec.601 perceived luminance (0-255) of a #RRGGBB colour.
_dfa_lum() {
  local h=${1#\#} r g b
  r=$((16#${h:0:2})); g=$((16#${h:2:2})); b=$((16#${h:4:2}))
  printf '%d' "$(( (299 * r + 587 * g + 114 * b) / 1000 ))"
}

# sRGB linearisation table: _DFA_LIN[c] = round(f(c) * 1000000), where f is
# WCAG's per-channel transform. A table is what keeps contrast measurable in pure
# integer bash -- the transform needs a 2.4 power that shell arithmetic cannot
# express, and the emitter must stay dependency-free because `theme auto` runs it.
_DFA_LIN=(
  0 304 607 911 1214 1518 1821 2125 2428 2732 3035 3347 3677 4025 4391 4777
  5182 5605 6049 6512 6995 7499 8023 8568 9134 9721 10330 10960 11612 12286 12983 13702
  14444 15209 15996 16807 17642 18500 19382 20289 21219 22174 23153 24158 25187 26241 27321 28426
  29557 30713 31896 33105 34340 35601 36889 38204 39546 40915 42311 43735 45186 46665 48172 49707
  51269 52861 54480 56128 57805 59511 61246 63010 64803 66626 68478 70360 72272 74214 76185 78187
  80220 82283 84376 86500 88656 90842 93059 95307 97587 99899 102242 104616 107023 109462 111932 114435
  116971 119538 122139 124772 127438 130136 132868 135633 138432 141263 144128 147027 149960 152926 155926 158961
  162029 165132 168269 171441 174647 177888 181164 184475 187821 191202 194618 198069 201556 205079 208637 212231
  215861 219526 223228 226966 230740 234551 238398 242281 246201 250158 254152 258183 262251 266356 270498 274677
  278894 283149 287441 291771 296138 300544 304987 309469 313989 318547 323143 327778 332452 337164 341914 346704
  351533 356400 361307 366253 371238 376262 381326 386429 391572 396755 401978 407240 412543 417885 423268 428690
  434154 439657 445201 450786 456411 462077 467784 473531 479320 485150 491021 496933 502886 508881 514918 520996
  527115 533276 539479 545724 552011 558340 564712 571125 577580 584078 590619 597202 603827 610496 617207 623960
  630757 637597 644480 651406 658375 665387 672443 679542 686685 693872 701102 708376 715694 723055 730461 737910
  745404 752942 760525 768151 775822 783538 791298 799103 806952 814847 822786 830770 838799 846873 854993 863157
  871367 879622 887923 896269 904661 913099 921582 930111 938686 947307 955973 964686 973445 982251 991102 1000000
)

# WCAG relative luminance, scaled by 1e6 (0..1000000).
_dfa_wcag_lum() {
  local h=${1#\#} r g b
  r=$((16#${h:0:2})); g=$((16#${h:2:2})); b=$((16#${h:4:2}))
  # 2126/7152/722 sum to 10000, so this is a weighted mean of the table entries.
  printf '%d' "$(( (2126 * _DFA_LIN[r] + 7152 * _DFA_LIN[g] + 722 * _DFA_LIN[b]) / 10000 ))"
}

# WCAG contrast ratio between two colours, scaled by 1000 (4500 == 4.5:1). Integer
# throughout: WCAG's +0.05 becomes +50000 at the 1e6 luminance scale. Agrees with a
# float implementation to within 0.001 in ratio terms.
#   _dfa_contrast <hex-a> <hex-b>
_dfa_contrast() {
  local la lb hi lo
  la=$(_dfa_wcag_lum "$1"); lb=$(_dfa_wcag_lum "$2")
  if (( la >= lb )); then hi=$la; lo=$lb; else hi=$lb; lo=$la; fi
  printf '%d' "$(( ( (hi + 50000) * 1000 ) / (lo + 50000) ))"
}

# Pick a readable foreground (near-black / near-white) for a #RRGGBB background
# using Rec.601 perceived luminance. Used for waybar pill text contrast.
#
# The cut is at 110, not the 150 this used to use. #141414 and #f0f0f0 sit at
# luminance 20 and 240, so 150 was biased toward white ink and handed it to
# mid-luminance accents that read better with dark text; WCAG's +0.05 offset
# pushes the true crossover lower still. Measured against every accent the
# shipped palettes actually use, 150 chose the worse of the two inks 22 times out
# of 111 and 110 chooses it twice.
_dfa_contrast_fg() {
  local lum
  lum=$(_dfa_lum "$1")
  if (( lum > 110 )); then printf '#141414'; else printf '#f0f0f0'; fi
}

# Choose an ink for text drawn on a surface: _dfa_ink_for <surface> <fg> <bg>.
#
# Prefers the palette's own foreground, then its background, then the
# near-black/near-white pair -- the first that measures AA against the surface,
# so the result stays on-palette wherever the palette can manage it. Where the
# surface is mid-luminance nothing may reach 4.5:1 (a saturated teal like #458588
# admits no ink that does), so the last resort is whichever of the two extreme
# inks contrasts best; that is the ceiling, not a failure of the caller.
_dfa_ink_for() {
  local surface=$1 pal_fg=$2 pal_bg=$3 cand
  for cand in "$pal_fg" "$pal_bg"; do
    if (( $(_dfa_contrast "$cand" "$surface") >= 4500 )); then
      printf '%s' "$cand"; return
    fi
  done
  _dfa_contrast_fg "$surface"
}

# Pick a legible surface+ink pair: _dfa_pair_for <surface> <fg> <bg>, printing
# "<surface> <ink>".
#
# Choosing the ink is enough on most palettes. Where the surface is a
# mid-luminance accent, no ink reaches AA against it at all -- so as a last
# resort the surface itself moves, away from the ink's own pole, which is the
# same escape the terminal-selection pairing uses for c8. It is capped at 25%:
# the point is to deepen an accent slightly, not to replace it. Measured over the
# shipped palettes, every case that needed this cleared AA within 10%.
_dfa_pair_for() {
  local surface=$1 pal_fg=$2 pal_bg=$3 ink pole q=0
  ink=$(_dfa_ink_for "$surface" "$pal_fg" "$pal_bg")
  if (( $(_dfa_contrast "$ink" "$surface") >= 4500 )); then
    printf '%s %s' "$surface" "$ink"; return
  fi
  if (( $(_dfa_lum "$ink") > 110 )); then pole='#000000'; else pole='#ffffff'; fi
  local moved=$surface
  while (( q < 25 )) && (( $(_dfa_contrast "$ink" "$moved") < 4500 )); do
    q=$(( q + 5 ))
    moved=$(_df_theme_mix "$surface" "$pole" "$q")
  done
  printf '%s %s' "$moved" "$ink"
}

# Ramp <start> toward <toward> in 5% steps until it measures <target> against
# <surface>, and print the result.
#   _dfa_ramp_to <start> <toward> <surface> <target>
#
# A colour that already measures is returned unchanged, so palettes where the
# raw slot reads keep their exact value and only the failures move -- the same
# discipline the workspace-dot and repo-root ramps use. Give it the ink that
# contrasts with <surface> as <toward> and the ramp works in both polarities:
# it darkens on a light surface and lightens on a dark one.
_dfa_ramp_to() {
  local start=$1 toward=$2 surface=$3 target=$4 out=$1 q=0
  while (( q < 100 )) && (( $(_dfa_contrast "$out" "$surface") < target )); do
    q=$(( q + 5 ))
    out=$(_df_theme_mix "$start" "$toward" "$q")
  done
  printf '%s' "$out"
}

# Of two variants of the same hue (normal and bright slot), print whichever sits
# further from <base> in perceived luminance -- i.e. the one that will actually
# read against it. On a dark bar that is usually the bright slot; on a light bar
# it is often the normal one, and on palettes like gruvbox-light -- whose
# "bright" slots are deliberately DARKER than its normal ones -- it flips again.
# Comparing against the background rather than assuming a mode handles all three.
#   _df_theme_pick_variant <hex-a> <hex-b> <base-hex>
_df_theme_pick_variant() {
  local la lb lbase da db
  la=$(_dfa_lum "$1"); lb=$(_dfa_lum "$2"); lbase=$(_dfa_lum "$3")
  da=$(( la > lbase ? la - lbase : lbase - la ))
  db=$(( lb > lbase ? lb - lbase : lbase - lb ))
  if (( db > da )); then printf '%s' "$2"; else printf '%s' "$1"; fi
}

# Deterministic 32-bit FNV-1a hash of a string, printed as a decimal integer.
#
# The waybar accent assignment is drawn per theme rather than being one fixed
# pattern, but it must be *stable*: tools/build-themes.sh has to reproduce
# themes/ byte-for-byte (tests/theme-build.bats enforces it), so a real random
# source would rewrite all 40 themes on every run. Seeding from the theme's own
# identity gives variety across themes and reproducibility within one.
_df_theme_hash() {
  local s=$1 i c h=2166136261
  for (( i = 0; i < ${#s}; i++ )); do
    printf -v c '%d' "'${s:i:1}"
    h=$(( (h ^ c) & 0xFFFFFFFF ))
    h=$(( (h * 16777619) & 0xFFFFFFFF ))
  done
  printf '%u' "$h"
}

# Mix two #rrggbb colours: _df_theme_mix <base> <toward> <percent-toward>.
# Integer bash arithmetic only -- the core tool stays dependency-free, so this
# must not reach for python even though the auto-theme palette backends may.
_df_theme_mix() {
  local a=${1#\#} b=${2#\#} p=$3 i out=''
  local -a av=() bv=()
  for i in 0 2 4; do
    av+=( "$((16#${a:i:2}))" )
    bv+=( "$((16#${b:i:2}))" )
  done
  for i in 0 1 2; do
    out+=$(printf '%02x' "$(( (av[i]*(100-p) + bv[i]*p + 50) / 100 ))")
  done
  printf '#%s' "$out"
}

# Emit every non-wallpaper seam file for a theme into <dest> from the caller's
# PAL palette (dynamic scope). Shared by auto-theming and the curated build tool.
#   $1 dest       theme directory (…/themes/<name>)
#   $2 tag        comment label written into the generated files
#   $3 nvim_spec  base16 | catppuccin:<flavour> | gruvbox:<dark|light>
#   $4 bat_theme  value for BAT_THEME
#   $5 opencode   opencode tui.json "theme" value
# PAL must define background, foreground, cursor, color0..color15 (and may set
# background_mode=dark|light for nvim/UI background).
df_theme_emit_seams() {
  local dest=$1 tag=$2 nvim_spec=$3 bat_theme=$4 opencode=$5
  local name; name=$(basename -- "$dest")
  local bg=${PAL[background]} fg=${PAL[foreground]} cur=${PAL[cursor]:-${PAL[foreground]}}
  local c0=${PAL[color0]} c1=${PAL[color1]} c2=${PAL[color2]} c3=${PAL[color3]}
  local c4=${PAL[color4]} c5=${PAL[color5]} c6=${PAL[color6]} c7=${PAL[color7]}
  local c8=${PAL[color8]} c9=${PAL[color9]} c10=${PAL[color10]} c11=${PAL[color11]}
  local c12=${PAL[color12]} c13=${PAL[color13]} c14=${PAL[color14]} c15=${PAL[color15]}
  local bgmode=${PAL[background_mode]:-dark}

  mkdir -p \
    "$dest/.config/kitty" "$dest/.config/ghostty/themes" "$dest/.config/hypr" \
    "$dest/.config/waybar" "$dest/.config/walker" "$dest/.config/tmux" \
    "$dest/.config/shell" "$dest/.config/opencode" "$dest/.config/nvim/lua" \
    "$dest/.config/btop/themes"

  # Terminal selection, shared by the kitty and ghostty seams below.
  #
  # This was selection_foreground=fg over selection_background=c8, which left
  # SELECTED TEXT under 4.5:1 in 26 of 40 themes -- solarized-light reached 1.21:1,
  # i.e. selecting text made it invisible. c8 is a mid grey on most palettes and fg
  # is often close to it in luminance; nothing in the pairing checked.
  #
  # Keep c8, since it is the palette's own selection tone, and pick the ink by
  # measurement: the theme's fg if it reads, else its bg, else the near-black or
  # near-white that must. If none of the three clears 4.5 -- c8 is mid-luminance on
  # 5 palettes, where no ink can -- move the surface instead, mixing c8 away from
  # the fg's own pole until it does. Every shipped theme now clears 4.5, worst
  # 4.53:1, and the 14 that already passed keep fg untouched.
  local sel_bg=$c8 sel_fg="" _sel_c _sel_q
  for _sel_c in "$fg" "$bg" "$(_dfa_contrast_fg "$c8")"; do
    if (( $(_dfa_contrast "$_sel_c" "$c8") >= 4500 )); then sel_fg=$_sel_c; break; fi
  done
  if [[ -z "$sel_fg" ]]; then
    sel_fg=$fg
    _sel_q=0
    while (( _sel_q < 100 )) && (( $(_dfa_contrast "$sel_fg" "$sel_bg") < 4500 )); do
      _sel_q=$(( _sel_q + 10 ))
      sel_bg=$(_df_theme_mix "$c8" "$(_dfa_contrast_fg "$fg")" "$_sel_q")
    done
  fi

  # kitty
  cat >"$dest/.config/kitty/current-theme.conf" <<EOF
# ${tag} kitty colors.
foreground              ${fg}
background              ${bg}
selection_foreground    ${sel_fg}
selection_background    ${sel_bg}
url_color               ${c4}
color0  ${c0}
color1  ${c1}
color2  ${c2}
color3  ${c3}
color4  ${c4}
color5  ${c5}
color6  ${c6}
color7  ${c7}
color8  ${c8}
color9  ${c9}
color10 ${c10}
color11 ${c11}
color12 ${c12}
color13 ${c13}
color14 ${c14}
color15 ${c15}
cursor                  ${cur}
cursor_text_color       ${bg}
active_border_color     ${c5}
inactive_border_color   ${c8}
EOF

  # ghostty
  cat >"$dest/.config/ghostty/themes/current" <<EOF
# ${tag} ghostty colors.
background = ${bg}
foreground = ${fg}
selection-background = ${sel_bg}
selection-foreground = ${sel_fg}
palette = 0=${c0}
palette = 1=${c1}
palette = 2=${c2}
palette = 3=${c3}
palette = 4=${c4}
palette = 5=${c5}
palette = 6=${c6}
palette = 7=${c7}
palette = 8=${c8}
palette = 9=${c9}
palette = 10=${c10}
palette = 11=${c11}
palette = 12=${c12}
palette = 13=${c13}
palette = 14=${c14}
palette = 15=${c15}
cursor-color = ${cur}
cursor-text = ${bg}
EOF

  # hypr / hyprlock (literal $vars -> printf)
  {
    printf '# %s hypr/hyprlock colors.\n' "$tag"
    _dfa_hypr_var rosewater "$c7";  _dfa_hypr_var flamingo "$c7"
    _dfa_hypr_var pink "$c13";      _dfa_hypr_var mauve "$c5"
    _dfa_hypr_var red "$c1";        _dfa_hypr_var maroon "$c9"
    _dfa_hypr_var peach "$c11";     _dfa_hypr_var yellow "$c3"
    _dfa_hypr_var green "$c2";      _dfa_hypr_var teal "$c6"
    _dfa_hypr_var sky "$c6";        _dfa_hypr_var sapphire "$c4"
    _dfa_hypr_var blue "$c4";       _dfa_hypr_var lavender "$c12"
    _dfa_hypr_var text "$fg";       _dfa_hypr_var subtext1 "$c7"
    _dfa_hypr_var subtext0 "$c7";   _dfa_hypr_var overlay2 "$c8"
    _dfa_hypr_var overlay1 "$c8";   _dfa_hypr_var overlay0 "$c8"
    _dfa_hypr_var surface2 "$c8";   _dfa_hypr_var surface1 "$c0"
    _dfa_hypr_var surface0 "$c0";   _dfa_hypr_var base "$bg"
    _dfa_hypr_var mantle "$bg";     _dfa_hypr_var crust "$bg"
    printf '%s\n' "" \
      "\$active_border = rgba(${c5#\#}ee) rgba(${c4#\#}ee) 45deg" \
      "\$inactive_border = rgba(${c8#\#}aa)" \
      "\$shadow_color = rgba(${bg#\#}ee)"
  } >"$dest/.config/hypr/current-theme.conf"

  # waybar
  #
  # The workspaces group is the bar's centrepiece, but it used to draw entirely
  # from the achromatic slots -- ws-bg=c0, ws-fg=c8, ws-fg-occupied=c7,
  # ws-fg-active=fg -- while every hue in the palette went to the pills. So it
  # rendered as grey chrome, and because each theme's grey ramp is tonally
  # similar it looked near-identical across all 41 themes. It also disappeared
  # outright in the 8 palettes where c0 IS the background (gruvbox, monokai/-pro,
  # onedark, oxocarbon, palenight, zenburn), since the bar draws @bar-bg.
  #
  # Treat it as a pill instead, and assign the bar's accents like this:
  #
  #   both left pills + the primary right pill   one shared accent
  #   workspaces                                 its own accent
  #   theme switcher                             its own accent
  #   battery                                    not themed at all -- the fixed
  #                                              red-to-green traffic-light
  #                                              palette in style.css
  #
  # Which hue lands where is drawn per theme instead of being the fixed
  # c5/c4/c6/c3 order every theme used to share, which made the bars recognisably
  # the same layout regardless of palette. The draw is seeded from the theme's
  # own identity, so it varies between themes and is identical on every rebuild.
  #
  # Red is held out of the pool: it carries error semantics elsewhere (walker's
  # error banner, starship's failure marker) and the battery's critical state.
  # That leaves five hue families, each with a normal and a bright slot; the
  # variant taken is whichever contrasts better with the bar.
  local -a _fam_lo=("$c2" "$c3" "$c4" "$c5" "$c6")
  local -a _fam_hi=("$c10" "$c11" "$c12" "$c13" "$c14")
  local -a pool=()
  local i j cand
  for i in 0 1 2 3 4; do
    cand=$(_df_theme_pick_variant "${_fam_lo[i]}" "${_fam_hi[i]}" "$bg")
    # Skip a hue that duplicates one already chosen -- a few palettes reuse the
    # same hex across slots, and "independent" has to mean visibly independent.
    for j in "${pool[@]}"; do [[ "${j,,}" == "${cand,,}" ]] && continue 2; done
    pool+=( "$cand" )
  done
  # Last-resort top-up for near-monochrome palettes, so three distinct accents
  # always exist. Red is acceptable here because the alternative is a collision.
  for cand in "$c1" "$c9" "$c7" "$c15"; do
    (( ${#pool[@]} >= 3 )) && break
    for j in "${pool[@]}"; do [[ "${j,,}" == "${cand,,}" ]] && continue 2; done
    pool+=( "$cand" )
  done

  # Fisher-Yates over the pool, driven by an LCG seeded with the theme name and
  # its hues. Including the palette (not just the name) means `theme auto`, which
  # is always called "auto", still redraws when the wallpaper changes.
  local seed tmp n=${#pool[@]}
  seed=$(_df_theme_hash "${name}|${c1}${c2}${c3}${c4}${c5}${c6}")
  for (( i = n - 1; i > 0; i-- )); do
    seed=$(( (seed * 1103515245 + 12345) & 0x7FFFFFFF ))
    j=$(( seed % (i + 1) ))
    tmp=${pool[i]}; pool[i]=${pool[j]}; pool[j]=$tmp
  done
  local accent_pill=${pool[0]} accent_ws=${pool[1]} accent_theme=${pool[2]}

  # The pill inks used to come from _dfa_contrast_fg, which picks near-black or
  # near-white by Rec.601 luma and never measures the result -- exactly what
  # AGENTS.md warns against when the question is legibility. On a mid-luminance
  # accent neither ink reaches AA (dawnfox's #3f83a6 tops out at 4.37:1 with
  # #141414), so the pill text sat just under target with nothing to catch it.
  #
  # _dfa_pair_for is the tool that already solves this for the starship
  # segments: it picks the ink by measurement and, only where no ink can clear
  # AA, deepens the surface itself by at most 25%. Assign the corrected accent
  # back over accent_pill/accent_theme so everything downstream -- including the
  # workspace-dot ramp, which uses the pill accent as its hue source -- sees the
  # colour the bar will actually show.
  local pill_ink theme_ink
  read -r accent_pill pill_ink <<<"$(_dfa_pair_for "$accent_pill" "$fg" "$bg")"
  read -r accent_theme theme_ink <<<"$(_dfa_pair_for "$accent_theme" "$fg" "$bg")"

  # The workspace dots ramp the *pill* accent toward the ink of the workspace
  # surface: a guaranteed-different hue, so the dots carry colour of their own
  # rather than being a darker wash of the surface they sit on. Ramping toward
  # the ink (not the surface) keeps it legible in both polarities -- the ink
  # flips with the surface.
  #
  # 25/55/85 were fixed stops, chosen for a monotonic ramp and a faint empty
  # state. They were never checked against the *surface*, though, and nothing in
  # the formula constrains that: the ramp starts from a different hue, so on
  # palettes where the pill accent sits near the workspace surface in luminance
  # the middle of the ramp lands almost on top of it. The occupied dot fell below
  # the 3:1 dot target in 16 of 40 themes, worst catppuccin-latte at 1.29:1.
  #
  # The occupied stop now starts at 55 and walks up until it measures 3:1 against
  # the surface, so the 24 themes that already passed keep their exact colours and
  # only the failures move. Active keeps its 15-point lead over occupied so the
  # ramp stays ordered. Empty stays fixed and deliberately faint -- an empty
  # workspace is chrome, and belongs below 3:1.
  local ws_bg=$accent_ws
  local ws_ink ws_occupied ws_empty ws_active ws_stop ws_active_stop
  ws_ink=$(_dfa_contrast_fg "$accent_ws")
  ws_empty=$(_df_theme_mix "$accent_pill" "$ws_ink" 25)
  ws_stop=55
  while (( ws_stop < 95 )) \
    && (( $(_dfa_contrast "$(_df_theme_mix "$accent_pill" "$ws_ink" "$ws_stop")" "$ws_bg") < 3000 )); do
    ws_stop=$(( ws_stop + 5 ))
  done
  ws_active_stop=$(( ws_stop + 15 ))
  (( ws_active_stop < 85 )) && ws_active_stop=85
  (( ws_active_stop > 100 )) && ws_active_stop=100
  ws_occupied=$(_df_theme_mix "$accent_pill" "$ws_ink" "$ws_stop")
  ws_active=$(_df_theme_mix "$accent_pill" "$ws_ink" "$ws_active_stop")
  # The volume/backlight sliders live inside the right-controls pill, and
  # style.css used to draw their fill straight from @ws-bg. That is invisible
  # wherever the workspace surface and the ctrl pill are both accents of similar
  # luminance -- 36 of the 40 shipped themes measured under 3:1, two of them at
  # exactly 1.00:1. @slider-fg gives the fill a seam of its own so a theme can
  # break away from that; it defaults to @ws-bg, so emitting it changes nothing
  # anywhere until a theme's override pins it to something legible.
  cat >"$dest/.config/waybar/colors.css" <<EOF
/* ${tag} waybar palette */
@define-color bar-bg          ${bg};
@define-color bar-fg          ${fg};
@define-color ws-bg           ${ws_bg};
@define-color ws-fg           ${ws_empty};
@define-color ws-fg-occupied  ${ws_occupied};
@define-color ws-fg-active    ${ws_active};
@define-color pill-brand-bg   ${accent_pill};
@define-color pill-brand-fg   ${pill_ink};
@define-color pill-stats-bg   ${accent_pill};
@define-color pill-stats-fg   ${pill_ink};
@define-color pill-ctrl-bg    ${accent_pill};
@define-color pill-ctrl-fg    ${pill_ink};
@define-color pill-theme-bg   ${accent_theme};
@define-color pill-theme-fg   ${theme_ink};
@define-color ws-glow          ${ws_active};
@define-color slider-fg       ${ws_bg};
EOF

  # walker
  #
  # accent_bg_color is the launcher's chrome -- window and preview borders.
  # highlight_bg_color is the selected row alone. They were one key, so a theme
  # could not give the selection a hue of its own; both default to c5 here, so
  # splitting them changed no theme's appearance.
  #
  # highlight_bg_color carries its own alpha rather than the stylesheet applying
  # one. With `alpha(@highlight_bg_color, 0.25)` hardcoded in the rule, the row
  # could only ever be 25% of the way from the window background toward the
  # accent, so a theme could not put the selection ON a palette colour: solving
  # 0.25*H + 0.75*window = c2 green for a mauve window needs H = (442,734,437),
  # far outside the gamut, and the brightest reachable row is #776b74. Keeping
  # the alpha in the value emits an identical colour for every theme while
  # letting one pin a solid accent. highlight_fg_color defaults to the shared
  # foreground for the same reason -- it only matters once a theme makes the
  # selection opaque. Every colour walker's
  # stylesheets reference must be defined here for every theme: an undefined
  # @colour makes GTK drop the whole rule, which silently removes the selection
  # background rather than erroring. tests/repo.bats asserts the pairing.
  cat >"$dest/.config/walker/colors.css" <<EOF
/* ${tag} walker palette */
@define-color window_bg_color ${bg};
@define-color accent_bg_color ${c5};
@define-color highlight_bg_color alpha(${c5}, 0.25);
@define-color highlight_fg_color ${fg};
@define-color theme_fg_color  ${fg};
@define-color error_bg_color  ${c1};
@define-color error_fg_color  ${bg};
EOF

  # tmux
  #
  # status-style is the modern option; status-bg/status-fg are the deprecated
  # pair it replaced. Setting status-bg does NOT update status-style (`show -g
  # status-style` keeps reporting its own value), but at render time the
  # deprecated pair WINS -- verified by capturing what a client emits: with
  # status-style left at its default green and only status-bg set, tmux writes
  # the status-bg colour.
  #
  # That precedence is why the seam has to clear them. tmux options live in the
  # server, not the config file, so a long-running server that ever sourced an
  # older seam still holds its status-bg, and it would override every later
  # theme's status-style forever -- the bar would simply stop following the
  # theme. `set -gu` is idempotent, so this is harmless where they were never set.
  cat >"$dest/.config/tmux/current-theme.conf" <<EOF
# ${tag} tmux colors
set -g pane-border-style fg=${c8}
set -g pane-active-border-style fg=${c5}
set -gu status-bg
set -gu status-fg
set -g status-style 'bg=${bg},fg=${fg}'
set -g status-left '#[fg=${c6}]#S #[fg=${c3}]|'
set -g status-right '#[fg=${c6}]%Y-%m-%d #[fg=${fg}]%H:%M #[fg=${c3}][#(whoami)]'
setw -g window-status-format '#I:#W'
setw -g window-status-current-format '#[fg=${c7},bold]#I:#W#[default]'
EOF

  # shell theme-env: fzf colors from palette; BAT_THEME per theme
  cat >"$dest/.config/shell/theme-env.sh" <<EOF
# shellcheck shell=sh
# ${tag} shell theme environment.
export BAT_THEME="${bat_theme}"
export FZF_DEFAULT_OPTS=" \\
  --color=bg+:${c0},bg:${bg},spinner:${c6},hl:${c1} \\
  --color=fg:${fg},header:${c1},info:${c5},pointer:${c6} \\
  --color=marker:${c6},fg+:${fg},prompt:${c5},hl+:${c1}"
EOF

  # opencode
  cat >"$dest/.config/opencode/tui.json" <<EOF
{
  "\$schema": "https://opencode.ai/tui.json",
  "theme": "${opencode}"
}
EOF

  # btop: a named theme "current" (activate once with color_theme = "current" in
  # btop.conf -- press `t` in btop). Neutral chrome (meters, dividers) needs to
  # sit on the *background* side, so it comes from the dim grey c8 on dark
  # palettes and the light grey c7 on light ones; without that split a light
  # theme draws dark bars on a light canvas.
  local btop_neutral=$c8
  [[ "$bgmode" == "light" ]] && btop_neutral=$c7
  cat >"$dest/.config/btop/themes/current.theme" <<EOF
# ${tag} btop theme (generated by tools/build-themes.sh -- do not hand-edit).
theme[main_bg]="${bg}"
theme[main_fg]="${fg}"
theme[title]="${fg}"
theme[hi_fg]="${c5}"
theme[selected_bg]="${c5}"
theme[selected_fg]="${bg}"
theme[inactive_fg]="${c8}"
theme[graph_text]="${fg}"
theme[meter_bg]="${btop_neutral}"
theme[proc_misc]="${c4}"
theme[cpu_box]="${c4}"
theme[mem_box]="${c2}"
theme[net_box]="${c1}"
theme[proc_box]="${c6}"
theme[div_line]="${btop_neutral}"
theme[temp_start]="${c2}"
theme[temp_mid]="${c3}"
theme[temp_end]="${c1}"
theme[cpu_start]="${c2}"
theme[cpu_mid]="${c3}"
theme[cpu_end]="${c1}"
theme[free_start]="${c2}"
theme[free_mid]="${c6}"
theme[free_end]="${c4}"
theme[cached_start]="${c6}"
theme[cached_mid]="${c4}"
theme[cached_end]="${c5}"
theme[available_start]="${c3}"
theme[available_mid]="${c5}"
theme[available_end]="${c1}"
theme[used_start]="${c3}"
theme[used_mid]="${c1}"
theme[used_end]="${c5}"
theme[download_start]="${btop_neutral}"
theme[download_mid]="${c6}"
theme[download_end]="${c4}"
theme[upload_start]="${btop_neutral}"
theme[upload_mid]="${c5}"
theme[upload_end]="${c1}"
theme[process_start]="${c3}"
theme[process_mid]="${c2}"
theme[process_end]="${c6}"
EOF

  # nvim
  _dfa_emit_nvim "$dest" "$name" "$nvim_spec" "$bgmode"

  # starship: reuse the shared file's structure, swap only the palette block.
  local base_starship="$DF_REPO/$DF_HOME_LAYER/.config/starship.toml"
  if [[ -f "$base_starship" ]]; then
    # Every segment's ink is measured against its OWN background rather than
    # sharing the palette foreground. Sharing it was a systemic contrast failure:
    # color_fg_primary is the palette's light text, and the template drew it on
    # the os, path and git-status accents, so on any palette whose accents are
    # mid-to-light it was light-on-light. Sweeping the shipped themes before this
    # change, all 40 had at least one starship pair under 4.5:1 across 190
    # distinct pairs -- worst were github-light drawing #24292f on #24292f (an
    # invisible os/user segment) and onedark's repo root at 1.00:1.
    local star_os_bg star_os_fg star_dir_bg star_dir_fg star_repo_bg star_repo_fg
    local star_change_fg star_diverge_fg
    read -r star_os_bg star_os_fg <<<"$(_dfa_pair_for "$c0" "$fg" "$bg")"
    read -r star_dir_bg star_dir_fg <<<"$(_dfa_pair_for "$c4" "$fg" "$bg")"
    read -r star_repo_bg star_repo_fg <<<"$(_dfa_pair_for "$c5" "$fg" "$bg")"
    # The ahead/behind segment draws on the same c4 as the path, so it takes the
    # same pair -- letting them diverge would put two nearly-identical blues on
    # the one line.
    star_diverge_fg=$star_dir_fg
    # The git-status change segment draws text on c8 -- the same surface, and the
    # same problem, as terminal selection. Reuse that already-measured pair rather
    # than solving it twice: it keeps c8 where c8 reads and moves the surface only
    # on the palettes where no ink can clear AA against it, which is the one case
    # _dfa_ink_for cannot fix on its own (it may only choose the ink).
    star_change_fg=$sel_fg
    local star_change_bg=$sel_bg

    # The repo-root name sits inside the path pill, so it needs to be legible on
    # the path accent while staying a hue of its own -- the same problem the
    # workspace dots have, solved the same way: start at the palette's cyan and
    # ramp it toward the ink of that surface only as far as AA requires, so
    # palettes where cyan already reads keep cyan exactly.
    local star_repo_root=$c6 _rr_stop=0 _rr_ink
    _rr_ink=$(_dfa_contrast_fg "$star_dir_bg")
    while (( _rr_stop < 100 )) \
      && (( $(_dfa_contrast "$star_repo_root" "$star_dir_bg") < 4500 )); do
      _rr_stop=$(( _rr_stop + 5 ))
      star_repo_root=$(_df_theme_mix "$c6" "$_rr_ink" "$_rr_stop")
    done

    # The IP row draws straight onto the terminal background, and both of its
    # colours were raw palette slots that nothing measured:
    #
    #   color_fg_sep    the  /  angle brackets and the "/" divider.
    #                   These are chrome -- they carry no information and are
    #                   meant to recede -- so the target is 3:1, not 4.5:1.
    #                   c8 missed even that in 24 of 40 themes (palenight 1.48:1).
    #   color_fg_right  the clock, local IP and external IP. That is content, so
    #                   4.5:1. c7 missed in 4 themes (solarized-light 1.13:1).
    #
    # Ramp each toward the background's own contrasting ink only as far as its
    # target needs, so the themes already passing keep their exact slot.
    local star_fg_sep star_fg_right _bg_ink
    _bg_ink=$(_dfa_contrast_fg "$bg")
    star_fg_sep=$(_dfa_ramp_to "$c8" "$_bg_ink" "$bg" 3000)
    star_fg_right=$(_dfa_ramp_to "$c7" "$_bg_ink" "$bg" 4500)

    # style_root marks a root shell. The shared template hardcoded ANSI `yellow`
    # on color_os_bg, which disappears whenever os_bg is light or a mid accent --
    # 10 themes measured under 4.5:1, dawnfox at 1.11:1 and rose-pine-dawn the
    # same. Derive it from the palette's own red, ramped against the os segment
    # it actually sits on, so the warning stays a warning colour and stays legible.
    local star_root_fg
    star_root_fg=$(_dfa_ramp_to "$c1" "$(_dfa_contrast_fg "$star_os_bg")" "$star_os_bg" 4500)

    local block; block=$(mktemp)
    {
      printf "color_fg_primary = '%s'\n" "$fg"
      printf "color_os_bg = '%s'\n" "$star_os_bg"
      printf "color_os_fg = '%s'\n" "$star_os_fg"
      printf "color_time_bg = '%s'\n" "$c5"
      printf "color_dir_bg = '%s'\n" "$star_dir_bg"
      printf "color_dir_fg = '%s'\n" "$star_dir_fg"
      printf "color_dir_repo_fg = '%s'\n" "$star_repo_root"
      printf "color_red = '%s'\n" "$c1"
      printf "color_connector = '%s'\n" "$c4"
      printf "color_repo_fg = '%s'\n" "$star_repo_fg"
      printf "color_repo_bg = '%s'\n" "$star_repo_bg"
      printf "color_repo_change_fg = '%s'\n" "$star_change_fg"
      printf "color_repo_change_bg = '%s'\n" "$star_change_bg"
      printf "color_repo_diverge_fg = '%s'\n" "$star_diverge_fg"
      printf "color_repo_diverge_bg = '%s'\n" "$star_dir_bg"
      printf "color_fg_right = '%s'\n" "$star_fg_right"
      printf "color_fg_sep = '%s'\n" "$star_fg_sep"
      printf "color_root_fg = '%s'\n" "$star_root_fg"
    } >"$block"
    awk -v rf="$block" '
      /^\[palettes\.starship_dubba\]/ { print; while ((getline line < rf) > 0) print line; close(rf); skip=1; next }
      skip==1 && /^\[/ { skip=0 }
      skip==1 { next }
      { print }
    ' "$base_starship" >"$dest/.config/starship.toml"
    rm -f "$block"
  fi
}

# Emit lua/dotfiles_theme.lua for the given nvim integration spec.
_dfa_emit_nvim() {
  local dest=$1 name=$2 spec=$3 bgmode=$4
  local f="$dest/.config/nvim/lua/dotfiles_theme.lua"
  local bg=${PAL[background]} fg=${PAL[foreground]}
  local c0=${PAL[color0]} c1=${PAL[color1]} c2=${PAL[color2]} c3=${PAL[color3]}
  local c4=${PAL[color4]} c5=${PAL[color5]} c6=${PAL[color6]} c7=${PAL[color7]}
  local c8=${PAL[color8]} c11=${PAL[color11]} c15=${PAL[color15]}
  case "$spec" in
    catppuccin:*)
      printf 'return { name = "%s", colorscheme = "catppuccin", flavour = "%s", background = "%s" }\n' \
        "$name" "${spec#catppuccin:}" "$bgmode" >"$f" ;;
    gruvbox:*)
      printf 'return { name = "%s", colorscheme = "gruvbox", background = "%s" }\n' \
        "$name" "${spec#gruvbox:}" >"$f" ;;
    *)
      cat >"$f" <<EOF
-- ${name}: base16 palette consumed by lua/plugins/colorscheme.lua
return {
  name = "$name",
  colorscheme = "base16",
  background = "$bgmode",
  base16 = {
    base00 = "$bg", base01 = "$c0", base02 = "$c8", base03 = "$c8",
    base04 = "$c7", base05 = "$fg", base06 = "$c7", base07 = "$c15",
    base08 = "$c1", base09 = "$c11", base0A = "$c3", base0B = "$c2",
    base0C = "$c6", base0D = "$c4", base0E = "$c5", base0F = "$c1",
  },
}
EOF
      ;;
  esac
}

# Generate the full themes/auto/ tree from <image>, copy the wallpaper, and
# record machine-local source/hash state (used by the watcher).
df_autotheme_generate() {
  local img=$1
  local auto="$DF_REPO/$DF_THEMES_DIR/$DF_AUTO_THEME_NAME"

  local -A PAL=()
  local k v
  while IFS='=' read -r k v; do
    [[ -n "$k" ]] && PAL[$k]=$v
  done < <(df_palette_extract "$img")

  df_theme_emit_seams "$auto" "Auto-generated (wallpaper-derived)" base16 ansi system

  # wallpaper
  cp -f -- "$img" "$auto/.config/background"

  # record machine-local source + hash (loop-guard / watcher use)
  mkdir -p "$DF_STATE_DIR"
  printf '%s\n' "$img" >"$(df_state_autotheme_source_file)"
  if command -v sha256sum &>/dev/null; then
    sha256sum "$img" 2>/dev/null | awk '{print $1}' >"$(df_state_autotheme_hash_file)" || true
  fi
}

# --- Activation (link + reload), mirrors the theme set/unset path -----------
df_autotheme_apply() {
  local apply_rc=0
  df_resolve_layers
  df_build_plan
  trap df_cleanup_plan RETURN
  df_print_plan 0
  # A conflict must not abort the reload (see lib/commands/theme.sh): the links
  # are already applied, so bailing here would just leave every tool -- and the
  # Hyprland error state -- on the previous theme.
  df_apply_plan || apply_rc=$?
  if [[ "$DF_TARGET" == "$HOME" ]]; then
    df_log ""
    df_info "reloading running tools..."
    _df_theme_reload
  fi
  return "$apply_rc"
}

# --- Subcommand entry points ------------------------------------------------

# One-off generate + apply. Optional positional <image>; else detect current.
df_autotheme_run() {
  local img=${1:-}
  if [[ -z "$img" ]]; then
    img=$(df_autotheme_current_wallpaper) \
      || df_die "could not detect the current wallpaper; pass one: dotfiles theme auto now <image>"
  fi
  [[ -f "$img" ]] || df_die "image not found: $img"

  df_autotheme_backend_notice
  df_info "generating auto theme from: $img"
  df_autotheme_generate "$img"
  mkdir -p "$DF_STATE_DIR"
  printf 'on\n' >"$(df_state_autotheme_file)"   # auto becomes the active theme
  df_log ""
  df_info "applying auto theme..."
  df_autotheme_apply
  df_ok "auto theme generated and applied"
}

df_autotheme_enable() {
  mkdir -p "$DF_STATE_DIR"
  printf 'on\n' >"$(df_state_autotheme_watch_file)"   # request continuous mode
  df_autotheme_run "${1:-}"
  if command -v systemctl &>/dev/null; then
    # Pick up a freshly-linked unit (post-merge hook links but never reloads).
    systemctl --user daemon-reload &>/dev/null || true
    if systemctl --user cat dotfiles-autotheme.service &>/dev/null; then
      if systemctl --user enable --now dotfiles-autotheme.service &>/dev/null; then
        df_ok "wallpaper watcher enabled (systemd user service)"
      else
        df_warn "could not enable dotfiles-autotheme.service"
      fi
    else
      df_dim "watcher unit not found - run 'dotfiles link' (then 'systemctl --user daemon-reload') and re-run enable"
    fi
  fi
}

df_autotheme_disable() {
  local was=0
  df_autotheme_enabled && was=1
  if command -v systemctl &>/dev/null \
     && systemctl --user is-active dotfiles-autotheme.service &>/dev/null; then
    systemctl --user disable --now dotfiles-autotheme.service &>/dev/null || true
  fi
  rm -f -- "$(df_state_autotheme_file)" "$(df_state_autotheme_watch_file)"
  if (( was )); then
    df_ok "auto-theming disabled; reverting to theme '$(df_theme_name)'"
    df_log ""
    df_info "applying..."
    df_autotheme_apply
  else
    df_dim "auto-theming was not enabled"
  fi
}

df_autotheme_status() {
  if df_autotheme_enabled; then
    df_info "auto-theming: enabled (auto is the active theme)"
  else
    df_dim "auto-theming: disabled"
  fi
  df_autotheme_watch_enabled && df_dim "continuous watch: requested"

  case "$(df_autotheme_backend)" in
    wallust) df_ok   "palette backend: wallust" ;;
    pywal)   df_warn "palette backend: pywal (install 'wallust' for better palettes)" ;;
    python)  df_warn "palette backend: python+Pillow (install 'wallust' - recommended - or 'pywal' for better palettes)" ;;
    none)    df_error "palette backend: none (install 'wallust', 'pywal', or python3 + Pillow)" ;;
  esac

  local sf; sf=$(df_state_autotheme_source_file)
  [[ -f "$sf" ]] && df_dim "source wallpaper: $(cat "$sf")"
  if [[ -d "$DF_REPO/$DF_THEMES_DIR/$DF_AUTO_THEME_NAME" ]]; then
    df_dim "generated: $DF_THEMES_DIR/$DF_AUTO_THEME_NAME/"
  else
    df_dim "not generated yet (run 'dotfiles theme auto now')"
  fi
}

# Continuous watcher (run by the systemd user service; DE-specific detection).
# Polls the current wallpaper and regenerates when it changes. Loop-safe: the
# generated theme copies the source to ~/.config/background, whose content hash
# matches the last-processed source, so re-applying does not re-trigger.
df_autotheme_watch() {
  local interval=${1:-2}
  command -v sha256sum &>/dev/null || df_die "auto watch requires sha256sum"
  df_info "auto-theme watcher started (poll ${interval}s)"
  while :; do
    df_autotheme_watch_tick || true
    sleep "$interval"
  done
}

# One watch iteration. Regenerates + applies when the current wallpaper differs
# from the last-processed hash; returns 0 if it did, non-zero otherwise.
df_autotheme_watch_tick() {
  local cur h last
  cur=$(df_autotheme_current_wallpaper) || return 1
  [[ -f "$cur" ]] || return 1
  h=$(sha256sum -- "$cur" 2>/dev/null | awk '{print $1}')
  [[ -n "$h" ]] || return 1
  last=$(cat "$(df_state_autotheme_hash_file)" 2>/dev/null || true)
  [[ "$h" != "$last" ]] || return 1
  df_info "wallpaper changed; regenerating auto theme from: $cur"
  df_autotheme_generate "$cur"
  printf 'on\n' >"$(df_state_autotheme_file)"
  df_autotheme_apply
}
