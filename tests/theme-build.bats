#!/usr/bin/env bats
# theme-build.bats - tools/build-themes.sh must reproduce themes/ exactly.
#
# The themes are generated output: the registry in build-themes.sh plus the
# shared emitter (df_theme_emit_seams) plus the hand-tuned overlays in
# tools/theme-overrides/. If any of those three drifts from what is committed,
# re-running the script silently reverts committed work -- which is exactly what
# happened when the emitter never learned about @define-color ws-glow and the
# polished themes' pill/starship/base16 tuning.
#
# Running the real script against a throwaway copy of the repo is the only check
# that actually proves this; asserting on individual keys would not have caught
# a missing line.

setup() { load test_helper; }

@test "build-themes.sh regenerates themes/ byte-for-byte" {
  command -v diff &>/dev/null || skip "diff not available"

  local work="$BATS_TEST_TMPDIR/build"
  mkdir -p "$work"
  # The script derives DF_REPO from its own location, so a copy of these three
  # trees (plus repo config) is a self-contained repo to build in.
  cp -r "$DF_SRC_REPO/lib" "$DF_SRC_REPO/tools" "$DF_SRC_REPO/themes" "$work/"
  [ -f "$DF_SRC_REPO/dotfiles.conf" ] && cp "$DF_SRC_REPO/dotfiles.conf" "$work/"

  run "$work/tools/build-themes.sh"
  [ "$status" -eq 0 ]

  # themes/auto is wallpaper-derived and machine-local (gitignored), so it is
  # not part of the reproducible set.
  run diff -r --exclude=auto "$DF_SRC_REPO/themes" "$work/themes"
  if [ "$status" -ne 0 ]; then
    echo "build-themes.sh does not reproduce themes/ -- committed content would"
    echo "be clobbered. Either teach lib/theme-auto.sh's emitter the difference,"
    echo "or record it in tools/theme-overrides/<theme>/."
    echo "$output"
    false
  fi
}

@test "every theme-override file corresponds to a real theme and seam path" {
  local dir="$DF_SRC_REPO/tools/theme-overrides"
  [ -d "$dir" ] || skip "no overrides"
  local f rel theme seam stale=""
  while IFS= read -r f; do
    rel=${f#"$dir"/}
    theme=${rel%%/*}
    seam=${rel#*/}
    # An override for a theme that no longer exists, or for a path the emitter
    # never produces, is dead weight that hides itself: it applies silently.
    [ -d "$DF_SRC_REPO/themes/$theme" ] || { stale+=" $rel(no-theme)"; continue; }
    [ -f "$DF_SRC_REPO/themes/$theme/$seam" ] || stale+=" $rel(no-seam)"
  done < <(find "$dir" -type f)
  [ -z "$stale" ] || { echo "stale overrides:$stale"; false; }
}
