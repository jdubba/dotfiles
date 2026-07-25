# shellcheck shell=sh
# catppuccin-mocha shell theme environment — tuned to match the bar and prompt
#
# BAT_THEME stays "ansi" as generated, and deliberately so: bat ships no
# catppuccin theme at all (`bat --list-themes` has zero matches), and "ansi"
# draws from the terminal's own 16 colours -- which, since the kitty and ghostty
# seams are catppuccin's official palette, means bat is already showing mocha.
# Giving it a named theme would mean shipping a .tmTheme and rebuilding bat's
# binary cache per machine, which is outside what a theme seam can do.
#
# fzf follows the rule the other seams settled on: the current item is green,
# identity and prompts are pink, and what is left is chrome from the achromatic
# ramp. The generated version put red on the match highlights, which collides
# with red's error semantics elsewhere in this theme, and cyan on the pointer.
#
#   pointer/marker  green  -- the selected row, as in walker, kitty and btop
#   hl / hl+        pink   -- matched characters (was red)
#   prompt          pink   -- identity, matching tmux's session name
#   spinner         green
#   info/header     subtext0, 7.36:1 -- chrome, not accent
#   bg+             surface1, keeping fg+ at 6.30:1 on the selected row
export BAT_THEME="ansi"
export FZF_DEFAULT_OPTS=" \
  --color=bg+:#45475a,bg:#1e1e2e,spinner:#a6e3a1,hl:#f5c2e7 \
  --color=fg:#cdd6f4,header:#a6adc8,info:#a6adc8,pointer:#a6e3a1 \
  --color=marker:#a6e3a1,fg+:#cdd6f4,prompt:#f5c2e7,hl+:#f5c2e7"
