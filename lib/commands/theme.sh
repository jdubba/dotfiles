# shellcheck shell=bash
#
# theme command - manage the active theme layer.

_df_theme_host_file() {
  local host; host=$(df_hostname)
  printf '%s/%s/%s/.config/dotfiles/theme' "$DF_REPO" "$DF_HOSTS_DIR" "$host"
}

_df_theme_seam_source() {
  local name=$1
  case "$name" in
    kitty)    [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/kitty/current-theme.conf" ]] && printf 'yes' || printf 'no' ;;
    ghostty)  [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/ghostty/themes/current" ]] && printf 'yes' || printf 'no' ;;
    hypr)     [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/hypr/current-theme.conf" ]] && printf 'yes' || printf 'no' ;;
    waybar)   [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/waybar/colors.css" ]] && printf 'yes' || printf 'no' ;;
    walker)   [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/walker/colors.css" ]] && printf 'yes' || printf 'no' ;;
    tmux)     [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/tmux/current-theme.conf" ]] && printf 'yes' || printf 'no' ;;
    nvim)     [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/nvim/lua/dotfiles_theme.lua" ]] && printf 'yes' || printf 'no' ;;
    starship) [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/starship.toml" ]] && printf 'yes' || printf 'no' ;;
    opencode) [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/opencode/tui.json" ]] && printf 'yes' || printf 'no' ;;
    wallpaper) [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/background" ]] && printf 'yes' || printf 'no' ;;
    theme-env) [[ -f "$DF_REPO/$DF_THEMES_DIR/$(df_theme_name)/.config/shell/theme-env.sh" ]] && printf 'yes' || printf 'no' ;;
    *)        printf '?' ;;
  esac
}

# --- Brave custom theme color -------------------------------------------------
#
# Brave has no reload path like the other tools: it keeps its preferences in
# memory, rewrites `Preferences` from that copy throughout a session (including
# on quit) and never re-reads the file. So an external write only survives while
# the browser is closed, and the change shows up at its next launch rather than
# immediately -- which is what the messages below say.
_DF_BRAVE_DIR=".config/BraveSoftware/Brave-Browser"

# True when a browser is live in that user-data-dir. Chromium's SingletonLock is
# a symlink to "<host>-<pid>": it is specific to this data-dir (so a Brave running
# on some other --user-data-dir is not mistaken for this one), but it also
# outlives a crash, hence the liveness check on the pid rather than trusting the
# lock's mere existence.
_df_theme_brave_running() {
  local target pid lock="$HOME/$_DF_BRAVE_DIR/SingletonLock"
  [[ -L "$lock" ]] || return 1
  target=$(readlink "$lock") || return 1
  pid=${target##*-}                                  # hostnames may contain '-'
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0               # unreadable lock: assume held
  [[ -d "/proc/$pid" ]]
}

_df_theme_brave_apply() {
  local prefs accent polarity rc=0
  prefs="$HOME/$_DF_BRAVE_DIR/Default/Preferences"

  # Skip silently when Brave was never installed/run, and when python3 is absent
  # (the core tool stays dependency-free; this is a cosmetic extra, and the JSON
  # edit is not something to attempt in bash).
  [[ -f "$prefs" ]] || return 0
  command -v python3 &>/dev/null || return 0

  # Color: the shared pill accent the emitter draws for this theme, read from the
  # active theme's waybar seam. Polarity: the theme's own declared background,
  # from its nvim seam. Every theme ships both (including the generated `auto`),
  # so aligning Brave needs no new seam of its own.
  accent=$(sed -n 's/^@define-color pill-brand-bg  *\(#[0-9a-fA-F]\{6\}\);.*/\1/p' \
    "$HOME/.config/waybar/colors.css" 2>/dev/null | head -n1)
  [[ -n "$accent" ]] || return 0
  polarity=$(sed -n 's/.*background *= *"\(light\|dark\)".*/\1/p' \
    "$HOME/.config/nvim/lua/dotfiles_theme.lua" 2>/dev/null | head -n1)

  if _df_theme_brave_running; then
    df_dim "brave: running, theme color left alone (re-run 'dotfiles theme set' once closed)"
    return 0
  fi

  python3 "$DF_REPO/lib/theme-brave.py" "$prefs" "$accent" "${polarity:-dark}" || rc=$?
  case "$rc" in
    0) df_ok "brave: theme color set to $accent (applies at next launch)" ;;
    2) : ;;                                          # already aligned
    *) df_warn "brave: could not update the theme color" ;;
  esac
}

_df_theme_reload() {
  local reloaded="" tool

  # Never reload in tests / scripted runs (the sandbox sets DF_TARGET==HOME).
  [[ -n "${DF_NO_RELOAD:-}" ]] && return 0

  # Only reload against real $HOME and in a graphical session.
  [[ "$DF_TARGET" == "$HOME" ]] || return 0

  # hyprland
  if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
    if hyprctl reload &>/dev/null; then
      reloaded+=" hyprland"
    fi
  fi

  # hyprpaper — push the updated wallpaper live to every output via IPC.
  # hyprpaper 0.8.x removed the preload/unload/listloaded/reload verbs; its
  # `wallpaper` verb now loads+applies in one shot (no preload, no daemon
  # restart, no flash). Works whether hyprpaper is a systemd service
  # (stationzebra) or exec-once (Fedora). Persistence across restarts is via
  # hyprpaper.conf's `path = $HOME/.config/background`, refreshed by the linker.
  if command -v hyprctl &>/dev/null && pgrep -x hyprpaper &>/dev/null; then
    local bg="$HOME/.config/background" mon pushed=0 mons
    mons=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}')
    [[ -n "$mons" ]] || mons=$(hyprctl hyprpaper listactive 2>/dev/null | cut -d: -f1)
    if [[ -e "$bg" && -n "$mons" ]]; then
      while IFS= read -r mon; do
        [[ -n "$mon" ]] || continue
        hyprctl hyprpaper wallpaper "$mon,$bg" &>/dev/null && pushed=1
      done <<<"$mons"
      (( pushed )) && reloaded+=" hyprpaper"
    fi
  fi

  # waybar
  if command -v killall &>/dev/null && pgrep -x waybar &>/dev/null; then
    if killall -SIGUSR2 waybar &>/dev/null; then
      reloaded+=" waybar"
    fi
  fi

  # kitty
  if command -v kitty &>/dev/null && pgrep -x kitty &>/dev/null; then
    if killall -SIGUSR1 kitty &>/dev/null; then
      reloaded+=" kitty"
    fi
  fi

  # tmux
  if command -v tmux &>/dev/null && tmux start-server \; list-sessions &>/dev/null; then
    if tmux source-file ~/.tmux.conf &>/dev/null; then
      reloaded+=" tmux"
    fi
  fi

  # ghostty
  if command -v killall &>/dev/null && pgrep -x ghostty &>/dev/null; then
    if killall -SIGUSR2 ghostty &>/dev/null; then
      reloaded+=" ghostty"
    fi
  fi

  if [[ -n "$reloaded" ]]; then
    df_ok "reloaded:$reloaded"
  fi

  # brave (no live reload; see _df_theme_brave_apply)
  _df_theme_brave_apply

  df_dim "manual restart may be needed for: nvim walker btop new shells opencode"
}

df_cmd_theme() {
  local sub=${1:-status}
  [[ $# -gt 0 ]] && shift || true

  case "$sub" in
    status|show)
      local name source_label
      name=$(df_theme_name)

      if df_autotheme_enabled; then
        source_label="auto (wallpaper-derived)"
      elif [[ -f "$(df_state_theme_file)" ]]; then
        source_label="machine-local selection"
      elif [[ -f "$(_df_theme_host_file)" ]]; then
        source_label="per-host override"
      elif [[ -f "$DF_REPO/$DF_THEMES_DIR/default" ]]; then
        source_label="repo default"
      else
        source_label="fallback"
      fi

      df_info "theme: $name ($source_label)"

      if [[ -d "$DF_REPO/$DF_THEMES_DIR/$name" ]]; then
        df_ok "theme directory: $DF_THEMES_DIR/$name/"
      else
        df_warn "theme directory '$DF_THEMES_DIR/$name/' does not exist"
      fi

      df_log ""
      df_dim "tool seams:"
      for tool in kitty ghostty hypr waybar walker tmux nvim starship opencode wallpaper theme-env; do
        local status; status=$(_df_theme_seam_source "$tool")
        printf '  %s: %s\n' "$tool" "$status" >&2
      done
      ;;

    name)
      # Resolved active theme name to stdout (for scripts/menus).
      df_theme_name
      printf '\n'
      ;;

    list)
      # --plain: theme names to stdout, one per line (for scripts/menus).
      if [[ "${1:-}" == "--plain" ]]; then
        df_available_themes
        return 0
      fi
      local name; name=$(df_theme_name)
      df_info "available themes:"
      while IFS= read -r t; do
        [[ -z "$t" ]] && continue
        if [[ "$t" == "$name" ]]; then
          printf '  %s* %s%s (active)\n' "$DF_C_GREEN" "$t" "$DF_C_RESET" >&2
        else
          printf '  %s  %s%s\n' "$DF_C_DIM" "$t" "$DF_C_RESET" >&2
        fi
      done < <(df_available_themes)
      ;;

    set)
      local name=${1:-}; [[ -n "$name" ]] || df_die "theme set: name required"
      local no_link=0 no_reload=0 arg apply_rc=0
      for arg in "$@"; do
        case "$arg" in
          --no-link)   no_link=1 ;;
          --no-reload) no_reload=1 ;;
        esac
      done

      if [[ "$name" == "$DF_AUTO_THEME_NAME" ]]; then
        df_die "theme set: use 'dotfiles theme auto now' (one-off) or 'dotfiles theme auto enable' (continuous) for the wallpaper-derived theme"
      fi

      # Explicitly choosing a theme turns off auto-theming (machine-local).
      if df_autotheme_enabled; then
        rm -f -- "$(df_state_autotheme_file)" "$(df_state_autotheme_watch_file)"
        df_dim "disabled auto-theming (explicit theme selected)"
      fi

      if [[ ! -d "$DF_REPO/$DF_THEMES_DIR/$name" ]]; then
        df_warn "no $DF_THEMES_DIR/$name/ directory yet; create one to add theme files"
      fi

      # Machine-local selection (never committed — no repo churn on switch).
      local f; f=$(df_state_theme_file)
      mkdir -p -- "$(dirname "$f")"
      printf '%s\n' "$name" >"$f"
      df_ok "set theme to '$name'"

      if (( no_link )); then
        df_dim "skipped linking (--no-link)"
      else
        df_log ""
        df_info "running dotfiles link..."
        df_resolve_layers
        df_build_plan
        trap df_cleanup_plan RETURN
        df_print_plan 0
        # A conflict makes df_apply_plan return 1, but the theme's own links are
        # already applied by then. Do NOT let `set -e` abort here: skipping the
        # reload leaves every tool showing the previous theme (and Hyprland
        # stuck in the transient error state its autoreload hit while the
        # current-theme.conf symlink was being replaced).
        df_apply_plan || apply_rc=$?
      fi

      if (( no_reload )); then
        df_dim "skipped reload (--no-reload)"
      elif (( no_link )) && [[ "$DF_TARGET" == "$HOME" ]]; then
        df_warn "reload skipped because --no-link was used (no new links to reload)"
      elif [[ "$DF_TARGET" != "$HOME" ]]; then
        df_dim "(reload skipped in test/non-home environment)"
      else
        df_log ""
        df_info "reloading running tools..."
        _df_theme_reload
      fi

      # Still surface the conflict in the exit status, now that the switch and
      # the reload have both completed.
      return "$apply_rc"
      ;;

    unset)
      local f apply_rc=0; f=$(df_state_theme_file)
      if [[ ! -f "$f" ]]; then
        df_ok "no machine-local theme selection to clear (committed default stays active)"
        return 0
      fi
      rm -f -- "$f"
      df_ok "cleared machine-local theme selection (now: $(df_theme_name))"

      df_log ""
      df_info "running dotfiles link..."
      df_resolve_layers
      df_build_plan
      trap df_cleanup_plan RETURN
      df_print_plan 0
      # See the `set` branch: a conflict must not abort the reload.
      df_apply_plan || apply_rc=$?

      if [[ "$DF_TARGET" == "$HOME" ]]; then
        df_log ""
        df_info "reloading running tools..."
        _df_theme_reload
      fi

      return "$apply_rc"
      ;;

    auto)
      # shellcheck source=lib/theme-auto.sh
      source "$DF_REPO/lib/theme-auto.sh"
      local asub=${1:-status}
      [[ $# -gt 0 ]] && shift || true
      case "$asub" in
        now)     df_autotheme_run "$@" ;;
        enable)  df_autotheme_enable "$@" ;;
        disable) df_autotheme_disable ;;
        status)  df_autotheme_status ;;
        watch)   df_autotheme_watch "$@" ;;
        watch-tick)
          if df_autotheme_watch_tick; then df_ok "auto theme regenerated"; else df_dim "wallpaper unchanged; nothing to do"; fi
          ;;
        *)       df_die "theme auto: unknown subcommand '$asub' (use now|enable|disable|status)" ;;
      esac
      ;;

    *)
      df_die "theme: unknown subcommand '$sub' (use status|list|set|unset|auto)"
      ;;
  esac
}
