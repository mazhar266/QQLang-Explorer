#!/usr/bin/env bash
# Fetch the QQL runtime this app ships — the library and the JSON data — from
# a QQ Lang release, into third_party/qql.
#
#   tool/fetch-qql.sh                  # the version in third_party/qql/VERSION
#   tool/fetch-qql.sh 3.2.0            # a specific version
#   tool/fetch-qql.sh 3.2.0 aarch64-macos
#
# Platforms are the release's own names: x86_64-linux, aarch64-macos,
# x86_64-macos, x86_64-windows. The default is guessed from this machine.
#
# The 51 MB static library and the two CLI binaries in the release are not
# copied: the app talks to the shared library over FFI and needs neither.

set -euo pipefail

REPO="mazhar266/QQ-Lang"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/third_party/qql"

version="${1:-}"
if [[ -z "$version" ]]; then
  version="$(cat "$DEST/VERSION" 2>/dev/null || true)"
fi
if [[ -z "$version" ]]; then
  echo "No version given and no $DEST/VERSION to read." >&2
  exit 1
fi

platform="${2:-}"
if [[ -z "$platform" ]]; then
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)   platform="x86_64-linux" ;;
    Darwin-arm64)   platform="aarch64-macos" ;;
    Darwin-x86_64)  platform="x86_64-macos" ;;
    MINGW*|MSYS*|CYGWIN*) platform="x86_64-windows" ;;
    *) echo "Cannot guess a platform for $(uname -s)-$(uname -m); pass one." >&2
       exit 1 ;;
  esac
fi

case "$platform" in
  *windows) archive="qql-v$version-$platform.zip" ;;
  *)        archive="qql-v$version-$platform.tar.gz" ;;
esac
url="https://github.com/$REPO/releases/download/v$version/$archive"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Fetching $archive"
curl -fSL --progress-bar -o "$work/$archive" "$url"

echo "Unpacking"
case "$archive" in
  *.zip)    unzip -q "$work/$archive" -d "$work" ;;
  *.tar.gz) tar xzf "$work/$archive" -C "$work" ;;
esac
unpacked="$work/qql-v$version-$platform"

# Replace the payload wholesale — a partial overlay could leave stale data
# files behind from an older release, which is worse than a clean miss.
rm -rf "$DEST/lib" "$DEST/sources"
mkdir -p "$DEST/lib"

# The shared library only. libqql.a is for static linking on iOS, and the
# release's qql / qql-index binaries are the CLI, which this app never runs.
for lib in libqql.so libqql.dylib qql.dll; do
  [[ -f "$unpacked/lib/$lib" ]] && cp -a "$unpacked/lib/$lib" "$DEST/lib/"
done

cp -a "$unpacked/sources" "$DEST/"
cp -a "$unpacked/LICENSE.md" "$DEST/"
echo "$version" > "$DEST/VERSION"

echo
echo "third_party/qql  $version  $platform  ($(du -sh "$DEST" | cut -f1))"
ls "$DEST/lib"
