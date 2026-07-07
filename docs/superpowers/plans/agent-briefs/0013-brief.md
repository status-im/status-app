# Agent brief — issue 0013: nimble-native build/run OOTB

Read `docs/superpowers/plans/agent-briefs/SHARED.md` first, then your issue:
`docs/superpowers/issues/0013-nimble-native-build-run.md` (the Decisions
section is user-approved — do not relitigate), plus:
`vendor/status-go/AGENTS.md` walls doc — NOTE it now lives at
`.phase2-vendor-backup/status-go/AGENTS.md` (or the statusgo store entry /
a developed checkout), the 0008–0012 verification records, `status.nims`
(you extend it), and `config.nims` (you make it env-independent).

## Your role

Implementer of issue 0013. **You HOLD the in-tree build lock** (no other
agents active). Work the phases in order A → B → C-spike (grill) → C → D;
commit per phase.

## Context you'd otherwise rediscover

- The motivating failure transcript is in the issue. Root causes: nimble's
  bin compile lacks make's env (config.nims gates app switches on env that
  doesn't exist), nimble resolves into the default store while make uses
  APP_NIMBLE_DIR, and `run` (builtin) shadows the `run` task — the builtin
  IS the target UX here.
- `nimble <anything>` pays ~46–75 s dispatch revalidation (documented tax,
  upstream ask #4) — measure hook overhead PAST that, don't fight it.
- The manifest already `include "status.nims"` (all driver tasks are nimble
  tasks). Hooks are declarative-parser-safe; code is safe in the ROOT
  manifest only (the wall applies to dependency manifests).
- 0002/0010 hook mechanics: `before build` fires before the bin compile;
  hook `return false` = hard error (unsuitable for skip switches — use a
  successful no-op); hooks can't inject env into the subsequent compile
  (hence phase A).
- Store hygiene: compiles must use ONLY nimble.paths/--path (--noNimblePath
  is already set at config.nims:2) — the stale-confutils incident is the
  regression to guard against (acceptance criterion 7).
- `qmake -query QT_INSTALL_LIBS` etc. — the driver's qmakeExe()/qmakeQuery()
  procs in status.nims already implement discovery + validation; REUSE (a
  shared include or moving shared procs) rather than duplicating in
  config.nims. Beware: config.nims runs for EVERY nim compile of the app —
  staticExec qmake queries must be cheap/cached (a derived-state file
  written by the driver/hook is an acceptable alternative to live queries;
  choose after measuring, and document the choice in the issue).
- Mobile: this issue targets the HOST nimble build/run path. Mobile stays
  driver/make-only — but your Makefile store migration (phase D) touches
  mobile recipes too; re-run one mobile leg as regression proof.
- Bring-up parity assertion (acceptance criterion 6): while make env is
  present, derived config.nims values must equal the exported ones — build
  once via make with the assertion on, then relax to prefer-env.

## Verification pointers

- "Fresh clone + empty ~/.nimble" criterion: use a temporary HOME or
  NIMBLE_DIR for the clean-room leg (don't wipe the developer's real
  ~/.nimble without backing up: `mv ~/.nimble ~/.nimble.bak-0013` and
  restore in the same session — announce it in your status line while it's
  moved).
- Byte-identical criterion: compare `bin/nim_status_client` checksums from
  the make path vs the nimble path against the same store (post-A/B they
  share flags; nimcache differences are acceptable, output bytes are not —
  if they differ, find out why before relaxing the claim; grill if it's a
  nim-flags asymmetry you cannot close).
- Record timing numbers next to 0008's baselines (no-op via nimble vs nim).

Follow the SHARED completion protocol (verification record, PRD row —
add a 0013 row — progress.txt, commits with `0013`, notify). Grill rule
applies as always: manifest/store/resolution compromises the docs and
nimble source cannot answer → stop, notify, one question at a time.
