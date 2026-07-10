# Agent brief — issue 0016: buildArtifacts goes native

Read `docs/superpowers/plans/agent-briefs/SHARED-i3.md` first (its required
reading list is binding), then your issue:
`docs/superpowers/issues/0016-build-artifacts-native.md` — the contract. The
PRD's "Artifact orchestration" block names your new include
`status_artifacts.nims`. Then read the 0015 brief + the verification records
in issues 0013/0014/0015 — they are your evidence-style templates and describe
the driver seams you are about to rework.

## Your role

Implementer of issue 0016. **You HOLD the in-tree build lock and you are the
only agent running.** Work in
`/Users/alexjbanca/Repos/status-desktop/.claude/worktrees/nimble-migration`.

## Settled decisions (user-confirmed 2026-07-10 — do not reopen)

1. **`stale(outputs, inputs)` is PRIVATE to the driver side** — it lives in
   `status_artifacts.nims` (or `status.nims`), never in the shared
   `status_env.nims`. Rationale, record it in the driver header: `config.nims`
   runs on **every** nim invocation including nimsuggest, and must never do
   filesystem gating; keeping `stale()` out of the shared include makes that
   impossible by construction. 0017's client compile will reuse it from the
   driver side.
2. All of the issue's "What to build" and the PRD's Implementation Decisions
   are user-approved. Do not relitigate; grill (per SHARED-i3) only on genuine
   unknowns they do not cover.

## Compiler facts (measured; do not re-derive, do not violate)

- `~/.nimble/bin/nim` on PATH **is the pinned store nim 2.2.4**. Do NOT
  prepend the NBS nim (2.2.10) — see the updated SHARED-i3 environment block.
- nimble injects the pinned compiler into task **and** `before build` hook
  PATH — inside anything nimble runs, plain `findExe("nim")` is the pin.
- Manifest-VM hazard: inside the `.nimble`, `selfExe()` /
  `querySetting(libPath)` return nimble's *evaluator*, not the pin. Only
  `findExe("nim")` is correct there. In `.nims` run by `nim`,
  `getCurrentCompilerExe()` (needs `import std/os`) is correct. See commit
  b119cf2d6d (`nimExe()`) — the driver is evaluated by nim AND by nimble;
  reuse that helper, do not invent a second resolution.

## The seams you are replacing (map, verified 2026-07-10)

`Makefile:979`: `client-deps: $(NIM_CLIENT_PRECLEAN) | statusq dotherside
check-qt-dir $(STATUSGO) $(NIMSDS_LIBFILE) $(STATUSKEYCARD_QT_LIB)
$(QRCODEGEN) rcc deps $(NIMBLE_SETUP_STAMP)` where:

- `NIM_CLIENT_PRECLEAN = force-rebuild-status-go` (`Makefile:971`).
- `deps: | check-qt-dir deps-common status-go-deps bottles` (`Makefile:202`).
- `NIMBLE_SETUP_STAMP := nimble.paths` (`Makefile:390`) — this is the stamp
  the issue relocates: the driver gates `nimble setup` on `nimble.paths` being
  stale w.r.t. the lock, the manifests and the develop overlay. Careful: the
  stamp recipe also runs `nim applyOverlay status.nims` (see the develop-mode
  comment block at `status.nims:398`); that ordering must survive.
- `QRCODEGEN := vendor/QR-Code-generator/c/libqrcodegen.a` (`Makefile:811`) —
  this whole target, its `--passL`, and its platform-sentinel cleanup entry
  are deleted; the Nim wrapper that binds it gains `{.compile.}` of the C
  source. Find the wrapper by grepping for qrcodegen bindings in `src/`.
- `rcc: $(UI_RESOURCES)` (`Makefile:843`); `compile-translations` at
  `Makefile:862` becomes a driver **task**, not a build step.
- The consumers today: `task buildArtifacts` (`status.nims:365`) does
  `prepareQtPkgconfig(); runMake "client-deps"`. `task app` (host arm,
  `status.nims:347`) and `task run` similarly shell to make. Your job ends
  when no `make` process appears anywhere under `nim app status.nims` /
  `nimble build` on host (criterion 1; mobile arms of `app` still go to
  `make mobile-build` — untouched this iteration).
- status-go / nim-sds / status-keycard-qt already have their build recipes;
  the **key-file pattern** for keyed invalidation was established by the
  status-go scratch engine (`.statusgo-build`) — study it before writing
  `stale()`; the two patterns must be the ONLY gating in the driver and both
  documented in the driver header.

## Context you would otherwise rediscover

- **PKG_CONFIG_PATH must always be exported**, even on System-mode kits —
  otherwise pkg-config answers from its built-in path (brew's Qt on this
  machine) and silently links the wrong Qt. 0015 amended its criterion for
  this; do not regress it.
- **Store byte-identity checks must exclude `nimblemeta.json`** (records
  `specialVersions`; pin-shape changes alter it while payload is identical).
- **Cold-store test**: only a `HOME` redirect is genuinely cold —
  `~/.nimble/nimbinaries` survives a `NIMBLE_DIR` override. Full cold
  `nimble setup` ≈ 5:18 wall / 7.9 GB; do this at most once, in a scratch
  HOME, and only for the "full build from a wiped store" criterion (wiping
  the relevant store *entries* is usually enough — check the criterion's
  wording and record exactly what you wiped).
- The 0011 `FETCHCONTENT_SOURCE_DIR_<NAME>` redirect-pair contract: **always
  pass the pair, empty value means pinned** — preserve verbatim in the
  generic cmake proc.
- `vendor/prl-to-pc` is a gitignored develop checkout at v0.3.0; disposable.
  `prepareQtPkgconfig()` and the env cache are 0015's work — build around
  them, do not rework them.
- Timings to beat (this machine, 2026-07-09): driver no-op **6.78–7.25 s**
  over five runs; `nimble build` ~1:44. Your no-op criterion is "within the
  established envelope (~7 s)" — measure ≥5 runs, report the range honestly.
- Walls: `nimble.lock` in the compile CWD disables nim's default nimblepath;
  parent-checkout `config.nims` poisons nested-worktree compiles
  (`--skipParentCfg:on`); `rm -rf` under `~/.nimble` is permission-blocked —
  `mv` to a backup dir instead. ALL nimble walls are in
  `.phase2-vendor-backup/status-go/AGENTS.md`; none may be rediscovered or
  fought.

## Suggested order (stale() first — it is a prefactor)

1. `stale()` + driver-header documentation of the two gating patterns.
2. Setup-stamp relocation (gate `nimble setup` natively) — everything else
   runs under nimble and needs the store resolved.
3. Bootstrap: targeted submodule init + brew bottles.
4. Generic cmake proc; port StatusQ, DOtherSide, status-keycard-qt,
   translations (as task) onto it.
5. qrcodegen `{.compile.}` + deletion of the static-lib target/flag/cleanup.
6. rcc under `stale()`.
7. Rewire `buildArtifacts` to the ordered call list; delete `client-deps`;
   make `nim app` (host) make-free.
8. Verification sweep: every acceptance criterion, evidence style of
   0013/0014, dated verification record appended to the issue file.

Commit in slices as you go (`git -c commit.gpgsign=false commit`, messages
`feat(nimble/0016): …` / `refactor(nimble/0016): …`), never `add -A`, never
amend.

## Pre-identified grill triggers (stop and ask, do not improvise)

- The setup-stamp relocation cannot express "stale w.r.t. lock + manifests +
  overlay" without breaking the `applyOverlay` ordering.
- A cmake artifact needs per-artifact special-casing that breaks the "one
  generic procedure" decision.
- `{.compile.}` of qrcodegen's C source misbehaves cross-arch or interacts
  with the platform sentinel in a way the issue does not anticipate.
- Deleting `client-deps` breaks a consumer you did not expect (grep for every
  reference first — CI files included).
- Anything that would mean an undocumented nimble workaround.

## Definition of done

Every acceptance criterion in the issue verified with pasted evidence (or
explicitly recorded as unverifiable on this machine), the dated verification
record in the issue file, the PRD Progress row updated, a progress.txt entry
appended, everything committed. Final message per SHARED-i3's completion
protocol — assume the orchestrator will independently re-verify, because it
will.
