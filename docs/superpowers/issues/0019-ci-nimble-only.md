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
- **Build via `nimble build`**, which needs no `nim` on `PATH` (spike-verified
  2026-07-09). Driver tasks CI needs (tests, the Windows launcher) are reached
  through the **nimble task aliases** the manifest already exposes, with
  `--os`/`--cpu` forwarding (verified 2026-07-07). The ~1-minute nimble
  dispatch tax is noise on CI while developers keep the fast `nim` driver path.
- **Everything must be reached THROUGH nimble** (task alias, or a shell with
  `eval "$(nimble shellenv)"`) — never a bare `make`. Spike finding: nimble
  injects the pinned compiler into task/hook PATH, so children inherit the
  right `nim` for free; a bare `make mobile-build` on a nim-free agent has no
  compiler and no reliable way to find one (`nimble path nim` prints two
  same-version entries).
- **Cold-agent cost is real**: a fresh agent with no `~/.nimble` pays ~5 min and
  ~8 GB to materialise the pinned compiler (spike-measured). Either cache
  `~/.nimble` on the agent image or accept the first-build cost. This is the
  concrete infra ask; it must be filed, not assumed away.
- **Manifest-VM hazard**: any compiler lookup reachable from the manifest VM
  must use `findExe("nim")`; `selfExe()`/`querySetting(libPath)` there return
  nimble's evaluator (2.2.10), not the pin. CI is the context that exercises
  this path, so a regression here fails only in CI.
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
- [ ] No pipeline invokes `make` bare; every make entry goes through a nimble
      task alias or a `nimble shellenv` shell (so the pinned compiler is on
      PATH for make's children).
- [ ] The cold-agent cost (~5 min, ~8 GB for first compiler materialisation) is
      either eliminated by caching `~/.nimble` on the agent image, or accepted
      and documented, with the infra request filed.
- [ ] Static review recorded: each Jenkinsfile diff walked against the targets
      it invokes, confirming every invoked target still exists.
- [ ] **Post-push checklist** (not verifiable here): each pipeline runs green;
      first-run store materialisation time recorded; any agent-image change
      requested from infra is filed.

## Blocked by

- 0018 (pipelines cannot assume a Nim-free agent until the build system that
  provided Nim is gone).
