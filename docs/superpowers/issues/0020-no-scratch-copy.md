---
id: 0020
title: No scratch copy — libstatus and libsds build from the read-only store copies
date: 2026-09-15
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: done
---

## Parent

Follow-up to the nimble migration (issue 0010, "status-go full-pin"), which
introduced the scratch copy this issue removes.

## Problem

Issue 0010 pinned status-go as a `URL#hash` nimble dependency, so the default
build resolves it to a READ-ONLY copy in nimble's package store — shared
between every consumer of that pin. But a status-go build wrote into its own
tree: `make generate` produced `*.pb.go`, migration bindata and mock packages;
`go:generate sh -c "… > FILE"` produced the `pkg/version` and `pkg/sentry`
files that `go:embed` then read back; the cbindings entry point was written to
`build/bin/statusgo-lib/main.go`; and `statusgo.nims` needed a `nimble.paths`
beside itself. nim-sds was worse: every task hardcoded `build/` and
`build/nimcache` relative to the working directory, located `./library`
the same way, and its entry point `sds.nims` had to be **symlinked into the
tree** before `nim <task>` would run at all.

So 0010 `cp -R`'d the whole store copy to `.statusgo-build/`, `chmod -R u+w`'d
it, copied the app's `nimble.paths` in, and `statusgo.nims` copied the nim-sds
store copy again to `.sds-build/` inside that. Two full source trees duplicated
per checkout, re-copied on every pin bump, and one more place for a build to
diverge from the tree the resolution actually names.

It also had a quiet bug: `pkg/version`'s `go:generate` runs `git describe`,
which walks UP from the working directory. The scratch copy sat inside
status-desktop, so status-go stamped the **desktop's** version into its own
`pkg/version/VERSION`.

## Decision

Nothing may be written into a package's source tree during a consumer build.
Every output — nimcache, objects, archives, shared libraries, the generated
cbindings entry point, key files — goes to a caller-chosen output directory.
Both resolved copies are then compiled IN PLACE, read-only or not, and
`.statusgo-build/` holds outputs only.

The output LAYOUT is unchanged, deliberately: `build/bin/libstatus.*` and
`.sds-build/{build,library}` still sit under `.statusgo-build/`, so every
`-L`/`-I` flag, rpath, packaging script and the platform sentinel kept working
untouched.

## What changed in each repo

### nim-sds (fork branch `nimble-v0.3.3`, `425287ae` + `0f8dc868`)

- `SDS_OUT_DIR` (default `build`, so the in-repo Makefile flow is unchanged) is
  the only directory any task writes to.
- `--nimcache` is set explicitly on every compile — the macOS/iOS tasks list
  the generated `.c` files by hand, so the location must be known.
- Sources are located from `thisDir()`, not from the working directory.
- The task entry point is COMMITTED instead of symlinked on demand:
  `library/sds_tasks.nims` for installed copies (see the installFiles wall
  below) and `sds.nims` at the root for checkouts, both one include of the
  manifest. The Makefile rule and the Nix `preBuild` hook that created the
  symlink are gone.
- ABI, `envNimFlags`, `nimLibDir` and the PR #85 localization are untouched.

### status-go (branch `nimble-phase1-pin-2`, `d71ea5d9d` + `a8a15198a` + `ba45188ab`)

- **The generated Go sources the library build needs are committed**: `*.pb.go`,
  `bindata.go`, `migrations.go`, `cmd/status-backend/server/endpoints.go`,
  `internal/protocol/messenger_handlers.go` — plus, unexpectedly,
  `pkg/services/connector/chainutils/mock/`: `pkg/services/connector/commands/
  test_helpers.go` is NOT a `_test.go` file, so the library build imports that
  one mock. Every other mock stays untracked.
  `scripts/cleanup_generated_files.sh` now sweeps only the untracked mocks.
- **`GENERATE_PREREQ`** (default `generate`) lets a consumer skip `make
  generate` entirely — which for a store copy would try to write into the
  package store. It also retires the `go install protoc-gen-go` line the
  desktop carried at three call sites.
- **`pkg/version` / `pkg/sentry` are `-ldflags -X` vars**, not `go:generate` +
  `go:embed` files. Same inputs (`git describe --tags`, `git rev-parse --short
  HEAD`, and the `SENTRY_CONTEXT_*` env vars embedders already set); the git
  probes run `git -C $(GIT_ROOT) … 2>/dev/null`, so a store copy gets the
  honest empty answer and falls back to `0.0.0-dev`/`unknown` instead of
  another repository's version.
- **`STATUS_GO_BUILD_DIR`** (default `$(GIT_ROOT)build`) roots every
  library-target output.
- **`statusgo.nims`**: `prepareSdsSource`/`.sds-build`/`mirrorInPlaceArtifacts`
  are gone. `STATUSGO_BUILD_DIR` takes the out dir from the caller,
  `STATUSGO_NIMBLE_PATHS` takes the resolution from the caller (and if a nested
  `nimble install` setup must generate one while this package IS a store copy,
  it lands in the out dir). The resolution is passed to the inner sds compile
  whole, sds entry included — the compiled copy IS the resolved copy, so there
  is no second sds to split type identities.

### status-desktop (this repo, `6f119cfa66`)

- `statusgoBuildRoot()` is now the OUTPUT root and is `.statusgo-build` in
  EVERY mode; the new `statusgoSourceRoot()` is the tree the sub-builds read
  (store copy, or `vendor/status-go` while developed). A develop checkout
  therefore stays clean too.
- `prepareStatusgoScratch` → `prepareStatusgoOut`: no `cp -R`, no `chmod`, same
  two keys (origin = resolved source root; artifact = flag set), with libstatus
  itself as the origin key's witness. `syncStatusgoPaths` is deleted.
- `buildLibsds` passes `STATUSGO_BUILD_DIR` + `STATUSGO_NIMBLE_PATHS` and runs
  `nim libsds <sourceRoot>/statusgo.nims` from the repo root. Its content key
  gained the artifact key: the flag-change arm drops libstatus only, and the
  old invalidation trick (touching the scratch `nimble.paths`) no longer has a
  file to touch.
- `buildLibstatus` drops the `go install protoc-gen-go` line and passes
  `STATUS_GO_BUILD_DIR`, `GENERATE_PREREQ=` and an explicit `STATUS_GO_VERSION`
  (the desktop version — the value the app always reported, now passed on
  purpose rather than inherited from a directory layout).
- Makefiles: `STATUSGO_ROOT` split into `STATUSGO_SRC` (derived from
  `nimble.paths` with `sed`, the same answer `statusgoSourceRoot()` gives) and
  `STATUSGO_OUT`; the `statusgo-scratch` target is `statusgo-out`; the
  `$(STATUSGO_ROOT)/nimble.paths` copy rule is deleted in both the root and the
  mobile Makefile. `make fix-wallet-migrations` still runs `go generate` in the
  statusgo tree and therefore now requires develop mode — noted in place.

## Verification record (Linux/WSL2, 2026-09-15)

Store integrity is the load-bearing check: `find <store copy> -type f | sort |
xargs md5sum` before and after.

- nim-sds alone: `libsdsDynamicLinux` and `libsdsStaticLinux` built from a
  `chmod -R a-w` copy, from an unrelated working directory, with `SDS_OUT_DIR`
  and the `NIMFLAGS` status-go passes. Copy byte-identical; working directory
  empty.
- status-go alone: `nim libsds statusgo.nims` + `make statusgo-shared-library
  STATUS_GO_BUILD_DIR=<out> GENERATE_PREREQ=` against a `chmod -R a-w` copy of
  the tree (no `.git`). 124 MB `libstatus.so` links, the `-X` values are in the
  binary, the copy is byte-identical (2561 files), the working directory stays
  empty.
- Full desktop chain: see the numbers appended to `progress.txt`.

### The overlay that does not work

The plan was to keep the cbindings entry point an in-module package path and
map it to the out-of-tree file with `go build -overlay`. Go's overlay does
supply a `main.go` for a path that does not exist on disk — but the package is
a cgo package, and cgo `chdir()`s into the real package directory first:

```
cgo: chdir /…/build/bin/statusgo-lib: no such file or directory
```

Only a committed placeholder directory would rescue that route. Instead the
file is handed to `go build` as a FILE (the synthetic `command-line-arguments`
package), which is what `statusgo-library` already did, and which needs
nothing committed.

### Two more walls, both paid for with a round-trip pin bump

- **nimble 0.22.3 ignores `installFiles`.** `installDirs` and `installFiles`
  are both resolved relative to `srcDir`, and even spelled `../sds.nims` —
  which nimble then finds, no "Missing file" warning — a root file is not
  installed. A `.nims` inside an `installDirs` directory does survive, hence
  `library/sds_tasks.nims`. And `nim <task> <pkg>.nimble` is not a fallback:
  nim answers "invalid command: libsdsDynamicLinux". It only appears to work
  when a `<pkg>.nims` sits beside the manifest, because nim loads that as the
  project config and the tasks come from there.
- **A stale store entry of the same package poisons the transitive
  special-version pick.** After two pin bumps the store held five
  `statusgo-0.1.0-*` copies requiring three different `sds#hash` revisions;
  nimble pre-bound sds to the wrong one and the resolution pointed at a copy
  the current pin does not name. `rm -rf` the stale `pkgs2/statusgo-*` and
  `pkgs2/sds-*` entries. A fresh store never sees this.

## Unverified legs

- **Mobile** (iOS + Android, both the nim-sds tasks and the status-go
  `statusgo-{ios,android}-library` targets): mechanically given the same
  out-dir treatment, never executed — no macOS host and no Android NDK here.
- **macOS and Windows** desktop: same.
- **Develop mode** (`nim develop status.nims statusgo` / `sds`): the code
  change is in (source root follows the overlay, outputs do not), not
  exercised.
- **`nimble build`** (the nimble front door, as opposed to the driver task).
- Byte-reproducibility of the fork's static libsds archive on this pin.
