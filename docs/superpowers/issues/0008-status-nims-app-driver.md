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

## Blocked by

- 0007 (pin flip) — the driver's bootstrap must target the post-flip graph.
