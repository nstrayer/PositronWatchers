#!/bin/bash
set -e

# Manual release script for major/minor version bumps.
# For routine releases, just merge a PR to main -- CI auto-releases.
#
# Usage: ./scripts/release.sh 2.0
#
# This bumps the version in the Xcode project, commits, tags, and pushes.
# The GitHub Actions workflow then builds the DMG and creates the release.

APP_NAME="PositronWatchers"
PROJECT_FILE="${APP_NAME}.xcodeproj/project.pbxproj"

usage() {
    echo "Usage: $0 <version>"
    echo ""
    echo "  version   Semver-style version (e.g. 1.1, 1.2.0, 2.0)"
    echo ""
    echo "Bumps the version, commits, tags, and pushes."
    echo "CI will build the DMG and create the GitHub release."
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

if [ -n "$(git status --porcelain)" ]; then
    echo "Error: Working tree is dirty. Commit or stash changes before releasing."
    exit 1
fi

OLD_VERSION=$(current_version)
echo "==> Bumping $APP_NAME v$OLD_VERSION -> v$VERSION"

# --- Bump version in Xcode project ---

OLD_BUILD=$(grep 'CURRENT_PROJECT_VERSION' "$PROJECT_FILE" | head -1 | sed 's/.*= *//;s/ *;.*//')
NEW_BUILD=$((OLD_BUILD + 1))

echo "==> Updating version to $VERSION (build $NEW_BUILD)..."
sed -i '' "s/MARKETING_VERSION = $OLD_VERSION;/MARKETING_VERSION = $VERSION;/g" "$PROJECT_FILE"
sed -i '' "s/CURRENT_PROJECT_VERSION = $OLD_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PROJECT_FILE"

# --- Commit, tag, and push ---

echo "==> Committing version bump..."
git add "$PROJECT_FILE"
git commit -m "chore: bump version to $VERSION"
git tag "v$VERSION"

echo "==> Pushing to origin..."
git push origin HEAD
git push origin "v$VERSION"

echo ""
echo "==> Done! Pushed v$VERSION."
echo "    CI will build and release at:"
echo "    https://github.com/nstrayer/PositronWatchers/actions"
