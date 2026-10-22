#!/usr/bin/env bash

# Signs a locally built .app bundle so the macOS data-protection keychain works
# (SecureStorage for "Stay logged in", and the hardened biometric Keychain items).
# Unsigned dev builds get errSecMissingEntitlement (-34018) from every write.
#
# Requires a ONE-TIME setup per machine (a Mac Team Provisioning Profile minted
# through Xcode) — see docs/internal/macos-secure-storage-testing.md.
#
# NOTE: every rebuild replaces the binary and erases the signature — re-run this
# script after each build of the target.

set -euo pipefail

if [[ $# -lt 4 ]]; then
    cat >&2 <<EOF
Usage: $(basename "$0") <app-bundle> <team-id> <bundle-id> <provisioning-profile> [signing-identity]

  app-bundle            path to the built .app (e.g. storybook/build/Qt6.11.0/bin/Storybook.app)
  team-id               Apple team id the profile belongs to (e.g. 8B5X2M6H2Y)
  bundle-id             bundle id to stamp into the app (must match the profile's
                        app id — a wildcard profile accepts any, e.g. im.status.storybook)
  provisioning-profile  path to the Mac Team Provisioning Profile (.provisionprofile)
  signing-identity      codesign identity (default: the "Apple Development"
                        certificate in your keychain whose team (OU) matches team-id)

Example:
  scripts/sign-macos-dev.sh storybook/build/Qt6.11.0/bin/Storybook.app \\
      8B5X2M6H2Y im.status.storybook ~/.status-dev/status-team-mac.provisionprofile
EOF
    exit 1
fi

APP="$1"
TEAM_ID="$2"
BUNDLE_ID="$3"
PROFILE="$4"
IDENTITY="${5:-}"

[[ -d "${APP}" ]] || { echo "App bundle not found: ${APP}" >&2; exit 1; }
[[ -f "${PROFILE}" ]] || { echo "Provisioning profile not found: ${PROFILE}" >&2; exit 1; }

if [[ -z "${IDENTITY}" ]]; then
    # Pick the signing identity whose certificate belongs to the given team: the team
    # id is the OU of the certificate subject (NOT the id in parentheses in the name).
    while IFS= read -r candidate; do
        ou=$(security find-certificate -c "${candidate}" -p 2>/dev/null \
                 | openssl x509 -noout -subject 2>/dev/null \
                 | grep -oE 'OU *= *[^/,]+' | head -1 | sed -E 's/OU *= *//')
        if [[ "${ou}" == "${TEAM_ID}" ]]; then
            IDENTITY="${candidate}"
            break
        fi
    done < <(security find-identity -v -p codesigning | grep -oE '"[^"]+"' | tr -d '"' | sort -u)

    if [[ -z "${IDENTITY}" ]]; then
        echo "No codesigning identity for team ${TEAM_ID} found in the keychain." >&2
        echo "Create one via Xcode -> Settings -> Accounts -> Manage Certificates," >&2
        echo "or pass the identity name explicitly as the 5th argument." >&2
        exit 1
    fi
fi

# codesign refuses symlinked main executables / Info.plists, and the dev bundle
# (bin/StatusDev.app from `make run`) symlinks its binary from bin/ — materialize any
# symlinks into regular files first. The copy (like the signature itself) goes stale
# on the next rebuild: re-run this script after every build, and launch the signed
# dev bundle with `make run-macos-signed` (a plain `make run` recreates the symlink).
for f in "${APP}/Contents/Info.plist" "${APP}"/Contents/MacOS/*; do
    if [[ -L "${f}" ]]; then
        resolved=$(readlink -f "${f}")
        echo "### Materializing symlink $(basename "${f}") -> ${resolved}"
        rm "${f}"
        cp "${resolved}" "${f}"
    fi
done

# codesign refuses resource forks / Finder info ("detritus") inside the bundle — the
# dev build attaches one to the binary via `fileicon`. Stripping the xattrs only costs
# the custom dev icon.
xattr -cr "${APP}"

ENTITLEMENTS="$(mktemp -t dev-entitlements).plist"
trap 'rm -f "${ENTITLEMENTS}"' EXIT

cat > "${ENTITLEMENTS}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.application-identifier</key>
	<string>${TEAM_ID}.${BUNDLE_ID}</string>
	<key>com.apple.developer.team-identifier</key>
	<string>${TEAM_ID}</string>
	<key>keychain-access-groups</key>
	<array>
		<string>${TEAM_ID}.${BUNDLE_ID}</string>
	</array>
</dict>
</plist>
EOF

echo "### Stamping bundle id '${BUNDLE_ID}'..."
plutil -replace CFBundleIdentifier -string "${BUNDLE_ID}" "${APP}/Contents/Info.plist"

echo "### Embedding provisioning profile..."
cp "${PROFILE}" "${APP}/Contents/embedded.provisionprofile"

echo "### Signing with '${IDENTITY}'..."
codesign --force --deep --sign "${IDENTITY}" --entitlements "${ENTITLEMENTS}" "${APP}"

echo "### Verifying..."
codesign -dv "${APP}" 2>&1 | grep -E "^(Identifier|TeamIdentifier)="

echo "### Done. Keychain items will live in access group ${TEAM_ID}.${BUNDLE_ID}."
