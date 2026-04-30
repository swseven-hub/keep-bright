#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="KeepBright"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
DMG_NAME="KeepBright-$VERSION-macOS-universal.dmg"
DMG_STAGING_DIR="$BUILD_DIR/dmg-staging"
DMG_MOUNT_DIR="$BUILD_DIR/dmg-mount"
DMG_RW="$BUILD_DIR/KeepBright-$VERSION-rw.dmg"
DMG_FINAL="$DIST_DIR/$DMG_NAME"
VOLUME_NAME="Keep Bright"

if [ ! -d "$APP_DIR" ]; then
  echo "Missing app bundle: $APP_DIR" >&2
  exit 1
fi

rm -rf "$DMG_STAGING_DIR" "$DMG_MOUNT_DIR" "$DMG_RW" "$DMG_FINAL"
mkdir -p "$DMG_STAGING_DIR" "$DMG_MOUNT_DIR" "$DIST_DIR"

cp -R "$APP_DIR" "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDRW \
  "$DMG_RW" >/dev/null

hdiutil attach "$DMG_RW" \
  -mountpoint "$DMG_MOUNT_DIR" \
  -nobrowse \
  -noverify \
  -noautoopen >/dev/null

detach_dmg() {
  for ATTEMPT in 1 2 3 4 5; do
    if hdiutil detach "$DMG_MOUNT_DIR" -quiet 2>/dev/null; then
      return 0
    fi
    sleep "$ATTEMPT"
  done

  hdiutil detach "$DMG_MOUNT_DIR" -force -quiet 2>/dev/null || true
}

cleanup() {
  detach_dmg
}
trap cleanup EXIT

mkdir -p "$DMG_MOUNT_DIR/.background"
swift "$ROOT_DIR/Tools/make_dmg_background.swift" "$DMG_MOUNT_DIR/.background/background.png"

osascript >/dev/null <<APPLESCRIPT || true
set dmgFolder to POSIX file "$DMG_MOUNT_DIR" as alias
tell application "Finder"
    open dmgFolder
    set current view of container window of dmgFolder to icon view
    set toolbar visible of container window of dmgFolder to false
    set statusbar visible of container window of dmgFolder to false
    set the bounds of container window of dmgFolder to {100, 100, 660, 460}
    set viewOptions to the icon view options of container window of dmgFolder
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set background picture of viewOptions to file ".background:background.png" of dmgFolder
    set position of item "$APP_NAME.app" of dmgFolder to {150, 190}
    set position of item "Applications" of dmgFolder to {410, 190}
    update dmgFolder without registering applications
    delay 1
    close container window of dmgFolder
end tell
APPLESCRIPT

sync
cleanup
trap - EXIT
sleep 2

for ATTEMPT in 1 2 3 4 5; do
  if hdiutil convert "$DMG_RW" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FINAL" >/dev/null; then
    break
  fi

  if [ "$ATTEMPT" = 5 ]; then
    exit 1
  fi

  sleep "$((ATTEMPT * 2))"
done

rm -rf "$DMG_STAGING_DIR" "$DMG_MOUNT_DIR" "$DMG_RW"

echo "$DMG_FINAL"
