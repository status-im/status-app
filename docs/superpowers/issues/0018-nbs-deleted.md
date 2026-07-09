---
id: 0018
title: NBS deleted — nimble is the only prerequisite, the store compiler is the compiler
date: 2026-07-09
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md`

## What to build

Delete the vendored nimbus-build-system. After 0017 its only remaining jobs are
to put a Nim compiler on `PATH` and to auto-init submodules — and the app
manifest already pins `nim == 2.2.4`, which nimble materialises in its own
store.

- **The machine prerequisite becomes nimble alone.** Post-clone bootstrap is
  `nimble setup && eval "$(nimble shellenv)"`, after which `nim` on `PATH` *is*
  the pinned compiler, by construction. No version guard is added — a
  bootstrapped shell cannot drift.

  *Spiked 2026-07-09*: with `PATH` scrubbed of both `~/.nimble/bin` and NBS
  (`which nim` → nothing), `nimble setup` resolved and used
  `pkgs2/nim-2.2.4-<checksum>/bin/nim`, and `nimble shellenv` emitted that
  `bin/` directory on `PATH`.

- **Internal `nim` invocations resolve the store compiler** — the driver, the
  status-go tasks, and the interim mobile make legs (which derive a `NIM`
  variable from `nimble.paths`). Artifacts are therefore governed by the
  manifest pin even when the caller's shell was never bootstrapped. This is
  what lets nimble-only CI agents run `make mobile-build`.

- **The submodule is removed** with the established backup-ref playbook
  (functional git dir preserved under the phase-2 vendor backup).

- **The root Makefile becomes self-contained**: local verbosity/output defines
  replace the NBS includes; there is no submodule auto-init `.DEFAULT` (the
  driver's bootstrap owns it since 0016).

- **Deleted with it**: `deps`, `update`, `deps-common`, `NIM_PARAMS`, the
  env-script wrapper, `.update.timestamp`, `NIM_SOURCES`, `REBUILD_NIM`. `make
  update` is **not** preserved as a shim — a shim perpetuates the front door
  being removed. `BUILDING.md` teaches the bootstrap and the driver instead.

- **`status-go-deps`** (a Go tool install) moves into status-go's own nimscript
  tasks.

The remaining C/C++ submodules (SortFilterProxyModel, QR-Code-generator,
fcitx5-qt, mobile openssl, and DOtherSide until master merges) are **pins, not
Vendors**, and stay submodules. `CONTEXT.md`'s end-state has been amended to
say so.

## Acceptance criteria

- [ ] **Nim-free machine proof**: from a fresh clone, with a `PATH` containing
      `nimble` and **no `nim`**, `nimble setup && nimble build` produces a
      runnable app; then `eval "$(nimble shellenv)" && nim app status.nims`
      succeeds. Recorded with the exact scrubbed `PATH`.
- [ ] Cold-store materialisation of the pinned compiler is verified (not just
      warm-store reuse).
- [ ] The nimbus-build-system submodule is gone; a backup ref preserves it.
- [ ] The root Makefile includes no external makefile and defines its own
      verbosity/output handling.
- [ ] `deps`, `update`, `deps-common`, `NIM_PARAMS`, the env-script wrapper,
      `.update.timestamp`, `NIM_SOURCES` and `REBUILD_NIM` no longer appear in
      either Makefile.
- [ ] The interim mobile make legs compile with the store compiler (no `PATH`
      Nim), proving the nimble-only-agent contract for `make mobile-build`.
- [ ] `make pkg-macos` still produces a signed dmg.
- [ ] `BUILDING.md` documents the nimble-only prerequisite and the bootstrap;
      no instruction references NBS or `make update`.
- [ ] `nim app status.nims` and `nimble build` are both green.

## Blocked by

- 0017 (hard: it removes the last consumers of the NBS env-script wrapper; NBS
  cannot be deleted while the Makefile still compiles Nim through it).
