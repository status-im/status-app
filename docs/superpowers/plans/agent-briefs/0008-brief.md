# Agent brief — issue 0008: status.nims app driver

Read `docs/superpowers/plans/agent-briefs/SHARED.md` first, then your issue:
`docs/superpowers/issues/0008-status-nims-app-driver.md`.

## Your role

Implementer of issue 0008, in two phases. You do NOT hold the in-tree build
lock in phase A — agent 0007 does. Do not run any build inside the repo tree
until phase B's gate opens.

## Phase A — flag-forwarding spike (scratch dir, start immediately)

The agreed UX is `nim app status.nims --os:ios --cpu:arm64`. Verify HOW
`--os/--cpu` reach a nimscript task, in your scratchpad (a toy `.nims` with a
`task app`): test flag placement before/after the file and task name; inspect
`commandLineParams()`, `paramStr`, and nim-provided values
(`system.hostOS` vs `--os`-affected defines are compile-time of the SCRIPT —
you likely must parse the flags yourself and must ensure nim doesn't consume
or choke on them). Also verify how extra non-flag args arrive, and behavior
when the same flags are also needed by an inner `nim c` the task spawns.
Precedent: `vendor/status-go/statusgo.nims` tasks read env vars (ARCH etc.)
— study it. If the agreed spelling cannot be made to work as designed, that
is a grill-rule stop (notify + one-question-at-a-time with recommendation).
Record spike findings in your issue file as you go.

While waiting on the build lock you may also WRITE the driver
(`status.nims`) — code, no in-tree builds:

- Tasks: `app` (host default; `--os:ios|android --cpu:<…>` dispatch to the
  existing make chains), `run`, plus stubs-with-clear-errors for
  `develop/undevelop/vendors` (issue 0009 implements them — leave TODO
  markers referencing 0009).
- Self-bootstrap: replicate the Makefile's stamp logic (nimble.paths vs
  lock/manifests) → run `nimble setup` into `APP_NIMBLE_DIR`
  (`~/.cache/status-desktop-nimbledeps`) only when stale. Reuse/refactor the
  Makefile's existing rule rather than inventing a second stamp scheme — the
  driver may simply delegate to a make target that already encodes it
  (`make nimble-deps`-style); check the Makefile first.
- Delegation only: the driver shells out to existing make targets
  (`nim_status_client`, `mobile-build`, `run-macos`). NO build logic
  reimplemented, NO new logic added to make (make-freeze ratchet, see PRD).
- Fail-fast env validation per target (QMAKE, IPHONE_SDK,
  QMAKE_DEVELOPMENT_TEAM, ANDROID_NDK_ROOT…): missing → <5 s error naming
  the exact variables. Mobile invocation reference: issue 0004's
  verification record has the exact working command lines.

## Phase B — wire up + verify (needs the build lock)

Gate: `git log --oneline | grep 0007` shows agent 0007's completion commit
(poll every few minutes while doing phase-A work; if you are fully blocked
waiting, `cmux set-status task "waiting for 0007 build lock"` and check
periodically). Then run the issue's acceptance matrix (host build incl.
bootstrap from wiped store, iOS + Android legs, no-op timing numbers, make
targets spot-check). Record wall times in the verification record — the
no-op number is a headline result for this iteration.

Follow the SHARED completion protocol. Your completion commit MUST contain
`0008`.
