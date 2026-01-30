#!/bin/bash
# Regenerates menubar icon assets from the source PNG at project root
# Usage: ./scripts/regenerate-menubar-icon.sh

set -e

SOURCE="Positron Watcher Icon.png"
DEST="PositronWatchers/Resources/Assets.xcassets/MenuBarIcon.imageset"

if [ ! -f "$SOURCE" ]; then
    echo "Error: $SOURCE not found in project root"
    exit 1
fi

echo "Regenerating menubar icons from $SOURCE..."

sips -z 18 18 "$SOURCE" --out "$DEST/MenuBarIcon.png"
sips -z 36 36 "$SOURCE" --out "$DEST/MenuBarIcon@2x.png"
sips -z 54 54 "$SOURCE" --out "$DEST/MenuBarIcon@3x.png"

echo "Done! Rebuild the app to see changes."
