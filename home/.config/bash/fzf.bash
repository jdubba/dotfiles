# shellcheck shell=bash
# ~/.config/bash/fzf.bash - fzf configuration for bash (mirrors zsh/fzf.zsh).

if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix'
elif command -v fdfind >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --strip-cwd-prefix'
fi

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="
    --height 40%
    --layout=reverse
    --border
    --preview 'bat --style=numbers --color=always {}'
"

# Ctrl+R (history) — see the note in zsh/fzf.zsh: overrides the bat preview above,
# which cannot apply to history lines.
export FZF_CTRL_R_OPTS="
    --preview 'printf %s {2..}'
    --preview-window up:3:hidden:wrap
    --bind 'ctrl-/:toggle-preview'
"
