---
id: 0016
title: buildArtifacts goes native — cmake proc, qrcodegen {.compile.}, rcc, bootstrap, stale()
date: 2026-07-09
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md`

## What to build

`buildArtifacts` — already the `nimble build` prebuild hook — currently
delegates to make's `client-deps`, which fans out to every non-Nim artifact
the client links against. Make it do the work itself, so the dev flow has no
make in its process tree.

A new nimscript include (sibling of the shared env include) holds one
procedure per artifact; `buildArtifacts` becomes an ordered call list. The
hook contract with nimble does not change.

What moves:

- **cmake artifacts** — StatusQ, DOtherSide, the status-keycard-qt wrapper and
  the translations project all go through **one generic configure/build
  procedure**, invoked unconditionally: cmake's own incrementality is the no-op
  path (this is already how these behave under make). The 0011
  `FETCHCONTENT_SOURCE_DIR_<NAME>` redirect-pair contract is preserved
  verbatim — always pass the pair, empty value means pinned.
- **DOtherSide gets no investment**: it is dead on `origin/master` (`chore:
  Drop DOtherSide`) and simply rides the generic procedure until this branch
  merges master.
- **QR-Code-generator** is Nim-only — no StatusQ consumer. Its C source is
  compiled into the client by the Nim wrapper that already binds it, via
  `{.compile.}`. Delete the static-library target, its link flag, and its
  entanglement with the platform-sentinel cleanup. Cross-arch flags come free
  from the client compile.
- **Translations** are cmake-driven (Qt LinguistTools) and are *not* part of
  the client's artifact set: `compile-translations` becomes a driver **task**,
  not a build step. The lokalise fixup script stays inside the update task.
- **Brew bottles** (macOS) and **submodule initialisation** move into the
  driver's bootstrap. Submodule init is targeted, not blanket-recursive.
- **The setup stamp** is relocated, not preserved: the driver gates `nimble
  setup` on `nimble.paths` being stale with respect to the lock, the manifests
  and the develop overlay.

Exactly **two gating patterns** may exist afterwards, both documented in the
driver header:

1. `stale(outputs, inputs)` — an mtime scan with make's semantics. This is the
   prefactor that 0017's client compile will reuse; land it first.
2. The existing **key-file** pattern for keyed invalidation (store path, target
   triple, flags), as established by the status-go scratch engine.

`client-deps` is deleted. The mobile Makefile keeps its own path this
iteration and is untouched here.

## Acceptance criteria

- [ ] `nim app status.nims` builds a runnable app with **no `make` process in
      the tree** (verifiable by removing make from `PATH` for the run).
- [ ] No-op rebuild stays within the established envelope (~7 s desktop).
- [ ] Full build from a wiped store succeeds.
- [ ] The client links a QR code generator compiled via `{.compile.}`; the
      static library, its link flag and its platform-cleanup entry are gone.
- [ ] `rcc` output is regenerated when its inputs change and skipped otherwise.
- [ ] A fresh clone with uninitialised submodules bootstraps and builds.
- [ ] `nimble setup` is not re-run when the lock, manifests and overlay are
      unchanged.
- [ ] `compile-translations` is reachable as a driver task and is not run
      during a normal build.
- [ ] Develop-mode round trip still works for a cmake Vendor
      (status-keycard-qt) and a nimble-graph Vendor.
- [ ] Platform sentinel flip (desktop → iOS → desktop) still cleans shared
      artifacts correctly.
- [ ] Only `stale()` and the key-file pattern are used for gating; both are
      documented.
- [ ] `client-deps` no longer exists.
- [ ] `nim app status.nims` and `nimble build` are both green.

## Blocked by

- 0015 (soft): 0015 reworks the `config.nims` environment block that this slice
  builds around. Running them in parallel means a merge conflict there.
