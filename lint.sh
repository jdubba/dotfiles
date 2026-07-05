#!/usr/bin/env bash
# lint.sh - shellcheck the dotfiles tool and shipped shell config.

set -euo pipefail

suggest_shellcheck_install() {
  echo "Error: shellcheck is not installed. Please install it first." >&2
  if command -v emerge &>/dev/null; then
    echo "Gentoo: sudo emerge --ask dev-util/shellcheck" >&2
  elif command -v dnf &>/dev/null; then
    echo "Fedora: sudo dnf install ShellCheck" >&2
  elif command -v apt &>/dev/null; then
    echo "Debian/Ubuntu: sudo apt install shellcheck" >&2
  elif command -v pacman &>/dev/null; then
    echo "Arch: sudo pacman -S shellcheck" >&2
  elif command -v brew &>/dev/null; then
    echo "macOS: brew install shellcheck" >&2
  fi
  echo "More info: https://github.com/koalaman/shellcheck#installing" >&2
  exit 1
}

command -v shellcheck &>/dev/null || suggest_shellcheck_install

echo "Running shellcheck on the tool..."

# The tool: bin/dotfiles has no extension, so enumerate targets explicitly.
targets=(bin/dotfiles)
while IFS= read -r f; do targets+=("$f"); done < <(find lib -type f -name '*.sh' | sort)
[[ -f hooks/post-merge ]] && targets+=(hooks/post-merge)
[[ -f test.sh ]] && targets+=(test.sh)
[[ -f lint.sh ]] && targets+=(lint.sh)

# SC1091: don't follow/verify sourced files that resolve at runtime.
shellcheck -x --exclude=SC1091 "${targets[@]}"

echo "Checking BATS test files..."
find tests -name '*.bats' -not -path 'tests/lib/*' -print0 \
  | xargs -0 -r shellcheck --shell=bash --external-sources --exclude=SC1091,SC2034 || true

echo "Sanity-checking shipped shell config (non-fatal)..."
# The dialect is auto-detected from each file's shebang / 'shell=' directive.
for f in \
    home/.bashrc home/.bash_profile home/.profile \
    home/.config/shell/*.sh \
    home/.config/shell/path.d/*.sh \
    home/.config/bash/*.bash; do
  [ -f "$f" ] || continue
  echo "  $f"
  shellcheck -x -e SC1090,SC1091,SC2148 "$f" || true
done

echo "Linting completed successfully!"
