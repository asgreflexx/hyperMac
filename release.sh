#!/bin/bash
set -e

VERSION="0.1.0"
APP_NAME="hyperMac"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR=".build/release"
STAGING_DIR=".build/dmg-staging"

# ── 1. Build ──────────────────────────────────────────────────────────────────
echo "Building ${APP_NAME}..."
swift build -c release

# ── 2. Assemble .app bundle ───────────────────────────────────────────────────
echo "Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}" "${STAGING_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}"                  "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Sources/${APP_NAME}/Resources/Info.plist"  "${APP_BUNDLE}/Contents/"

# ── 3. Ad-hoc code sign ───────────────────────────────────────────────────────
echo "Signing (ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

# ── 4. Create DMG ─────────────────────────────────────────────────────────────
echo "Creating ${DMG_NAME}..."

mkdir -p "${STAGING_DIR}"
cp -r "${APP_BUNDLE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}"

rm -rf "${STAGING_DIR}"

echo ""
echo "Done → ${DMG_NAME}"
echo ""
echo "Note: because this is ad-hoc signed, users must right-click → Open"
echo "the first time to bypass Gatekeeper."
