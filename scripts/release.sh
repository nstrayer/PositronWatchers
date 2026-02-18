#!/bin/bash
set -e

APP_NAME="PositronWatchers"
SCHEME="PositronWatchers"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}.dmg"
PROJECT_FILE="${APP_NAME}.xcodeproj/project.pbxproj"

# --- Helpers ---

usage() {
    echo "Usage: $0 <version>"
    echo ""
    echo "  version   Semver-style version (e.g. 1.1, 1.2.0, 2.0)"
    echo ""
    echo "This script will:"
    echo "  1. Update the version in the Xcode project"
    echo "  2. Build a Release DMG"
    echo "  3. Commit and tag the version bump"
    echo "  4. Create a GitHub release with the DMG attached"
    exit 1
}

current_version() {
    grep -m1 'MARKETING_VERSION' "$PROJECT_FILE" | sed 's/.*= *//;s/ *;.*//'
}

# --- Validate inputs ---

VERSION="${1:?$(usage)}"

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
    echo "Error: Invalid version format '$VERSION'. Expected semver (e.g. 1.1, 1.2.0)"
    exit 1
fi

if ! command -v gh &>/dev/null; then
    echo "Error: GitHub CLI (gh) is required. Install with: brew install gh"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "Error: Not authenticated with GitHub CLI. Run: gh auth login"
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "Error: Working tree is dirty. Commit or stash changes before releasing."
    exit 1
fi

OLD_VERSION=$(current_version)
echo "==> Releasing $APP_NAME v$OLD_VERSION -> v$VERSION"

# --- Step 1: Bump version in Xcode project ---

# Increment build number: extract the highest current build number and add 1
OLD_BUILD=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_FILE" | head -1 | sed 's/.*= *//;s/ *;.*//')
NEW_BUILD=$((OLD_BUILD + 1))

echo "==> Updating version to $VERSION (build $NEW_BUILD)..."
sed -i '' "s/MARKETING_VERSION = $OLD_VERSION;/MARKETING_VERSION = $VERSION;/g" "$PROJECT_FILE"
sed -i '' "s/CURRENT_PROJECT_VERSION = $OLD_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PROJECT_FILE"

# --- Step 2: Build DMG ---

echo "==> Cleaning previous build..."
rm -rf "$BUILD_DIR"
rm -f "$DMG_NAME"

echo "==> Building Release..."
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build

APP_PATH=$(find "$BUILD_DIR" -name "${APP_NAME}.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find ${APP_NAME}.app in build output"
    exit 1
fi

echo "==> Found app at: $APP_PATH"

STAGING_DIR="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

rm -rf "$BUILD_DIR"

# --- Step 3: Commit and tag ---

echo "==> Committing version bump..."
git add "$PROJECT_FILE"
git commit -m "chore: bump version to $VERSION"
git tag "v$VERSION"

# --- Step 4: Push and create GitHub release ---

echo "==> Pushing to origin..."
git push origin HEAD
git push origin "v$VERSION"

# Generate release notes from commits since last tag
PREV_TAG=$(git tag --sort=-v:refname | grep -v "v$VERSION" | head -1)
if [ -n "$PREV_TAG" ]; then
    NOTES=$(git log --pretty=format:"- %s" "$PREV_TAG..v$VERSION" | grep -v "chore: bump version")
else
    NOTES=$(git log --pretty=format:"- %s" | grep -v "chore: bump version")
fi

if [ -z "$NOTES" ]; then
    NOTES="Release v$VERSION"
fi

echo "==> Creating GitHub release..."
gh release create "v$VERSION" "$DMG_NAME" \
    --title "$APP_NAME v$VERSION" \
    --notes "$NOTES"

echo ""
echo "==> Done! Released $APP_NAME v$VERSION"
echo "    https://github.com/nstrayer/PositronWatchers/releases/tag/v$VERSION"
