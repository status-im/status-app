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

## Blocked-by-0018 handoff (written 2026-07-12 by 0018's fix wave — read first)

0018 deleted the targets CI called (`make update`, `make deps`,
`make status-go-deps`) and edited `ci/` **only** to stop calling them. It gave
the pipelines a **half bootstrap**, and it is 0019's job to finish it. Reviewed
and decided (orchestrator + user, 2026-07-12): 0018 must NOT touch `ci/`
further, so the gap is written down here rather than patched there.

Exactly what is open:

1. **`nimble setup` without a PATH bootstrap — 6 files.** `Jenkinsfile.macos`,
   `.linux`, `.windows`, `.flatpak`, `.tests-nim` run `sh 'nimble setup'`;
   `.linux-nix` runs `nix.shell('nimble setup', pure: true)`. Each Jenkins `sh`
   step is its OWN shell, so the resolution is done but no later step has the
   pinned compiler on `PATH`: a subsequent `nim <task> status.nims` or a bare
   `make` leg takes the image's `nim` (or finds none). Fix per step: reach the
   build through nimble (`nimble build`, or a task alias) — or, where a make
   leg is unavoidable, `source ./env.sh && make …` (env.sh hoists and *asserts*
   the pinned compiler; a bare `eval "$(nimble shellenv)"` loses the PATH-order
   race — 0018 §7).
2. **`Jenkinsfile.ios` has NO bootstrap at all** — it goes straight to
   `sh 'make status-go'` and the mobile leg. `Jenkinsfile.android` likewise has
   no `nimble setup` (it drives make legs only). Both compile the client
   through `mobile/scripts/buildNimStatusClient.sh`, which is now a plain
   `nim c` — i.e. it needs the bootstrapped PATH that nothing gives it.
3. **Criterion 3 of 0018 ("both front doors compile the client with the pin")
   is scoped to the LOCAL front doors** — its CI leg is deliberately unclaimed
   and belongs to this issue's acceptance criteria.

New in 0018's fix wave, and load-bearing for this work: the driver now **fails
fast** when the compiler about to compile the client is not the pinned store
entry (adjudication A1). A pipeline that forgets the bootstrap therefore fails
loudly instead of silently building with the image's Nim — but it *does* fail,
so every make/driver leg in CI must be given the bootstrap before this issue can
go green. Round 2 of that wave widened the guard to the test suite, the Windows
launcher and the mobile `nim c` (`mobile/scripts/buildNimStatusClient.sh`), so
the iOS/Android legs fail fast too.

**Bootstrap cost (0018 round 2, R6):** `source ./env.sh` runs `nimble shellenv`,
a full re-solve — ~50 s per call, pre-existing (issue 0013). Bootstrap ONCE per
stage and run every step inside that shell; a per-step `source` multiplies the
tax by the step count. A cached shellenv (key = `nimble.lock` + manifests) is
0018's follow-up 6, not this issue's.

## Master moved under this issue (2026-09-15 rebase addendum — read with the handoff)

The branch was rebased onto master `872090c705` (1002 commits past its July
base). The CI map the handoff above and the acceptance criteria describe has
changed on master since:

1. **`ci/Jenkinsfile.tests-nim`, `.tests-ui` and `.ios` no longer exist**
   (master 143fecd95d, 2026-08-16). Their work is serialised into
   `Jenkinsfile.linux` (stages `Nim Tests`, `UI Tests`, AppImage `Package`)
   and `Jenkinsfile.macos` (stages `macOS`, `iOS`). Criterion "the Nim test
   pipeline invokes the driver's tests task" now means the `Nim Tests` stage
   of `Jenkinsfile.linux`, which since this rebase runs
   `BENCH_ASSERTS=0 BENCH_QUICK=1 nim tests status.nims --benches` — still
   WITHOUT the PATH bootstrap (handoff item 1 applies; the driver's compiler
   guard makes it fail loudly).
2. **Master builds from a system nim 2.2.10** on every agent (Docker images
   bumped, nim installed on the Windows/macOS hosts; `USE_SYSTEM_NIM=1` in
   `MAKEFLAGS`, now a no-op variable since 0018 deleted the make legs that
   read it). The manifest pin was moved to `nim == 2.2.10` in this rebase so
   the store compiler and the images agree — but the guard asserts the pinned
   STORE ENTRY, not a version, so an image nim of the same version is still
   refused. The agent prerequisite this issue asks for ("nimble only") is
   therefore unchanged: the images' nim is at most where `nimble` comes from.
3. **Cold-agent cost is now avoidable**: the images already carry nim 2.2.10,
   so `nimble setup` need not build the compiler — but only if nimble is
   taught to adopt an existing 2.2.10 as the store entry, which nimble 0.22
   does not do (it always materialises its own). The `~/.nimble` cache ask
   stands.
4. Master's `Jenkinsfile.linux` still runs `./scripts/ci-fetch-submodules.sh`,
   `make status-go`, `make statusq`, `make qrcodegen` (a no-op alias kept for
   it), `make tests-nim-linux` (now the driver call above) and the
   `override-status-go-ref.sh` stage ("must run after `make update`, which
   resets submodules" — there is no `make update` and no status-go submodule
   any more; the override must become a pin override, e.g. an env-driven
   develop-mode materialisation).
5. Master added `Jenkinsfile.combined` (keycard e2e against a
   `USE_SIMULATED_KEYCARD: true` build — the flag is a driver knob since this
   rebase), `Jenkinsfile.flatpak` in nightly/releases (its image is the
   nim-2.2.10 one), and an e2e messaging peer container. None of these are in
   the acceptance list above; walk them in the static review.

## Blocked by

- 0018 (pipelines cannot assume a Nim-free agent until the build system that
  provided Nim is gone).
