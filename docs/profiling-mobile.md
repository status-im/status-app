# Mobile profiling (Android)

## TL;DR

```
make mobile-profile
```

The app installs as the **profile** APK (a release-like build with
`debuggable=false` and `profileable=true`, so Android Studio's CPU
profiler attaches without the "Profiling debuggable builds" warning).
Profile and `mobile-run` share the same `app.status.mobile.debug`
package id — installing one replaces the other, keeping a single Status
flavor on the device.

It launches and **blocks at QML engine creation** waiting for a QML
profiler / debugger to attach to `localhost:49152`. While the app is
blocked you can also attach Android Studio's CPU profiler.

iOS profiling is **not implemented yet**
**Go to source** support in Android studio profiler is **not implemented yet**

## What `mobile-profile` enables

| Layer            | Profile-mode change                                          |
| ---------------- | ------------------------------------------------------------ |
| DOtherSide (C++) | Built with `-DQML_DEBUG_PORT=49152` and `QT_QML_DEBUG`. `QT_QML_DEBUG` is what triggers Qt's `QQmlDebuggingEnabler` static-init via its header — without it the debug services never bind, regardless of the CLI arg. On desktop this is implicit (the `QML_DEBUG=true` make var sets `CMAKE_BUILD_TYPE=Debug` which fires the existing `$<$<CONFIG:Debug>:QT_QML_DEBUG>` generator expression). On mobile the build type is hardcoded to `Release` in `commonCmakeConfig.sh`, so the DOtherSide `CMakeLists.txt` was patched to also define `QT_QML_DEBUG` whenever `QML_DEBUG_PORT` is set. With both defined, `dos_qguiapplication_create` passes `-qmljsdebugger=port:49152,block` to `QGuiApplication`, the engine binds on TCP 49152 and blocks until a client connects. |
| Nim              | Compiled with `-d:release -d:nimTypeNames`. |
| `adb`            | `adb -s <serial> forward tcp:49152 tcp:49152` is set up by `mobile/scripts/android/run.sh`, so a host-side `qmlprofiler` can dial `localhost:49152`. |
| Android Gradle   | A dedicated `profile` build type with `debuggable=false`, `profileable=true`, and `applicationIdSuffix .debug` (so it replaces the debug install). `assembleProfile` packages `libnim_status_client.so` with debug symbols intact via per-buildtype `packaging.jniLibs.keepDebugSymbols` — release/fdroid builds strip it as before. |

The QML debug port (default `49152`) can be overridden via the
`QML_DEBUG_PORT` env var.

## Workflow

1. **Connect a device** and confirm `adb devices` lists exactly one or
   export `ANDROID_SERIAL` so the run script doesn't pause at an
   interactive prompt.

2. **Build & launch** with all the standard mobile env (Nim on PATH,
   `QMAKE` set to the Android Qt kit, `USE_SYSTEM_NIM=1`):

   ```bash
   export PATH="$(pwd)/vendor/nimbus-build-system/vendor/Nim/bin:$PATH"
   export QMAKE=~/Qt/6.11.0/android_arm64_v8a/bin/qmake
   ANDROID_SERIAL=$(adb devices | awk 'NR>1 && /device$/ {print $1; exit}') \
       make mobile-profile -j10 V=3 USE_SYSTEM_NIM=1
   ```

   When the script logs `App started with PID: …`, the app is up and
   blocked waiting for a QML client.

3. **(Optional) Attach Android Studio CPU profiler**: View → Tool Windows → Profiler
   pick the running PID → CPU. No special setup. Start the recording
   *before* releasing the QML block if you want to capture startup.

4. **Attach a QML profiler** to release the block:
   - **`qmlprofiler` CLI**:
     ```bash
     qmlprofiler -attach localhost:49152
     ```
   - **Qt Creator**: Analyze → QML Profiler → Attach to Waiting
     Application → Host `localhost`, Port `49152`. **Important: Pick the desktop kit**

   You can run the Android Studio CPU profiler and a QML profiler at the
   same time — attach Android Studio first while the app is still
   blocked, then release with the QML side.

## Switching back to a normal run

Just run any non-profile mobile target:

```bash
make mobile-run
```

Both `mobile-run` and `mobile-profile` declare a `mobile-profile-mode-check`
prerequisite that compares the desired mode to the contents of
`mobile/build/.profile-mode`. On a flip it runs `make -C mobile
clean-dotherside`, which forces DOtherSide to be rebuilt without the
QML debug listener. The Nim lib is *not* auto-cleaned — flipping back to
profile only requires DOtherSide.

If the sentinel ever gets out of sync with the actual lib state (e.g.
after a manual `rm -rf build/`), force a clean rebuild:

```bash
make -C mobile clean-dotherside
rm -f mobile/build/.profile-mode
```

## Implementation reference

The profile mode plumbing lives in:

- `Makefile` — `mobile-profile` target, `mobile-profile-mode-check`,
  sentinel at `mobile/build/.profile-mode`.
- `mobile/Makefile` — `PROFILE` and `QML_DEBUG_PORT` env passthrough to
  the build / run scripts.
- `mobile/scripts/buildNimStatusClient.sh` — gates `-d:nimTypeNames` on
  `PROFILE=1`.
- `mobile/scripts/buildDOtherSide.sh` — passes `-DQML_DEBUG_PORT=…` to
  cmake when the env var is set.
- `mobile/scripts/android/run.sh` — sets up `adb forward` when
  `QML_DEBUG_PORT` is set.
- `mobile/android/qt6/build.gradle` — `profile` build type
  (`debuggable=false`, `profileable=true`, `applicationIdSuffix=".debug"`),
  per-buildtype `packaging.jniLibs.keepDebugSymbols` for the Nim lib in
  `debug` and `profile` only.
- `mobile/scripts/buildApp.sh` — recognises `assembleProfile` so the
  output APK lands in `build/outputs/apk/profile/`.
- `vendor/DOtherSide/lib/CMakeLists.txt` — defines `QT_QML_DEBUG`
  whenever `QML_DEBUG_PORT` is set, inside the existing `if(DEFINED
  QML_DEBUG_PORT)` block. This needs to be upstreamed to DOtherSide and
  the submodule pointer bumped.

## iOS

Not implemented. The `mobile-profile` target detects the iOS Qt kit
(`mkspecs == ios`) and exits with a TODO. When iOS support lands the
plan is similar: keep `QML_DEBUG_PORT` and `QT_QML_DEBUG` plumbed
through to cmake, set up forwarding via `iproxy` instead of `adb
forward`, and ensure the iOS
build doesn't strip Nim symbols.
