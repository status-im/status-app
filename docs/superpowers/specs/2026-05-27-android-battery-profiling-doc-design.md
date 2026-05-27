# Android Battery Profiling Doc — Design Spec

- **Date:** 2026-05-27
- **Status:** Approved (design)
- **Output:** `docs/mobile-battery-profiling.md`

## Goal

A terse, command-first cookbook for profiling the Status **Android** app's battery
impact. Three independent toolchains, each its own chapter: status-go pprof, the QML
profiler, and Android/Pixel platform data. Minimal prose — essential commands, the exact
code changes needed to enable each tool, and the gotchas that waste time.

## Scope & non-goals

- **In scope:** Android only. Re-applyable patches for the two tools whose enablement is
  not committed (pprof, QML profiler). Copy-pasteable commands for capture and analysis.
- **Non-goals:** iOS profiling. Interpreting specific traces. Tuning fixes. A tutorial on
  pprof/Perfetto internals — link out, don't re-explain.
- **Audience:** a Status dev who has already built the mobile app once (knows the
  `PATH` / `QMAKE` / `USE_SYSTEM_NIM=1` env from `CLAUDE.md` and `mobile/DEV_SETUP.md`).

## Current-state facts the doc must encode

Two of the three tools are **not enabled in the committed tree** — the doc carries the
patches to re-apply, it does not assume they exist:

1. **pprof** lives only in `git stash` on the status-go submodule (the `StartPprof`/
   `StopPprof` runtime API). The doc reproduces the patch.
2. **QML profiler**: the DOtherSide side is committed
   (`vendor/DOtherSide/lib/CMakeLists.txt:47-51` defines `QML_DEBUG_PORT`;
   `DOtherSide.cpp:216-218` injects `-qmljsdebugger=port:N,block`), but the **mobile build
   plumbing** that forwards `QML_DEBUG_PORT` into that build is missing. The doc carries
   that small patch.
3. **Platform data** needs no code change — Perfetto/`dumpsys`/`/proc` work on a stock build.

The pprof C binding does **not** need a manual edit: the Android library build runs
`go run ./tools/generate-cbindings`, which scans exported `mobile` package funcs and
regenerates `build/bin/statusgo-lib/main.go`. Adding `StartPprof`/`StopPprof` to
`mobile/status.go` is enough to export the C symbol.

---

## Chapter 1 — status-go pprof (Go-side CPU / heap / goroutines)

Profiles the `:statusgo` service process — where Waku, messaging, and mvds run, i.e. the
process that actually burns background battery.

### Patch A — status-go (`vendor/status-go/`)

`mobile/status.go`, after `resumeServices` (~line 905):

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

> Note vs. the stash: the stash's goroutine omits `defer common.LogOnPanic()`. Keep it —
> it's a CI hard-failure and free insurance.

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

## Chapter 2 — QML profiler (UI-process CPU)

Profiles the QML/JS engine in the UI process. CPU there is a proxy for UI-side battery
(bindings, timers, animations, model churn).

### Patch C — forward `QML_DEBUG_PORT` into the mobile DOtherSide build

The CMake/cpp consumer is already committed; only the build wiring is missing.

`mobile/scripts/buildDOtherSide.sh` — pass the define through to CMake when set, e.g. add
to the `cmake` invocation:

```bash
${QML_DEBUG_PORT:+-DQML_DEBUG_PORT=$QML_DEBUG_PORT}
```

`mobile/Makefile` (DOtherSide recipe, ~line 87) — forward the var into the script env
prefix if it does not already reach the script via environment inheritance:

```make
@DOTHERSIDE=$(DOTHERSIDE) QT_MAJOR=$(QT_MAJOR) LIB_SUFFIX=$(LIB_SUFFIX) \
  LIB_EXT=$(LIB_EXT) QML_DEBUG_PORT=$(QML_DEBUG_PORT) $(DOTHERSIDE_SCRIPT) $(HANDLE_OUTPUT)
```

> `QML_DEBUG_PORT` set on the `make mobile-run` command line propagates to recipe
> environments, so the script may already see it — verify empirically and keep the
> Makefile edit only if needed.

### Build & run

The `QML_DEBUG_PORT` define is compiled in and CMake caches it, so wipe the DOtherSide
build artifacts before toggling:

```bash
rm -rf vendor/DOtherSide/build/android
rm -f mobile/lib/android/qt6/libDOtherSide*.so

export ANDROID_SERIAL=<device-serial>   # skips run.sh device picker
QML_DEBUG=true QML_DEBUG_PORT=49152 make mobile-run -j10 V=3 USE_SYSTEM_NIM=1
```

App blocks at the splash; logcat shows
`QML Debugger: Waiting for connection on port 49152...`.

### Attach (host)

```bash
adb -s "$ANDROID_SERIAL" forward tcp:49152 tcp:49152
<qt>/bin/qmlprofiler --attach 127.0.0.1 --port 49152 --output ~/trace.qzfd
# engine resumes on attach; type `quit` to write the trace
```

Open in Qt Creator → Analyze → Load QML Trace.

### Troubleshoot

- Attach fails / no data: confirm the debug plugins shipped in the APK —
  `unzip -l mobile/bin/android/qt6/Status.apk | grep qmldbg`. If `libqmldbg_*.so` are
  missing, add `ANDROID_EXTRA_PLUGINS += $$[QT_INSTALL_QML]/qmldbg` (env-gated) to
  `mobile/wrapperApp/Status.pro`.

---

## Chapter 3 — Platform data (whole-device & per-process)

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

## Gotchas footer (collect at end of doc)

- **status-go logs don't reach logcat** (separate process, no JNI log pump). Use pprof
  goroutine dumps or the Java-side `bgFilter:` logs instead.
- **`batterystats --checkin` per-UID `pwi` (modeled mAh)** is often 0 / unreliable for
  short windows. Trust measured `current_now` and `/proc/<pid>/stat` over modeled mAh.
- **Forwards must be re-issued on the wifi serial** after switching to wireless ADB.
```
