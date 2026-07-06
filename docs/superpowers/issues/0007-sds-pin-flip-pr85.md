---
id: 0007
title: Flip the sds requires to the PR #85 pin; retire the local nim-sds clone from the default flow
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: closed (2026-07-06)
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`

## What to build

nim-sds PR #85 (head `alexjba/nim-sds@5c89d61f897b44b75f2f28978f9928960181cf95`)
contains the entire 6-patch local queue (ffi pin, NIMFLAGS forwarding,
libsdsStaticMac localization, installDirs whitelist, ZERO_AR_DATE, -fno-common).
Point `vendor/status-go/statusgo.nimble` at it:

- Replace the interim `requires "file:///…/vendor/nim-sds"` with
  `requires "https://github.com/alexjba/nim-sds.git#5c89d61f…"` (comment: interim
  fork pin, moves to the logos-messaging merge SHA when PR #85 lands).
- Drop the explicit nim-ffi pin from statusgo.nimble — 5c89d61 pins ffi itself
  (and the file://+sibling-#hash mutual-drop wall that forced juggling it is no
  longer in play).
- Default flow must no longer require `vendor/nim-sds` to exist: sds resolves
  into the store and builds via the existing `.sds-build/` scratch engine
  (statusgo.nims already handles store copies). The local clone becomes a
  develop-mode-only artifact (issue 0009).
- Regenerate/hand-fix the app lock + setup stamp as needed (expect the known
  lock-divergence pattern; wipe stale `~/.nimble/pkgcache/nim-sds*` clones —
  the pin's commit must be discoverable).

## Acceptance criteria

- [x] From a wiped app store AND with `vendor/nim-sds` moved aside: `make
  nim_status_client` resolves sds from the GitHub pin, builds libsds from the
  store scratch copy, app links and launches.
- [x] `nm -gU` on the produced static libsds (host static task) shows only
  `_Sds*` exports (the localization patch is in the pin).
- [x] iOS libsds cross-task spot-check from the store copy passes (same 9-symbol
  check), proving the pin carries the mobile-relevant patches.
- [x] `statusgo.nimble` contains no `file://` requires and no ffi requires.
- [x] The app's `nimble.paths` stamp regenerates once and is stable across
  repeated builds (no per-build re-solve).

## Verification record (2026-07-06, macOS arm64 host; nim 2.2.4, nimble 0.22.3, Qt 6.11.0/macos)

Prep: `mv vendor/nim-sds /tmp/nim-sds-0007-aside`, `rm -rf
~/.cache/status-desktop-nimbledeps`, `rm -f nimble.paths
vendor/status-go/nimble.paths`, stale `~/.nimble/pkgcache/*sds*` purged,
`bin/nim_status_client` + `vendor/status-go/build/bin/libstatus.*` deleted.

- Criterion 1 (wiped store, no vendor/nim-sds):
  - `make nimble-deps` from the wiped store = 6:17, exit 0. nimble.paths
    resolves sds from the store
    (`pkgs2/sds-0.3.0-89a7872a…`, url alexjba/nim-sds, vcsRevision 5c89d61f),
    ffi 0.1.4 via sds's own pin, and the verified matrix
    libp2p 2.0.0 / websock 0.4.0 / lsquic 0.5.4. No vendor/nim-sds anywhere
    in the resolution.
  - `QMAKE=~/Qt/6.11.0/macos/bin/qmake USE_SYSTEM_NIM=1 make
    nim_status_client` → libsds built in the store-scratch
    `vendor/status-go/.sds-build/` (scratch carries the store copy's
    `nimblemeta.json` — provenance proof), artifacts
    `.sds-build/build/libsds.dylib` + `.sds-build/library/`;
    `bin/nim_status_client` links `@rpath/libsds.dylib`. (First attempt
    without the QMAKE prefix died in status-keycard-qt with linux paths —
    the standing kit-env gotcha, not a flow defect.)
  - `make run-macos`: StatusDev.app launched (pid up), status-go up —
    `Status/data/pre_login.log`: 0 errors, "media server started";
    SIGTERM → process exited, `make` reports plain `Terminated: 15`.
- Criterion 2 (host static symbols): `cd vendor/status-go && nim libstatus
  statusgo.nims` → `nm -gU build/bin/libsds.a` = exactly 9 exported globals,
  all `_Sds*` (single `libsds_merged.o`), 0 non-Sds.
- Criterion 3 (iOS spot-check): `cd vendor/status-go && nim libsdsIos
  statusgo.nims` (built from the store scratch copy; log shows
  iPhoneOS26.5.sdk) → `.sds-build/build/libsds.a`, `lipo` = arm64,
  `otool -lv` = `platform IOS, minos 16.2`, `nm -gU` = the same 9 `_Sds*`
  exports, 0 non-Sds.
- Criterion 4: `statusgo.nimble` now carries a single
  `requires "https://github.com/alexjba/nim-sds.git#5c89d61f…"` — no
  `file://`, no ffi requires (5c89d61 pins ffi itself, #fb25f069 = 0.1.4).
- Criterion 5 (stamp stability): immediately repeated
  `make nim_status_client` = 8s no-op; nimble.paths mtime unchanged
  (1783351385), client binary mtime unchanged, `nimble setup` ran 0 times.
  After restoring vendor/nim-sds the next build still did not re-solve
  (the sds.nimble stamp prerequisite is gone) — the local clone is out of
  the default flow.

### Blocker found and resolved mid-issue (grilled 2026-07-06)

Clean-store `nimble setup` with a lock file hard-failed ("Couldn't find a
solution") — for the OLD (file:// sds) config too, i.e. pre-existing, only
exposed by this issue's wiped-store discipline. Root cause (minimal
2-package repro + instrumented nimble 0.22.3 build): vNext dependency
validation extracts an EMPTY version from old INI-format manifests on a
fresh pkgcache clone → uuids' `isaac >= 0.1.3` fails ("wanted >= 0.1.3
got .") → uuids dropped from the graph → lock-path reachability check kills
the solve. Decision (human-approved): fork + modernize manifests + pin —
`alexjba/uuids@5d79d279` (0.1.12 + modern manifest + isaac pinned by
revision) and `alexjba/isaac@5bd05be4` (v0.1.3 + modern manifest), pinned in
`nim_status_client.nimble`. Details in vendor/status-go/AGENTS.md (two new
walls: INI-manifest validation; lock fast-path unreachable for URL-pinned
manifests — the lock never constrains this app's solves, which also
retroactively explains the 0003 "websock hand-fix" as a misattribution).

### Notes / follow-ups (not in scope)

- Long-term: drop uuids/isaac from the app graph (unmaintained since ~2018;
  16 files use `genUUID()` for correlation IDs) — removes the fork pair.
- Upstream nimble issues to file: (a) INI-manifest empty-version extraction
  in vNext validation, (b) requirer silently dropped on dependency
  validation failure + lock-mode reachability hard-fail, (c) lock coverage
  check never matches URL-form requires (fast path unreachable, every setup
  re-solves), (d) `nimble lock` records versions its own `setup` does not
  pick (websock 0.3.0 vs 0.4.0).
- The sds pin moves to the logos-messaging merge SHA when PR #85 lands.
- fdroid/build-app.sh + CI Jenkinsfiles still export NIM_SDS_SOURCE_DIR for
  status-go's standalone Option-1 clone flow (untouched by this issue; CI
  migrates on its own schedule per the PRD).

## Blockers — grill before implementing

None known. If resolution behaves unexpectedly (pkgcache staleness, graph
changes from the ffi-pin removal), stop and run a /grill-with-docs session
before working around anything.

## Blocked by

Nothing. First issue of the iteration.
