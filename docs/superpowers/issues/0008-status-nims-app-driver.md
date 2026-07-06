---
id: 0008
title: status.nims app driver — one command from clean clone to runnable build
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`

## What to build

A root `status.nims` nimscript driver — the canonical front door:

- `nim app status.nims` → host dev build (today's `make nim_status_client`
  result); `nim app status.nims --os:ios --cpu:arm64` / `--os:android
  --cpu:arm64` → the mobile chains. The task parses `--os/--cpu` from its
  invocation; host is the default. Kit selection stays environment-driven
  (QMAKE, IPHONE_SDK, QMAKE_DEVELOPMENT_TEAM, ANDROID_NDK_ROOT, ARCH …) with
  fail-fast, actionable errors when a required variable is missing for the
  selected target.
- `nim run status.nims` → build if needed + launch with the correct env
  (today's `make run-macos` semantics, incl. DYLD paths for libsds).
- Self-bootstrap: the task checks the setup stamp (nimble.paths vs
  lock/manifests) and runs `nimble setup` into `APP_NIMBLE_DIR` only when
  stale — a clean clone genuinely needs only the one command (plus kit env).
- Delegation: the driver shells out to the existing make recipes (Q12
  decision) — no build logic is reimplemented, and **no new logic lands in
  make** (make-freeze ratchet; PRD implementation decision).

Explicitly NOT nimble tasks: `nimble <task>` costs ~46–48 s of graph
revalidation per warm invocation on this manifest (measured 2026-07-06;
`--offline` errors, `--legacy` worse). The `.nims` driver starts in ~1 s.

## Acceptance criteria

- [ ] Clean clone + documented kit env: `nim app status.nims` → runnable dev
  build (macOS host), including the initial `nimble setup` bootstrap.
- [ ] `nim app status.nims --os:ios --cpu:arm64` and `--os:android
  --cpu:arm64` produce the signed iOS app / debug APK, equivalent to today's
  `make mobile-build` results.
- [ ] Missing kit env for a selected target fails in <5 s with a message
  naming the exact variables to set.
- [ ] No-op re-run of `nim app status.nims` (default mode, no source changes)
  completes with wall time recorded in the verification record; driver
  overhead (before make takes over) ≤ ~2 s. (The minutes-level vendor
  no-op cost is addressed by 0010's stamp-skip arm — record both numbers.)
- [ ] All pre-existing make targets still work unchanged (spot-check
  `make nim_status_client`, `make mobile-build`, `make run-macos`).

## Blockers — grill before implementing

- Exact task/flag parsing shape in nimscript (how `--os/--cpu` arrive in
  `commandLineParams` when passed to `nim <task> file.nims`) — verify
  empirically first; if the flags are consumed by nim itself rather than
  forwarded, grill the fallback spelling (e.g. `nim app status.nims ios`)
  before deviating from the agreed UX.

## Phase-A spike findings (2026-07-06, nim 2.2.4, scratch-dir toy .nims)

The agreed UX works exactly as designed — no grill needed:

- **Flags placed AFTER the .nims file are not consumed by nim at all**:
  `nim app toy.nims --os:ios --cpu:arm64` evaluates the script with host
  defines (`hostOS: macosx`, `defined(ios): false`) and the flags arrive
  verbatim in the process argv. nim does not validate them either
  (`--os:bogusvalue` after the file is ignored by nim) — the task must parse
  AND validate them itself. Both `--os:ios` and `--os=ios` spellings arrive.
- **Flags placed BEFORE the file ARE consumed by nim**: they flip the
  script evaluation's own defines (`hostOS: ios`, `defined(ios): true`) and
  are validated by nim (`--os:` before the file with a bad value hard-errors).
  They still appear in argv, so an argv-wide scan handles both placements;
  the canonical spelling (after the file) is the safe one.
- `commandLineParams()` does not exist in nimscript ("undeclared
  identifier") — use `paramCount()`/`paramStr(i)`; argv includes the `nim`
  binary and nim's own options, so args-for-the-task = params after the
  param whose basename is the script filename.
- Extra non-flag args after the file arrive verbatim, no nim error.
- An inner `nim` spawned by the task (`exec "nim …"`) inherits nothing from
  the outer invocation in either placement (fresh process) — target
  selection must travel explicitly; in this driver it travels via env
  (QMAKE/ARCH/IPHONE_SDK…) into the make chains, so no nim-flag forwarding
  is needed.
- A task named `run` does not collide with nim's builtin commands (the
  builtin is `r`; `nim r file.nims` tries to *compile* the script — avoid
  task names that shadow real nim commands: c, cpp, js, e, r, doc…).
- Bootstrap delegation is already fully make-side: `nim_status_client`,
  `mobile-build`/`mobile-run`, `run-macos` and `nim-test-run/%` all depend
  on `$(NIMBLE_SETUP_STAMP)` (= `nimble.paths`, keyed on nimble.lock + the
  three manifests, `make nimble-deps` names it), and on a clean clone the
  Makefile's `.DEFAULT` rule auto-runs
  `git submodule update --init --recursive` and restarts. The driver adds
  no second stamp scheme — delegation inherits the existing one.
- Repo-root eval note: evaluating `status.nims` at the repo root walks the
  parent-dir configs, so the app's `config.nims` (and, in nested worktrees,
  the enclosing checkout's) runs as script *config*. Its switch() calls are
  inert for a nimscript eval; visible effect is only the "Building for
  macOS" echo noise. `include "nimble.paths"` is existence-guarded, so a
  clean clone (no nimble.paths yet) still evaluates.

## Blocked by

- 0007 (pin flip) — the driver's bootstrap must target the post-flip graph.
