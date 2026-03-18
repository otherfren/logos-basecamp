#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# macOS Code Signing & Notarization for LogosApp.app
# Based on proven working laptop script
#
# Required env vars:
#   MACOS_CODESIGN_IDENT       - Developer ID Application identity
#   MACOS_NOTARY_ISSUER_ID     - App Store Connect API issuer ID
#   MACOS_NOTARY_KEY_ID        - App Store Connect API key ID
#   MACOS_NOTARY_KEY_FILE      - Path to .p8 AuthKey file
#   MACOS_KEYCHAIN_PASS        - Password for the .p12 certificate
#   MACOS_KEYCHAIN_FILE        - Path to the .p12 certificate file
###############################################################################

TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

APP_BUNDLE="./result/LogosApp.app"
CONTENTS="${APP_BUNDLE}/Contents"
ENTITLEMENTS="${TEMP_DIR}/entitlements.plist"
KEYCHAIN_NAME="build.keychain"
DMG_NAME="LogosApp.dmg"

# Codesign options — hardened runtime required for notarization
CODESIGN_OPTS=(
    --force
    --timestamp
    --options runtime
    --sign "${MACOS_CODESIGN_IDENT}"
)

###############################################################################
# 0. Copy app to temp directory and fix permissions (critical!)
###############################################################################
echo "==> Copying app bundle to temp directory..."
cp -a "${APP_BUNDLE}" "${TEMP_DIR}/"
APP_BUNDLE="${TEMP_DIR}/LogosApp.app"
CONTENTS="${APP_BUNDLE}/Contents"

echo "==> Setting write permissions..."
chmod -R u+w "${APP_BUNDLE}"

###############################################################################
# 1. Create entitlements file
###############################################################################
echo "==> Creating entitlements..."
cat > "${ENTITLEMENTS}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF

###############################################################################
# 1. Set up keychain
###############################################################################
echo "==> Setting up keychain..."
security delete-keychain "${KEYCHAIN_NAME}" 2>/dev/null || true
security create-keychain -p "${MACOS_KEYCHAIN_PASS}" "${KEYCHAIN_NAME}"
security unlock-keychain -p "${MACOS_KEYCHAIN_PASS}" "${KEYCHAIN_NAME}"

security import "${MACOS_KEYCHAIN_FILE}" \
    -k "${KEYCHAIN_NAME}" \
    -P "${MACOS_KEYCHAIN_PASS}" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -k "${MACOS_KEYCHAIN_PASS}" "${KEYCHAIN_NAME}"

security list-keychains -d user -s \
    "${KEYCHAIN_NAME}" \
    "$HOME/Library/Keychains/login.keychain-db" \
    "/Library/Keychains/System.keychain"

echo "==> Available identities:"
security find-identity -v -p codesigning || echo "Warning: No identities found"

###############################################################################
# 2. Sign .lgx archives in Contents/preinstall/
###############################################################################
echo "==> Signing dylibs inside .lgx archives..."
find "${CONTENTS}/preinstall" -name "*.lgx" 2>/dev/null | while read -r lgx; do
    echo "  Processing: ${lgx}"
    tmpdir=$(mktemp -d)
    tar -xzf "$lgx" -C "$tmpdir"
    find "$tmpdir" -name "*.dylib" -exec \
        codesign --force --options runtime --sign "${MACOS_CODESIGN_IDENT}" --timestamp {} \;
    tar -czf "$lgx" -C "$tmpdir" .
    rm -rf "$tmpdir"
    echo "  Repacked: ${lgx}"
done

###############################################################################
# 3. Sign all dylibs in Frameworks/
###############################################################################
echo "==> Signing dylibs in Frameworks..."
find "${CONTENTS}/Frameworks" -name '*.dylib' -type f 2>/dev/null | while read -r dylib; do
    echo "  Signing: ${dylib}"
    codesign "${CODESIGN_OPTS[@]}" "${dylib}"
done

###############################################################################
# 4. Sign all dylibs in Resources/qt/
###############################################################################
echo "==> Signing dylibs in Resources/qt..."
find "${CONTENTS}/Resources/qt" -type f -name '*.dylib' 2>/dev/null | while read -r dylib; do
    echo "  Signing: ${dylib}"
    codesign "${CODESIGN_OPTS[@]}" "${dylib}"
done

###############################################################################
# 5. Sign Qt frameworks
###############################################################################
echo "==> Signing Qt frameworks..."
find "${CONTENTS}/Frameworks" -name '*.framework' -type d -maxdepth 1 2>/dev/null | sort | while read -r fw; do
    fw_name=$(basename "${fw}" .framework)
    fw_binary="${fw}/Versions/A/${fw_name}"

    if [[ -f "${fw_binary}" ]]; then
        echo "  Signing framework binary: ${fw_binary}"
        codesign "${CODESIGN_OPTS[@]}" "${fw_binary}"
    fi

    echo "  Signing framework bundle: ${fw}"
    codesign "${CODESIGN_OPTS[@]}" "${fw}"
done

###############################################################################
# 6. Sign executables in Contents/MacOS/
###############################################################################
echo "==> Signing executables..."
for exe in "${CONTENTS}/MacOS/LogosApp.bin" \
           "${CONTENTS}/MacOS/logos-app" \
           "${CONTENTS}/MacOS/logos_host" \
           "${CONTENTS}/MacOS/logoscore"; do
    if [[ -f "${exe}" ]]; then
        echo "  Signing: ${exe}"
        codesign "${CODESIGN_OPTS[@]}" --entitlements "${ENTITLEMENTS}" "${exe}"
    fi
done

# Sign the shell script wrapper last (no --options runtime for scripts)
if [[ -f "${CONTENTS}/MacOS/LogosApp" ]]; then
    echo "  Signing wrapper: ${CONTENTS}/MacOS/LogosApp"
    codesign --force --timestamp --sign "${MACOS_CODESIGN_IDENT}" "${CONTENTS}/MacOS/LogosApp"
fi

###############################################################################
# 7. Sign the top-level app bundle
###############################################################################
echo "==> Signing app bundle..."
codesign "${CODESIGN_OPTS[@]}" --entitlements "${ENTITLEMENTS}" "${APP_BUNDLE}"

###############################################################################
# 8. Verify
###############################################################################
echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}" || {
    echo "WARNING: Signature verification failed, but continuing..."
}

echo "==> Checking Gatekeeper assessment..."
spctl --assess --type execute --verbose=2 "${APP_BUNDLE}" || true

###############################################################################
# 9. Create DMG
###############################################################################
echo "==> Creating DMG..."
DMG_TEMP="LogosApp_temp.dmg"
DMG_VOLUME="LogosApp"

# Create temporary read-write DMG
hdiutil create -srcfolder "${APP_BUNDLE}" \
    -volname "${DMG_VOLUME}" \
    -fs HFS+ \
    -format UDRW \
    -ov "${DMG_TEMP}"

# Add Applications symlink
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "${DMG_TEMP}" | grep '/Volumes/' | awk '{print $NF}')
ln -s /Applications "${MOUNT_DIR}/Applications" || true
hdiutil detach "${MOUNT_DIR}"

# Convert to compressed DMG
hdiutil convert "${DMG_TEMP}" -format UDZO -o "${DMG_NAME}"
rm -f "${DMG_TEMP}"

###############################################################################
# 10. Sign the DMG
###############################################################################
echo "==> Signing DMG..."
codesign --force --timestamp --sign "${MACOS_CODESIGN_IDENT}" "${DMG_NAME}"

###############################################################################
# 11. Notarize the DMG
###############################################################################
echo "==> Submitting DMG for notarization..."
xcrun notarytool submit "${DMG_NAME}" \
    --issuer "${MACOS_NOTARY_ISSUER_ID}" \
    --key-id "${MACOS_NOTARY_KEY_ID}" \
    --key "${MACOS_NOTARY_KEY_FILE}" \
    --wait \
    --timeout 30m

###############################################################################
# 12. Staple the DMG
###############################################################################
echo "==> Stapling notarization ticket to DMG..."
xcrun stapler staple "${DMG_NAME}"

###############################################################################
# 13. Final verification
###############################################################################
echo "==> Final verification..."
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}" || true
spctl --assess --type execute --verbose=2 "${APP_BUNDLE}" || true
spctl --assess --type open --context context:primary-signature --verbose=2 "${DMG_NAME}" || true

###############################################################################
# 14. Cleanup
###############################################################################
echo "==> Cleaning up keychain..."
security delete-keychain "${KEYCHAIN_NAME}" 2>/dev/null || true
rm -f "${ENTITLEMENTS}"

echo "==> Done! DMG is signed and notarized: ${DMG_NAME}"