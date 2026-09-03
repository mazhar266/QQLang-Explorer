#!/usr/bin/env bash
# Install a desktop entry for QQL Explorer, into the current user's own
# directories only.
#
# This is what puts the icon in the dock, the switcher and the app grid on
# GNOME under Wayland, where GTK3 has no window-icon protocol and the shell
# matches a window to a desktop entry by application id instead.
#
#   tool/install-desktop-entry.sh            # uses the release build
#   tool/install-desktop-entry.sh --debug    # uses the debug build
#   tool/install-desktop-entry.sh --remove
#
# Everything it writes is listed at the end, and --remove takes it all back.

set -euo pipefail

APP_ID="fi.mazhar.qqlang.explorer"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
DESKTOP_FILE="$DESKTOP_DIR/$APP_ID.desktop"

if [[ "${1:-}" == "--remove" ]]; then
  rm -fv "$DESKTOP_FILE"
  for size in 48 128 512; do
    rm -fv "$ICON_ROOT/${size}x${size}/apps/$APP_ID.png"
  done
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
  gtk-update-icon-cache -f -t "$ICON_ROOT" 2>/dev/null || true
  echo "Removed."
  exit 0
fi

MODE="release"
[[ "${1:-}" == "--debug" ]] && MODE="debug"
BINARY="$ROOT/build/linux/x64/$MODE/bundle/qqlang_explorer"

if [[ ! -x "$BINARY" ]]; then
  echo "No $MODE build at $BINARY" >&2
  echo "Build it first:  flutter build linux --$MODE" >&2
  exit 1
fi

for size in 48 128 512; do
  install -Dm644 "$ROOT/assets/icon/app_icon_$size.png" \
    "$ICON_ROOT/${size}x${size}/apps/$APP_ID.png"
done

mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_FILE" <<ENTRY
[Desktop Entry]
Type=Application
Name=QQL Explorer
Comment=Run QQ Lang queries against the Quran and the hadith collections
Exec=$BINARY %U
Icon=$APP_ID
Terminal=false
Categories=Education;Utility;
Keywords=quran;hadith;qql;query;
StartupWMClass=$APP_ID
ENTRY

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$ICON_ROOT" 2>/dev/null || true

echo "Installed:"
echo "  $DESKTOP_FILE"
for size in 48 128 512; do
  echo "  $ICON_ROOT/${size}x${size}/apps/$APP_ID.png"
done
echo
echo "Undo with: tool/install-desktop-entry.sh --remove"
