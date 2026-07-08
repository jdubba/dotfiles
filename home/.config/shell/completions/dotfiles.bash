# shellcheck shell=bash
# Programmable completion for the `dotfiles` CLI.
#
# Dialect: bash-completion (complete / compgen / COMPREPLY). It is loaded by
# bash directly and by zsh through `bashcompinit`, so a single definition
# serves both shells (wired up in ~/.bashrc and ~/.zshrc). Dynamic candidates
# (theme, profile and machine-env names) are fetched by calling the tool's own
# `<cmd> list --plain` helpers, so completion always tracks the live repo -
# add a theme and it shows up under `theme set` with no extra wiring.

_dotfiles() {
  local cur prev cmd sub df
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  # Invoke the very binary being completed (works when it's on PATH as
  # `dotfiles` and when it's called by an absolute path), falling back to the
  # PATH name.
  df=${COMP_WORDS[0]:-dotfiles}

  local commands="link status doctor add sync profile theme env dconf hook info help version"

  # Position 1: the top-level command.
  if (( COMP_CWORD == 1 )); then
    # shellcheck disable=SC2207
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return 0
  fi

  cmd=${COMP_WORDS[1]}
  case "$cmd" in
    link|apply|install)
      # shellcheck disable=SC2207
      COMPREPLY=( $(compgen -W "--dry-run --verbose" -- "$cur") ) ;;
    status|st)
      # shellcheck disable=SC2207
      COMPREPLY=( $(compgen -W "--verbose" -- "$cur") ) ;;
    doctor)
      # shellcheck disable=SC2207
      COMPREPLY=( $(compgen -W "--fix" -- "$cur") ) ;;
    sync)
      # shellcheck disable=SC2207
      COMPREPLY=( $(compgen -W "--no-link" -- "$cur") ) ;;

    add)
      case "$prev" in
        --to)
          # shellcheck disable=SC2207
          COMPREPLY=( $(compgen -W "home host profile:" -- "$cur") )
          return 0 ;;
        --profile)
          # shellcheck disable=SC2207
          COMPREPLY=( $(compgen -W "$("$df" profile list --plain 2>/dev/null)" -- "$cur") )
          return 0 ;;
      esac
      if [[ "$cur" == -* ]]; then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "--to --host --profile" -- "$cur") )
      else
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi
      ;;

    profile)
      if (( COMP_CWORD == 2 )); then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "list enable disable show" -- "$cur") )
      elif (( COMP_CWORD == 3 )); then
        case "${COMP_WORDS[2]}" in
          enable|disable)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "$("$df" profile list --plain 2>/dev/null)" -- "$cur") ) ;;
        esac
      fi
      ;;

    theme)
      if (( COMP_CWORD == 2 )); then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "status list set unset auto name show" -- "$cur") )
      else
        sub=${COMP_WORDS[2]}
        case "$sub" in
          set)
            if [[ "$cur" == -* ]]; then
              # shellcheck disable=SC2207
              COMPREPLY=( $(compgen -W "--no-link --no-reload" -- "$cur") )
            else
              # shellcheck disable=SC2207
              COMPREPLY=( $(compgen -W "$("$df" theme list --plain 2>/dev/null)" -- "$cur") )
            fi
            ;;
          list)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "--plain" -- "$cur") ) ;;
          auto)
            if (( COMP_CWORD == 3 )); then
              # shellcheck disable=SC2207
              COMPREPLY=( $(compgen -W "now enable disable status" -- "$cur") )
            fi
            ;;
        esac
      fi
      ;;

    env)
      if (( COMP_CWORD == 2 )); then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "status set skip add unset list" -- "$cur") )
      elif (( COMP_CWORD == 3 )); then
        case "${COMP_WORDS[2]}" in
          set|skip|unset|rm)
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "$("$df" env list --plain 2>/dev/null)" -- "$cur") ) ;;
        esac
      fi
      ;;

    dconf)
      if (( COMP_CWORD == 2 )); then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "dump load" -- "$cur") )
      else
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi
      ;;

    hook)
      if (( COMP_CWORD == 2 )); then
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "install uninstall" -- "$cur") )
      fi
      ;;
  esac
  return 0
}

# Register the completion. `complete` is a bash builtin; under zsh it is
# provided by `bashcompinit`, which ~/.zshrc loads before sourcing this file.
if command -v complete >/dev/null 2>&1; then
  complete -F _dotfiles dotfiles
fi
