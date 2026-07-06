---
title: status-go as a first-class nimble package (importable lib + installable status-backend)
date: 2026-07-03
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
parent: status-im/status-desktop#19907
---

## Progress

| Issue | Slice | Stories covered | Status |
|-------|-------|-----------------|--------|
| 0001 wrapper absorption + auto-link | `status_go` module absorbed into status-go, auto-link with `-d:statusGoNoAutoLink` opt-out, host `libstatus` task, outside-consumer proof | 1–5 (16, 17 hold by construction; 6 resolution proven, consumer lock not exercised) | pass: true (2026-07-03; verification record in the issue file) |
| 0002 installable status-backend | cgo export + thin Nim bin, `nimble install` → `status_backend` on PATH answering RPC, hybrid store install (sources+artifacts), skip switch, prereq checks | 7–9, 18, 21 (16, 17 hold by construction; 8 uninstall/rebuild exercised via reinstall flow) | pass: true (2026-07-03; verification record in the issue file) |
| 0003 desktop single-graph consumption | app manifest requires statusgo (interim `file://`; develop blocked by a nimble wall), second solve + `statusgo-nimbledeps` deleted, statusgo `nimble.paths` derived by copy, out-of-tree app store (`~/.cache/status-desktop-nimbledeps`), `-d:statusGoNoAutoLink`, desktop build + launch, edit propagation, clean-env ~4 min | 10–13, 19 advanced (12 via `file://` link semantics; 16, 17, 20 hold by construction) | pass: true (2026-07-06; verification record in the issue file. Merged-graph SAT walls + lock hand-fix documented in vendor/status-go/AGENTS.md) |
| 0004 mobile matrix on the new package | iOS app build+sign (libsds `_Sds*`-only surface), Android arm64-v8a APK, desktop→iOS→Android→desktop sentinel matrix, no-op/FORCE proofs (required making libstatus/libsds byte-reproducible: cbindings sorted emit, `-buildid=`, `ZERO_AR_DATE`), mobile recipe audit + dead-var cleanup | 13, 14, 20 (19 exercised cross-platform) | pass: true (2026-07-06; verification record in the issue file. Android release signing gated on user keystore `STATUS_APP_KEYSTORE_PATH`; debug-signed APK verified) |
| 0005 sds build from nimble resolution | engine (nimble.paths-only locator, in-place vs `.sds-build/` store scratch), install-context bootstrap, sds `installDirs` patch, install proof re-passed, negative + localization + desktop in-place + iOS spot-check | 6, 15, 19, 22 advanced | pass: true (2026-07-04; verification record in the issue file. Local substitution = manifest-level `file://` interim requires — nimble 0.22.3's develop mode verified unusable for URL requires; defect matrix in vendor/status-go/AGENTS.md) |
| 0006 sds target subdir artifact packages | — | — | open (upstream-gated; same design doc) |

## Problem Statement

status-go cannot be consumed as a normal Nim dependency. A Nim developer who wants to talk to the Status protocol today has to reverse-engineer status-desktop's build machinery: clone the right repos at the right revisions, discover the separate `nim-status-go` wrapper package (which historically drifts out of sync with `libstatus.h`, since they live in different repos and are versioned independently), hand-assemble a long platform-specific list of link flags (libstatus, libsds, Go-runtime frameworks/syslibs), and drive the Go build themselves. There is also no supported way to *install* status-go's RPC server (`status-backend`) onto a machine — you must clone the repo and build it manually.

Inside status-desktop, the same gap shows up as duplication: the app maintains its own dependency resolution for status-go's Nim dependencies (a second SAT solve measured at ~11.5 minutes, in a separate cache directory, with a second lock to maintain) because status-go isn't a package that can participate in the app's dependency graph.

## Solution

Make status-go a first-class **hybrid nimble package** — importable as a library and installable as an executable — following the model of packages like nimssl (wrapper + native build in one versioned unit):

- A Nim developer adds one `requires` line, writes `import status_go`, and gets a compiling, *linking* program: the wrapper module travels with the package and carries its own link flags.
- Anyone can run one `nimble install` command and get a working `status-backend` RPC server on their PATH, built from source.
- status-desktop consumes status-go through its single dependency graph (develop-linked submodule): one `nimble setup`, one lock file, no second resolution.

The Go build stays owned by status-go's own Makefile (per the #18377 delegation and ADR 0003); nimble becomes the packaging and consumption interface, with hooks and tasks shelling out to make.

## User Stories

1. As a Nim library developer, I want to depend on status-go with a single `requires` entry, so that my package manager resolves and fetches everything I need to build against the Status protocol.
2. As a Nim library developer, I want `import status_go` to give me the full libstatus API surface, so that I don't have to write or vendor my own C bindings.
3. As a Nim library developer, I want the wrapper module to carry its own link flags (libstatus, libsds, platform frameworks/syslibs), so that my program links without me maintaining a platform-specific flag list.
4. As a Nim library developer with a bespoke build setup, I want a compile-time opt-out from the automatic link flags, so that auto-linking never fights my own linker configuration.
5. As a Nim library developer, I want the Nim wrapper and the C header to be versioned together in one repo, so that the wrapper can never drift from the library it binds.
6. As a Nim library developer, I want transitive Nim dependencies of status-go (the SDS reliability layer and its FFI helper) resolved by my own dependency graph, so that I can see and pin them in my lock file like any other dependency.
7. As a developer or tester, I want `nimble install` of status-go to put a working `status-backend` executable on my PATH, so that I can stand up a Status RPC server without cloning and studying the repo.
8. As a developer or tester, I want the installed `status-backend` to be tracked by nimble (symlinked, uninstallable, rebuildable), so that it behaves like any other nimble-installed tool.
9. As a QA or CI engineer, I want to provision `status-backend` on a machine with one package-manager command, so that end-to-end test environments are reproducible from a version pin.
10. As a status-desktop developer, I want the app's single `nimble setup` to resolve status-go's Nim dependencies together with the app's own, so that there is one dependency resolution, one cache, and one lock file to maintain.
11. As a status-desktop developer, I want to stop paying a second multi-minute dependency solve for status-go, so that clean-environment setup time drops substantially.
12. As a status-desktop developer, I want the status-go submodule develop-linked into the app's graph, so that local changes to status-go are picked up by the next build without publishing anything.
13. As a status-desktop developer, I want desktop and mobile builds to keep working through the existing make targets unchanged in their interface, so that the packaging rework does not change my daily workflow.
14. As a mobile developer, I want cross-compilation of libstatus and libsds for iOS and Android to remain driven by environment variables and package tasks, so that the mobile build flow matches the wider Nim ecosystem convention and today's muscle memory.
15. As a status-go maintainer, I want the Go build (build tags, ldflags, version stamping, CGO environment) to remain defined solely in status-go's Makefile, so that the nimble layer can never drift from the canonical build.
16. As a status-go maintainer, I want the package manifest to stay declarative (hooks only, no imports/procs/tasks in the manifest), so that consumers' dependency resolution stays fast and does not hang.
17. As a status-go maintainer, I want updating the C API to require updating the Nim wrapper in the same change, so that binding regressions are caught at review time rather than by downstream consumers.
18. As a third-party integrator on a fresh machine, I want the package's prerequisites (Go toolchain, make) to be documented and checked, so that a failed install tells me what to install rather than failing cryptically mid-build.
19. As a third-party integrator, I want to pin status-go to an exact revision through my dependency file, so that my builds are reproducible even though the package builds from source.
20. As a release/CI engineer for status-desktop, I want the platform sentinel and delegation semantics of ADR 0003 preserved (order-only cleanup prerequisite, FORCE delegation, compare-before-copy), so that desktop↔mobile switching and incremental correctness are not regressed by the packaging change.
21. As a developer skipping the heavy path, I want an environment switch that skips the Go build hook, so that source-only workflows (dependency resolution, wrapper-only compilation checks) don't pay a full Go build.
22. As a Status protocol team member, I want the SDS reliability layer consumed as a normal upstream nimble dependency of status-go, so that special-case checkout scripts and sibling-clone conventions disappear from consuming repos.

## Implementation Decisions

Decisions were settled in an interview session; the mechanical claims below were each verified empirically against nimble 0.22.3 with prototype packages, not taken from documentation.

- **Package shape:** one hybrid package rooted at status-go's repository top level (the Go sources must travel with the package because the artifact is built from source at the consumer). The package manifest stays fully declarative — verified that code in the manifest (imports/procs/tasks) degrades or hangs nimble's declarative parser, while hook blocks are safe. Tasks live in a companion nimscript file.
- **Artifact acquisition:** build from source. Go toolchain (plus NDK/Xcode for mobile targets) is a documented prerequisite, exactly as it is for every Status project today. No prebuilt-binary hosting is introduced.
- **Wrapper absorption:** the existing separate Nim wrapper package for libstatus is absorbed into the status-go repository, keeping its module name so existing imports compile unchanged. The separate wrapper repo requirement is dropped from status-desktop's manifest and lock. The wrapper and header now version together.
- **Auto-link with opt-out:** the wrapper module embeds its link flags (artifact paths computed from the package's own directory, per-OS frameworks/syslibs), gated behind a compile-time define for consumers with bespoke link setups. status-desktop initially keeps its explicit flags via the opt-out and can migrate later.
- **Executable delivery:** a thin Nim main declared as the package's `bin` entry, calling a new small cgo export on the Go side that wraps the existing status-backend server package (whose Go main is only flag parsing plus server setup). This makes the binary a real nimble artifact — built, symlinked, and uninstalled natively — and every install exercises the same wrapper+link path library consumers use.
- **Install mechanics** (verified with a prototype; the shape below encodes the load-bearing findings):

  ```nim
  # statusgo.nimble (declarative manifest + hooks only)
  bin         = @["status_backend"]     # hybrid: lib sources still install alongside
  installDirs = @["build"]              # carries untracked hook-produced artifacts into the store

  before build:                          # fires during `nimble install`, in the staging dir,
    exec "make <library-target>"         # BEFORE the Nim bin compiles → Go artifacts exist at link time
  ```

  Verified: hybrid packages install library sources next to the built binary and symlink the binary; `before build` runs during install ahead of the bin compile; `installDirs` copies untracked artifacts produced by the hook into the package store; `before install` is unsuitable (runs in the source dir; its outputs are not installed).
- **Build driver:** hooks and tasks shell out to status-go's existing Makefile targets. The Makefile already encodes build tags, ldflags/version stamping, CGO environment, and per-platform gates; reimplementing them in nimscript is permanent drift risk. make is already a hard prerequisite on all platforms (Windows via msys2).
- **Cross-compilation interface:** environment-driven package tasks (arch and NDK/SDK selection via env vars), matching the Nim ecosystem convention. `nimble install` always targets the host — which is what the executable use case needs. Flag-forwarded cross-install (`--os/--cpu` through install) is explicitly not built: hook nimscript is evaluated on the host without reliable access to those flags, and nimble's package store is target-blind (two targets of one version collide) — an upstream nimble limitation to be filed, not worked around.
- **status-desktop consumption:** single dependency graph. The app's manifest requires status-go; the git submodule is develop-linked so the app's one `nimble setup` resolves everything (SDS and FFI pins land in the app's lock). Develop-linked packages are not install-built, so desktop's Go builds remain task-driven through make. The separate per-status-go dependency cache and its second solve are deleted.
- **ADR 0003 preserved:** shared-artifact targets keep the order-only platform-cleanup sentinel prerequisite; the mobile library target keeps FORCE delegation to status-go's PHONY sub-make with compare-before-copy; status-desktop continues not to track status-go/nim-sds sources (the #18377 boundary).
- **SDS layer:** status-go's manifest owns the nim-sds pin as a normal `requires`; the sibling-clone convention and checkout scripts are gone. Until the three upstream nim-sds patches merge (dependency-range cap, iOS common-symbol fix, build-flag forwarding), the patched local clone is develop-linked into the app's graph.
- **Consumers pay a host Go build at dependency setup** (inherent to build-from-source, since nimble builds dependencies' binaries during setup); documented, with an environment switch to skip the hook for source-only workflows.
- Naming and versioning: package name and module name stay as today (`statusgo` package, `status_go` module); the new cgo export lives beside the existing mobile cgo exports.

## Testing Decisions

Good tests here exercise external behavior at package boundaries — what a consumer runs — never hook internals, task internals, or Makefile plumbing. If the boundaries hold, the plumbing is correct by construction.

Two seams (confirmed with the developer):

1. **The nimble package boundary (new, primary).** Exercised entirely from outside, as a third party:
   - Install proof: `nimble install` of the package on a clean nimble dir → `status_backend` appears on PATH via nimble's bin symlink and answers a real RPC request over HTTP.
   - Import proof: a throwaway consumer package containing only a `requires` on status-go and a program that `import status_go` and calls a real function → resolves, compiles, links (via auto-link), runs.
2. **The status-desktop make matrix (existing).** The established acceptance seam for the migration, unchanged: desktop build + launch, iOS app build, Android build. No new hooks into internals.

Prior art: the migration's phase acceptance runs used exactly the make-matrix seam (build + launch + on-device smoke); the install/import proofs mirror the toy-package verification harness used to validate nimble's hybrid/hook semantics during design.

## Out of Scope

- Prebuilt binary downloads (fast-path installs without a Go toolchain) — a release-engineering project with its own CI matrix; the hook design does not preclude adding it later.
- Flag-forwarded cross-compiling installs (`nimble install --os:... --cpu:...`) — blocked on nimble's target-blind package store and undefined hook/flag semantics; to be filed upstream as a nimble issue instead.
- Migrating status-go's Makefile logic into nimble as the single source of truth — deliberately rejected in favor of make remaining the build engine.
- status-desktop adopting auto-link (dropping its explicit link flags) — desktop starts on the opt-out; migration is a later, independent change.
- Windows validation — the design keeps make/msys2 exactly as today, but no Windows verification is performed in this change (the desktop Windows build is independently blocked).
- Fixing the known nimble vNext defects encountered during design (stale-lock drift; wrong vcsRevision recorded for URL dependencies) — reported upstream separately; workarounds are documented where they bite.
- Any change to the SDS wire protocol or its version selection — the pin bump accompanying this work is a separate, messaging-team-owned decision.

## Further Notes

- Parent effort: the nimble migration (#19907). This PRD covers the status-go packaging leg; phases 1–2 (workspace toolchain + vendor submodules → lock) are complete as pending changes on the migration branch.
- Upstream sequencing: the absorbed wrapper, cgo export, manifest/hooks, and Makefile adjustments in status-go ship as a status-go PR; the three nim-sds patches ship as upstream nim-sds PRs; status-desktop's submodule pointer and manifest flip once those land. Until then everything runs from develop-linked local checkouts.
- Every nimble mechanism this design depends on (hybrid lib+bin install, hook ordering relative to the bin compile, `installDirs` carrying untracked artifacts, hook impact on the declarative parser, subdir-URL support) was verified by experiment on nimble 0.22.3 during design, and the design uses only the verified subset.
