#!/usr/bin/env bash
set -euo pipefail

notes="${RUNNER_TEMP:-/tmp}/release-notes.md"

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "::notice::Release $TAG already exists; keeping its notes."
else
  prev_tag="$(gh release list --exclude-drafts --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName // empty')"
  prev="${prev_tag#v}"

  mode=range
  if [ -z "$prev" ]; then
    mode=all
    echo "::notice::No release published yet; the notes carry every section from $VER down."
  elif ! grep -qF "## [$prev]" "$CHANGELOG"; then
    mode=single
    echo "::warning::$CHANGELOG carries no section for $prev_tag; the notes carry $VER alone."
  fi

  awk -v ver="$VER" -v prev="$prev" -v mode="$mode" '
    index($0, "## [") == 1 {
      if (index($0, "## [" ver "]") == 1) inside = 1
      else if (inside && (mode == "single" || (mode == "range" && index($0, "## [" prev "]") == 1))) exit
    }
    inside { a[++n] = $0; if ($0 != "") last = n }
    END { for (i = 1; i <= last; i++) print a[i] }
  ' "$CHANGELOG" > "$notes"

  if [ ! -s "$notes" ]; then
    echo "::error::$CHANGELOG carries no section for $VER"
    exit 1
  fi

  gh release create "$TAG" --target "$TARGET" --title "$TAG" --notes-file "$notes"
fi

files=()
while IFS= read -r file; do
  [ -n "$file" ] && files+=("$file")
done <<<"$ASSETS"

gh release upload "$TAG" "${files[@]}" --clobber
