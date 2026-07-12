#!/usr/bin/env bash
# Builds the share extension (mobile/ios/shareExtension/, fork issues #13/#14)
# via xcodebuild, embeds it into the already-built app bundle's
# PlugIns/, and re-signs the outer app (adding nested code after signing
# breaks the app's signature seal).
#
# There is no shared Xcode project to add the extension target to — the app is
# qmake-generated — so this runs as a post-link step from buildApp.sh.
#
# Usage: buildShareExtension.sh <path-to-built .app>
# Env (mirrors buildApp.sh): SDK, ARCH, BUILD_DIR, VERSION, BUILD_VERSION,
#   QMAKE_EXTRA_CONFIG (fastlane => signing disabled, fastlane re-signs later),
#   DEVELOPMENT_TEAM (default: Status org team, as in wrapperApp/Status.pro).
set -eo pipefail

CWD=$(realpath "$(dirname "$0")")
SRC_DIR=$(realpath "$CWD/../../ios/shareExtension")

APP_BUNDLE=${1:?usage: buildShareExtension.sh <path-to-built .app>}
SDK=${SDK:-iphonesimulator}
ARCH=${ARCH:-arm64}
BUILD_DIR=${BUILD_DIR:-"$CWD/../../build"}
EXT_BUILD_DIR="$BUILD_DIR/shareExtension"
DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM:-8B5X2M6H2Y}

# The extension bundle id must be prefixed by the host app's (works for both
# variants: app.status.mobile / app.status.mobile.pr).
HOST_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_BUNDLE/Info.plist")
EXT_BUNDLE_ID="$HOST_BUNDLE_ID.ShareExtension"

echo "Building share extension $EXT_BUNDLE_ID (sdk: $SDK, arch: $ARCH)"

XCODE_FLAGS=(
  -project "$SRC_DIR/ShareExtension.xcodeproj"
  -target StatusShareExtension
  -configuration Release
  -sdk "$SDK" -arch "$ARCH"
  SYMROOT="$EXT_BUILD_DIR" OBJROOT="$EXT_BUILD_DIR"
  PRODUCT_BUNDLE_IDENTIFIER="$EXT_BUNDLE_ID"
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
  ${VERSION:+MARKETING_VERSION="$VERSION"}
  ${BUILD_VERSION:+CURRENT_PROJECT_VERSION="$BUILD_VERSION"}
)
if [[ "${QMAKE_EXTRA_CONFIG:-}" == "fastlane" ]]; then
  # CI: disable signing; fastlane signs app + extension after the build.
  XCODE_FLAGS+=(CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO)
else
  # Local: let xcodebuild fetch a provisioning profile with the App Group.
  XCODE_FLAGS+=(-allowProvisioningUpdates)
fi

xcodebuild "${XCODE_FLAGS[@]}" build | xcbeautify

APPEX="$EXT_BUILD_DIR/Release-$SDK/StatusShareExtension.appex"
[[ -e "$APPEX/Info.plist" ]] || { echo "Share extension build failed: $APPEX missing"; exit 1; }

echo "Embedding $APPEX into $APP_BUNDLE/PlugIns/"
mkdir -p "$APP_BUNDLE/PlugIns"
rm -rf "$APP_BUNDLE/PlugIns/StatusShareExtension.appex"
cp -R "$APPEX" "$APP_BUNDLE/PlugIns/"

if [[ "${QMAKE_EXTRA_CONFIG:-}" != "fastlane" ]]; then
  # Re-sign the outer app: embedding invalidated its signature seal. The appex
  # keeps the signature xcodebuild gave it; --preserve-metadata keeps the app's
  # entitlements (incl. the App Group added in mobile/ios/*.entitlements).
  if [[ "$SDK" == iphonesimulator* ]]; then
    IDENTITY="-" # simulator runs ad-hoc signed code
  else
    IDENTITY="${CODE_SIGN_IDENTITY:-Apple Development}"
  fi
  echo "Re-signing $APP_BUNDLE with identity: $IDENTITY"
  codesign --force --sign "$IDENTITY" --preserve-metadata=entitlements,requirements,flags "$APP_BUNDLE"
fi

echo "Share extension embedded: $APP_BUNDLE/PlugIns/StatusShareExtension.appex"
