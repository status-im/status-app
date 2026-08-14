# Share-intake instrumentation tests

## `ShareIntakeSecurityTest` — RED (expected to fail)

Pins the critical finding on PR #21769: `StatusQtActivity.handleShareIntake`
copies every `EXTRA_STREAM` into the app-private `share-intake` cache with the
app's own UID, **without validating the URI scheme or authority**.

A zero-permission app can send `ACTION_SEND` with type `image/png` and a
`file:///data/user/0/app.status.mobile/...` URI (or a `content://` URI on
Status's own `${applicationId}.qtprovider` authority). The stream is read as
Status and staged as a sendable image, exfiltrating private keystore/DB/log
content into a chat.

The test asserts the intended contract: **only foreign `content://` streams are
accepted**. `fileSchemeStreamIsRejected` and `ownFileProviderAuthorityIsRejected`
fail today; `foreignContentStreamIsAccepted` already passes and guards against an
over-broad fix.

### Fix that turns it GREEN

Vet each extracted stream in `handleShareIntake` before `copySharedImagesToCache`:
reject any URI whose scheme is not `content`, and reject `content://` URIs whose
authority equals `${applicationId}.qtprovider`.

### Running

Needs a booted emulator/device and the app built with the Qt Android toolchain
(`QT_ANDROID_DIR`, status-go libs, NDK):

```bash
cd mobile/android/qt6
./gradlew connectedAndroidTest
```

The test itself does not boot Qt — it invokes the pure static `extractStreamUris`
seam by reflection — but it runs under instrumentation because `android.net.Uri`
scheme/authority parsing needs the real framework.
