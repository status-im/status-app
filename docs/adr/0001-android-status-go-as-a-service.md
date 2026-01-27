# ADR-0001: Android "status-go as a Service" (separate process + Binder IPC)

## Status
- **Proposed**
- **Date**: 2026-01-16
- **Owners**: Status Desktop (Android target)

## Why

We need:

- A backend that survives UI process death (swipe-away, memory pressure).
- Decrypted notifications when UI is not running.
- Push notifications for de-googled phones (no firebase dependency).
- A design that matches Android’s process model and OEM restrictions.

Historically, `status-go` ran in the UI process; killing the UI killed messaging and decryption. This ADR documents the separate-process service architecture now implemented.

## How (implementation)

### Transport and contract

- **IPC:** Binder (AIDL).
- **RPC shape:** `call(method, argsJson)` and `callToFile(...)` for large payloads.
- **Signals:** service emits JSON to UI via `RemoteCallbackList` + `IStatusGoSignalListener`.
- **Login state:** UI uses `status_account.getActiveAccount()` over the service RPC path as the authoritative check for resume vs onboarding. 

### Process split

- **Service process:** Android `Service` in its own process, loads `libstatus_service.so` which links real `libstatus.so`.
- **UI process:** links a stub library implementing the C API; stub forwards all calls to the service via Binder and re-injects signals into the existing pipeline.

### Compilation and running

- The UI process links the **stub** library and starts/binds the service early (Activity startup).
- The service process loads **real** `libstatus.so` via the JNI wrapper and handles all status-go calls.
- The AIDL surface is intentionally minimal to avoid churn.

### Lifetime behavior and mitigations

- Service starts **foreground immediately** to avoid `ForegroundServiceDidNotStartInTime`.
- Uses `START_STICKY` so the OS can restart it.
- On logout, clears session markers and stops itself.
- `DeadObjectException` is handled in the client with a rebind and single retry.
- Resume marker file exists for telemetry only and is deleted on service start; it must not be used for resume gating.

## What was considered (transport options)

- **Binder (AIDL)**: chosen. Low latency, lifecycle-aware, Android-native.
- **Local TCP/Unix + JSON-RPC**: more security hardening and weaker lifecycle integration.
- **Typed AIDL per method**: too much churn as status-go evolves.
- **gRPC/protobuf IPC**: heavier stack without solving Android lifecycle constraints.

## What next

- **Lower battery impact:** add a true sleep mode in status-go (suspend Waku), with wake on app open or push.
- **Transport replaceability:** keep the generic call/args shape as a stable boundary so Binder could be swapped for another IPC later with minimal churn.

## References (code)

- Service process: [mobile/android/qt6/src/app/status/mobile/ipc/StatusGoService.java](https://github.com/status-im/status-app/blob/master/mobile/android/qt6/src/app/status/mobile/ipc/StatusGoService.java)
- AIDL: [mobile/android/qt6/aidl/app/status/mobile/ipc/IStatusGoService.aidl](https://github.com/status-im/status-app/blob/master/mobile/android/qt6/aidl/app/status/mobile/ipc/IStatusGoService.aidl)
- UI client + stub: [mobile/android/qt6/src/app/status/mobile/ipc/StatusGoServiceClient.java](https://github.com/status-im/status-app/blob/master/mobile/android/qt6/src/app/status/mobile/ipc/StatusGoServiceClient.java),
                  [mobile/android/qt6/src/app/status/mobile/StatusGoStub.java](https://github.com/status-im/status-app/blob/master/mobile/android/qt6/src/app/status/mobile/StatusGoStub.java)
- Resume gating: [src/app/modules/onboarding/module.nim](https://github.com/status-im/status-app/blob/master/src/app/modules/onboarding/module.nim), [src/app/boot/app_controller.nim](https://github.com/status-im/status-app/blob/master/src/app/boot/app_controller.nim)
- Stub generator: [vendor/status-go/tools/generate-stub-bindings](https://github.com/status-im/status-app/blob/master/vendor/status-go/tools/generate-stub-bindings)

### Data/control flow (signals)

1. status-go emits a JSON signal in the service process.
2. JNI calls back into `StatusGoService.onNativeSignal(json)`.
3. Service broadcasts to registered `IStatusGoSignalListener` clients.
4. UI client forwards into native `StatusGoStub.nativeDeliverSignal(json)` so existing signal pipelines keep working.

### Login state detection (“should we show onboarding or AppMain?”)

Goal: avoid file-based heuristics and decide based on the **live** service state.

- UI startup performs a short poll loop before loading `main.qml`:
  - if a keyUid is returned and matches a local account, UI resumes into AppMain.
  - else UI proceeds to onboarding.

Key design constraint:

- **Never claim “logged in” after OS-kill** when the service process was actually terminated.
  - Keys are in memory; if the process died, they are gone.
  - Therefore the service must not “restore logged-in” from a stale file marker.

## Service lifetime design

Android lifetime is not a single mode; this proposal outlines multiple modes depending on user settings and device capabilities.

### Mode A: Foreground “keepalive” while logged in (status-mobile style)

**When**: user enables messenger notifications / wants background message processing.

**How**:

- Service promotes itself to a foreground service *only while logged in*.
- Foreground notification indicates “Status is running”.
- Use `START_STICKY` so system can restart the service process if needed.

**Pros**
- Best reliability across OEMs.
- Allows local decrypted notifications without push round-trips.
- UI process can die and be restarted; service stays alive.

**Cons**
- Always-on notification (acceptable by product decision, but not ideal UX for all users).
- Power usage can be non-trivial if Waku stays connected.

### Mode B: “Push-driven / on-demand” service (sleep until wake)

**When**: user disables background messaging or wants reduced resource usage; also useful for “push enabled” devices.

**How (conceptual)**:

- Keep the service process **not running** most of the time (or running but “suspended”).
- Wake it only when needed:
  - app is opened, or
  - a push notification arrives (GMS/FCM path).

**Two implementation variants**

1) **Hard sleep (process not running)**
   - Don’t run the service until needed.
   - On push: start service, run minimal work, stop service.
   - **Constraint**: cannot keep keys unlocked across kills → this only supports “wake for sync” if keys can be unlocked.

2) **Soft sleep (process alive but networking suspended)**
   - Service remains alive (likely still foreground or exempted), but Waku/network subsystems are paused.
   - On push/app-open: resume networking and process.
   - Requires explicit status-go API support:
     - e.g. `wakuext_suspend()` / `wakuext_resume()` or a high-level “messenger sleep” toggle.

**Pros**
- Reduced battery/network usage vs always-connected Waku.
- Can be aligned with “push as wakeup” concept - similar to Signal.

**Cons / risks**
- Android push delivery is not guaranteed (Doze, OEM restrictions, network).
- FCM data messages may be delayed or dropped when app is background restricted.
- For encrypted pushes: decryption still needs keys; if process was killed, you are effectively logged out for background work.

### Mode C: Hybrid (recommended long-term)

- Use Mode A for users who enable background messaging (most reliable).
- Consider Mode B (soft sleep) as an optimization knob:
  - keep service alive (foreground) but pause Waku when idle,
  - wake on push or periodic lightweight alarms.

## App resilience

### Scenario matrix

| Scenario | UI process | Service process | Expected UX |
|---|---:|---:|---|
| User closes window / swipe away Recents (service is foreground) | killed | alive | Next open: **resume to AppMain** (no login) |
| UI process killed by OS (service alive) | killed | alive | Next open: **resume to AppMain** |
| OS kills service process (memory pressure / user force-stop) | any | killed | Next open: **onboarding** (must re-auth) |
| App update/reinstall leads to stale Binder | restarted | restarted | Client must detect `DeadObjectException`, reconnect and retry once |

### Lifetime & failure analysis (detailed)

This section describes what happens for key lifecycle/failure events and how the design should behave.

#### UI crash (Qt/Nim/QML process crash)

- **What happens**
  - UI process terminates (SIGABRT/SIGSEGV/uncaught exception).
  - Binder callbacks to UI will fail; the service removes dead binder clients.
- **Expected behavior**
  - **Service keeps running** (when foreground keepalive is enabled / policy keeps it alive).
  - Messages can continue syncing; local-notifications can still be produced by the service.
  - On next app open, UI should **query ``status_account.getActiveAccount()``** and resume if the service is logged in.
- **Mitigations**
  - `RemoteCallbackList` on the service side to clean up dead callbacks.
  - UI binder client reconnects on restart (and retries once on `DeadObjectException`).

#### Service crash (Java Service process crash)

Examples: `StatusGoService` throws, process hits ANR, or the OS kills the service due to a crash.

- **What happens**
  - UI binder calls fail with `DeadObjectException`.
  - Any in-memory keys/session state are lost with the process.
- **Expected behavior**
  - UI resets binder connection, rebinds, and retries once.
  - If the service comes back but is **not logged in**, UI falls back to onboarding.
  - UI must not auto-resume from any stale marker; “logged-in” is authoritative only when returned by the live service.
- **Mitigations**
  - Reconnect+retry once on `DeadObjectException` (client-side).
  - Optional future: a “service ready” signal/handshake so UI does not call feature RPCs before status-go is initialized.

#### status-go crash (native crash inside the service process)

This is a special case of service crash where the crash occurs in `libstatus.so` (JNI/native).

- **What happens**
  - The service process dies (tombstone / fatal signal).
  - On restart, the service process is “fresh” and **not logged in** (keys lost).
- **Expected behavior**
  - UI treats this as “service not logged in” and shows onboarding.
  - If configured `START_STICKY`, Android may restart the service, but it still won’t have unlocked keys.
- **Mitigations**
  - Optional: telemetry and a UI-visible “backend crashed” banner when this happens while UI is active.
  - Optional: explicit version/handshake checks so UI can detect a “fresh” backend.

#### App reinstall / update

We distinguish two common cases:

1) **Update install (same package, data typically preserved)**
   - **What happens**
     - UI process and service process may be restarted during update.
     - Existing Binder handles can become stale → `DeadObjectException`.
   - **Expected behavior**
     - UI reconnects/retries once.
     - If the service process was restarted, it is not logged in; UI should show onboarding.
     - If the service survived (rare during update), UI can resume if `status_account.getActiveAccount()` returns a non-empty account.
   - **Mitigations**
     - Keep reconnection logic in the client.

2) **Uninstall + install (fresh install)**
   - **What happens**
     - Android removes the app package and kills all its processes.
     - App-private data directory is removed; the service cannot persist.
   - **Expected behavior**
     - Fresh install behaves as logged-out; onboarding shown.
   - **Mitigations**
     - None required; this is expected platform behavior.

#### App uninstall

- **What happens**
  - Android kills UI + service processes.
  - All app private storage is removed.
- **Expected behavior**
  - No background work remains; no notifications from the app after uninstall.
- **Mitigations**
  - None; ensure no exported components allow external restarts after uninstall (standard Android packaging).

### Why “logged-in” must be an in-memory fact

If the service process is not alive, *there is no unlocked key material*. Any persistent marker would be misleading and can cause:

- UI “auto-resume” into logged-in flows,
- immediate backend RPC failures,
- unstable teardown (crashes) due to inconsistent state.

Therefore:

- The canonical “logged-in” state is the live service’s in-memory keyUid.
- Persistence markers are allowed only as debugging/telemetry, not as a resume authority.

## Push notifications approach

### Current baseline (status-mobile style)

- Android chat notifications are primarily delivered via **status-go local-notifications** while the service is running.
- Remote “generic chat push” is avoided to prevent duplicates and low-quality content.

### Proposed evolution: push as a wake-up signal

This ADR supports a roadmap where FCM acts as a wake signal when enabled.

#### Option 1: Wake service and resume Waku (no payload decryption in push handler)

- Push arrives (data message).
- Start service (if not running) or signal it (if running).
- Service wakes Waku and lets the normal message sync deliver messages.
- status-go generates decrypted local-notifications as messages arrive.

**Pros**
- Minimal cryptographic surface in the push handler.
- Avoids needing to decrypt message payload directly from push.

**Cons**
- Requires Waku to sync quickly after wake; might still be delayed by background constraints.

#### Option 2: Decrypt push payload directly (advanced)

- Push payload includes encrypted message preview.
- Service decrypts immediately and posts a local notification without waiting for Waku.

**Pros**
- Faster perceived notifications.

**Cons**
- Key availability constraints remain (service must be alive + unlocked keys).
- Higher complexity and security review surface.

### Non-GMS devices fallback

For non-GMS builds/devices, a push-driven model is not reliable. The fallback is:

- foreground keepalive (Mode A), or
- periodic background work via WorkManager/AlarmManager (best-effort), understanding delivery limits.

## IPC / bindings analysis

### Proposed approach: Binder (AIDL) + “C API stub”

**What we would do**

- Keep the existing Nim ↔ C API boundary stable: Nim calls a C ABI “status-go” API.
- Replace the implementation behind those symbols in the UI process with a stub that forwards to the service.
- Use Android-native IPC (Binder + AIDL) for robustness and performance.

**Why this is a good fit (for Android)**

- Low latency IPC, lifecycle-aware, well-supported by Android tooling.
- Easy to build “signals” using `RemoteCallbackList`.
- AIDL gives a typed interface and a stable contract surface.

**Costs**

- Two binaries/processes to reason about.
- Any new status-go API surface must be exposed through:
  - stub symbol, Java bridge, AIDL method (or generic `call`), service implementation.
- More complex debugging (two PIDs, logcat filtering).

### Alternatives considered

#### 1) In-process status-go (no IPC)

**Pros**
- Simplest integration surface.
- No IPC glue.

**Cons**
- Cannot survive UI process death.
- Decrypted notifications become unreliable.
- Hard to make resilient to Android lifecycle.

Considered but not recommended for Android given the resilience requirements.

#### 2) Local TCP/Unix socket + JSON-RPC

**Pros**
- Cross-platform story (same IPC on desktop/mobile).
- Can reuse existing JSON-RPC patterns.

**Cons**
- More security hardening required (authn, binding to loopback, file permissions).
- Harder lifecycle integration vs Binder.
- Performance overhead and more error-prone in Android background conditions.

Considered; not recommended as the primary Android path due to lifecycle/security/perf trade-offs vs Binder.

#### 3) AIDL with typed methods for every status-go call

**Pros**
- Fully typed contract; compile-time safety.

**Cons**
- Large API surface; heavy maintenance as status-go evolves.
- Code generation churn.

We propose keeping a **generic `call(method, argsJson)`** RPC shape to contain churn.

#### 4) gRPC / protobuf IPC

**Pros**
- Strongly typed; tooling ecosystem.

**Cons**
- Significant additional stack; lifecycle and background constraints unchanged.
- More complexity than needed for in-device IPC.

Considered; likely too heavy for on-device IPC in this context.

### Code generation strategy

The current approach minimizes codegen:

- AIDL generates `IStatusGoService` and `IStatusGoSignalListener`.
- The C ABI stub bindings are generated from `libstatus.h` (exported C API) by `vendor/status-go/tools/generate-stub-bindings`.
  - Outputs are written to `vendor/status-go/build/bin/` and consumed by the mobile build.
- Everything else stays “generic method + json args”.

If stronger typing becomes valuable later, we could add **a thin typed facade** on top of the generic call without changing the underlying transport.

## Operational notes / maintenance burden

### What this adds to day-to-day development

- Two-process debugging:
  - UI PID and service PID.
  - Need to filter logs per PID when diagnosing startup/resume.
- Binder failure modes:
  - `DeadObjectException` must be handled with reconnect + retry.
  - Service version mismatch risks after upgrades.
- Build complexity:
  - Separate JNI wrapper library (`status_service`) and stub library in the UI process.

### Mitigations

- Keep the AIDL surface minimal:
  - `call/callToFile`, `registerSignalListener`.
- Use a single “gateway” for RPC errors and reconnect behavior:
  - `StatusGoServiceClient.call()` retries once on `DeadObjectException`.
- Keep “login state” checks authoritative and cheap:
  - ``status_account.getActiveAccount()`` used during startup gating.

## Consequences

### Positive

- UI can restart without losing the backend session (when service is alive).
- Enables decrypted notifications via status-go local notifications pipeline.
- Allows explicit lifetime policies (foreground keepalive vs on-demand).

### Negative / trade-offs

- Additional code and maintenance surface (service, IPC, stub).
- “Always-on” notification required for the most reliable background mode.
- If OS kills the service process, the user must re-authenticate (expected, secure behavior).

## Follow-ups / roadmap

### Near-term hardening

- Add structured telemetry for:
  - service start reasons (app open vs push)
  - time-to-ready
  - reconnect/retry counts

### Sleep / wake work (if desired)

- Define status-go API for suspend/resume of Waku/messenger (soft sleep).
- Tie sleep policy to:
  - notifications enabled
  - device doze state
  - network type / battery saver
- Implement “push wake” integration that triggers resume without decrypting push payload initially.

