#!/usr/bin/env bats
# palette-pages.bats - docs/palettes/ must match the themes it describes.
#
# The pages are generated output, read straight out of themes/<name>/. That is
# what makes them trustworthy, and also what makes them rot: nothing in
# build-themes.sh regenerates them, so a theme change leaves a page quietly
# describing colours that are no longer shipped -- and a stale swatch page is
# worse than none, because it is consulted precisely when deciding what to
# change next.
#
# Same shape as theme-build.bats: run the real generator against a throwaway
# copy and diff. Asserting on individual colours would not catch a section that
# stopped being emitted.

setup() { load test_helper; }

@test "build-palette-pages.py regenerates docs/palettes/ byte-for-byte" {
  command -v diff &>/dev/null || skip "diff not available"
  command -v python3 &>/dev/null || skip "python3 not available"

  local work="$BATS_TEST_TMPDIR/pages"
  mkdir -p "$work"
  # The generator derives the repo root from its own location, so tools/ plus
  # themes/ plus a docs/ to write into is a self-contained tree.
  cp -r "$DF_SRC_REPO/tools" "$DF_SRC_REPO/themes" "$work/"
  mkdir -p "$work/docs"

  run python3 "$work/tools/build-palette-pages.py"
  [ "$status" -eq 0 ]

  run diff -r "$DF_SRC_REPO/docs/palettes" "$work/docs/palettes"
  if [ "$status" -ne 0 ]; then
    echo "docs/palettes/ is stale -- a theme changed without the pages being"
    echo "rebuilt. Run: tools/build-palette-pages.py"
    echo "$output"
    false
  fi
}

@test "every committed theme has a palette page, and every page a theme" {
  local name missing="" orphan=""
  for d in "$DF_SRC_REPO"/themes/*/; do
    name=$(basename -- "$d")
    # themes/auto is wallpaper-derived and machine-local (gitignored).
    [ "$name" = "auto" ] && continue
    [ -f "$DF_SRC_REPO/docs/palettes/$name.html" ] || missing+=" $name"
  done
  for f in "$DF_SRC_REPO"/docs/palettes/*.html; do
    name=$(basename -- "$f" .html)
    [ "$name" = "index" ] && continue
    [ -d "$DF_SRC_REPO/themes/$name" ] || orphan+=" $name"
  done
  [ -z "$missing" ] || { echo "themes with no palette page:$missing"; false; }
  [ -z "$orphan" ] || { echo "palette pages for themes that no longer exist:$orphan"; false; }
}

@test "the index links every palette page" {
  local idx="$DF_SRC_REPO/docs/palettes/index.html"
  [ -f "$idx" ]
  local name missing=""
  for f in "$DF_SRC_REPO"/docs/palettes/*.html; do
    name=$(basename -- "$f" .html)
    [ "$name" = "index" ] && continue
    grep -q "href=\"$name.html\"" "$idx" || missing+=" $name"
  done
  [ -z "$missing" ] || { echo "not linked from the index:$missing"; false; }
}
