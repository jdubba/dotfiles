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

  # kitty
  cat >"$dest/.config/kitty/current-theme.conf" <<EOF
# ${tag} kitty colors.
foreground              ${fg}
background              ${bg}
selection_foreground    ${fg}
selection_background    ${c8}
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
selection-background = ${c8}
selection-foreground = ${fg}
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

  # The workspace dots ramp the *pill* accent toward the ink of the workspace
  # surface: a guaranteed-different hue, so the dots carry colour of their own
  # rather than being a darker wash of the surface they sit on. Ramping toward
  # the ink (not the surface) keeps it legible in both polarities -- the ink
  # flips with the surface. The 25/55/85 stops were picked by measuring every
  # palette: they keep the ramp monotonic and hold the faintest state near 2:1.
  local ws_bg=$accent_ws
  local ws_ink ws_occupied ws_empty ws_active
  ws_ink=$(_dfa_contrast_fg "$accent_ws")
  ws_empty=$(_df_theme_mix "$accent_pill" "$ws_ink" 25)
  ws_occupied=$(_df_theme_mix "$accent_pill" "$ws_ink" 55)
  ws_active=$(_df_theme_mix "$accent_pill" "$ws_ink" 85)
  cat >"$dest/.config/waybar/colors.css" <<EOF
/* ${tag} waybar palette */
@define-color bar-bg          ${bg};
@define-color bar-fg          ${fg};
@define-color ws-bg           ${ws_bg};
@define-color ws-fg           ${ws_empty};
@define-color ws-fg-occupied  ${ws_occupied};
@define-color ws-fg-active    ${ws_active};
@define-color pill-brand-bg   ${accent_pill};
@define-color pill-brand-fg   $(_dfa_contrast_fg "$accent_pill");
@define-color pill-stats-bg   ${accent_pill};
@define-color pill-stats-fg   $(_dfa_contrast_fg "$accent_pill");
@define-color pill-ctrl-bg    ${accent_pill};
@define-color pill-ctrl-fg    $(_dfa_contrast_fg "$accent_pill");
@define-color pill-theme-bg   ${accent_theme};
@define-color pill-theme-fg   $(_dfa_contrast_fg "$accent_theme");
@define-color ws-glow          ${ws_active};
EOF

  # walker
  cat >"$dest/.config/walker/colors.css" <<EOF
/* ${tag} walker palette */
@define-color window_bg_color ${bg};
@define-color accent_bg_color ${c5};
@define-color theme_fg_color  ${fg};
@define-color error_bg_color  ${c1};
@define-color error_fg_color  ${bg};
EOF

  # tmux
  cat >"$dest/.config/tmux/current-theme.conf" <<EOF
# ${tag} tmux colors
set -g pane-border-style fg=${c8}
set -g pane-active-border-style fg=${c5}
set -g status-bg '${bg}'
set -g status-fg '${fg}'
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
    local block; block=$(mktemp)
    {
      printf "color_fg_primary = '%s'\n" "$fg"
      printf "color_os_bg = '%s'\n" "$c0"
      printf "color_time_bg = '%s'\n" "$c5"
      printf "color_dir_bg = '%s'\n" "$c4"
      printf "color_dir_repo_fg = '%s'\n" "$c6"
      printf "color_red = '%s'\n" "$c1"
      printf "color_connector = '%s'\n" "$c4"
      printf "color_repo_fg = '%s'\n" "$fg"
      printf "color_repo_bg = '%s'\n" "$c5"
      printf "color_repo_change_fg = '%s'\n" "$fg"
      printf "color_repo_change_bg = '%s'\n" "$c8"
      printf "color_repo_diverge_fg = '%s'\n" "$fg"
      printf "color_repo_diverge_bg = '%s'\n" "$c4"
      printf "color_fg_right = '%s'\n" "$c7"
      printf "color_fg_sep = '%s'\n" "$c8"
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
