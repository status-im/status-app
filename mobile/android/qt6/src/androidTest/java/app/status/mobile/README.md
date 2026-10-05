# Share-intake instrumentation tests

## `ShareIntakeSecurityTest`

Regression guard for the share-intake stream vetting in
`StatusQtActivity.handleShareIntake`: every `EXTRA_STREAM` is opened as Status
itself, so without vetting a zero-permission app could send `ACTION_SEND` with a
`file:///data/user/0/app.status.mobile/...` URI (or a `content://` URI on
Status's own `${applicationId}.qtprovider` authority) and have private
keystore/DB/log content staged as a sendable image.

Contract under test: **only foreign `content://` streams are accepted**.
`fileSchemeStreamIsRejected` and `ownFileProviderAuthorityIsRejected` pin the
two rejection paths; `foreignContentStreamIsAccepted` guards against an
over-broad fix.

### Running

Needs a booted emulator/device and the app built with the Qt Android toolchain
(`QT_ANDROID_DIR`, status-go libs, NDK). Gradle runs from the androiddeployqt
output dir, so go through the mobile build:

```bash
GRADLE_TARGETS="assembleDebug connectedDebugAndroidTest" make mobile-build
```

The test itself does not boot Qt — it invokes the static `extractStreamUris`
seam by reflection — but it runs under instrumentation because `android.net.Uri`
parsing and the `PackageManager` provider lookup need the real framework.
