---
id: 0019
title: CI nimble-only — pipelines build through nimble, agents need no Nim toolchain
date: 2026-07-09
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md`

## What to build

CI today gets its compiler from the vendored build system and drives everything
through make targets. After 0018 neither exists. Move the pipelines onto the
same paths a developer uses.

- **Agent prerequisite becomes `nimble` only.** No Nim toolchain on the image,
  no build-system submodule. (`choosenim` provisioning and a manifest-version
  extraction script were considered and rejected: the compiler already comes
  from the nimble graph.)
- **Build via `nimble build`**, which needs no `nim` on `PATH`. Driver tasks CI
  needs (tests, the Windows launcher) are reached through the **nimble task
  aliases** the manifest already exposes, with `--os`/`--cpu` forwarding
  (verified 2026-07-07). The ~1-minute nimble dispatch tax is noise on CI while
  developers keep the fast `nim` driver path.
- **Packaging pipelines** call `make pkg-*` against the prebuilt binary.
- Pipelines that called `make deps` / `make update` drop those steps: resolution
  and bootstrap are part of the build.

This slice changes pipeline definitions only. It contains no application
change and is the one slice that **cannot be verified locally** — this
repository cannot execute Jenkins. It therefore ships with a
**CI-verification checklist to be walked after push**, not a pass claim.
Keeping it separate from 0018 protects that slice's clean nim-free-machine
gate from unverifiable edits.

## Acceptance criteria

- [ ] No pipeline references the vendored build system, `make deps`, `make
      update`, or a `PATH` Nim toolchain.
- [ ] Desktop pipelines build with `nimble build`; packaging stages consume the
      prebuilt binary via `make pkg-*`.
- [ ] The Nim test pipeline invokes the driver's tests task through its nimble
      alias.
- [ ] Mobile pipelines still build (they call the interim mobile make legs,
      which use the store compiler per 0018).
- [ ] Every pipeline's agent prerequisite is documented as "nimble" and nothing
      else.
- [ ] Static review recorded: each Jenkinsfile diff walked against the targets
      it invokes, confirming every invoked target still exists.
- [ ] **Post-push checklist** (not verifiable here): each pipeline runs green;
      first-run store materialisation time recorded; any agent-image change
      requested from infra is filed.

## Blocked by

- 0018 (pipelines cannot assume a Nim-free agent until the build system that
  provided Nim is gone).
