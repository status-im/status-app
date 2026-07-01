# Mobile profiling (Android)

`make mobile-profile` builds and launches a profile-mode Android APK that
**blocks at QML engine creation** waiting for a profiler/debugger on
`localhost:49152`. The profile APK installs over the `mobile-run` debug
install (same package id), so a single Status flavor stays on the device.

iOS profiling and Android Studio "Go to source" are not implemented yet.

## What it enables

| Layer      | Change                                                              |
| ---------- | ------------------------------------------------------------------- |
| Qt engine  | Engine binds + blocks on `QML_DEBUG_PORT` (default `49152`).        |
| Nim        | `-d:release -d:nimTypeNames` (so Android Studio resolves Nim frames). |
| adb        | `adb forward tcp:$PORT tcp:$PORT` set up automatically.             |
| Gradle     | `profile` build type: `debuggable=false`, `profileable=true`.       |

Override the port with `QML_DEBUG_PORT=NNNN make mobile-profile`.

## Workflow

1. Connect a device (or set `ANDROID_SERIAL`).
2. Run `make mobile-profile` (same env as `make mobile-run`). When you
   see `App started with PID: …`, the app is blocked waiting for a QML
   client.
3. *(Optional)* Attach Android Studio CPU profiler: View → Tool Windows →
   Profiler → pick the PID → CPU. Start recording **before** releasing
   the QML block to capture startup.
4. Attach a QML profiler to release the block:
   - CLI: `qmlprofiler -attach localhost:49152`
   - Qt Creator: Analyze → QML Profiler → Attach to Waiting Application
     → `localhost:49152`. **Pick the desktop kit.**

You can run both profilers concurrently — attach Android Studio first
while the app is still blocked, then release with the QML side.

To switch back to a normal run, just `make mobile-run`.
