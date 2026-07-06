---
id: 0007
title: Flip the sds requires to the PR #85 pin; retire the local nim-sds clone from the default flow
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
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

- [ ] From a wiped app store AND with `vendor/nim-sds` moved aside: `make
  nim_status_client` resolves sds from the GitHub pin, builds libsds from the
  store scratch copy, app links and launches.
- [ ] `nm -gU` on the produced static libsds (host static task) shows only
  `_Sds*` exports (the localization patch is in the pin).
- [ ] iOS libsds cross-task spot-check from the store copy passes (same 9-symbol
  check), proving the pin carries the mobile-relevant patches.
- [ ] `statusgo.nimble` contains no `file://` requires and no ffi requires.
- [ ] The app's `nimble.paths` stamp regenerates once and is stable across
  repeated builds (no per-build re-solve).

## Blockers — grill before implementing

None known. If resolution behaves unexpectedly (pkgcache staleness, graph
changes from the ffi-pin removal), stop and run a /grill-with-docs session
before working around anything.

## Blocked by

Nothing. First issue of the iteration.
