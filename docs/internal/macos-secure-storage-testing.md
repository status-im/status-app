# Testing secure storage (data-protection keychain) locally on macOS

The "Stay logged in" feature (`SecureStorage`, service `StatusDesktop.AutoLogin`)
stores its credential exclusively in the macOS **data-protection keychain**, because
only that keychain supports the device-only, non-migratable accessibility the feature
requires (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). The hardened biometric
items of the `Keychain` class use the same store (with a legacy fallback —
`SecureStorage` deliberately has none).

The data-protection keychain requires an **application identifier from a code
signature backed by a provisioning profile**. A locally built binary (ad-hoc signed)
gets `errSecMissingEntitlement` (OSStatus **-34018**) from every write, so:

- `SecureStorage.available` reports `false` ("Secure storage is unavailable on this
  device" in the UI, `Unavailable` statuses in the Storybook SecureStorage page),
- the console shows `SecureStorage: data-protection keychain unavailable (missing
  entitlements, unsigned build?)`.

This is **by design**, not a bug. A certificate alone is not enough: signing with
restricted entitlements but no profile makes AMFI kill the app at launch (exit 137),
and signing without the entitlements still yields -34018. To test the real backend
you need the setup below (verified end to end on a developer machine).

## One-time setup per machine (~10 min)

You need an Apple Development certificate for the Status team (`8B5X2M6H2Y`) in your
keychain — check with:

```bash
security find-identity -v -p codesigning
```

The team is the **OU** of the certificate, not the id in parentheses; verify with
`security find-certificate -c "Apple Development" -p -a | openssl x509 -noout -subject`.
If you don't have one, add your Apple account in Xcode → Settings → Accounts and
create one via "Manage Certificates".

Then mint a **Mac Team Provisioning Profile** (Xcode is the easiest way, and it also
registers your Mac as a team device):

1. Xcode → File → New → Project → **macOS → App**. Any name (e.g. `DPKTest`),
   Team: *Status Research & Development GmbH*, any bundle id.
2. In *Signing & Capabilities*, keep "Automatically manage signing" and add the
   **Keychain Sharing** capability (accept the default group). Without a capability
   that needs provisioning, Xcode won't create a profile.
3. Build once (⌘B), then copy the profile out of the built app and keep it:

```bash
mkdir -p ~/.status-dev
cp ~/Library/Developer/Xcode/DerivedData/DPKTest-*/Build/Products/Debug/DPKTest.app/Contents/embedded.provisionprofile \
   ~/.status-dev/status-team-mac.provisionprofile
```

The result is a **wildcard** profile (`8B5X2M6H2Y.*` for both the app identifier and
the keychain access groups), so it signs any bundle id under the team. It is bound to
your Mac and expires after a year — re-mint it the same way when it does. The dummy
Xcode project can be deleted.

## Signing a build

Use the helper script after **every** build of the target (a rebuild replaces the
binary and erases the signature):

```bash
# Storybook (the SecureStorage page is the quickest manual test surface):
scripts/sign-macos-dev.sh storybook/build/Qt6.11.0/bin/Storybook.app \
    8B5X2M6H2Y im.status.storybook ~/.status-dev/status-team-mac.provisionprofile
```

The script stamps the bundle id, embeds the profile, and codesigns with the
`application-identifier` / `keychain-access-groups` entitlements. Keychain items are
bound to the access group (`<team>.<bundle id>`), so keep the bundle id stable
between runs or previously stored items become unreachable.

### The dev app (`bin/StatusDev.app`)

The dev bundle made by `make run` symlinks its binary from `bin/`, which codesign
refuses — the script detects this and replaces the symlink with a copy. Because a
plain `make run` both rebuilds and recreates the symlink (erasing the signature), the
signed dev app has its own launch target:

```bash
make run                       # build once; quit the app after it starts
scripts/sign-macos-dev.sh bin/StatusDev.app \
    8B5X2M6H2Y im.status.desktop ~/.status-dev/status-team-mac.provisionprofile
make run-macos-signed          # launches WITHOUT rebuilding (ARGS=... works as usual)
```

After any rebuild, repeat the sign + `run-macos-signed` pair (`run-macos-signed`
refuses to start while the binary is still a symlink, i.e. unsigned).

Dev builds derive their data dir from the executable location (`<repo>/Status/` for
`make run`); since the signed bundle holds a copy of the binary, `run-macos-signed`
pins `-d=<repo>/Status` explicitly so both launch modes share the same dev data
(pass your own `-d=`/`--dataDir` in `ARGS` to override). If the app unexpectedly
shows the profiles of an installed Status, the binary was built without an effective
`-d:development` (stale incremental build) — `touch src/env_cli_vars.nim` and
rebuild; verify with `--help`, which prints the compiled-in data-dir default.

## Verifying

- Storybook → **SecureStorage** page: `available: ✅`, `Set → Success`,
  `Get` returns the value, `Delete → Success`. The page logs named statuses and
  prints the sent/read values to the console.
- **Keychain Access.app**: search for the service (`StatusStorybook.SecureStorage`
  in Storybook, `StatusDesktop.AutoLogin` in the app). Note: the `security` CLI does
  **not** see data-protection keychain items — "not found" from it proves nothing.
- Full app end-to-end: onboarding with "Save password on this device" ON → quit →
  relaunch → no password prompt; sign out → relaunch → login screen and the keychain
  item is gone.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `-34018` (`errSecMissingEntitlement`) in logs, `available: false` | Unsigned build, or a rebuild erased the signature — re-run the signing script |
| App killed at launch (exit 137, AMFI message in Console) | Entitlements without an embedded profile, or bundle/app id not covered by the profile |
| Worked before, stopped on this Mac | Profile expired (re-mint via Xcode), or testing on a different Mac (profiles are device-bound) |
| Items visible but `Get` returns NotFound | Bundle id (access group) changed between runs |

## Note for release builds

Production signing (`scripts/sign-macos-pkg.sh` + `resources/Entitlements.plist`)
currently carries no `com.apple.application-identifier`. The data-protection keychain
has the same requirement there — if biometrics/stay-logged-in fail on a signed build,
the entitlements (and, for Apple Development certs, an embedded profile) are the
first thing to check.
