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

## PR builds and the env file

`BUILD_VARIANT=pr make mobile-build` produces `app.status.mobile.pr` with `<profileable android:shell="true"/>`
(release and fdroid stay non-profileable), so heapprofd, simpleperf and Perfetto can attach to the APKs CI builds.
It does not make `/proc/<pid>/smaps` readable from the shell: that still needs a debuggable build and `run-as`.

Debug, profile and PR packages apply `KEY=VALUE` lines from `/sdcard/Android/data/<package>/files/status-env.txt`
to both processes before Qt and status-go load. Lines starting with `#` are ignored. Go runtime variables
(`GOGC`, `GOMEMLIMIT`, `GODEBUG`) have no effect: the Go runtime keeps the environment from process start.

```sh
printf 'QSG_ATLAS_WIDTH=1024\nQSG_ATLAS_HEIGHT=1024\nQSG_INFO=1\nSTATUS_RUNTIME_LOG_LEVEL=DEBUG\n' > status-env.txt
adb push status-env.txt /sdcard/Android/data/app.status.mobile.pr/files/status-env.txt
adb shell am force-stop app.status.mobile.pr   # both processes read the file on the next start
adb logcat -d | grep 'StatusApplication: env'
```

## Go pprof before login

`STATUS_PPROF=1` makes the app start status-go's `net/http/pprof` on `127.0.0.1:6060` at startup, before the
login screen; any other value is used as the address (status-go only accepts loopback addresses). Unset means off.
Release builds do not filter it at compile time: the variable has to reach the process, which on Android only
happens through the env file of debug, profile and PR packages. Any app on the same device can reach a loopback
port, so leave it unset when you are not profiling. The app logs `pprof listening` or `pprof failed to start`.

Desktop:

```sh
STATUS_PPROF=1 make run
curl -s 'localhost:6060/debug/pprof/heap?debug=1' | head
```

Android (the server runs in the `:statusgo` process):

```sh
echo 'STATUS_PPROF=1' >> status-env.txt   # push and force-stop as above
adb forward tcp:6060 tcp:6060
curl -s 'localhost:6060/debug/pprof/heap?debug=1' | head
```

iOS simulator (shares the Mac's loopback):

```sh
SIMCTL_CHILD_STATUS_PPROF=1 xcrun simctl launch booted app.status.mobile
curl -s 'localhost:6060/debug/pprof/heap?debug=1' | head
```

iOS device (`iproxy` comes with libimobiledevice; use another host port if 6060 is taken):

```sh
xcrun devicectl device process launch --terminate-existing --device <udid> \
  --environment-variables '{"STATUS_PPROF":"1"}' app.status.mobile
iproxy 6060:6060 &
curl -s 'localhost:6060/debug/pprof/heap?debug=1' | head
```

## QML object and compilation-unit inventory

`STATUS_QML_INVENTORY` makes StatusQ record every `QObject` created after it loads (through Qt's `qtHookData`
add/remove hooks) and write snapshots of what is alive. The value is the delay in seconds after start, or a comma
separated list for several snapshots (`30,120`). Unset means off: no hook, no timer.

Each snapshot is written to `qml-inventory-<yyyyMMdd-HHmmss>-<n>.json` (`n` is the snapshot's position in the list)
and a top-20 summary is logged under `status.qmlInventory`. It holds:

- `objects`: live objects grouped by type (QML type name, or C++ class name), `creationFile` (the QML file that
  declares the object; objects a QML object creates from C++, like attached objects, take their nearest ancestor's)
  and `owningFile` (the file that instantiated the document `creationFile` belongs to: the user of a component, or
  the creation context of a `Loader`/`Repeater`/`createObject` delegate). An instance of `Foo.qml` used in `Bar.qml`
  counts as type `Foo` declared in `Bar.qml`; the objects inside `Foo.qml` count as declared in `Foo.qml` and owned
  by `Bar.qml`. `parentless` counts objects without a `QObject` parent (JS-owned objects, singletons, models).
  Objects living on other threads only count under `<other thread>`.
- `compilationUnits`: the units loaded by every live engine, by URL, with `unitBytes` (the compiled unit data;
  `unitOnHeap` is false when it is mapped from the binary or a `.qmlc` file rather than allocated),
  `runtimeBytes` (the per-engine tables allocated when the unit is linked: string, regexp, class, block and
  template object pointers, lookups and `QV4::Function` objects; the JS heap objects they point to are not counted),
  `propertyCaches` and `liveObjects` (objects declared in the file plus instances of it). `liveObjects: 0` marks a
  unit that is loaded but has nothing alive.

The tool's own bookkeeping (a set of every live object pointer) inflates PSS slightly while it is enabled.
A hook installed later (e.g. GammaRay) must chain `RemoveQObject`, or the inventory reads dangling pointers.
While a snapshot walks the objects, other threads block when they create or delete a `QObject`.

Desktop (written to the data dir, `./Status/` at the repo root for dev builds):

```sh
STATUS_QML_INVENTORY=60 make run
```

Android (written to the app's external files dir):

```sh
echo 'STATUS_QML_INVENTORY=30,120' >> status-env.txt   # push and force-stop as above
adb logcat -d | grep status.qmlInventory
adb pull /sdcard/Android/data/app.status.mobile.pr/files/ inventory/
```

Compare two dumps (deltas per type, per owning file, per group and per unit, by absolute size) or list the top
entries of one:

```sh
scripts/qml_inventory_diff.py before.json after.json
scripts/qml_inventory_diff.py dump.json
```
