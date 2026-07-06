---
id: 0001
title: Absorb the status_go wrapper into status-go with auto-link, proven by an outside consumer
date: 2026-07-03
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: done
pass: true
completed: 2026-07-03
---

## Parent

PRD: `docs/superpowers/prds/2026-07-03-statusgo-nimble-package-prd.md` (parent effort: status-im/status-desktop#19907)

## What to build

Make `requires status-go` + `import status_go` a complete consumption story for a Nim developer. The existing separate Nim wrapper package for libstatus is absorbed into the status-go repository, keeping the `status_go` module name so existing imports compile unchanged. The wrapper carries its own link flags — libstatus, libsds, and the per-OS frameworks/syslibs the Go runtime needs — computed from the package's own directory, gated behind a `-d:statusGoNoAutoLink` compile-time opt-out for consumers with bespoke link setups.

The slice includes just enough build wiring (package tasks delegating to status-go's Makefile targets, per the #18377 delegation and ADR 0003) to produce host-target libstatus and libsds artifacts that the auto-link flags resolve against.

The package manifest must stay fully declarative (hook blocks only — no imports/procs/tasks in the manifest; verified during design that code in the manifest degrades or hangs nimble's declarative parser). Tasks live in the companion nimscript file.

## Acceptance criteria

- [x] A throwaway consumer package outside the status-go tree, containing only a `requires` on status-go and a program with `import status_go`, resolves, compiles, links via auto-link, and successfully calls a real libstatus function.
- [x] The same consumer compiled with `-d:statusGoNoAutoLink` fails to link (proving the flags came from the wrapper, not the environment) or links only when the consumer supplies flags manually.
- [x] The `status_go` module name is unchanged; status-desktop's existing imports would compile against the absorbed wrapper without edits.
- [x] The wrapper and the C header now live in the same repo; a wrapper/header mismatch is impossible to introduce in a single-repo change without touching both.
- [x] Dependency resolution of a consumer requiring status-go completes without parser degradation (manifest stays declarative).

## Blocked by

None - can start immediately.

## Verification record (2026-07-03, macOS arm64)

- Consumer package (scratch dir outside any workspace): `requires "statusgo"` +
  `nimble develop --add:<repo>` + `nimble setup -l` → resolved statusgo at the
  local checkout, sds `884ce6f0` + ffi `fb25f069` transitively (full solve
  ~10 min, no lock — known cost; manifest evaluation itself instant, no parser
  degradation).
- `nim libstatus statusgo.nims` → `build/bin/libstatus.a` (186 MB,
  `gowaku_no_rln`) + `build/bin/libsds.a`; `nm -gU` on libsds.a shows only the
  9 `_Sds*` exports (host static localization added to nim-sds
  `libsdsStaticMac`, mirroring the iOS pipeline).
- `nim c -r consumer.nim` → linked via auto-link (explicit archive paths +
  CoreFoundation/Security/IOKit/resolv), ran `hashMessage` and
  `validateMnemonic` against real libstatus, correct results, `otool -L` shows
  no libstatus/libsds dylib deps.
- `nim c -d:statusGoNoAutoLink consumer.nim` → link fails with undefined
  `_HashMessage`/`_ValidateMnemonic`, proving flags came from the wrapper.
- Wrapper absorbed byte-identical from nim-status-go `7f79f183` (the revision
  status-desktop pins), auto-link block added guarded; desktop's existing
  `import status_go` surface unchanged. Desktop's shared flavor unaffected:
  `nim libsds statusgo.nims` (dynamic) re-verified after the change.
