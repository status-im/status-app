---
id: 0008
title: status.nims app driver — one command from clean clone to runnable build
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: done (2026-07-06)
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`

## What to build

A root `status.nims` nimscript driver — the canonical front door:

- `nim app status.nims` → host dev build (today's `make nim_status_client`
  result); `nim app status.nims --os:ios --cpu:arm64` / `--os:android
  --cpu:arm64` → the mobile chains. The task parses `--os/--cpu` from its
  invocation; host is the default. Kit selection stays environment-driven
  (QMAKE, IPHONE_SDK, QMAKE_DEVELOPMENT_TEAM, ANDROID_NDK_ROOT, ARCH …) with
  fail-fast, actionable errors when a required variable is missing for the
  selected target.
- `nim run status.nims` → build if needed + launch with the correct env
  (today's `make run-macos` semantics, incl. DYLD paths for libsds).
- Self-bootstrap: the task checks the setup stamp (nimble.paths vs
  lock/manifests) and runs `nimble setup` into `APP_NIMBLE_DIR` only when
  stale — a clean clone genuinely needs only the one command (plus kit env).
- Delegation: the driver shells out to the existing make recipes (Q12
  decision) — no build logic is reimplemented, and **no new logic lands in
  make** (make-freeze ratchet; PRD implementation decision).

Explicitly NOT nimble tasks: `nimble <task>` costs ~46–48 s of graph
revalidation per warm invocation on this manifest (measured 2026-07-06;
`--offline` errors, `--legacy` worse). The `.nims` driver starts in ~1 s.

## Acceptance criteria

- [x] Clean clone + documented kit env: `nim app status.nims` → runnable dev
  build (macOS host), including the initial `nimble setup` bootstrap.
- [x] `nim app status.nims --os:ios --cpu:arm64` and `--os:android
  --cpu:arm64` produce the signed iOS app / debug APK, equivalent to today's
  `make mobile-build` results.
- [x] Missing kit env for a selected target fails in <5 s with a message
  naming the exact variables to set.
- [x] No-op re-run of `nim app status.nims` (default mode, no source changes)
  completes with wall time recorded in the verification record; driver
  overhead (before make takes over) ≤ ~2 s. (The minutes-level vendor
  no-op cost is addressed by 0010's stamp-skip arm — record both numbers.)
- [x] All pre-existing make targets still work unchanged (spot-check
  `make nim_status_client`, `make mobile-build`, `make run-macos`).

## Blockers — grill before implementing

- Exact task/flag parsing shape in nimscript (how `--os/--cpu` arrive in
  `commandLineParams` when passed to `nim <task> file.nims`) — verify
  empirically first; if the flags are consumed by nim itself rather than
  forwarded, grill the fallback spelling (e.g. `nim app status.nims ios`)
  before deviating from the agreed UX.

## Phase-A spike findings (2026-07-06, nim 2.2.4, scratch-dir toy .nims)

The agreed UX works exactly as designed — no grill needed:

- **Flags placed AFTER the .nims file are not consumed by nim at all**:
  `nim app toy.nims --os:ios --cpu:arm64` evaluates the script with host
  defines (`hostOS: macosx`, `defined(ios): false`) and the flags arrive
  verbatim in the process argv. nim does not validate them either
  (`--os:bogusvalue` after the file is ignored by nim) — the task must parse
  AND validate them itself. Both `--os:ios` and `--os=ios` spellings arrive.
- **Flags placed BEFORE the file ARE consumed by nim**: they flip the
  script evaluation's own defines (`hostOS: ios`, `defined(ios): true`) and
  are validated by nim (`--os:` before the file with a bad value hard-errors).
  They still appear in argv, so an argv-wide scan handles both placements;
  the canonical spelling (after the file) is the safe one.
- `commandLineParams()` does not exist in nimscript ("undeclared
  identifier") — use `paramCount()`/`paramStr(i)`; argv includes the `nim`
  binary and nim's own options, so args-for-the-task = params after the
  param whose basename is the script filename.
- Extra non-flag args after the file arrive verbatim, no nim error.
- An inner `nim` spawned by the task (`exec "nim …"`) inherits nothing from
  the outer invocation in either placement (fresh process) — target
  selection must travel explicitly; in this driver it travels via env
  (QMAKE/ARCH/IPHONE_SDK…) into the make chains, so no nim-flag forwarding
  is needed.
- A task named `run` does not collide with nim's builtin commands (the
  builtin is `r`; `nim r file.nims` tries to *compile* the script — avoid
  task names that shadow real nim commands: c, cpp, js, e, r, doc…).
- Bootstrap delegation is already fully make-side: `nim_status_client`,
  `mobile-build`/`mobile-run`, `run-macos` and `nim-test-run/%` all depend
  on `$(NIMBLE_SETUP_STAMP)` (= `nimble.paths`, keyed on nimble.lock + the
  three manifests, `make nimble-deps` names it), and on a clean clone the
  Makefile's `.DEFAULT` rule auto-runs
  `git submodule update --init --recursive` and restarts. The driver adds
  no second stamp scheme — delegation inherits the existing one.
- Repo-root eval note: evaluating `status.nims` at the repo root walks the
  parent-dir configs, so the app's `config.nims` (and, in nested worktrees,
  the enclosing checkout's) runs as script *config*. Its switch() calls are
  inert for a nimscript eval; visible effect is only the "Building for
  macOS" echo noise. `include "nimble.paths"` is existence-guarded, so a
  clean clone (no nimble.paths yet) still evaluates.

## Blocked by

- 0007 (pin flip) — the driver's bootstrap must target the post-flip graph.

## Verification record (2026-07-06, macOS arm64 host; Qt 6.11.0 kits; team 8B5X2M6H2Y; post-0007 graph a30e7706e5)

Common env for all runs: `PATH=$PWD/vendor/nimbus-build-system/vendor/Nim/bin:$PATH`
(NBS nim 2.2.10 first on PATH) and `USE_SYSTEM_NIM=1` for the desktop legs
(`mobile-build` sets its own). Store = `~/.cache/status-desktop-nimbledeps`.

- Bootstrap from wiped store (criterion 1):
  `rm -rf ~/.cache/status-desktop-nimbledeps && rm -f nimble.paths
  vendor/status-go/nimble.paths`, then
  `QMAKE=~/Qt/6.11.0/macos/bin/qmake USE_SYSTEM_NIM=1 nim app status.nims`
  → exit 0 in **6:25 wall**. One command drove: `make nimble-deps` stamp →
  `nimble setup` (dependency graph re-downloaded and materialized, known
  special-version warnings only) → libsds host build in the 0007
  `vendor/status-go/.sds-build` store-scratch → fresh
  `bin/nim_status_client` (Mach-O 64-bit arm64). Runnable proof:
  `nim run status.nims` assembled StatusDev.app and launched it (Qt up,
  status-go logging); app exited on SIGTERM (the driver then correctly
  propagates make's non-zero — a normal user quit exits 0). Only
  pre-existing benign noise in the logs (StatusQ install_name_tool
  rpath-delete lines, OnboardingLayout TypeError).
- iOS (criterion 2a): `QMAKE=~/Qt/6.11.0/ios/bin/qmake IPHONE_SDK=iphoneos
  QMAKE_DEVELOPMENT_TEAM=8B5X2M6H2Y nim app status.nims --os:ios
  --cpu:arm64` → exit 0 in **2:45** (warm mobile trees + Go cache).
  Platform sentinel `darwin-arm64 -> ios-arm64` fired; libsds iOS rebuilt
  from `.sds-build`; `mobile/bin/ios/qt6/Status.app/Status` = Mach-O 64-bit
  arm64; `codesign --verify --deep --strict` OK,
  TeamIdentifier=8B5X2M6H2Y, Identifier=app.status.mobile.
- Android (criterion 2b): `QMAKE=~/Qt/6.11.0/android_arm64_v8a/bin/qmake
  ANDROID_SDK_ROOT=~/Library/Android/sdk
  ANDROID_NDK_ROOT=~/Library/Android/sdk/ndk/27.2.12479018
  nim app status.nims --os:android --cpu:arm64` → exit 0 in **3:28**.
  Sentinel `ios-arm64 -> android-arm64` fired; driver defaulted
  `GRADLE_TARGETS=assembleDebug` and `ARCH=arm64`;
  `mobile/bin/android/qt6/Status.apk` (268 MB) carries lib/arm64-v8a
  libstatus.so, libsds.so, libnim_status_client.so, libstatus_stub.so,
  libstatus_service.so (+ Qt); gradle product =
  `outputs/apk/debug/android-build-debug.apk` (debug variant, only one
  present).
- Missing kit env (criterion 3): every failure path exits in **~0.8 s**
  (budget <5 s) naming the exact variables. Matrix exercised: no
  QMAKE/no qmake; QMAKE→nonexistent path; wrong-kit QMAKE for host, iOS and
  Android (XSPEC cross-check — catches the ambient Android-QMAKE trap);
  IPHONE_SDK missing / invalid / contradicting --cpu;
  QMAKE_DEVELOPMENT_TEAM missing for iphoneos; ANDROID_SDK_ROOT +
  ANDROID_NDK_ROOT missing (both named in one message); Android --cpu vs
  per-ABI kit mismatch; unknown --os/--cpu values; unrecognized extra args.
- No-op re-run (criterion 4): `nim app status.nims` (host, no changes) =
  **7 s wall**; bare `make -j10 nim_status_client` immediately after =
  **5 s** → driver overhead ≈ **2 s** (script eval alone: 0.74 s via
  `nim help status.nims`; the rest is one `qmake -query` + make process
  startup). `bin/nim_status_client` mtime unchanged across both. Second
  number for 0010: the desktop no-op FORCE chain is already seconds-level;
  the mobile FORCE chain measured **70 s** as a direct
  `make mobile-build` no-op (warm Go cache; 0004 measured ~2:20 cold) —
  that is the cost 0010's stamp-skip arm removes.
- make targets unchanged (criterion 5): direct `make -j10 mobile-build`
  (android env) exit 0 in 70 s; direct `make -j10 nim_status_client` exit 0
  in 57 s including the return sentinel
  `android-arm64 -> darwin-arm64`; direct `make run-macos` launched
  StatusDev.app (process verified, then terminated). No make rule was
  added or changed by this issue — the driver is delegation-only.

Driver behavior notes (for 0009+): `--os/--cpu` are honored wherever they
appear on the nim command line, canonical spelling after the file;
`develop`/`undevelop`/`vendors` are fail-fast stubs referencing issue 0009;
`run` is host-only until develop-mode iterations extend it.

Follow-ups recorded, not done (scope): BUILDING.md gains the front-door
mention when 0009/0010 settle the vendor UX; config.nims' "Building for
macOS" echo prints during driver eval (cosmetic).
