---
id: 0015
title: prl-to-pc nimble-native — executed nimscript interface, v0.3.0 pin, env cache
date: 2026-07-09
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md`

## What to build

prl-to-pc's consumer interface today is a **makefile**. A make-free dev flow
cannot consume it, and the app has grown a second, silently-divergent copy of
prl-to-pc's kit-derivation logic (which lacks the System/Generated probe that
now lives upstream).

Give prl-to-pc a **nimscript consumer interface** and make the app consume it
as the single source of truth.

Upstream (prl-to-pc, released as **v0.3.0** cut from `main`) gains
`qt_pkgconfig.nims`, invoked as `nim e <package root>/qt_pkgconfig.nims <cmd>`:

- **`env`** — prints `KEY=VAL` lines describing the pkg-config environment for
  the current Qt kit, or nothing when the kit's own pkg-config data is usable
  (System mode). Owns kit derivation *and* the System/Generated probe.
- **`tools <buildDir> <consumerPaths>`** — builds the pkg-config wrapper and
  the `.pc` generator from package sources, resolving `regex`/`unicodedb`
  through the **consumer's** `nimble.paths`.
- **`generate`** — regenerates a kit's `.pc` tree; refuses when the package
  root is a store copy.

`qt-pkgconfig.mk` is **retained unchanged** in v0.3.0: the interim mobile make
legs and any external make consumer keep working (dual interface; removing the
makefile is a later major-version decision).

The app consumes it through the driver: `buildArtifacts` calls `tools`, then
calls `env` once and **caches** the result to a repo-local, gitignored
artifact keyed on (qmake path, resolved package root, kit). `config.nims`
reads that cache and sets the environment — no subprocess per Nim invocation.
`config.nims` stops deriving the `.pc` tree path and stops asserting that a
wrapper exists (in System mode there is none). `generate` becomes an explicit
driver task, never a build step. The app's `make qt-pkgconfig*` targets are
deleted; the Makefile's own inclusion of `qt-pkgconfig.mk` survives only for
the interim mobile legs.

**The interface must be executed, not included.** The store path is dynamic
(`prl_to_pc-0.2.0-<checksum>`), and `include`/`import` resolve at *parse* time
while `nimble.paths`'s `--path` switches only take effect at script *runtime* —
so no config or driver script can `include` a file from the store. This
constraint is the whole reason for the `nim e` shape.

**Authoring order (this is also the acceptance path):** author in develop mode
(`nim develop status.nims prl-to-pc`, checkout from `main`, not the `v0.2.0`
tag) against the live app build; only once the desktop and iOS legs pass, push
to prl-to-pc `main`, cut the annotated tag `v0.3.0`, `undevelop`, bump the app
pin to `#v0.3.0`, and re-verify from the store.

**PUSH GATE:** the app's pin bump cannot land before v0.3.0 is pushed. Known up
front (unlike 0014, where it was discovered at the end).

## Acceptance criteria

- [ ] `nim e <root>/qt_pkgconfig.nims env` prints a correct environment on a
      Generated-mode kit and an empty/no-op environment on a System-mode kit;
      both are covered by prl-to-pc's own `nimble test` harness.
- [ ] `generate` refuses to run against a store copy, with an actionable
      message; it succeeds from a develop checkout.
- [ ] The app builds and launches on a **Generated-mode kit** (Qt 6.11.0).
- [ ] The app builds on a **System-mode kit** (Qt 6.11.1 or 6.12) — proving
      `config.nims` no longer requires a wrapper to exist.
- [ ] `config.nims` contains no kit derivation (`.pc` path, kit, version) and
      no wrapper assertion; the environment comes from the cached `env` output.
- [ ] The prl-to-pc store entry is **byte-identical** before and after a full
      build (tools land in the repo-local build dir, never in the store).
- [ ] The env cache is regenerated when its key changes (qmake path, package
      root, kit) and dropped on develop-mode flips.
- [ ] `make qt-pkgconfig`, `qt-pkgconfig-tools` and `qt-pkgconfig-generate` no
      longer exist; the desktop build never invokes them.
- [ ] prl-to-pc `v0.3.0` is pushed and tagged; the app pin is `#v0.3.0`; a
      wiped store entry re-solves it from the remote.
- [ ] Develop round-trip: `develop prl-to-pc` → an upstream edit is observed in
      the app build → `undevelop` → build returns to the pinned store entry.
- [ ] `nim app status.nims` and `nimble build` are both green.

## Blocked by

None — can start immediately. (Carries its own external push gate for the
final pin bump; all authoring and verification proceed in develop mode before
it.)
