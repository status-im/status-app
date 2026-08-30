# F-Droid Build & Reproducibility

This directory contains the scripts used to build the Status app APK the same
way F-Droid's buildserver does, plus the patches that make that build
byte-for-byte reproducible.

## Why reproducibility matters

Our F-Droid metadata ([fdroiddata `app.status.mobile.yml`](https://gitlab.com/fdroid/fdroiddata))
uses the `Binaries:` field, pointing at the APK we publish on GitHub releases:

```yaml
Binaries:
  https://github.com/status-im/status-app/releases/download/%v/app.status.mobile_%c.apk
```

With `Binaries:` set, F-Droid only publishes our **developer-signed** APK if
their own from-source rebuild is byte-identical to it.

## How F-Droid verifies a release

For every new version tagged in the metadata, F-Droid's buildserver:

1. Checks out the `commit:` pinned in the metadata and builds the APK from
   source inside their VM (`fdroid build`), producing an *unsigned* APK.
2. Downloads our published release APK from the `Binaries:` URL.
3. Uses [apksigcopier](https://github.com/obfusk/apksigcopier) to copy the APK
   Signing Block from our published APK onto their unsigned build.
4. Verifies the result with `apksigner verify` and compares it against our
   published APK.

Step 4 only succeeds if every file inside the APK i.e every native library,
`classes.dex`, resources, manifest is byte-identical between the two builds.
The signature is the only part that is copied rather than rebuilt, and it is
additionally gated by `AllowedAPKSigningKeys` (the SHA-256 of our release
signing certificate).

## What makes the build deterministic

**Timestamps and locale** (`build-qt.sh`):
- `SOURCE_DATE_EPOCH` is set to the commit time of the latest release tag,
  not `HEAD`, so new commits do not change the build date baked into the
  libraries.
- `LC_ALL=C` for stable tool output ordering.

**Qt** (`build-qt.sh`):
- `--build-id=none` and `-ffile-prefix-map` are patched into Qt's top-level
  `CMakeLists.txt` to keep build IDs and absolute paths out of the `.so` files.
- QML modules are compiled with `qmlcachegen --only-bytecode` (patched into
  `Qt6QmlMacros.cmake`) because its AOT codegen is not deterministic.
- `CMAKE_UNITY_BUILD` and `CMAKE_INTERPROCEDURAL_OPTIMIZATION` are off.
- De-registered Qt submodules are deleted after `init-repository`.

**libstatus.so** (`mobile/Makefile`, android branch):
- `GOFLAGS="-trimpath -buildvcs=false"` keeps workspace paths and VCS stamps
  out of the binary.
- `go-toolexec-wrapper.sh` derives cgo's per-package symbol hash from source
  content instead of the random `$WORK` temp directory.
- `CGO_LDFLAGS="-Wl,--build-id=none"` plus `llvm-objcopy` stripping of the
  build-id notes after linking.
- `-s -w -buildid=` lives in status-go's `statusgo-android-library` ldflags.
- status-go's `generate-cbindings` sorts exported functions before emitting
  `main.go`, otherwise Go's random map iteration reshuffles the export order
  every build.


## Running the build locally

```sh
git clone https://gitlab.com/fdroid/fdroiddata.git
FDROIDDATA_PATH=$PWD/fdroiddata ./scripts/fdroid-local-build.sh app.status.mobile:29500000
```
