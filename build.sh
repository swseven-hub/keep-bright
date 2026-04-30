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
MACOS_TARGET="apple-macosx26.0"
ARCHS=(arm64 x86_64)
SOURCES=(
  "$ROOT_DIR/Sources/KeepBright/main.swift"
  "$ROOT_DIR/Sources/KeepBright/AppDelegate.swift"
  "$ROOT_DIR/Sources/KeepBright/AppPreferences.swift"
  "$ROOT_DIR/Sources/KeepBright/AutomationManager.swift"
  "$ROOT_DIR/Sources/KeepBright/AwakeDuration.swift"
  "$ROOT_DIR/Sources/KeepBright/BatteryMonitor.swift"
  "$ROOT_DIR/Sources/KeepBright/DisplaySleepAssertion.swift"
  "$ROOT_DIR/Sources/KeepBright/GlobalHotKeyManager.swift"
  "$ROOT_DIR/Sources/KeepBright/LoginItemManager.swift"
  "$ROOT_DIR/Sources/KeepBright/MenuBarDisplayMode.swift"
  "$ROOT_DIR/Sources/KeepBright/NotificationManager.swift"
  "$ROOT_DIR/Sources/KeepBright/PreferencesWindowController.swift"
  "$ROOT_DIR/Sources/KeepBright/SleepPreventionMode.swift"
  "$ROOT_DIR/Sources/KeepBright/UpdateChecker.swift"
)

rm -rf "$APP_DIR" "$ICONSET_DIR" "$BUILD_DIR/AppIcon.icns" "$BUILD_DIR/bin"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swift "$ROOT_DIR/Tools/make_icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/AppIcon.icns"

mkdir -p "$BUILD_DIR/bin"
ARCH_BINARIES=()

for ARCH in "${ARCHS[@]}"; do
  OUTPUT="$BUILD_DIR/bin/$APP_NAME-$ARCH"
  swiftc \
    -O \
    -sdk "$SDK_PATH" \
    -target "$ARCH-$MACOS_TARGET" \
    -framework AppKit \
    -framework Carbon \
    -framework IOKit \
    -framework ServiceManagement \
    -framework UserNotifications \
    "${SOURCES[@]}" \
    -o "$OUTPUT"
  ARCH_BINARIES+=("$OUTPUT")
done

lipo -create "${ARCH_BINARIES[@]}" -output "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

codesign --force --sign - "$APP_DIR"

echo "$APP_DIR"
"$ROOT_DIR/Tools/create_dmg.sh"
