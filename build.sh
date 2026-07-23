#!/bin/zsh
set -euo pipefail

PROJECT_DIR=${0:A:h}
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/DiskScope.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
ICON_SOURCE="$PROJECT_DIR/Assets/AppIcon-generated.png"
ARM_BINARY="$BUILD_DIR/DiskScope-arm64"
INTEL_BINARY="$BUILD_DIR/DiskScope-x86_64"
SIGNING_IDENTITY="${DISKSCOPE_SIGNING_IDENTITY:--}"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  -O \
  -target arm64-apple-macosx14.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework Combine \
  "$PROJECT_DIR/Sources/DiskScopeApp.swift" \
  -o "$ARM_BINARY"

swiftc \
  -swift-version 5 \
  -parse-as-library \
  -O \
  -target x86_64-apple-macosx14.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework Combine \
  "$PROJECT_DIR/Sources/DiskScopeApp.swift" \
  -o "$INTEL_BINARY"

lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$MACOS_DIR/DiskScope"

cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

for localization_dir in "$PROJECT_DIR"/Resources/*.lproj; do
  if [[ -d "$localization_dir" ]]; then
    ditto "$localization_dir" "$RESOURCES_DIR/${localization_dir:t}"
  fi
done

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --deep --options runtime --sign - "$APP_DIR"
else
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$SIGNING_IDENTITY" \
    "$APP_DIR"
fi

echo "$APP_DIR"
