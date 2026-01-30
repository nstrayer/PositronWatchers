#!/bin/bash
set -e

APP_NAME="PositronWatchers"
SCHEME="PositronWatchers"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}.dmg"

echo "==> Cleaning previous build..."
rm -rf "$BUILD_DIR"
rm -f "$DMG_NAME"

echo "==> Building Release..."
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build

# Find the built .app
APP_PATH=$(find "$BUILD_DIR" -name "${APP_NAME}.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find ${APP_NAME}.app in build output"
    exit 1
fi

echo "==> Found app at: $APP_PATH"

# Create staging directory for DMG contents
STAGING_DIR="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING_DIR"

# Copy app to staging
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create symlink to Applications folder
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

echo "==> Cleaning up..."
rm -rf "$BUILD_DIR"

echo "==> Done! Created: $DMG_NAME"
