---
id: 0005
title: Build nim-sds from nimble resolution — delete sibling/clone/env improvisations
date: 2026-07-03
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: done
pass: true
completed: 2026-07-04
---

## Parent

PRD: `docs/superpowers/prds/2026-07-03-statusgo-nimble-package-prd.md`
Design: `docs/superpowers/specs/2026-07-03-sds-from-nimble-resolution-design.md`

## What to build

One rule in statusgo.nims: **every sds build task builds the nimble-resolved
nim-sds copy** (all flavors — host static for install/auto-link, desktop
shared, iOS, Android).

- Locate sds via `nimble.paths` (the nested-`nimble setup` bootstrap from
  issue 0002 already guarantees it exists in install context).
- Develop-linked checkout (path outside the store) → build **in place**;
  artifact locations unchanged (`<checkout>/build`), so desktop's Makefile
  is untouched.
- Store copy (`/pkgs2/sds-…`) → copy to `.sds-build/` at the package root
  (dot-dir, never installed) and build there; the store stays pristine.
- Delete: `NIM_SDS_SOURCE_DIR` handling, the sibling `../nim-sds`
  convention, `ensureSdsSource`'s git clone, and `sdsPin()` manifest
  parsing. Patched/local sds is substituted via `nimble develop --add`
  (wire this for the desktop worktree: develop-link `vendor/nim-sds` into
  statusgo's graph).
- No sds entry in `nimble.paths` → fail with an actionable message (run
  `nimble setup` / develop-link your checkout), not a clone.

## Acceptance criteria

- [x] `grep`-clean: no `NIM_SDS_SOURCE_DIR`, no `../nim-sds` sibling
  default, no `git clone` in statusgo.nims. (2026-07-03: verified; also
  removed the dead `NIM_SDS_SOURCE_DIR` export from the desktop Makefile and
  the packaging scripts now take `NIMSDS_LIBDIR`.)
- [x] Desktop flow (develop-linked patched sds): `nim libsds statusgo.nims`
  builds from `vendor/nim-sds` in place; desktop make matrix unchanged.
  (2026-07-04: substitution mechanism changed from `nimble develop` — broken
  on nimble 0.22.3 for URL requires, see status note — to the user-chosen
  manifest edit: statusgo.nimble's interim requires is an ABSOLUTE
  `file://…/vendor/nim-sds`, which nimble resolves with link semantics
  (nimble.paths points into the checkout). `nim libsds` (dylib), `nim
  libstatus` (localized static, 9 `_Sds*`/0 others), and `nim libsdsIos`
  (arm64, minos 16.2) all rebuilt `vendor/nim-sds` in place, no `.sds-build`;
  `make -n` graphs for desktop and mobile-iOS unchanged.)
- [x] Install flow (store sds): the issue-0002 clean-dir install proof
  re-passes end to end (install → bin on PATH → RPC answer) with the sds
  build sourced from the store copy via `.sds-build/`, upstream sds
  unpatched caveat noted as before. (2026-07-03: clean `~/.cache/sg5/nd`,
  `nimble install file://<copy>`; sds resolved from the store, built in
  `.sds-build/`, store pristine; `status_backend` symlinked on PATH;
  `/health` + `HashMessage "hello"` → `0x50b2c43f…b37750` (matches 0002);
  SIGTERM → graceful logout; installed `libsds.a` exports exactly the 9
  `_Sds*` symbols. Caveat sharpened: the proof pins a PATCHED sds revision
  (throwaway loopback-served snapshot) because the unpatched upstream pin
  cannot work at all — no NIMFLAGS forwarding and an unlocalized static-mac
  archive that fails the bin link with 17 duplicate Nim-runtime symbols —
  and additionally the store copy needs sds's new `installDirs` whitelist
  (5th local patch) or nimble's install action drops `library/` entirely.)
- [x] Host static localization still holds: `nm -gU build/bin/libsds.a`
  shows only `_Sds*` exports (whichever sds copy was built). (2026-07-03:
  9 `_Sds*`, 0 others, develop-linked patched copy.)
- [x] Negative: with no develop link and an empty store path set, the task
  fails with the actionable message (no clone attempted). (2026-07-03:
  crafted sds-less nimble.paths → actionable quit, no network, no files.)
- [x] Mobile tasks (`libsdsIos`, `libsdsAndroid`) resolve sds the same way
  (spot-check one: builds from the resolved copy). (2026-07-03: `nim
  libsdsIos statusgo.nims` in the install-proof copy resolved the store sds,
  built in `.sds-build/` → arm64 `libsds.a`, exports = 9 `_Sds*` only.)

## Status note (2026-07-04) — RESOLVED, all criteria pass

`nimble develop` is unusable for this substitution on nimble 0.22.3 (a
develop-linked checkout can never satisfy a URL-form requires — #hash,
#hash+lock+sync, URL+range, and bare-URL forms all verified failing; tested
matrix in `vendor/status-go/AGENTS.md` and progress.txt). Resolution, per
the user's direction: the substitution lives in the MANIFEST — the worktree
interim state points `requires` at the patched checkout with an absolute
`file://` URL (link semantics; restored to the exact-revision GitHub pin
when the sds patch queue merges upstream). Two coupled gotchas, both
documented in AGENTS.md: (1) a `file://` dependency and a sibling URL#hash
requires silently drop each other — the interim state therefore also
disables the explicit ffi pin (the patched sds's `< 0.2.0` cap owns ffi;
it floats within 0.1.x, currently 0.1.5, until the pins return);
(2) nim-ffi 0.1.5 enforces signal-ownership declaration, so the mobile sds
tasks now pass `-d:noSignalHandler` like the host tasks always did (correct
everywhere: libsds is always embedded in a host process).

## Blocked by

None — the engine has no upstream dependency. (0002's nested-setup
bootstrap is already on the branch.)
