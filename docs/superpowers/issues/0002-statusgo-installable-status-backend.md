---
id: 0002
title: Installable status-backend — hybrid bin entry with build hooks
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

Make `nimble install` of status-go put a working `status-backend` RPC server on the user's PATH, built from source, tracked natively by nimble (symlinked, uninstallable, rebuildable).

Mechanism (each element verified by prototype during design):

- A new small cgo export on the Go side wrapping the existing status-backend server package (whose Go main is only flag parsing plus server setup).
- A thin Nim main (~20 lines) declared as the package's `bin` entry, calling that export and linking through the absorbed `status_go` wrapper with auto-link — every install thereby exercises the same wrapper+link path library consumers use.
- Install mechanics in the manifest (shape from the prototype):

  ```nim
  bin         = @["status_backend"]     # hybrid: lib sources still install alongside
  installDirs = @["build"]              # carries untracked hook-produced artifacts into the store

  before build:                          # fires during `nimble install`, BEFORE the Nim bin compiles
    exec "make <library-target>"         # Go artifacts exist at link time
  ```

- The hook shells out to status-go's existing Makefile target (make stays the Go-build engine: tags, ldflags/version stamping, CGO env).
- Prerequisite checks: a missing Go toolchain or make produces a clear actionable error, not a cryptic mid-build failure.
- An environment switch skips the Go-build hook for source-only workflows (dependency resolution, wrapper-only compile checks).

`nimble install` always targets the host — cross-compilation is explicitly not part of the install path.

## Acceptance criteria

- [x] On a clean nimble dir, `nimble install` of the package completes and `status_backend` is on PATH via nimble's bin symlink.
- [x] The installed `status_backend` starts and answers a real RPC request over HTTP.
- [x] Library sources install alongside the binary (hybrid behavior intact — a consumer can still `import status_go` from the installed package).
- [x] With the skip-hook environment switch set, installation performs no Go build and states why the binary step was skipped.
- [x] With the Go toolchain absent (or simulated absent), the failure message names the missing prerequisite.

## Blocked by

- 0001 (`0001-statusgo-wrapper-absorption-autolink.md`) — the Nim main links through the absorbed wrapper's auto-link.

## Verification record (2026-07-03, macOS arm64)

Implementation: `cmd/status-backend/server/serve.go` (`Run(address)` — logging
init, interrupt logout, Listen/RegisterMobileAPI/Serve); generator appends a
verbatim `StatusBackendRunServer` export (server pkg imports `mobile`, so the
export cannot live in `mobile/`); wrapper procs in `status_go/impl.nim` +
`status_go.nim`; thin `status_backend.nim` (+`.nim.cfg` with
`-d:noSignalHandler`); manifest gains `bin`, `installDirs=@["build",
"status_go"]`, `installFiles=@["status_go.nim","statusgo.nims"]` and the
declarative-safe `before build` hook (skip switch, go/make prereq checks,
delegate to `nim libstatus statusgo.nims`); `statusgo.nims` gained
install-context support (nested `nimble setup` when `nimble.paths` is absent,
`NIM_SDS_SOURCE_DIR` override, in-package `.sds-src` clone fallback).

- Clean nimble dir (`~/.cache/sg0002/nimble-clean`, freshly created):
  `nimble install` of the package copy completed (full solve + sds static
  build + `make statusgo-library` + bin link); `$NIMBLE_DIR/bin/status_backend`
  symlink present.
- Installed bin from PATH: `/health` answered; POST `/statusgo/HashMessage`
  "hello" → `0x50b2c43f…b37750` (matches the 0001-verified direct call).
  SIGTERM → graceful logout + exit. Re-proven end-to-end after the final
  manifest change (install exit 0, same RPC answers).
- Hybrid: `file://` + local-commit install created
  `pkgs2/statusgo-0.1.0-94af3ede`; store copy holds bin + `build/bin/*.a` +
  wrapper sources; a consumer compiled only against the store copy
  (`--path:<store>`) auto-linked and returned the correct hash.
  (First attempt failed — bin packages install **no sources** by default;
  fixed with the installDirs/installFiles whitelists.)
- Skip switch `STATUS_GO_SKIP_GO_BUILD=1`: with artifacts present → stated
  reuse message, zero Go builds, install completed; without artifacts →
  stated skip message, zero Go builds, binary step cancelled (nimble reports
  "Pre-hook prevented further execution" — the hook-false semantics; install
  does not complete source-only, documented deviation).
- Go absent (stripped PATH): install fails before any build with
  "…needs the Go toolchain, but `go` was not found on PATH. Install Go
  (https://go.dev/dl/) or set STATUS_GO_SKIP_GO_BUILD=1…".
- Quality: `golangci-lint` on changed Go pkgs → 0 issues;
  `goroutine-defer-guard` (lint-panics) clean; desktop shared flavor
  (`nim libsds statusgo.nims`) re-verified after the nims changes.
- Caveats: sds source pointed at the patched local `vendor/nim-sds`
  (`NIM_SDS_SOURCE_DIR`) until the `libsdsStaticMac` localization patch merges
  upstream — same caveat as 0001. Local-path installs build in-place and
  symlink to the source dir (nimble 0.22.3 vNext); the store path was
  exercised via the `file://` flavor. `/health` version is empty in the
  scratch copy (no git history for stamping); the in-repo smoke showed the
  real version. Very long NIMBLE_DIR paths overflow macOS's 255-byte filename
  limit in nimcache (documented in AGENTS.md).
