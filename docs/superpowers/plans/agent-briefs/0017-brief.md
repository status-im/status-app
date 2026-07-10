# Agent brief — issue 0017: driver owns every Nim compile

Read `docs/superpowers/plans/agent-briefs/SHARED-i3.md` first (ground rules,
grill protocol, verification standards — its environment block was updated
2026-07-10: do NOT prepend the NBS nim; `~/.nimble/bin/nim` on PATH is the
pinned 2.2.4). Then your issue:
`docs/superpowers/issues/0017-driver-owns-nim-compiles.md` (check the exact
filename with `ls docs/superpowers/issues/0017-*`). Then, mandatory: issue
0016's **Verification record + review-round section**
(`docs/superpowers/issues/0016-build-artifacts-native.md`) — 0016 landed the
engine you are finishing, and its record states exactly what already exists.

## Your role

Implementer of issue 0017. **You HOLD the in-tree build lock; you are the only
agent running.** Fresh context — everything you need is in the files named
here. Work only in
`/Users/alexjbanca/Repos/status-desktop/.claude/worktrees/nimble-migration`.

## What 0016 already landed (do NOT redo; commits f19b0479d3..eee60af62d)

User-adjudicated pull-forward, recorded in 0016's issue file:

- `status_artifacts.nims` — the driver-side engine: `stale()`,
  `keyStale(keyFile, key, witness)` (the ONLY two gating patterns; ONE
  spelling each; no bare `fileExists` gates), generic cmake proc, qrcodegen
  `{.compile.}`, rcc, bootstrap, relocated setup stamp. `client-deps` is gone.
- **`buildClient(force)` already compiles the client natively** with keyed
  relink (`clientKey()` = qmake + `clientFlagEnv`, `.status-client.key`).
- **`launchHostApp()`** — the `run` task already launches natively.
- `REBUILD_NIM` → `applyDevelopModeArms()` (returns the force bool for
  developed vendors) already wired into `app`/`run`/`buildArtifacts`.

Your remaining scope (0016's issue file, "0017's remaining scope shrinks to"):
**the Nim test suite, the Windows launcher, deleting the `run-*` and
`nim_status_client` make targets (plus `.qmake_previous`), pointing packaging
at the driver-built binary, the explicit force flag on `app`, the Windows flag
branches into config.nims, and a portable (content-key) `stale()`.**

## User adjudications binding on you (2026-07-10 — do not reopen)

1. The portable `stale()` is IN your scope: 0016's `stale()` returns
   unconditionally-true on Windows (disclosed regression, accepted). Implement
   the content-key variant (the walls doc / 0016 follow-up 4: content hash of
   inputs + compiler version + flags). Recorded as ported/unverified for the
   Windows arm — same honest pattern as the flag branches.
2. cmake configure stays key-gated; criterion-1-style "no make" claims follow
   0016's amended wording (root-Makefile targets, not cmake-internal make).

## Ordering that protects the parity criterion

The parity criterion (driver binary ≡ pre-migration binary to the 0013 floor:
identical text/const/symbols; LC_UUID, OSO stab mtimes, signature excepted)
compares against a MAKE-built client. `make nim_status_client` still exists
and parses today. **Build both and run the comparison BEFORE you delete the
make targets** — after deletion there is nothing to compare against. The 0013
verification record documents the comparison method and the floor; both
compilers are now the same 2.2.4 (`~/.nimble/bin/nim` on PATH with
`USE_SYSTEM_NIM=1`), so the 0015-era divergence caveat no longer applies.

## Context you would otherwise rediscover

- **Nim test suite seam**: `nim-test-run/%` at `Makefile:1277` carries
  `NIM_PARAMS += --passL:"$(QT_SEAQT_EXTRA_LIBS)"`; the criterion "Makefile
  has no NIM_PARAMS" dies with it. The driver `tests` task must own the
  library-path environment (macOS: the DYLD paths the suite needs — a prior
  session's recipe needed QMAKE + DYLD symlinks for seaqt QtObject tests; see
  progress.txt if the suite fails to load Qt libs).
- **`run-*` scope ambiguity — resolve before deleting**: the criterion says
  "`run-*` make targets no longer exist", and the PRD's rationale is "two ways
  to run THE APP". The root Makefile also has `run-statusq-tests`,
  `run-storybook`, `run-storybook-tests`, `run-statusq-sanity-checker` — these
  run OTHER products, contain no `nim` invocation, and deleting them removes
  front doors this iteration does not replace. My read (orchestrator): delete
  the app-launch `run` targets; keep the storybook/statusq ones (the grep
  invariant is about `nim` invocations, which they don't have). If your
  reading of the criterion text disagrees, that is a pre-identified grill —
  send DECISION NEEDED rather than deleting them.
- **The grep invariant** must be recorded re-runnably (a script or a
  documented one-liner in the issue): no `nim c` / `nim e` / env-script
  wrapper in the root Makefile. Scope: ROOT Makefile only; `mobile/Makefile`
  still compiles the client until the mobile follow-on.
- **Windows launcher**: find it via the Windows packaging path in the root
  Makefile (`pkg-windows` / launcher-related targets); it is a small nim
  compile. Port to a driver task; compile as far as a macOS host allows
  (`--os:windows` cross-compile may not link — record honestly).
- **Windows flag branches**: the client's Windows-only make flags
  (clang/msvc target flags, ssl define, import-lib hooks) move into
  `config.nims`'s existing OS-switch. Ported, unverified — state it.
- **Force flag on `app`**: the driver's arg parsing lives in
  `parseTarget()`/`rejectExtras()` in `status.nims` — extend it (e.g.
  `--force`) rather than bolting on a second parser. It must force the client
  compile even when `clientKey()` + sources are fresh.
- **`make pkg-macos` signed dmg**: exercise as far as this machine allows. If
  the signing identity is unavailable, verify the dmg assembly consumes the
  driver-built binary and record signing as not-verifiable-here.
- **Walls**: all nimble walls in `.phase2-vendor-backup/status-go/AGENTS.md`;
  parent-checkout config poisoning → `--skipParentCfg:on`; `rm -rf` under
  `~/.nimble` is permission-blocked (use `mv`). Never fight a wall — report.
- Timings: driver no-op currently **4.5–5.6 s** (0016's improvement) — do not
  regress it; measure ≥5 runs at the end.

## Environment

    export QMAKE=~/Qt/6.11.0/macos/bin/qmake USE_SYSTEM_NIM=1

No NBS-nim prepend. Store = default `~/.nimble`. Qt kits: 6.11.0 = Generated
mode, 6.11.1/6.12.0 = System mode (host build on 6.11.0 is fine for this
issue).

## Pre-identified grill triggers (stop and ask, do not improvise)

- The `run-*` deletion scope (above) if the criterion text vs product reality
  cannot be reconciled by the grep-invariant reading.
- Parity comparison fails the 0013 floor for any section other than the
  documented residue (LC_UUID / OSO stabs / signature).
- Packaging targets turn out to rebuild the binary through a hidden path
  (e.g. a recursive `$(MAKE) nim_status_client`) that cannot simply be
  re-pointed at `bin/nim_status_client`.
- The content-key `stale()` cannot be expressed without shelling out per
  compile (defeats the no-op envelope).
- Any undocumented nimble wall.

## Completion protocol (SHARED-i3, verbatim)

Every acceptance criterion verified with pasted evidence or explicitly
recorded unverifiable → dated Verification record in the issue file → PRD
Progress row + progress.txt entry → commits
(`git -c commit.gpgsign=false commit`, `feat(nimble/0017): …`, stage only
your own files, never --amend, never add -A) → final message: what landed,
evidence per criterion, surprises, follow-ups. The orchestrator independently
re-verifies everything.
