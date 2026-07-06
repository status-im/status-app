# Nimble Migration & Nim-Library Architecture

**Date:** 2026-07-02
**Issue:** [status-im/status-app#19907](https://github.com/status-im/status-app/issues/19907)
**Related:** [status-app#21356](https://github.com/status-im/status-app/pull/21356), [nim-sds#84](https://github.com/logos-messaging/nim-sds/pull/84), [status-go#7583](https://github.com/status-im/status-go/pull/7583)

## Problem

`nim_status_client` links status-go; status-go links Nim libraries (nim-sds today,
logos-storage-nim opt-in, more Logos libs coming). This creates two problems:

1. **Build ergonomics.** status-go's Makefile clones and builds nim-sds as a sibling
   checkout (`../nim-sds`) with its own copy of nimbus-build-system. A Go build system
   is a poor home for Nim toolchain management, and every desktop/mobile developer pays
   for it.
2. **Duplicate Nim runtimes.** The app and each Nim library carry their own Nim runtime.
   With mismatched Nim versions or vendored deps this produces undefined behavior and
   crashes — worst on iOS, where everything is statically linked into one binary.
   Versions currently align by luck: the app pins Nim v2.2.4 via a vendored compiler
   while nim-sds independently declares `nim >= 2.2.6`; no solver connects them.

Separately, issue #19907 mandates replacing nimbus-build-system with Nimble for IDE
support, faster CI, and simpler integration of Logos Nim libraries.

## Ground truths that constrain the design

- **Go build modes are platform-asymmetric** (verified against Go's platform support
  matrix): iOS supports only `c-archive` (static), Android only `c-shared` (dynamic),
  desktop supports both. "Compile status-go statically everywhere" is impossible.
- **Android already runs status-go in a separate service process** (JNI stub/service
  split, `mobile/Makefile:57-78`). status-go must remain independently runnable there
  and as a server regardless of any linking scheme.
- **The duplicate-runtime collision only bites on iOS.** Desktop is fully dynamic
  (runtimes isolated by the dynamic linker); Android is cross-process. On iOS,
  nim-sds#84 fixes it robustly: `ld -r` partial-links all of libsds into one
  relocatable object exporting only `_Sds*`, localizing the entire Nim runtime.
- **status-go already supports consuming a prebuilt libsds** via
  `NIM_SDS_LIB_DIR`/`NIM_SDS_INC_DIR` (the mode Nix uses). This is the integration seam.
- **Prior art exists.** logos-delivery (#3798) and nim-sds (#52) completed the same
  nimbus-build-system → Nimble migration: single `.nimble` manifest, committed
  `nimble.lock` with exact `vcsRevision` per dep, `nimble setup --localdeps`, CI cached
  on `hashFiles('nimble.lock')`.
- **Nimble 0.22 capabilities verified locally** (macOS arm64, nimble 0.22.3):
  - `requires "nim == X"` auto-downloads and uses that exact compiler at build time
    (cached in `~/.nimble/nimbinaries/`). No choosenim, no vendored compiler.
  - `nimble develop --add:<path>` maps a package to an existing local checkout (e.g. a
    git submodule); source edits there are picked up on the next build. The directory
    must be under version control; note `--add` (existing checkout) vs `--path` (clone
    destination).

## Decision

**Option C — "Rehome": a Nimble workspace owns one lock and one toolchain for all Nim
artifacts; status-go consumes prebuilt Nim libraries through its existing external-lib
seam — designed to keep Option B (single Nim runtime on iOS) open as a future
optimization.**

Rejected alternatives:

- **A (Federate):** app migrates to nimble, status-go keeps building its own Nim libs.
  Leaves the ergonomics and version-skew problems unsolved.
- **B (Unify now):** compile Nim libs into the app's single runtime; status-go resolves
  `Sds*` symbols from the app. Only pays off on iOS (which #84 already fixes), costs
  platform-specific linking gymnastics and dual wiring in status-go, and Android still
  needs a standalone libsds for the service process. Kept as a possible future
  iOS-focused optimization, not the target.

## Target architecture

### Nimble workspace

- `nim_status_client.nimble` (today vestigial) becomes the real manifest: all pure-Nim
  deps as `requires` (git-URL + SHA pins for unpublished packages, logos-delivery
  style), an exact Nim version pin, plus a committed **`nimble.lock`** recording exact
  `vcsRevision` per dep — including nim-sds and logos-storage-nim.
- **Nim version selection:** the workspace pin must satisfy every pinned library's
  floor. nim-sds at the pinned v0.2.5 declares `nim >= 2.2.4`, matching the app's
  current 2.2.4, so Phase 1 pins **`requires "nim == 2.2.4"`**. (Newer nim-sds raises
  the floor to 2.2.6; the workspace pin moves together with the library pin, and the
  skew becomes visible at resolve time instead of shipping mismatched runtimes.)
- **Toolchain:** the developer environment owns Nim and nimble (choosenim or
  equivalent; documented in BUILDING.md). In Phase 1 the build system does not
  download, provision, or version-check compilers at all — nim-sds builds with the
  Nim on PATH (its own floor is `nim >= 2.2.4`). Pin *enforcement* arrives in Phase
  2, when nimble builds the app and resolves `requires "nim == X"` itself (nimble ≥
  0.22 self-provisions the pinned compiler — verified). No Nix dependency; works on
  Windows.
- **Make remains the top-level orchestrator** (qmake, cmake, Go builds, codesigning are
  not nimble tasks). Nimble owns the Nim subgraph: dependency resolution, compiler
  provisioning, and Nim compilation.

### Nim C-library artifacts (libsds, libstorage, future Logos libs)

- Declared as workspace dependencies and materialized as local checkouts synced to the
  lock (`nimble sync`); artifacts are built by invoking **each library's own upstream
  nimble tasks** (`libsdsIOS`, `libsdsAndroid`, `libsdsStaticMac`, …) with the
  workspace-provisioned toolchain.
- Rationale: same *toolchain* and same *dependency resolutions* as the app (one lock, no
  skew), but the packaging recipe (`--app:staticlib/lib --noMain
  --nimMainPrefix:<lib> --mm:refc`, the #84 symbol localization) is the library's
  correctness concern and stays owned upstream. Copying those recipes into status-app
  would fork them and reintroduce drift.
- **Developer workflow:** `nimble develop --add:<local-clone>` points the workspace at
  an editable checkout; edits compile on the next build. `nimble.develop` is local-only
  (not committed); CI builds strictly from `nimble.lock`.

### status-go: nimble package, submodule fetch (hybrid)

- **Dependency ownership inverts:** status-go grows a `statusgo.nimble` declaring its
  Nim dependencies (`requires "sds == 0.2.5"`, `requires "logos_storage == …"`). The
  app requires `statusgo`; nimble's solver unifies the graph. status-app no longer
  enumerates status-go's Nim deps, and no cross-repo version-pin CI guard is needed —
  the pin lives in one place, in the status-go repo, next to the Makefile that uses it
  (which should read the pin from the `.nimble` file, replacing `NIM_SDS_VERSION`).
- **Fetch mechanism stays the git submodule** (`vendor/status-go`), mapped into the
  nimble graph via a develop-mode local-path entry (verified mechanism). Rationale:
  status-go is needed by Make steps outside the Nim world (mobile stub-bindings
  generation, Android service lib, Go/NDK env), `vendor/status-go` paths are wired
  through the build, and git SHA pinning keeps CI diff visibility. Switching to a pure
  nimble-fetched dep later is a fetch-mechanism swap only.
- **Building libstatus stays a Make-orchestrated step**: build libsds for the target
  platform via its upstream task → pass `NIM_SDS_LIB_DIR`/`NIM_SDS_INC_DIR` (existing
  external mode) → `make -C vendor/status-go statusgo-{shared,ios,android}-library`.
  Two hardening fixes to this seam emerged during implementation: (a) status-go's
  mobile external-mode existence gates now check the target platform's lib extension
  (`libsds.so` for Android, `libsds.a` for iOS) rather than its `LIBSDS` variable's
  extension, which is derived from the *host* `LIB_EXT` (e.g. `.dylib` on a macOS
  build machine) and would never match a cross-compiled artifact; (b) status-go's
  `CGO_CFLAGS`/`CGO_LDFLAGS` injections for the nim-sds (and logos-storage) flag blocks
  use `override +=` instead of plain `+=`, because GNU make drops plain `+=` onto a
  variable that was also set as a command-line argument — so a caller passing
  `CGO_LDFLAGS=...` on the `make` command line was silently dropping `-lsds` from the
  link.
- status-go **retains its own clone-and-build path** for standalone builds (server,
  status-go CI) — unchanged.
- Consequence to accept: nimble's solver arbitrates if app and status-go ever want
  different versions of the same Nim lib — it fails at resolve time instead of shipping
  two copies. Bumping nim-sds in status-go implies a lock update in status-app.

### Nim C-library packaging contract

Every Nim library linked into a non-Nim host (status-go or the final app binary) must:

1. Build with `--noMain --nimMainPrefix:<libname>` and `-d:noSignalHandler`.
2. Export **only** its prefixed C API: Apple targets via the #84 `ld -r
   -exported_symbol` partial-link; ELF targets get the equivalent (version script or
   `objcopy --keep-global-symbols`) as Phase-2 hardening; Windows DLLs already export
   only marked symbols.
3. Ship a C header (`libsds.h`). **The header + link name is the only contract
   status-go may depend on — never the artifact kind.** This keeps Option B open:
   replacing "prebuilt libsds.a" with "symbols exported by the app binary" on iOS later
   is a link-time change invisible to status-go source.
4. Choose its own memory model (nim-sds uses `refc`; the app uses `orc`). Legal because
   runtimes are isolated; documented, not unified.

### Platform link matrix (unchanged from today)

| Platform | status-go | Nim libs | App ↔ libs |
|---|---|---|---|
| macOS/Linux/Windows | `c-shared` (dylib/so/dll) | shared | fully dynamic, runtimes isolated by loader |
| Android | `c-shared` `.so` | `.so` | status-go + libsds in separate service process |
| iOS | `c-archive` `.a` | `.a`, symbol-localized (#84) | one static binary; isolation via localization |

## Phasing (incremental; each phase ships independently)

### Phase 1 — Toolchain + Logos libs (fixes the pressing status-go pain)

- Real `nim_status_client.nimble` with the exact Nim pin; nimble-provisioned
  compiler; bootstrap make target. (`nimble.lock` arrives when there are
  nimble-resolvable deps to lock — the Logos C-lib pins live in `statusgo.nimble`
  as version constants until nim-sds is nimble-native, and the Nim pin is exact in
  the manifest.)
- Workspace builds libsds on all five platforms via upstream tasks; status-go consumes
  via `NIM_SDS_LIB_DIR`/`NIM_SDS_INC_DIR`; the sibling-clone requirement (`../nim-sds`)
  is removed.
- `statusgo.nimble` lands in status-go declaring its Nim deps; status-go's Makefile
  reads the pin from it. **Phase 1 form:** the pin is a greppable version constant
  (`const nimSdsVersion = "v0.2.5"`) rather than a `requires "sds == …"` clause,
  because nim-sds v0.2.5 predates its own nimble migration (two `.nimble` files,
  NBS-internal layout) and is not consumable as a nimble package. The requires-form
  and full solver unification activate when status-go's pin reaches a nimble-native
  nim-sds (v0.4.x era). For the same reason, Phase 1 builds libsds via the pinned
  version's upstream build interface — its Makefile (`make libsds USE_SYSTEM_NIM=1`)
  driven by the workspace-provisioned compiler — switching to pure nimble tasks when
  the pin moves.
- Absorb/land #21356's platform sentinel and first-class-libsds-target fixes
  (complementary).

### Phase 2 — App deps to nimble — DELIVERED (uncommitted; staged for human review)

Implemented largely as designed; four deviations from the plan, all recorded below
(evidence for each was verified against the working tree during implementation).
See `docs/superpowers/plans/2026-07-02-nimble-migration-phase2.md` for the task
breakdown.

- Migrated 25 of the ~32 candidate pure-Nim vendor submodules to
  `requires "<url>#<sha>"` entries in `nim_status_client.nimble`, locked via
  `nimble lock` → committed `nimble.lock`, revision-identical to their prior
  submodule SHAs (verified package-by-package). `nimble setup --localdeps`
  materializes them into the gitignored `nimbledeps/pkgs2/`; a Make stamp
  (`nimbledeps/.setup-stamp`, keyed on `nimble.lock`) re-runs it automatically as
  an order-only prerequisite of the desktop `nim_status_client` target.
- **Deviation — 7 packages dropped entirely, not migrated:** `chroma`, `edn.nim`,
  `semver.nim`, `nimage`, `nimPNG`, `nim-confutils`, `nim-websock` had zero
  importers anywhere in `src/` or the surviving Nim dependency graph. Proven, not
  assumed: after staging their submodule removal (Task 4) the app rebuilt clean
  and launched with all 32 candidate vendor dirs physically absent — no
  "cannot open file" errors named any of the 7, so none were restored.
- **Deviation — `isaac` has no direct `requires` line; it resolves transitively
  via `uuids`.** Adding an explicit `requires "https://.../isaac.git#<sha>"`
  alongside `uuids`' own `requires "isaac >= 0.1.3"` floor makes nimble's SAT
  resolver report "Unsatisfiable dependencies" (isolated repro confirmed:
  nim + uuids#sha + isaac#sha alone fails to lock). Omitting the explicit
  requires lets nimble satisfy the floor transitively, and it still resolves to
  the exact submodule SHA (`45a5cbbd54ff59ba3ed94242620c818b9aad1b5b`) — so
  revision-identity holds despite the pin being implicit rather than explicit.
  A second, related workaround was needed in `config.nims`: `nimble setup
  --localdeps` reliably emits both the package-root and package-root/`src`
  path entries in `nimble.paths` for every *directly*-required `srcDir: "src"`
  package, but for `isaac` — resolved only transitively — it emits just the
  root path and omits `/src`, breaking `import isaac`. Worked around with a
  small `config.nims` loop that finds `isaac-*` under `nimbledeps/pkgs2/` at
  build time and adds its `/src` path explicitly (hash suffix in the dir name
  changes whenever the lock is regenerated, so it can't be hardcoded). Both
  quirks are upstream-worthy (nimble transitive-pin path emission), not
  something to carry forward as permanent debt.
- Kept as submodules, exactly as planned, plus two the plan under-enumerated
  that also needed to stay (both non-Nim build tooling, unaffected by this
  section but listed for completeness): `nim-seaqt`, `nimqml-seaqt`,
  `DOtherSide`, `SortFilterProxyModel`, `QR-Code-generator`,
  `status-keycard-qt`, `status-go`, `fcitx5-qt`, `prl-to-pc`,
  `mobile/vendors/openssl`, `nimbus-build-system` (11 total). `nim-seaqt` and
  `nimqml-seaqt` are wired into the Nim compile via explicit
  `switch("path", ...)` entries in `config.nims` (`nimqml-seaqt/src` — its Nim
  sources live under `src/`; `nim-seaqt` root — its `seaqt/` package sits at
  the submodule root, no `src/` dir), verified against each package's actual
  source layout rather than assumed.
- **Deviation — nim-sds isolation gap found and fixed on the Android leg only:**
  nim-sds v0.2.5's `buildMobileAndroid` task (`sds.nimble`) invokes `nim c`
  without `--skipParentCfg`, unlike its own desktop/iOS tasks which hardcode it.
  Because Phase 1 moved the `nim-sds` checkout inside this workspace
  (`vendor/nim-sds`), Nim's parent-config search now walks up into the
  workspace's own `config.nims`, whose `--noNimblePath` (added in this phase)
  disables nim-sds's independent nimbus-build-system dependency discovery and
  breaks its Android build (`cannot open file: libp2p/protobuf/minprotobuf`).
  Fixed with a consumer-side shim — `scripts/nimsds.mk`'s `libsds-android`
  recipe passes `NIMFLAGS=--skipParentCfg:on` — staged, not upstream. Tracked
  as an upstream follow-up: `buildMobileAndroid` should hardcode
  `--skipParentCfg:on` like its sibling tasks, and the shim dropped once the
  nim-sds pin picks that up.
- **C-source deps of the Nim graph turned out to need no dedicated make
  recipes** (deviation from the plan's expectation of a `BearSSL.mk`-style
  pattern): bearssl, secp256k1, and zlib compile their bundled C via
  `{.compile.}` pragmas from within the package directory, which works
  identically whether the package lives in `nimbledeps/pkgs2/` or a submodule —
  confirmed by the clean vendor-less rebuild in Task 4.
- **ELF symbol-localization hardening deferred, not delivered:** out of scope
  for this phase per the plan's own risk register — it belongs upstream in
  nim-sds's own build, and Linux is not locally testable in this environment
  anyway.
- **Additional deviation not anticipated by the plan:** nimbus-build-system's
  `variables.mk` unconditionally sets `USE_SYSTEM_NIM := 0` on include,
  clobbering this phase's `USE_SYSTEM_NIM ?= 1` default regardless of ordering.
  The root `Makefile` reasserts `USE_SYSTEM_NIM := 1` immediately after the
  `-include $(BUILD_SYSTEM_DIR)/makefiles/variables.mk` line (an explicit
  command-line `make USE_SYSTEM_NIM=0` still overrides it, per make's variable
  origin precedence).

### Phase 3 — Retire nimbus-build-system

- Delete the submodule, `env.sh` plumbing, vendored-compiler bootstrap; CI drops
  compiler rebuilds; IDE setup documented (nimsuggest reads `nimble.paths`); optionally
  revisit pure nimble-fetch for status-go.

## Risks & mitigations

- **Nimble maturity** (macOS segfaults observed in nim-sds Nix Android cross-builds;
  stale-lock issues during logos-delivery review): pin the nimble version itself;
  tarball fallback for provisioning; lock-consistency check in CI.
- **Cross-repo version drift:** eliminated by design (solver-unified graph); residual
  risk is coordination cost of lock bumps, surfaced at resolve time.
- **Windows:** no Nix anywhere in the required path (explicit lesson from #3798);
  provisioning is plain download; existing `gen-import-lib.sh` flow unchanged.
- **Platform-switch artifact staleness:** #21356's sentinel, kept in Phase 1.
- **Compiler cache location:** nimble provisions compilers into `~/.nimble/nimbinaries/`
  even with `--nimbleDir` overridden — CI cache config must include it.

## Testing / acceptance

- **Phase 1:** fresh clone builds on macOS/Linux/Windows/Android/iOS with no sibling
  `../nim-sds`; the #21356 demo sequence (macos → ios → android → macos) passes;
  `nm build/libsds.a` (iOS) shows only `_Sds*` global symbols; app runs with SDS
  functional end-to-end.
- **Phase 2:** app binary behavior-identical (same deps at same revisions); clean-cache
  CI build time measurably improves vs nimbus-build-system baseline.
- **Ownership inversion:** a deliberate version conflict (app lock vs `statusgo.nimble`
  pin) fails at nimble resolve time with a clear error.

## Verified spikes (2026-07-02, macOS arm64, nimble 0.22.3 standalone binary)

1. Package with `requires "nim == 2.2.6"` on a system with nim 2.2.4: `nimble build`
   auto-downloaded 2.2.6 and built with it; binary reports 2.2.6.
2. `nimble develop --add:../libx` mapped a package to a local checkout; app built
   against it; editing the dep's source and rebuilding picked up the change with no
   extra steps. Requires the target directory to be under version control.

**Provisioning notes (revised during Phase 1 implementation):** Phase 1 ultimately
ships with **no compiler provisioning in the build system** — Nim/nimble are a
documented developer-environment prerequisite (choosenim), and nim-sds builds with
the Nim on PATH via `USE_SYSTEM_NIM=1`. Findings from the provisioning experiments,
recorded for Phase 2 (where nimble resolves `requires "nim == X"` for the app
build): (1) `nimble install nim@X` works with a standard user nimble 0.22.3
installation and provisions the full toolchain including `nimsuggest`; it must run
from a non-package directory (in a package directory nimble also tries to build
that package). (2) The same install through a session-downloaded standalone nimble
binary failed in `koch`/`nimsuggest`/`csources_v3` — environment-specific, does not
reproduce with a normal installation.
