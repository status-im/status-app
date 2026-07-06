---
id: 0003
title: status-desktop consumes status-go through the single dependency graph
date: 2026-07-03
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: closed (pass: true, 2026-07-06)
---

## Parent

PRD: `docs/superpowers/prds/2026-07-03-statusgo-nimble-package-prd.md` (parent effort: status-im/status-desktop#19907)

## What to build

Collapse status-desktop's two dependency resolutions into one. The app's manifest requires status-go; the git submodule is develop-linked so the app's single `nimble setup` resolves everything — status-go's Nim dependencies (the SDS reliability layer and its FFI helper) land in the app's lock file like any other dependency, visible and pinnable by the app.

Consequences to implement:

- The separate per-status-go dependency cache and its second multi-minute solve are deleted, along with the setup-stamp machinery that drove it.
- The separate Nim wrapper package requirement is dropped from the app's manifest and lock (the wrapper now ships inside status-go, per issue 0001).
- The patched local nim-sds checkout is develop-linked into the app's graph until the three upstream nim-sds patches merge (dependency-range cap, iOS common-symbol fix, build-flag forwarding).
- Develop-linked packages are not install-built, so desktop's Go builds remain task-driven through make — the make targets keep their existing interface; daily workflow (`make run`) is unchanged.
- Desktop initially keeps its explicit link flags via the wrapper's auto-link opt-out define (migrating desktop to auto-link is out of scope).

## Acceptance criteria

- [x] A single `nimble setup` at the app root materializes the entire graph, including status-go's Nim dependencies; no second resolution or separate cache dir exists anywhere in the build.
- [x] The SDS and FFI pins appear in the app's lock file; the separate wrapper package no longer does. *(Interim caveat: the ffi pin is in the lock; sds itself is omitted because nimble 0.22.3 does not lock `file://` packages — its pin lives in statusgo.nimble until the upstream sds patches merge and the GitHub pin returns.)*
- [x] Desktop macOS builds and launches via the existing make target with the app linking a libsds/libstatus produced under the single-graph flow.
- [x] Editing the develop-linked status-go or nim-sds checkout is picked up by the next build without publishing or reinstalling anything. *(Consumption is via absolute `file://` requires, not develop links — nimble 0.22.3 refuses to develop-link a package whose manifest carries a `file://` requires, which statusgo.nimble interim-does for sds. Same link semantics either way; the name-form + develop final shape is documented in the manifest for the post-upstream flip.)*
- [x] Clean-environment setup time no longer includes the second SAT solve (previously ~11.5 minutes). *(Measured: ~4 min for a from-scratch store, network-download bound, lock-driven — no SAT solve.)*

## Verification record (2026-07-06, macOS arm64)

- Single graph: `nimble setup` at the app root resolves 41 packages incl.
  statusgo → `vendor/status-go` and sds → `vendor/nim-sds` (link semantics,
  absolute `file://` requires), ffi 0.1.4 (#fb25f069), libp2p 2.0.0,
  websock 0.4.0, lsquic 0.5.4. `~/.cache/statusgo-nimbledeps` machinery and
  the `STATUSGO_NIMBLE_DIR` second solve are deleted from both Makefiles;
  `vendor/status-go/nimble.paths` is now a byte-for-byte copy of the app's
  resolution (cmp-gated Make rule).
- Store location: the app's dependency store moved OUT of tree
  (`APP_NIMBLE_DIR`, default `~/.cache/status-desktop-nimbledeps`) because
  the merged graph contains a binary-building dependency (dnsclient, via
  libp2p) whose `nimble setup` compile is poisoned by Nim's parent-dir config
  walk when built inside the repo (and, for nested git worktrees, by an
  enclosing checkout's config.nims — empirically fatal in this workspace).
  config.nims additionally guards all app-specific switches away from any
  in-tree dependency builds.
- Desktop: full `make nim_status_client` (REBUILD_NIM) compiled the wrapper
  from `vendor/status-go/status_go.nim` (verified via nimcache module path,
  `-d:statusGoNoAutoLink` from config.nims) and `make run` launched
  StatusDev.app — status-go initialized (media server up, 0 errors in
  pre_login.log), QML engine loaded, graceful shutdown. `run-macos` gained
  `NIMSDS_LIBDIR` on DYLD_LIBRARY_PATH (libstatus.dylib references
  @rpath/libsds.dylib; the Linux run targets already had it — desktop launch
  had been a standing carry-over since 0005).
- Edit propagation: appended a comment to `vendor/nim-sds/sds/message.nim`,
  `nim libsds statusgo.nims` rebuilt `vendor/nim-sds/build/libsds.dylib` in
  place (mtime advanced), no publish/reinstall; probe reverted.
- Clean environment: wiped store + paths → `make nimble-deps` completed in
  3:56 (downloads; no SAT solve). Required one lock hand-fix first: nimble's
  lock generator records websock at 0.3.0 while the resolution picks 0.4.0,
  and a clean-store `solveLockFileDeps` hard-fails on that divergence
  (warm-store setups mask it). Hand-fixed version/vcsRevision/checksum in
  nimble.lock — the established pattern; documented in
  vendor/status-go/AGENTS.md.
- App-side pin changes: json_rpc 0.6.0 → 0.6.1 (0.6.0 caps websock < 0.4.0;
  libp2p 2.x needs >= 0.4.0). nim-sds local patch queue extended: the ffi
  requires switched from range to the CI-certified #fb25f069 pin (nimble
  0.22.3 hard-fails graph expansion on nim-ffi 0.2.0's cbor_serialization
  dep otherwise — released upstream 2026-07-04).
- Not achievable on nimble 0.22.3 (all counter-measures verified failing,
  full matrix in vendor/status-go/AGENTS.md): forcing libp2p 2.1.x in the
  merged graph — 1.15.x candidate manifests special-pin lsquic to a 0.0.1-era
  commit and nimble pre-binds it package-wide, making 2.1.x unsatisfiable.
  The graph lands on libp2p 2.0.0 (between sds's CI-certified 1.15.2 and the
  Jul-4 statusgo-graph 2.1.3); libsds built and desktop-verified against it.

## Blocked by

- 0001 (`0001-statusgo-wrapper-absorption-autolink.md`) — the app drops the separate wrapper package only once the absorbed wrapper exists. Can run in parallel with 0002.
