---
id: 0004
title: Mobile build matrix (iOS + Android) on the status-go nimble package
date: 2026-07-03
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: closed (pass: true, 2026-07-06)
---

## Parent

PRD: `docs/superpowers/prds/2026-07-03-statusgo-nimble-package-prd.md` (parent effort: status-im/status-desktop#19907)

## What to build

Bring the mobile targets onto the single-graph package flow. Cross-compilation of libstatus and libsds for iOS and Android stays environment-driven (arch and NDK/SDK selection via env vars, the Nim ecosystem convention): the mobile Makefile invokes the status-go package's cross tasks, which delegate to status-go's own Makefile targets for the Go side.

ADR 0003 semantics must be preserved intact:

- Shared-artifact targets keep the order-only platform-cleanup sentinel prerequisite (desktop↔mobile switching stays safe).
- The mobile library target keeps FORCE delegation to status-go's PHONY sub-make with compare-before-copy (status-go owns the incremental-rebuild decision; dependents relink only when library content changed).
- status-desktop continues not to track status-go/nim-sds sources (the #18377 boundary).
- The iOS libsds archive keeps its symbol hygiene: only the public SDS API exported, Nim runtime internalized (single global Nim runtime at final link).

## Acceptance criteria

- [x] Full iOS app build succeeds under the single-graph flow: app archive produced, signed, with the libsds archive exporting only the public SDS API symbols.
- [x] Android build succeeds under the single-graph flow for at least one production ABI. *(arm64-v8a, debug-signed APK; the release-signing leg needs the user's keystore via `STATUS_APP_KEYSTORE_PATH` — unset on this machine, gradle's release signingConfig falls back to `/nonexistent`. Everything up to `:packageRelease` passed; not a flow defect.)*
- [x] Switching desktop → iOS → Android builds in one working tree produces no stale-artifact link failures (platform sentinel intact).
- [x] A no-op mobile rebuild does not relink app targets (compare-before-copy intact); a status-go source change does trigger a fresh library via FORCE delegation. *(Required making the library outputs byte-reproducible first — see the verification record; compare-before-copy had been silently defeated by three nondeterminism sources predating this migration.)*
- [x] No mobile recipe references status-go or nim-sds internals beyond the package's tasks and the established artifact-directory contract.

## Verification record (2026-07-06, macOS arm64 host; Qt 6.11.0 kits; team 8B5X2M6H2Y)

- iOS (criterion 1): `QMAKE=~/Qt/6.11.0/ios/bin/qmake IPHONE_SDK=iphoneos
  QMAKE_DEVELOPMENT_TEAM=8B5X2M6H2Y make mobile-build USE_SYSTEM_NIM=1` →
  `mobile/bin/ios/qt6/Status.app` (Mach-O arm64), signed
  (TeamIdentifier=8B5X2M6H2Y, `codesign --verify --deep --strict` OK).
  The 6.9.2 iOS Qt kit referenced by older notes no longer exists on this
  machine; 6.11.0/ios matches the desktop/Android kits. Symbol hygiene:
  `nm -gU` on `vendor/nim-sds/build/libsds.a` AND the copied
  `mobile/lib/ios/qt6/libsds.a` → exactly 9 exported globals, all `_Sds*`
  (single `libsds_merged.o`), 0 non-Sds symbols. The build ran
  `nim libsdsIos statusgo.nims` against `vendor/status-go/nimble.paths`
  (cmp-gated copy of the app's single-graph resolution; libp2p 2.0.0 matrix)
  — libsds iOS cross-compile needed no changes for the 0003 matrix.
- Android (criterion 2): `QMAKE=~/Qt/6.11.0/android_arm64_v8a/bin/qmake
  GRADLE_TARGETS=assembleDebug make mobile-build USE_SYSTEM_NIM=1` →
  `mobile/bin/android/qt6/Status.apk` with arm64-v8a `libstatus.so`,
  `libsds.so` (ELF aarch64), `libstatus_stub.so`, `libstatus_service.so`,
  `libnim_status_client.so`. `nim libsdsAndroid statusgo.nims` (ARCH +
  ANDROID_NDK_ROOT env) built vendor/nim-sds in place.
- Switch matrix (criterion 3): one working tree, sequence desktop → iOS →
  Android → desktop. Sentinel transitions observed in the logs:
  `darwin-arm64 -> ios-arm64`, `ios-arm64 -> android-arm64`,
  `android-arm64 -> darwin-arm64`, each cleaning the shared artifacts. Zero
  stale-artifact link failures on any leg; the return desktop
  `make nim_status_client` (exit 0) rebuilt libsds.dylib + libstatus.dylib
  for darwin-arm64 and correctly did NOT relink the client binary (desktop
  links the shared flavors; no Nim source changed).
- No-op rebuild (criterion 4a): two identical consecutive iOS builds.
  Vendor libraries were rebuilt by the FORCE-delegated sub-make (mtimes
  1783333589→1783333764 libstatus, 1783333545→1783333718 libsds — status-go
  owns that decision) but content was byte-identical, so cmp gated the
  copies: `mobile/lib/ios/qt6/libstatus.a` (1783333589),
  `libsds.a` (1783333589), `libnim_status_client.a` (1783332064) and
  `Status.app/Status` (1783333655) all UNCHANGED; "Building app" appears 0
  times in the no-op log. Second no-op run wall time ~2:20.
- FORCE delegation (criterion 4b): line-shifting comment appended near the
  top of `vendor/status-go/mobile/status.go` → rebuild produced a fresh
  library and relinked/re-signed the app: libstatus copy 1783333589→1783333920,
  `Status.app/Status` 1783333655→1783333986 (codesign verify OK), while the
  untouched libsds copy stayed at 1783333589. Probe reverted.
- Reproducibility work that criterion 4 forced (all in locally patched
  repos, upstream-bound; details in vendor/status-go/AGENTS.md):
  1. `tools/generate-cbindings` iterated Go maps (packages, files, scope
     objects), so the generated `statusgo-lib/main.go` reshuffled every run
     and the c-archive churned ~60 MB per build → all loops now iterate
     sorted keys (verified: two `make statusgo-c-bindings` runs → identical).
  2. Go link-time build ID varies run-to-run → `-ldflags=-buildid=` added to
     `statusgo-ios-library` / `statusgo-android-library`.
  3. ar member-header mtimes: Go's archive writer (iOS c-archive) → recipe
     repacks with `ZERO_AR_DATE=1 libtool -static -no_warning_for_no_symbols`;
     nim-sds's `ar rcs` after the `ld -r` localization (iOS + static-mac
     tasks) → prefixed `ZERO_AR_DATE=1` in sds.nimble.
  Verified: two consecutive `statusgo-ios-library` runs and two
  `nim libsdsIos` runs each produce byte-identical archives (`cmp` clean).
- Recipe audit (criterion 5): grep of `mobile/` — remaining references are
  the package tasks (`nim libsdsIos|libsdsAndroid statusgo.nims`), status-go
  PHONY make targets (`statusgo-ios-library`, `statusgo-android-library`,
  `statusgo-stub-bindings`), the artifact-dir contract
  (`vendor/status-go/build/bin/*`, `vendor/nim-sds/build` + `library/`), and
  the version contract (`scripts/version.sh`). Removed two dead
  boundary-violating variables from `mobile/scripts/Common.mk`:
  `STATUS_GO_FILES` (a `find` over all status-go Go sources executed at
  every make parse, referenced nowhere — would re-couple #18377 if ever
  used) and `STATUS_GO_SCRIPT` (dangling `buildStatusGo.sh`, deleted by
  #18377).

## Blocked by

- 0003 (`0003-desktop-single-graph-consumption.md`) — mobile builds on the single-graph resolution.
