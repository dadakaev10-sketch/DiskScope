#!/bin/zsh
set -euo pipefail

PROJECT_DIR=${0:A:h}
OUTPUT_DIR="${1:-$PROJECT_DIR/release}"
SIGNING_IDENTITY="${DISKSCOPE_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${DISKSCOPE_NOTARY_PROFILE:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "DISKSCOPE_SIGNING_IDENTITY fehlt (Developer ID Application: …)"
  exit 2
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "DISKSCOPE_NOTARY_PROFILE fehlt (notarytool-Keychain-Profil)"
  exit 3
fi

if ! xcrun notarytool --version >/dev/null 2>&1; then
  echo "notarytool ist nicht verfügbar. Installiere die aktuelle vollständige Xcode-Version."
  exit 4
fi

mkdir -p "$OUTPUT_DIR"
DISKSCOPE_SIGNING_IDENTITY="$SIGNING_IDENTITY" "$PROJECT_DIR/build.sh"

STAGE_DIR=$(mktemp -d)
DMG_PATH="$OUTPUT_DIR/DiskScope.dmg"
cp -R "$PROJECT_DIR/build/DiskScope.app" "$STAGE_DIR/DiskScope.app"
cp "$PROJECT_DIR/INSTALLATION.txt" "$STAGE_DIR/INSTALLATION.txt"
ln -s /Applications "$STAGE_DIR/Programme"

hdiutil create \
  -volname "DiskScope" \
  -srcfolder "$STAGE_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

codesign \
  --force \
  --timestamp \
  --sign "$SIGNING_IDENTITY" \
  "$DMG_PATH"

xcrun notarytool submit \
  "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

find "$STAGE_DIR" -depth -delete
echo "$DMG_PATH"
