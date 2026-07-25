# =======================================
# fzf
# =======================================

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

# Ctrl+R (history). fzf's widget appends FZF_CTRL_R_OPTS *after* FZF_DEFAULT_OPTS,
# so this is also what stops the bat preview above from being applied to history
# lines (bat would just error on "command not a file"). Preview the selected
# command itself instead — hidden until toggled, for long/multi-line entries.
export FZF_CTRL_R_OPTS="
    --preview 'printf %s {2..}'
    --preview-window up:3:hidden:wrap
    --bind 'ctrl-/:toggle-preview'
"

_fzf_file_no_hidden() {
    local cmd result
    cmd="${FZF_DEFAULT_COMMAND/--hidden }"
    result=$(eval "${cmd:-find . -type f}" | fzf) && LBUFFER+="$result"
    zle reset-prompt
}

zle -N _fzf_file_no_hidden
