#!/usr/bin/env bash
# Cross-compile the QQL shared library for Android, into
# third_party/qql/android/<abi>/libqql.so.
#
#   tool/build-qql-android.sh [path-to-QQ-Lang-checkout]
#
# The releases ship desktop builds only, so unlike the rest of the runtime
# this half cannot be fetched — it has to be built from source. Needs the
# Android NDK, cargo-ndk, and the Rust Android targets:
#
#   rustup target add aarch64-linux-android armv7-linux-androideabi \
#       x86_64-linux-android
#   cargo install cargo-ndk
#
# QQ Lang takes its version from the git tag and its release workflow stamps
# Cargo.toml before building, so the number checked in there is a placeholder.
# This does the same stamping, against a copy — the checkout is never written
# to — using the version in third_party/qql/VERSION so the Android library
# reports what the desktop one does.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${1:-$HOME/Projects/QQ Lang}"
DEST="$ROOT/third_party/qql/android"
ABIS=(arm64-v8a armeabi-v7a x86_64)

[[ -f "$SOURCE/Cargo.toml" ]] || {
  echo "No QQ Lang checkout at $SOURCE" >&2
  echo "Pass one: tool/build-qql-android.sh /path/to/QQ-Lang" >&2
  exit 1
}

version="$(cat "$ROOT/third_party/qql/VERSION" 2>/dev/null || true)"
[[ -n "$version" ]] || {
  echo "No third_party/qql/VERSION — run tool/fetch-qql.sh first." >&2
  exit 1
}

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  # Newest installed NDK, which is what Android Studio keeps current.
  ANDROID_NDK_HOME="$(find "${ANDROID_HOME:-$HOME/Android/Sdk}/ndk" \
    -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)"
fi
[[ -n "$ANDROID_NDK_HOME" && -d "$ANDROID_NDK_HOME" ]] || {
  echo "No Android NDK found. Install one, or set ANDROID_NDK_HOME." >&2
  exit 1
}
export ANDROID_NDK_HOME

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Only what compiles the crate: the data is 120 MB and irrelevant here.
for item in Cargo.toml Cargo.lock src include README.md LICENSE.md; do
  cp -a "$SOURCE/$item" "$work/"
done

python3 - "$work/Cargo.toml" "$version" <<'STAMP'
import re, sys, pathlib
path, version = pathlib.Path(sys.argv[1]), sys.argv[2]
text, n = re.subn(r'^version = ".*"$', f'version = "{version}"',
                  path.read_text(), count=1, flags=re.M)
assert n == 1, "no version line in Cargo.toml"
path.write_text(text)
print(f"building as {version}")
STAMP

targets=()
for abi in "${ABIS[@]}"; do targets+=(-t "$abi"); done

( cd "$work" && cargo ndk "${targets[@]}" -o "$DEST" \
    build --release --features vector,fulltext )

echo
for abi in "${ABIS[@]}"; do
  lib="$DEST/$abi/libqql.so"
  if [[ -f "$lib" ]]; then
    printf '%-14s %s  %s\n' "$abi" \
      "$(du -h "$lib" | cut -f1)" \
      "$(file -b "$lib" | cut -d, -f2)"
  fi
done

# The whole point of the stamping above, so it is worth checking.
#
# grep -c rather than grep -q: -q exits at the first hit, which hands strings
# a SIGPIPE, which pipefail then reports as a failed pipeline — warning about
# a library that carries the version perfectly well. -c reads to the end.
for abi in "${ABIS[@]}"; do
  hits="$(strings -a "$DEST/$abi/libqql.so" | grep -cF "$version" || true)"
  if [[ "$hits" -eq 0 ]]; then
    echo "warning: $abi does not carry version $version" >&2
  fi
done
