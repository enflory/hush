#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Hush"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

echo "Building $APP_NAME..."
swift build -c release
BIN_PATH=$(swift build -c release --show-bin-path)

echo "Assembling $APP_NAME.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BIN_PATH/$APP_NAME"       "$CONTENTS/MacOS/$APP_NAME"
cp Resources/Info.plist        "$CONTENTS/Info.plist"
cp Resources/AppIcon.icns      "$CONTENTS/Resources/AppIcon.icns"

echo "Code signing (ad-hoc)..."
codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "To install: cp -R $APP_BUNDLE /Applications/"
