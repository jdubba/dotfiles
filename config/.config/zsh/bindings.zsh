# ===========================================
# Keybindings
# ===========================================

# Cursor shape per vi mode
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
ZVM_NORMALMODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VISUALMODE_CURSOR=$ZVM_CURSOR_BLOCK

# Disable command mode highlight
ZVM_VI_HIGHLIGHT_BACKGROUND=none
ZVM_VI_HIGHLIGHT_FOREGROUND=none
ZVM_VI_HIGHLIGHT_EXTRASTYLE=none


zvm_after_init() {
    # Ctrl+right -> move forward one word
    bindkey '^[[1;5C' forward-word

    # Ctrl+left -> move backward one word
    bindkey '^[[1;5D' backward-word

    # Ctrl+F -> fzf file picker (no hidden)
    bindkey '^F' _fzf_file_no_hidden

    # Ctrl+\ -> toggle autosuggestions
    bindkey '^\' autosuggest-toggle

    # Up/Down -> history search by substring
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
}
