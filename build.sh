#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="KeepBright"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

rm -rf "$APP_DIR" "$ICONSET_DIR" "$BUILD_DIR/AppIcon.icns"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swift "$ROOT_DIR/Tools/make_icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/AppIcon.icns"

swiftc \
  -O \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macosx26.0 \
  -framework AppKit \
  -framework IOKit \
  -framework ServiceManagement \
  -framework UserNotifications \
  "$ROOT_DIR/Sources/KeepBright/main.swift" \
  "$ROOT_DIR/Sources/KeepBright/AppDelegate.swift" \
  "$ROOT_DIR/Sources/KeepBright/AwakeDuration.swift" \
  "$ROOT_DIR/Sources/KeepBright/DisplaySleepAssertion.swift" \
  "$ROOT_DIR/Sources/KeepBright/LoginItemManager.swift" \
  "$ROOT_DIR/Sources/KeepBright/NotificationManager.swift" \
  "$ROOT_DIR/Sources/KeepBright/UpdateChecker.swift" \
  -o "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

codesign --force --sign - "$APP_DIR"

echo "$APP_DIR"
