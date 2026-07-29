#!/bin/bash
#
# Builds, signs, notarizes, staples, and publishes the macOS Poseiosc
# Receiver as a GitHub Release asset.
#
# One-time setup (see README "Releasing the receiver"):
#   1. A "Developer ID Application" certificate in your keychain
#      (Xcode → Settings → Accounts → Manage Certificates → +).
#   2. Notary credentials stored in the keychain:
#      xcrun notarytool store-credentials poseiosc-notary \
#        --apple-id you@example.com --team-id YOURTEAMID \
#        --password <app-specific password from appleid.apple.com>
#   3. gh CLI authenticated (gh auth login).
#
# Usage:
#   POSEIOSC_TEAM_ID=YOURTEAMID Scripts/release-receiver.sh [--dry-run]
#
# --dry-run does everything except create the GitHub release.

set -euo pipefail

cd "$(dirname "$0")/.."

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

: "${POSEIOSC_TEAM_ID:?Set POSEIOSC_TEAM_ID to your Apple Developer team ID}"

VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml | head -1)
[[ -n "$VERSION" ]] || { echo "Could not read MARKETING_VERSION from project.yml"; exit 1; }

BUILD_DIR="build/release"
ARCHIVE="$BUILD_DIR/PoseioscReceiver.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/PoseioscReceiver.app"
ZIP="$BUILD_DIR/PoseioscReceiver-$VERSION-macOS.zip"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

echo "=== Releasing Poseiosc Receiver $VERSION (team $POSEIOSC_TEAM_ID) ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "--- Archiving"
xcodebuild -project Poseiosc.xcodeproj \
    -scheme PoseioscReceiver \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    DEVELOPMENT_TEAM="$POSEIOSC_TEAM_ID" \
    archive | tail -2

echo "--- Exporting with Developer ID signing"
sed "s/TEAM_ID_PLACEHOLDER/$POSEIOSC_TEAM_ID/" Scripts/ExportOptions.plist > "$EXPORT_OPTIONS"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" | tail -2

echo "--- Notarizing (waits for Apple; typically a few minutes)"
ditto -c -k --keepParent "$APP" "$BUILD_DIR/notarize-upload.zip"
xcrun notarytool submit "$BUILD_DIR/notarize-upload.zip" \
    --keychain-profile poseiosc-notary \
    --wait

echo "--- Stapling notarization ticket"
xcrun stapler staple "$APP"

echo "--- Verifying Gatekeeper acceptance"
spctl -a -vv "$APP"

echo "--- Zipping final artifact"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Created $ZIP"

if [[ $DRY_RUN -eq 1 ]]; then
    echo "--- Dry run: skipping GitHub release. Artifact: $ZIP"
    exit 0
fi

echo "--- Publishing GitHub release v$VERSION"
gh release create "v$VERSION" "$ZIP" \
    --title "Poseiosc $VERSION" \
    --notes "macOS Poseiosc Receiver $VERSION — signed and notarized; download, unzip, and open.

The iOS sender is distributed via TestFlight. To build either app from source, see the README."

echo "=== Done: https://github.com/JGL/Poseiosc/releases/tag/v$VERSION ==="
