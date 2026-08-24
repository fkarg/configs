#!/usr/bin/env bash
# Bump ./source.json to upstream's current Stably Orca release.
#
# electron-builder publishes latest-linux.yml next to every release, listing the
# version and a per-artifact sha512. That sha512 is base64 of the raw digest,
# which is byte-for-byte Nix's SRI encoding — so the pin can be rewritten from a
# ~700 byte metadata fetch, with no 160MB prefetch to compute a hash locally.
#
# Rewrites the file only; committing is the caller's job (see
# ../../shared/programs/stably-orca.nix), so a manual run stays inert in git.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_json="$here/source.json"
feed="https://github.com/stablyai/orca/releases/latest/download/latest-linux.yml"

yml="$(curl -fsSL --retry 3 --max-time 60 "$feed")"

version="$(printf '%s\n' "$yml" | sed -n 's/^version: *//p' | head -1)"
if [ -z "$version" ]; then
  echo "stably-orca: no version field in $feed" >&2
  exit 1
fi

# The .deb's sha512 is the line after its url: entry in the files list. Match the
# deb specifically — the top-level `sha512:` key at the end of the file belongs
# to the AppImage, which is a different artifact.
sha="$(printf '%s\n' "$yml" |
  grep -A1 -F "url: orca-ide_${version}_amd64.deb" |
  sed -n 's/^ *sha512: *//p' | head -1)"
if [ -z "$sha" ]; then
  echo "stably-orca: no .deb sha512 for $version in $feed" >&2
  exit 1
fi

current="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$source_json")"
if [ "$version" = "$current" ]; then
  echo "stably-orca: already at $version"
  exit 0
fi

printf '{\n  "version": "%s",\n  "hash": "sha512-%s"\n}\n' "$version" "$sha" >"$source_json"
echo "stably-orca: $current -> $version"
