# Android Battery Profiling

Three independent tools, one per chapter. Each chapter is self-contained: the patches
it requires, the commands to build with those patches applied, and the commands to
capture and inspect data. Read only the chapter you need.


**Tools covered:**

| Chapter | Tool                | Measures                                |
|---------|---------------------|-----------------------------------------|
| 1       | status-go pprof     | Go-side CPU, heap, goroutines (`:statusgo` process) |
| 2       | QML profiler        | UI-process QML/JS engine CPU            |
| 3       | Perfetto + Android  | Whole-device & per-process battery/CPU  |

The pprof and QML profiler enablements are **not committed** — each chapter carries
the patches you re-apply locally.

---

## 1. status-go pprof

Profiles the `:statusgo` service process — where Waku, messaging, and mvds run, i.e. the
most likely process to burn background battery.

### Patch A — status-go. Enabling pprof

`mobile/status.go`, after the `resumeServices` function:

```go
// StartPprof starts a pprof HTTP server on addr (e.g. "127.0.0.1:6060").
func StartPprof(addr string) string { return callWithResponse(startPprof, addr) }
func startPprof(addr string) string { return makeJSONResponse(statusBackend.StartPprof(addr)) }

// StopPprof shuts down the pprof server started by StartPprof.
func StopPprof() string { return callWithResponse(stopPprof) }
func stopPprof() string { return makeJSONResponse(statusBackend.StopPprof()) }
```

`pkg/backend/geth_backend.go`:
- import `pprof "net/http/pprof"` (and `common` for `LogOnPanic`, if not already imported)
- add field `pprofServer *http.Server` to `StatusBackend`
- add methods:

```go
func (b *StatusBackend) StartPprof(addr string) error {
    b.mu.Lock(); defer b.mu.Unlock()
    if b.pprofServer != nil { _ = b.pprofServer.Close() }
    mux := http.NewServeMux()
    mux.HandleFunc("/debug/pprof/", pprof.Index)
    mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
    mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
    mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
    mux.HandleFunc("/debug/pprof/trace", pprof.Trace)
    b.pprofServer = &http.Server{Addr: addr, Handler: mux}
    go func() {
        defer common.LogOnPanic() // required: CI hard-fails goroutines without it
        if err := b.pprofServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            b.logger.Error("pprof server error", zap.Error(err))
        }
    }()
    b.logger.Info("pprof server started", zap.String("addr", addr))
    return nil
}

func (b *StatusBackend) StopPprof() error {
    b.mu.Lock(); defer b.mu.Unlock()
    if b.pprofServer == nil { return nil }
    err := b.pprofServer.Close(); b.pprofServer = nil
    return err
}
```

### Patch B — trigger (`mobile/android/qt6/src/app/status/mobile/ipc/StatusGoService.java`)

Auto-start, flag-gated, once. `nativeCall` already runs inside the `:statusgo` process, so
no Nim wiring is needed. In `scheduleBackendLifecycleUpdate(...)`, right after
`if (namesJson == null) return;` (the point where the node is confirmed up):

```java
if (PPROF && pprofStarted.compareAndSet(false, true)) {
    nativeCall("StartPprof", "[\"127.0.0.1:6060\"]");
}
```

With class-level declarations:

```java
private static final boolean PPROF = false; // flip to true to profile, rebuild
private final java.util.concurrent.atomic.AtomicBoolean pprofStarted =
        new java.util.concurrent.atomic.AtomicBoolean(false);
```

### Build

Usual mobile build (see `CLAUDE.md` for the full env):

```bash
make mobile-run -j10 V=3 USE_SYSTEM_NIM=1
```

### Inspect (host)

```bash
adb forward tcp:6060 tcp:6060
# 60s CPU profile in an interactive web UI
go tool pprof -http=:8000 http://127.0.0.1:6060/debug/pprof/profile?seconds=60
# goroutine dump (find leaks / stuck loops)
curl 'http://127.0.0.1:6060/debug/pprof/goroutine?debug=2'
# heap
go tool pprof -http=:8000 http://127.0.0.1:6060/debug/pprof/heap
# fastest subsystem attribution
go tool pprof -text -focus='<pkg>' -cum <profile>
```

- `allocs` is **cumulative since process start** — snapshot at the start and end of the
  window and diff for window-only allocations.

---

## 2. QML profiler + Android Studio CPU

`make mobile-profile` builds a profile-mode APK that **blocks at QML engine creation**
on `localhost:49152`, with `profileable=true` so Android Studio's CPU profiler can
attach. The profile APK installs over the `mobile-run` debug install (same package id —
one Status flavor stays on the device).

Added to master in [`beb8fefc2d`](https://github.com/status-im/status-app/commit/beb8fefc2d132312b5a74afc90f70e20372869d3) — cherry-pick onto a branch that doesn't have it.

| Layer      | What `mobile-profile` enables                                       |
|------------|---------------------------------------------------------------------|
| DOtherSide | Engine binds + blocks on `QML_DEBUG_PORT` (default `49152`).        |
| Nim        | `-d:release -d:nimTypeNames` — Android Studio resolves Nim frames.  |
| adb        | `adb forward tcp:$PORT tcp:$PORT` set up automatically.             |
| Gradle     | `profile` build type: `debuggable=false`, `profileable=true`.       |

### Build & run

```bash
export ANDROID_SERIAL=<device-serial>   # skips run.sh device picker
make mobile-profile -j10 V=3 USE_SYSTEM_NIM=1
# override port: QML_DEBUG_PORT=NNNN make mobile-profile
```

App blocks at QML engine creation; logcat shows `App started with PID: …`.
Flipping between `mobile-run` and `mobile-profile` auto-rebuilds DOtherSide.

### Attach Android Studio CPU profiler (native + Nim frames)

View → Tool Windows → Profiler → pick the PID → CPU. **Start recording before
releasing the QML block** to capture startup. Nim frames resolve because the
`profile` gradle config keeps `libnim_status_client.so`'s debug symbols.

### Attach the QML profiler (releases the block)

CLI:

```bash
qmlprofiler -attach localhost:49152
```

Qt Creator: Analyze → QML Profiler → Attach to Waiting Application →
`localhost:49152` → **pick the desktop Qt kit**. Type `quit` at the qmlprofiler
prompt to write the trace.

You can run both profilers concurrently — attach Android Studio first while the
app is still blocked, then release with the QML side.

## 3. Platform data

Stock build — no code change. Two pids matter: `pidof app.status.mobile.debug` (UI) and
`pidof app.status.mobile.debug:statusgo` (the process that keeps working backgrounded,
`oom_score_adj=200`, not Doze-throttled).

### Background-state setup

```bash
adb shell input keyevent KEYCODE_POWER          # screen off
adb shell dumpsys deviceidle force-idle          # immediate Doze (`unforce` to release)
adb shell dumpsys batterystats --reset
```

On a desk the device may only reach Light Doze (`deep state: INACTIVE`); leaving it
genuinely idle reaches `deep state: IDLE`.

### Per-process CPU (no rebuild)

```bash
adb shell cat /proc/$(adb shell pidof app.status.mobile.debug:statusgo)/stat
```

Fields 14 (utime) + 15 (stime) are in clock ticks; `CLK_TCK=100`, so `ticks/100` =
CPU-seconds. Sample at window start/end and diff.

### Real battery current (mA)

`current_now` only reports real discharge when the device is **physically unplugged**;
`dumpsys battery unplug` only flips OS state (engages Doze) — it does **not** stop the
charger IC.

```bash
adb tcpip 5555; adb connect <wlan-ip>:5555    # wireless ADB, then physically unplug
adb -s <wlan-ip>:5555 forward tcp:6060 tcp:6060   # re-issue forwards on the wifi serial
adb shell 'while true; do dumpsys battery | grep "current now:"; sleep 5; done'  # avg 5 min
```

`adbd` over wifi adds ~2–5 mW noise — ignore for ratio comparisons.

### Perfetto (best tool, no rebuild)

Built into recent Android (`/system/bin/perfetto`). Record on-device, then pull:

```bash
adb shell perfetto --txt -c - -o /data/misc/perfetto-traces/t.pt < config.pbtxt
adb pull /data/misc/perfetto-traces/t.pt
```

`config.pbtxt` data sources (set `duration_ms` — no PTY means no Ctrl-C):
- `linux.ftrace`: `sched/sched_switch`, `sched/sched_waking`, `power/cpu_idle`,
  `power/cpu_frequency`, `power/suspend_resume`, `compact_sched{enabled:true}`
- `linux.process_stats`: `scan_all_processes_on_start:true proc_stats_poll_ms:1000`
- `linux.sys_stats`: `stat_period_ms:1000 stat_counters:STAT_CPU_TIMES cpufreq_period_ms:1000`
- `android.power`: `battery_poll_ms:1000` + `BATTERY_COUNTER_CHARGE/CURRENT/CAPACITY_PERCENT`

Analyze with the prebuilt host CLI (**one SELECT per `-q` file** — loop for multiple):

```bash
curl -LO https://get.perfetto.dev/trace_processor && chmod +x trace_processor
./trace_processor t.pt -q q.sql
```

Useful queries: per-process on-CPU time & schedule count
(`sched_slice JOIN thread USING(utid) JOIN process USING(upid)`, exclude `pid=0` idle
task); per-thread schedule-count buckets (steady-loop vs bursty); `batt.*`/`cpufreq`/
`cpuidle` from `counter JOIN counter_track`; wakeup attribution via
`thread_state.waker_utid`. Or drag the `.pt` into `ui.perfetto.dev`.

Derive discharge from the **coulomb counter**, not modeled mA:
`Δbatt.charge_uah / Δt` (e.g. 4132 µAh over 59.2 s ≈ 251 mA).

### Device floor (attribution baseline)

```bash
adb shell am force-stop app.status.mobile.debug
```

Measure the floor with Status killed; subtract to attribute draw. (S21 FE floor was
~136 mA — most idle draw is modem/OS, not Status.)

### Pixel-6+ note — ODPM power rails

On Pixel 6 and newer, add to the `android.power` source:
`collect_power_rails:true`. This yields per-rail mW (CPU clusters, modem, display, etc.) —
the cleanest attribution available. **Samsung (incl. S21 FE) does not expose ODPM/power
rails**; only `batt.charge_uah` / `batt.current_ua` / `batt.capacity_pct` appear, and
`batt.current_ua` is **mis-scaled on Samsung** (ignore it — use the coulomb counter).

---

## Gotchas

- **status-go logs don't reach logcat** (separate process, no JNI log pump). Use pprof
  goroutine dumps or the Java-side `bgFilter:` logs instead.
- **`batterystats --checkin` per-UID `pwi` (modeled mAh)** is often 0 / unreliable for
  short windows. Trust measured `current_now` and `/proc/<pid>/stat` over modeled mAh.
- **Forwards must be re-issued on the wifi serial** after switching to wireless ADB
  (the USB-serial forwards do not carry over).
- **QML profiler does't attach** make sure to select and use the desktop qt 6.11 for the profiler
- **There no make mobile-profile**: In this case you're probably profiling on the release branch. Cherry-pick this commit https://github.com/status-im/status-app/commit/beb8fefc2d132312b5a74afc90f70e20372869d3
