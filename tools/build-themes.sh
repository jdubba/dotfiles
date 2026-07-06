#!/usr/bin/env bash
#
# tools/build-themes.sh - (re)generate the curated theme layers under themes/
# from a palette registry, using the shared seam emitter (lib/theme-auto.sh).
#
# Each theme is one build_theme row: official/canonical 16-colour palette +
# integration metadata. nvim uses the catppuccin/gruvbox plugins where a
# flavour/background exists, else a base16 palette; bat uses a built-in theme
# where bat ships one, else "ansi" (follows the themed terminal); opencode uses
# a built-in theme where one exists, else "system".
#
# Wallpapers: generated from the palette (lib/theme-auto/wallpaper.py) only when
# themes/<name>/.config/background is absent, so real drop-in wallpapers are
# preserved. Re-run any time; it's idempotent.
#
# Usage: tools/build-themes.sh [name ...]   (no args = all)

set -euo pipefail

DF_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DF_REPO
# shellcheck source=lib/core.sh
source "$DF_REPO/lib/core.sh"
# shellcheck source=lib/config.sh
source "$DF_REPO/lib/config.sh"
# shellcheck source=lib/identity.sh
source "$DF_REPO/lib/identity.sh"
# shellcheck source=lib/theme.sh
source "$DF_REPO/lib/theme.sh"
# shellcheck source=lib/theme-auto.sh
source "$DF_REPO/lib/theme-auto.sh"
df_load_repo_config

ONLY=("$@")

_wanted() {
  [[ ${#ONLY[@]} -eq 0 ]] && return 0
  local n
  for n in "${ONLY[@]}"; do [[ "$n" == "$1" ]] && return 0; done
  return 1
}

gen_wallpaper() {
  local dest=$1 bg=$2 accent=$3 mode=$4
  local bgfile="$dest/.config/background"
  [[ -f "$bgfile" ]] && return 0   # preserve an existing (real) wallpaper
  command -v python3 &>/dev/null || return 0
  python3 "$DF_REPO/lib/theme-auto/wallpaper.py" "$bgfile" "$bg" "$accent" "" "$mode" 2>/dev/null || true
}

# build_theme <name> <nvim> <bat> <opencode> <mode> <bg> <fg> <c0..c15>
build_theme() {
  _wanted "$1" || return 0
  local name=$1 nvim=$2 bat=$3 opencode=$4 mode=$5 bg=$6 fg=$7
  shift 7
  local -A PAL=()
  PAL[background]="#${bg#\#}" PAL[foreground]="#${fg#\#}" PAL[cursor]="#${fg#\#}" PAL[background_mode]=$mode
  local i
  for i in $(seq 0 15); do PAL[color$i]="#${1#\#}"; shift; done
  local dest="$DF_REPO/$DF_THEMES_DIR/$name"
  df_theme_emit_seams "$dest" "$name" "$nvim" "$bat" "$opencode"
  gen_wallpaper "$dest" "${PAL[background]}" "${PAL[color4]}" "$mode"
  printf '  %s\n' "$name"
}

df_info "building themes into $DF_THEMES_DIR/ ..."

#            name                 nvim                 bat                  opencode              mode  bg     fg     c0     c1     c2     c3     c4     c5     c6     c7     c8     c9     c10    c11    c12    c13    c14    c15
# --- Catppuccin ---
build_theme catppuccin-latte      catppuccin:latte     ansi                 catppuccin            light eff1f5 4c4f69 5c5f77 d20f39 40a02b df8e1d 1e66f5 ea76cb 179299 acb0be 6c6f85 d20f39 40a02b df8e1d 1e66f5 ea76cb 179299 bcc0cc
build_theme catppuccin-frappe     catppuccin:frappe    ansi                 catppuccin            dark  303446 c6d0f5 51576d e78284 a6d189 e5c890 8caaee f4b8e4 81c8be b5bfe2 626880 e78284 a6d189 e5c890 8caaee f4b8e4 81c8be a5adce
build_theme catppuccin-macchiato  catppuccin:macchiato ansi                 catppuccin-macchiato  dark  24273a cad3f5 494d64 ed8796 a6da95 eed49f 8aadf4 f5bde6 8bd5ca b8c0e0 5b6078 ed8796 a6da95 eed49f 8aadf4 f5bde6 8bd5ca a5adcb
build_theme catppuccin-mocha      catppuccin:mocha     ansi                 catppuccin            dark  1e1e2e cdd6f4 45475a f38ba8 a6e3a1 f9e2af 89b4fa f5c2e7 94e2d5 bac2de 585b70 f38ba8 a6e3a1 f9e2af 89b4fa f5c2e7 94e2d5 a6adc8

# --- Nord ---
build_theme nord                  base16               Nord                 nord                  dark  2e3440 d8dee9 3b4252 bf616a a3be8c ebcb8b 81a1c1 b48ead 88c0d0 e5e9f0 4c566a bf616a a3be8c ebcb8b 81a1c1 b48ead 8fbcbb eceff4

# --- Solarized ---
build_theme solarized-dark        base16               "Solarized (dark)"   system                dark  002b36 839496 073642 dc322f 859900 b58900 268bd2 d33682 2aa198 eee8d5 586e75 cb4b16 859900 b58900 268bd2 6c71c4 93a1a1 fdf6e3
build_theme solarized-light       base16               "Solarized (light)"  system                light fdf6e3 657b83 073642 dc322f 859900 b58900 268bd2 d33682 2aa198 eee8d5 586e75 cb4b16 859900 b58900 268bd2 6c71c4 93a1a1 fdf6e3

# --- Rose Pine ---
build_theme rose-pine             base16               ansi                 system                dark  191724 e0def4 26233a eb6f92 31748f f6c177 9ccfd8 c4a7e7 ebbcba e0def4 6e6a86 eb6f92 31748f f6c177 9ccfd8 c4a7e7 ebbcba e0def4
build_theme rose-pine-moon        base16               ansi                 system                dark  232136 e0def4 393552 eb6f92 3e8fb0 f6c177 9ccfd8 c4a7e7 ea9a97 e0def4 6e6a86 eb6f92 3e8fb0 f6c177 9ccfd8 c4a7e7 ea9a97 e0def4
build_theme rose-pine-dawn        base16               ansi                 system                light faf4ed 575279 f2e9e1 b4637a 286983 ea9d34 56949f 907aa9 d7827e 575279 9893a5 b4637a 286983 ea9d34 56949f 907aa9 d7827e 575279

# --- Gruvbox ---
build_theme gruvbox-dark          gruvbox:dark         gruvbox-dark         gruvbox               dark  282828 ebdbb2 282828 cc241d 98971a d79921 458588 b16286 689d6a a89984 928374 fb4934 b8bb26 fabd2f 83a598 d3869b 8ec07c ebdbb2
build_theme gruvbox-light         gruvbox:light        gruvbox-light        gruvbox               light fbf1c7 3c3836 fbf1c7 cc241d 98971a d79921 458588 b16286 689d6a 7c6f64 928374 9d0006 79740e b57614 076678 8f3f71 427b58 3c3836

# --- Dracula ---
build_theme dracula               base16               Dracula              system                dark  282a36 f8f8f2 21222c ff5555 50fa7b f1fa8c bd93f9 ff79c6 8be9fd f8f8f2 6272a4 ff6e6e 69ff94 ffffa5 d6acff ff92df a4ffff ffffff

# --- Tokyo Night ---
build_theme tokyonight-night      base16               ansi                 tokyonight            dark  1a1b26 c0caf5 15161e f7768e 9ece6a e0af68 7aa2f7 bb9af7 7dcfff a9b1d6 414868 f7768e 9ece6a e0af68 7aa2f7 bb9af7 7dcfff c0caf5
build_theme tokyonight-storm      base16               ansi                 tokyonight            dark  24283b c0caf5 1d202f f7768e 9ece6a e0af68 7aa2f7 bb9af7 7dcfff a9b1d6 414868 f7768e 9ece6a e0af68 7aa2f7 bb9af7 7dcfff c0caf5
build_theme tokyonight-moon       base16               ansi                 tokyonight            dark  222436 c8d3f5 1b1d2b ff757f c3e88d ffc777 82aaff c099ff 86e1fc 828bb8 444a73 ff757f c3e88d ffc777 82aaff c099ff 86e1fc c8d3f5
build_theme tokyonight-day        base16               ansi                 tokyonight            light e1e2e7 3760bf b4b5b9 f52a65 587539 8c6c3e 2e7de9 9854f1 007197 6172b0 a1a6c5 f52a65 587539 8c6c3e 2e7de9 9854f1 007197 3760bf

# --- One Dark ---
build_theme onedark               base16               TwoDark              one-dark              dark  282c34 abb2bf 282c34 e06c75 98c379 e5c07b 61afef c678dd 56b6c2 abb2bf 545862 e06c75 98c379 e5c07b 61afef c678dd 56b6c2 c8ccd4

# --- Everforest ---
build_theme everforest-dark       base16               ansi                 everforest            dark  2d353b d3c6aa 475258 e67e80 a7c080 dbbc7f 7fbbb3 d699b6 83c092 d3c6aa 475258 e67e80 a7c080 dbbc7f 7fbbb3 d699b6 83c092 d3c6aa
build_theme everforest-light      base16               ansi                 everforest            light fdf6e3 5c6a72 e6e2cc f85552 8da101 dfa000 3a94c5 df69ba 35a77c 5c6a72 e6e2cc f85552 8da101 dfa000 3a94c5 df69ba 35a77c 5c6a72

# --- Kanagawa ---
build_theme kanagawa-wave         base16               ansi                 kanagawa              dark  1f1f28 dcd7ba 090618 c34043 76946a c0a36e 7e9cd8 957fb8 6a9589 c8c093 727169 e82424 98bb6c e6c384 7fb4ca 938aa9 7aa89f dcd7ba
build_theme kanagawa-dragon       base16               ansi                 kanagawa              dark  181616 c5c9c5 0d0c0c c4746e 8a9a7b c4b28a 8ba4b0 a292a3 8ea4a2 c8c093 a6a69c e46876 87a987 e6c384 7fb4ca 938aa9 7aa89f c5c9c5
build_theme kanagawa-lotus        base16               ansi                 kanagawa              light f2ecbc 545464 1f1f28 c84053 6f894e 77713f 4d699b b35b79 597b75 545464 8a8980 d7474b 6e915f 836f4a 6693bf 624c83 5e857a 43436c

# --- Monokai ---
build_theme monokai               base16               "Monokai Extended"   system                dark  272822 f8f8f2 272822 f92672 a6e22e f4bf75 66d9ef ae81ff a1efe4 f8f8f2 75715e f92672 a6e22e f4bf75 66d9ef ae81ff a1efe4 f9f8f5
build_theme monokai-pro           base16               "Monokai Extended"   system                dark  2d2a2e fcfcfa 2d2a2e ff6188 a9dc76 ffd866 fc9867 ab9df2 78dce8 fcfcfa 727072 ff6188 a9dc76 ffd866 fc9867 ab9df2 78dce8 fcfcfa

# --- Ayu ---
build_theme ayu-dark              base16               ansi                 ayu                   dark  0a0e14 b3b1ad 01060e ea6c73 91b362 f9af4f 53bdfa fae994 90e1c6 c7c7c7 686868 f07178 c2d94c ffb454 59c2ff ffee99 95e6cb ffffff
build_theme ayu-mirage            base16               ansi                 ayu                   dark  1f2430 cbccc6 191e2a ed8274 a6cc70 fad07b 6dcbfa cfbafa 90e1c6 c7c7c7 686868 f28779 bae67e ffd580 73d0ff d4bfff 95e6cb ffffff
build_theme ayu-light             base16               ansi                 ayu                   light fcfcfc 5c6166 e6e1cf f07171 86b300 f2ae49 399ee6 a37acc 4cbf99 5c6166 8a9199 f07171 86b300 f2ae49 399ee6 a37acc 4cbf99 5c6166

# --- GitHub ---
build_theme github-dark           base16               ansi                 system                dark  0d1117 c9d1d9 484f58 ff7b72 3fb950 d29922 58a6ff bc8cff 39c5cf b1bac4 6e7681 ffa198 56d364 e3b341 79c0ff d2a8ff 56d4dd f0f6fc
build_theme github-light          base16               GitHub               system                light ffffff 24292f 24292f cf222e 116329 4d2d00 0969da 8250df 1b7c83 6e7781 57606a a40e26 1a7f37 633c01 218bff a475f9 3192aa 8c959f

# --- Material ---
build_theme material              base16               ansi                 system                dark  263238 eeffff 000000 f07178 c3e88d ffcb6b 82aaff c792ea 89ddff eeffff 546e7a f07178 c3e88d ffcb6b 82aaff c792ea 89ddff ffffff

# --- Oxocarbon ---
build_theme oxocarbon             base16               ansi                 system                dark  161616 f2f4f8 161616 ff7eb6 42be65 be95ff 33b1ff ee5396 3ddbd9 dde1e6 525252 ff7eb6 42be65 be95ff 33b1ff ee5396 3ddbd9 ffffff

# --- Nightfox family ---
build_theme duskfox               base16               ansi                 system                dark  232136 e0def4 393552 eb6f92 a3be8c f6c177 569fba c4a7e7 9ccfd8 e0def4 47407d eb98b5 b1d196 f9cb8c 65b1cd d3b8f2 aadceb e2e0f7
build_theme nordfox               base16               ansi                 system                dark  2e3440 cdcecf 3b4252 bf616a a3be8c ebcb8b 81a1c1 b48ead 8fbcbb e5e9f0 465780 d06f79 b1d196 f0d399 8cafd2 c895bf 93ccdc e7ecf4
build_theme terafox               base16               ansi                 system                dark  152528 e6eaea 2f3239 e85c51 7aa4a1 fda47f 5a93aa ad5c7c a1cdd8 eaeeee 4e5157 eb746b 8eb2af ffa07a 73a3b7 c78ba0 afdfeb fdf1ed
build_theme carbonfox             base16               ansi                 system                dark  161616 f2f4f8 282828 ee5396 25be6a 08bdba 78a9ff be95ff 33b1ff dfdfe0 484848 f16da6 46c880 3fc7c5 8cb6ff c8a5ff 52bdff f2f4f8
build_theme dawnfox               base16               ansi                 system                light faf4ed 575279 f2e9e1 a5222f 396847 ac5402 286983 6e33ce 3f83a6 575279 938aa4 b3434e 4c8f5c c47b28 4a9db8 8452d5 5c9dbb 575279

# --- Melange ---
build_theme melange               base16               ansi                 system                dark  292522 ece1d7 34302c bd8183 78997a ebc06d a3a9ce b380b0 87a987 c1a78e 867462 d47766 85b695 ecd28b a3a9ce cf9bc2 89b3b6 ece1d7

# --- Zenburn ---
build_theme zenburn               base16               ansi                 system                dark  3f3f3f dcdccc 3f3f3f cc9393 7f9f7f d0bf8f 6ca0a3 dc8cc3 93e0e3 dcdccc 709080 dca3a3 bfebbf f0dfaf 8cd0d3 ec93d3 93e0e3 ffffff

# --- Palenight ---
build_theme palenight             base16               ansi                 system                dark  292d3e a6accd 292d3e f07178 c3e88d ffcb6b 82aaff c792ea 89ddff d0d0d0 434758 ff8b92 ddffa7 ffe585 9cc4ff e1acff a3f7ff ffffff

df_ok "done."
