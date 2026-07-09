---
id: 0017
title: driver owns every Nim compile — client, tests, launcher; make never invokes nim
date: 2026-07-09
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md`

## What to build

Three places still shell into `nim` from the root Makefile: the client compile,
the Nim test suite, and the Windows launcher. Move all three into the driver,
making **"the root Makefile never invokes `nim`"** a mechanically checkable
invariant.

- **Client** — the driver compiles it directly. `config.nims` has owned the
  full flag set since 0013 (parity-asserted), so this is a recipe move, not a
  flag move.
- **Nim tests** — become a driver task that owns the library-path environment
  the suite needs.
- **Windows launcher** — becomes a driver task; the Windows packaging target
  calls it.
- **`run-*` make targets are deleted.** The driver's `run` task has owned the
  launch environment since 0013; keeping both perpetuates two ways to run the
  app.
- **Packaging targets consume the driver-produced binary.** Signing,
  notarisation and dmg/AppImage/flatpak assembly are untouched — they simply
  stop depending on a make-built binary.
- **Windows flag branches are ported into `config.nims`** (the clang/msvc
  target flags, ssl version define, import-lib hooks). They are recorded as
  **ported, unverified** — a real Windows build belongs to the Windows push.
  Leaving them in make would restore the two-owners-of-one-flag-set problem
  this iteration exists to end.

`REBUILD_NIM` is replaced by two things: a developed nimble-graph Vendor skips
the `stale()` gate and always invokes the compiler, and an explicit force flag
on the `app` task serves humans.

**Invariant scope:** during this iteration the check applies to the **root**
Makefile only. The mobile Makefile still compiles the client for iOS/Android
(0018 makes it use the store compiler); it joins the invariant at the mobile
follow-on.

## Acceptance criteria

- [ ] The root Makefile contains **no `nim` invocation** — asserted by a grep
      check over `nim c`, `nim e` and the removed env-script wrapper. The check
      is recorded so it can be re-run.
- [ ] `nim app status.nims` compiles the client directly; the produced binary
      matches the pre-migration binary to the established parity floor
      (identical text/const/symbols; `LC_UUID`, OSO stab mtimes and signature
      excepted).
- [ ] `nim tests status.nims` runs the Nim suite green, with no make.
- [ ] The Windows launcher builds through a driver task (compile verified as
      far as a non-Windows host allows; recorded as ported, unverified).
- [ ] `make pkg-macos` produces a signed dmg from the driver-built binary.
- [ ] `run-*` make targets no longer exist; `nim run status.nims` launches the
      app.
- [ ] Windows flag branches exist in `config.nims` and nowhere else; the
      Makefile has no `NIM_PARAMS`.
- [ ] Forcing a full client rebuild works via the `app` task's force flag, and
      a developed Vendor's source change always reaches the binary.
- [ ] `nim app status.nims` and `nimble build` are both green.

## Blocked by

- 0016 (`buildArtifacts` must own the artifacts before the driver can own the
  compile that consumes them; `stale()` lands there and is reused here).
