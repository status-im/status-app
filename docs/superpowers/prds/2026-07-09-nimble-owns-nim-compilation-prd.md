---
title: Nimble owns Nim compilation — prl-to-pc nimble-native, NBS deleted, make demoted to packaging
date: 2026-07-09
tracker: local (GH publication deferred by user; all work stays local)
triage-label: ready-for-agent
parent: status-im/status-desktop#19907
predecessor: 2026-07-06-one-command-and-develop-mode-prd.md (closed over issues 0007–0014)
---

## Progress

| Issue | Slice | Status |
|-------|-------|--------|
| 0015 prl-to-pc nimble-native | upstream `qt_pkgconfig.nims` (`env`/`tools`/`generate`) authored in develop mode → prl-to-pc **v0.3.0** pushed + tagged → app pin bump; env-cache artifact; `config.nims` stops duplicating kit derivation; `make qt-pkgconfig*` deleted | **in progress** — all code landed & verified on both kits (Generated 6.11.0, System 6.11.1), store byte-identical, no-op 6.8–7.3 s. Interim pin = the v0.3.0 commit `#4a31fc06…`. **Awaiting the human push of prl-to-pc `main` + tag `v0.3.0`**, then the pin bump + remote re-solve |
| 0016 `buildArtifacts` goes native | `status_artifacts.nims`: generic cmake proc (StatusQ, DOtherSide, status-keycard-qt, translations), qrcodegen via `{.compile.}`, rcc, brew bottles, submodule bootstrap, setup-stamp absorption, `stale()` helper; `client-deps` deleted | open |
| 0017 driver owns the Nim compiles | client, nim tests, windows launcher become driver tasks; `run-*` targets deleted; Windows flag branches ported into `config.nims` (ported, unverified); packaging consumes the prebuilt binary | open |
| 0018 NBS deleted | submodule removed (backup ref); root Makefile self-contained; store-nim rule; `REBUILD_NIM`/`.update.timestamp`/`NIM_SOURCES`/`deps`/`update` gone | open |
| 0019 CI nimble-only | Jenkinsfiles build via `nimble build` + task aliases; agent prerequisite becomes **nimble only** | open |

## Problem Statement

After iteration 2 the app resolves every Vendor through one nimble graph and
builds with one command — but **make is still the thing that compiles Nim**.
The driver (`nim app status.nims`) is a delegating front door: underneath, a
1352-line root Makefile shells into `nim c` for the client, the Nim tests and
the Windows launcher, fans out to every non-Nim artifact, and inherits its
scaffolding from a vendored copy of nimbus-build-system (NBS) — a submodule
whose only remaining jobs are to provide a Nim compiler on `PATH` and to
auto-init submodules.

Three concrete costs fall out of that:

1. **Two owners of the same knowledge.** `config.nims` owns the client's flag
   set (issue 0013), yet the Makefile still carries the Windows `NIM_PARAMS`
   branches; `config.nims` derives the Qt kit's `.pc` tree path, and so does
   prl-to-pc's `qt-pkgconfig.mk` — two implementations of prl-to-pc's own
   layout knowledge, one of which (the app's) silently lacks the
   System-vs-Generated probe that now lives upstream. Divergence is a matter
   of time.
2. **The toolchain is provisioned twice, inconsistently.** Every developer and
   every CI job puts NBS's vendored Nim on `PATH`, while the manifest pins
   `nim == 2.2.4` and nimble materialises that compiler in its own store. The
   pin governs `nimble build`; the `PATH` governs everything else. Nothing
   enforces that they agree.
3. **make is a prerequisite for a Nim developer.** A contributor who wants to
   build the app needs GNU make, a vendored build-system submodule, and the
   knowledge of which target to invoke — in a project whose dependency
   manager, compiler and build driver are all already nimble/nimscript. On
   Windows that make dependency is an msys2 dependency.

Meanwhile prl-to-pc — the Vendor that supplies Qt's `.pc` trees and the
pkg-config wrapper — publishes its consumer interface **as a makefile**
(`qt-pkgconfig.mk`). A make-free dev flow cannot consume it.

## Solution

**Nimble and nimscript own all Nim compilation. make survives only for
packaging and CI-only helpers, and never invokes `nim`.**

From the developer's perspective:

- The only machine prerequisite is **nimble**. After cloning:
  `nimble setup && eval "$(nimble shellenv)"` puts the *pinned* compiler on
  `PATH` — by construction, not by convention. `nimble build` works with no
  Nim on `PATH` at all.
- `nim app status.nims` remains the fast daily front door (~6 s no-op) and now
  builds everything itself: it orchestrates the cmake artifacts, the
  resources, the Qt pkg-config tooling and the client compile, with no `make`
  in the process tree.
- prl-to-pc ships a **nimscript consumer interface** (`qt_pkgconfig.nims`,
  executed via `nim e`) alongside the existing makefile, so the app consumes
  Qt kit derivation, the System/Generated probe, tool building and `.pc`
  generation from **one upstream source of truth** instead of a local copy.
- NBS is deleted. The Nim compiler comes from the nimble graph; submodule
  bootstrap comes from the driver.
- `make` remains for `pkg-*`, notarisation/signing, flatpak, storybook, the
  interim mobile legs and CI helpers. It consumes the binary the driver
  produced; it never compiles Nim.

## User Stories

1. As a Nim developer cloning status-desktop, I want the only prerequisite to
   be nimble, so that I do not have to install or vendor a build system.
2. As a Nim developer, I want `nimble setup && eval "$(nimble shellenv)"` to
   put the project's pinned compiler on my `PATH`, so that my Nim version can
   never drift from the manifest.
3. As a developer with no Nim on `PATH`, I want `nimble build` to produce a
   runnable app, so that a bare nimble installation is a sufficient
   environment.
4. As a developer, I want `nim app status.nims` to build the whole app without
   invoking make, so that the build has one owner and one mental model.
5. As a developer, I want the no-op rebuild to stay in the seconds range after
   make is removed, so that the daily loop does not regress.
6. As a developer, I want the client's compile flags to live in exactly one
   place for every platform, so that a Windows-only flag cannot silently
   diverge from the macOS one.
7. As a developer on a Qt kit that ships working `.pc` files, I want the build
   to use the kit's own pkg-config data (System mode) with no wrapper, so that
   I am not shadowed by a generated tree I do not need.
8. As a developer on a Qt kit with a broken prefix, I want the build to
   transparently fall back to the committed relocatable `.pc` trees and the
   wrapper (Generated mode), so that the kit's defect is invisible to me.
9. As a developer, I want prl-to-pc to decide which pkg-config mode applies,
   so that the app never re-implements prl-to-pc's layout or probe logic.
10. As a prl-to-pc maintainer, I want the nimscript consumer interface to live
    in prl-to-pc, so that every consumer — not just status-desktop — gets kit
    derivation, tool building and generation for free.
11. As a prl-to-pc consumer that still uses make, I want `qt-pkgconfig.mk` to
    keep working unchanged in v0.3.0, so that an interface addition does not
    force me to migrate.
12. As a developer hacking on prl-to-pc, I want `nim develop status.nims
    prl-to-pc` to let me author the new interface against the live app build,
    so that the two-repo change can be validated before anything is pushed.
13. As a developer, I want the Qt pkg-config tools to be built into a
    repo-local directory and never into the package store, so that pinned
    content stays byte-identical across builds.
14. As a developer, I want `.pc` regeneration to be an explicit, deliberate
    command that refuses to run against a read-only store copy, so that I
    cannot accidentally mutate pinned content.
15. As a developer, I want the pkg-config environment to be computed once per
    build and cached, so that every subsequent `nim` invocation (including
    nimsuggest) does not fork a subprocess to recompute it.
16. As a developer, I want the driver to build StatusQ, DOtherSide,
    status-keycard-qt and the translations through one generic cmake step, so
    that adding or removing a cmake artifact is a one-line change.
17. As a developer, I want cmake's own incrementality to be the no-op path for
    cmake artifacts, so that the driver does not reimplement dependency
    tracking that cmake already does.
18. As a developer, I want the QR code generator compiled into the Nim binary
    by the Nim wrapper that uses it, so that there is no separate C library,
    no platform-cleanup interplay and no extra link flag.
19. As a developer, I want Qt resources (rcc) regenerated only when their
    inputs changed, so that a no-op build stays a no-op.
20. As a developer on macOS, I want the brew bottles fetched as part of
    bootstrap, so that a fresh clone builds without a separate command.
21. As a developer, I want missing submodules initialised by the driver's
    bootstrap, so that a fresh clone builds out of the box without make's
    auto-init.
22. As a developer, I want dependency resolution re-run only when the lock,
    the manifests or the develop overlay changed, so that I do not pay a
    re-solve on every build.
23. As a developer, I want one documented staleness helper used by every
    generated artifact, so that gating logic is uniform and reviewable.
24. As a developer, I want `nim tests status.nims` to run the Nim test suite,
    so that testing does not require make.
25. As a developer, I want to force a full client rebuild explicitly, so that
    I have a replacement for `REBUILD_NIM=true` when I need one.
26. As a developer working on a Vendor in develop mode, I want the client to
    be rebuilt unconditionally, so that my Vendor's source changes always
    reach the binary.
27. As a developer, I want `run-*` make targets removed now that the driver's
    `run` task owns the launch environment, so that there is one way to run
    the app.
28. As a release engineer, I want `make pkg-macos` / `pkg-linux` /
    `pkg-windows` to consume the binary the driver built, so that the shipped
    artifact is compiled by the same path developers use.
29. As a release engineer, I want signing, notarisation, dmg/AppImage/flatpak
    assembly to stay in make and scripts, so that this migration does not
    touch the release-critical path.
30. As a release engineer building for Windows, I want the launcher built by a
    driver task, so that no packaging step compiles Nim through make.
31. As a maintainer, I want a mechanical check that make never invokes `nim`,
    so that the invariant is enforced rather than asserted.
32. As a CI maintainer, I want agents to need only nimble, so that image
    provisioning does not carry a Nim toolchain or a build-system submodule.
33. As a CI maintainer, I want pipelines to build via `nimble build` and the
    driver's nimble task aliases, so that CI exercises the same paths a
    developer uses.
34. As a CI maintainer, I want the per-invocation nimble dispatch tax to be
    acceptable on CI while developers keep the fast `nim` driver path, so that
    neither audience pays for the other's constraints.
35. As a maintainer, I want NBS deleted rather than merely unused, so that the
    repository does not carry a dead build system.
36. As a maintainer, I want the root Makefile to be self-contained after NBS
    is gone, so that packaging does not depend on an external makefile
    include.
37. As a mobile developer, I want the mobile build to keep working through its
    existing make path during this iteration, so that the desktop migration is
    not gated on a device test matrix.
38. As a mobile developer on a nimble-only agent, I want the mobile make legs
    to compile with the store's pinned Nim, so that they do not depend on a
    `PATH` compiler that no longer exists.
39. As a maintainer, I want each slice to leave `nim app` and `nimble build`
    green, so that the migration is bisectable and revertable.
40. As a maintainer, I want the prl-to-pc push gate identified before
    implementation starts, so that no slice stalls waiting for an upstream
    release.

## Implementation Decisions

**Front door and toolchain**

- The **App entry point** stays `nim app status.nims`; `nimble build` remains
  the out-of-the-box path (issue 0013). Neither the ~46–78 s nimble dispatch
  tax nor the driver's role is re-litigated.
- The **dev environment owns nimble only**. `requires "nim == 2.2.4"` in the
  app manifest is the single source of truth for the compiler; nimble
  materialises it in the store, and `nimble shellenv` exposes it. No version
  guard is added — a bootstrapped shell cannot drift. *(Spiked 2026-07-09: with
  `PATH` scrubbed of `~/.nimble/bin` and NBS, `nimble setup` resolves and uses
  the store compiler; `nimble shellenv` emits its `bin/` directory.)*
- **Internal `nim` invocations resolve the store compiler** (driver, statusgo
  tasks, and the interim mobile make legs via a `NIM :=` derived from
  `nimble.paths`), so artifacts are governed by the manifest pin even when the
  caller's `PATH` is not bootstrapped.

**prl-to-pc consumer interface (upstream v0.3.0)**

- prl-to-pc gains `qt_pkgconfig.nims`, **executed via `nim e`**, not included.
  A dynamic store path (`prl_to_pc-0.2.0-<checksum>`) cannot be reached by
  `include`/`import`, because those resolve at parse time while
  `nimble.paths`'s `--path` switches only take effect at script runtime.
  Subcommands:
  - `env` — prints `KEY=VAL` lines describing the pkg-config environment, or
    nothing in System mode. Owns kit derivation and the System/Generated probe.
  - `tools <buildDir> <consumerPaths>` — builds the pkg-config wrapper and the
    generator from package sources, resolving `regex`/`unicodedb` through the
    consumer's `nimble.paths`.
  - `generate` — regenerates a kit's `.pc` tree; refuses when the package root
    is a store copy (`nimblemeta.json` marker).
- `qt-pkgconfig.mk` is **retained unchanged** in v0.3.0 (dual interface): the
  interim mobile make legs and any external make consumer keep working.
  Removing the makefile interface is a later major-version decision.
- The app's driver calls `env` once per build and **caches the result** in a
  repo-local, gitignored artifact keyed on (qmake path, resolved package root,
  kit). `config.nims` reads that file and `putEnv`s — no subprocess per Nim
  invocation. A missing cache file fails fast, naming the driver.
- `config.nims` **stops deriving the kit's `.pc` path** and stops asserting on
  the wrapper's existence: in System mode there is no wrapper, and only the
  upstream `env` command knows which mode applies.
- Pin becomes the annotated tag **`#v0.3.0`**, cut from prl-to-pc `main`
  (which already carries the probe-mode work and the space-safe consumer-paths
  fix). Tag pins resolve on nimble 0.22.3 (issue 0014); the pkgcache key
  embeds the ref, so a new tag mints a fresh clone and the pkgcache-staleness
  wall does not apply.
- The change is authored **in develop mode** (`nim develop status.nims
  prl-to-pc`) against the live app build, then pushed, tagged, undeveloped and
  re-verified from the store. **PUSH GATE:** the app pin bump cannot land
  before v0.3.0 is pushed.

**Artifact orchestration**

- A new nimscript include (sibling of the existing shared env include) holds
  one procedure per artifact; `buildArtifacts` — already the `nimble build`
  prebuild hook — becomes an ordered call list. The hook contract does not
  change.
- **cmake artifacts** (StatusQ, DOtherSide, status-keycard-qt wrapper,
  translations) go through one generic configure/build procedure and are
  invoked unconditionally: cmake's own incrementality is the no-op path. The
  0011 `FETCHCONTENT_SOURCE_DIR_<NAME>` redirect-pair contract is preserved
  verbatim.
- **DOtherSide** receives no investment: it is dead on `origin/master`
  (`chore: Drop DOtherSide`) and rides the generic cmake procedure until this
  branch merges master.
- **QR-Code-generator** is Nim-only (no StatusQ consumer). Its C source is
  compiled into the client by the Nim wrapper that already binds it, via
  `{.compile.}`. The static library target, its `--passL`, and its
  platform-cleanup interplay are deleted. Cross-arch flags are inherited from
  the client compile.
- **Translations** are cmake-driven (Qt LinguistTools) and are *not* part of
  the client's artifact set: `compile-translations` becomes a driver task, not
  a build step. The lokalise fixup script stays inside the update task.
- **Brew bottles** and **submodule initialisation** move into the driver's
  bootstrap. Submodule init is targeted, not blanket-recursive.
- The **setup stamp** is not a survivor but a relocation: the driver gates
  `nimble setup` on `nimble.paths` being stale with respect to the lock, the
  manifests and the develop overlay.
- Exactly **two gating patterns** exist and are documented in the driver
  header: a `stale(outputs, inputs)` mtime scan (make semantics), and the
  existing key-file pattern for keyed invalidation (store path, target triple,
  flags) established by `.statusgo-build`.
- **nimterop is rejected.** Its binding generation is unnecessary (bindings are
  handwritten) and its build orchestration is compile-time, target-blind, and
  unmaintained since April 2023 — its own documentation discourages `cCompile`
  for projects that rely on build tools. The stdlib `{.compile.}` pragma
  covers the only need.

**Nim compilation moves out of make**

- The client, the Nim test suite and the Windows launcher become driver tasks.
  Packaging targets depend on the driver-produced binary.
- `run-*` make targets are deleted; the driver's `run` task owns the launch
  environment (issue 0013).
- The Windows-only flag branches are **ported into `config.nims`** now and
  recorded as *ported, unverified* — the same honest-record pattern used for
  0012's Android seaqt leg. Leaving them in make would restore the two-owner
  problem this iteration exists to end.
- The invariant is mechanical: **no `nim` invocation in the root Makefile**.
  During this iteration the invariant is scoped to the root Makefile; the
  mobile Makefile joins at the mobile follow-on (it still compiles the client
  for iOS/Android, using the store compiler).
- `REBUILD_NIM` is replaced by: a developed nimble-graph Vendor skips the
  `stale()` gate and always invokes the compiler, plus an explicit force flag
  on the `app` task for humans.

**NBS deletion**

- The submodule is removed with the established backup-ref playbook
  (`.phase2-vendor-backup/`).
- The root Makefile becomes self-contained: local verbosity/output defines
  replace the NBS includes; there is no `.DEFAULT` submodule auto-init.
- Deleted with it: `deps`, `update`, `deps-common`, `NIM_PARAMS`,
  `ENV_SCRIPT`, `.update.timestamp`, `NIM_SOURCES`, `REBUILD_NIM`. `make
  update` is not preserved as a shim — a shim perpetuates the front door being
  removed; `BUILDING.md` teaches the driver instead.
- `status-go-deps` (a Go tool install) moves into status-go's own nimscript
  tasks.
- The remaining C/C++ submodules (SortFilterProxyModel, QR-Code-generator,
  fcitx5-qt, mobile openssl, and DOtherSide until master merges) are **pins,
  not Vendors**, and stay submodules. `CONTEXT.md`'s end-state has been
  amended to say so.

**CI**

- Agents require **nimble only**. Pipelines build with `nimble build` and
  invoke driver tasks through the existing nimble task aliases (`include
  "status.nims"` in the manifest, with `--os`/`--cpu` forwarding verified
  2026-07-07). Packaging pipelines call `make pkg-*` against the prebuilt
  binary.
- Jenkinsfile changes ship in this iteration; they are **statically reviewed
  here and verified by real pipeline runs after push** — this repository
  cannot execute Jenkins. The issue carries a CI-verification checklist, not a
  pass claim.

## Testing Decisions

A good test here exercises **external behaviour at the build system's public
seams** — the commands a developer or CI actually types — and asserts on
observable outputs (binary exists and runs, artifact bytes, process tree,
timing envelope). It never asserts on the internal structure of a nimscript
procedure. This mirrors how issues 0007–0014 were verified: an explicit
verification record per issue, reproducible from a clean state.

**Seams, in preference order (fewest, highest):**

1. **`nim app status.nims [--os --cpu]`** — the primary seam. Everything the
   dev flow does is reachable here. Assertions: exit status, the binary runs,
   no-op timing envelope, and *no `make` process in the tree* (the
   make-free-dev-flow claim, observable via a process check or by removing
   make from `PATH` for the duration).
2. **`nimble build`** — the out-of-the-box seam. Asserted from a **fresh
   clone with a `PATH` containing nimble and no Nim**, proving the
   nimble-only-machine contract; then `eval "$(nimble shellenv)"` and the
   driver path.
3. **`nim e <package root>/qt_pkgconfig.nims <subcommand>`** — prl-to-pc's new
   public interface. Tested in prl-to-pc against real kits (System-mode kit and
   Generated-mode kit) via its existing hermetic harness (prl-to-pc already
   carries `tests/test_qt_pkgconfig_mk.nim` wired into `nimble test` — the
   nimscript interface joins that suite), and from the app by building on both
   kinds of kit.
4. **A grep invariant on the root Makefile** — no `nim` invocation. Cheap,
   mechanical, and the only assertion that keeps the architecture from
   regressing silently.

**What is exercised where:**

- *prl-to-pc*: subcommand behaviour, both probe modes, the store-copy
  generation refusal, and byte-identity of the store entry across builds
  (tools must never be written into the store). Prior art: the 0014
  verification record and prl-to-pc's own test harness.
- *Driver / artifacts*: wiped-store full build; no-op timing; develop-mode
  round trip per Vendor (`develop` → probe change observed in the build →
  `undevelop` → return to pin); platform sentinel flip (desktop → iOS →
  desktop). Prior art: issues 0009–0014 verification records.
- *Toolchain*: the nim-free-machine proof (0018's gate); a cold-store
  materialisation of the pinned compiler.
- *Parity*: the driver-produced binary and the pre-migration binary agree to
  the established floor (identical text/const/symbols; `LC_UUID`, OSO stab
  mtimes and signature excepted), reusing 0013's byte-compare method.
- *Packaging*: `pkg-macos` produces a signed dmg from the driver-built binary.
  Linux/Windows packaging is statically reviewed only (no agents here).

Nothing in this iteration introduces a new runtime seam in the application
itself; there is no product behaviour to test.

## Out of Scope

- **Mobile's make legs.** The iOS/Android build keeps its existing make path
  this iteration (it consumes prl-to-pc through the retained makefile
  interface and compiles with the store Nim). Converting the mobile Makefile
  to the driver is a follow-on issue whose cost is a device test matrix.
- **Storybook**, which stays a make target by explicit decision.
- **Packaging internals**: signing, notarisation, dmg/AppImage/flatpak/fdroid
  assembly, and the Windows resource compilation stay in make and scripts.
- **Verifying the Windows leg.** Its flags are ported; a real Windows build
  belongs to the Windows push.
- **Converting the remaining C/C++ submodules** to FetchContent pins.
- **Deleting `qt-pkgconfig.mk`** from prl-to-pc.
- **Executing CI**: pipeline definitions change here; their green runs happen
  after push.
- The standing carry-overs unchanged by this PRD: issue 0006 (sds target
  subdir artifact packages, upstream-gated), the seaqt `qt-6.11` pin
  evaluation, and the status-go `nimble-phase1-pin` → `develop` PR.

## Further Notes

- **Ordering.** 0015 runs first: it is the only slice with an external push
  gate (prl-to-pc v0.3.0), and its develop-mode authoring loop is independent
  of the artifact refactor. 0016 → 0017 → 0018 then proceed strictly
  (0017 removes the last `ENV_SCRIPT` consumers that 0018's NBS deletion would
  otherwise break); 0019 lands last.
- Every slice must leave both `nim app status.nims` and `nimble build` green,
  so the iteration stays bisectable.
- **Serendipity worth recording**: `nimble shellenv` already derives the store
  compiler's `bin/` from the project's own graph. The "dev environment owns
  the toolchain" ruling from Phase 1 therefore costs nothing and provisions
  the *pinned* compiler rather than merely *a* compiler — closing, by
  construction, the drift hole that a version guard would otherwise have to
  police.
- Two decisions in this PRD are candidates for an ADR once implemented: *Nim
  compilation is owned by nimble/the driver, and the store compiler is the
  compiler* (hard to reverse, surprising, genuinely traded off against a
  `PATH`-nim world); and *a Vendor's consumer interface is executed, not
  included* (forced by nimble's path-resolution timing — a future reader will
  ask why prl-to-pc ships a script instead of an include).
- The upstream-asks ledger gains no new nimble issues from this iteration; the
  `nim e` interface exists *because of* ask #8-adjacent constraints already
  filed (dynamic store paths, parse-time include resolution).
