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

## `ShareTextDocumentsTest`

Decoding of text document shares (`text/*` streams with no inline text, pasted
as message text): BOM-sniffed UTF-16, strict UTF-8, binary behind a text claim
rejected, and a read cut at the memory guard still decoding. Pure Java; lives
here because the module has no JVM test source set.

## `VCardTextTest`

A shared contact (vCard) is rendered as a readable card: name (`FN`, else
`N`), title, organisation, labelled phones/emails/URLs/addresses, note; folded
lines, `item1.` groups, escapes and vCard 2.1 bare type words handled; `PHOTO`
and unknown fields dropped. Pure Java, same reason as above.

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
