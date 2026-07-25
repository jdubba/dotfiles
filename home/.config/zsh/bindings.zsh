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


# zsh-vi-mode initialises lazily (ZVM_INIT_MODE defaults to "last", i.e. on the
# first precmd) and rebuilds the viins/main keymaps from scratch. That happens
# *after* .zshrc sourced fzf's key-bindings, so every fzf bindkey in those two
# keymaps is discarded — which is why Ctrl+R silently reverted to zsh's
# bck-i-search. Anything that must survive belongs in this hook, which zvm runs
# once its own bindings are in place.
zvm_after_init() {
    # Ctrl+right -> move forward one word
    bindkey '^[[1;5C' forward-word

    # Ctrl+left -> move backward one word
    bindkey '^[[1;5D' backward-word

    # Ctrl+F -> fzf file picker (no hidden)
    bindkey '^F' _fzf_file_no_hidden

    # Ctrl+R -> fzf history search (zvm clobbers fzf's own binding; vicmd
    # survives, viins/main do not, so re-bind both explicitly)
    if (( ${+widgets[fzf-history-widget]} )); then
        bindkey -M viins '^R' fzf-history-widget
        bindkey -M vicmd '^R' fzf-history-widget
    fi

    # Ctrl+\ -> toggle autosuggestions
    bindkey '^\' autosuggest-toggle

    # Up/Down -> history search by substring
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
}
