# Agent brief — issue 0018: NBS deleted

Read `docs/superpowers/plans/agent-briefs/SHARED-i3.md` first (ground rules,
grill protocol, verification standards; environment: NO NBS-nim prepend —
after your issue lands that instruction becomes moot, and part of your job is
amending SHARED-i3's environment block to the post-NBS truth). Then your
contract: `docs/superpowers/issues/0018-nbs-deleted.md`. Then issues 0016 and
0017's Verification records — they describe the driver engine and Makefile
state you are finishing.

## Your role

Implementer of issue 0018. **You HOLD the in-tree build lock; you are the
only agent running.** Fresh context — everything you need is in the files
named here. Work only in
`/Users/alexjbanca/Repos/status-desktop/.claude/worktrees/nimble-migration`.

## DANGER — the one way to destroy user data (read twice)

This checkout is a **nested worktree**; the parent checkout
`~/Repos/status-desktop` shares `.git/modules` with it and its OTHER branches
still use NBS. When removing the submodule:

- `git submodule deinit` + `git rm vendor/nimbus-build-system` + committing
  the `.gitmodules` edit affect ONLY this branch — fine.
- **NEVER prune, delete or rewrite anything under the shared git modules
  directory** (`git rev-parse --git-common-dir`/modules). The P2 removal of
  32 submodules followed exactly this rule (progress.txt precedent); the
  backup-ref playbook is: preserve the functional git dir by REFERENCE under
  `.phase2-vendor-backup/` (see how `.phase2-vendor-backup/status-go` and
  `prl-to-pc` are kept), never by moving the module out of `.git/modules`.
- Never touch the parent checkout's working tree.

## Facts already established (do not re-spike)

- **Cold-store compiler materialisation is DONE and ticked** in your issue
  (orchestrator spike 2026-07-09: HOME-redirect + scrubbed PATH → `nimble
  setup` built and used `pkgs2/nim-2.2.4-b4bb510b…`, 5:18 wall). Do not
  repeat it — it needs a 7.9 GB build; the criterion is already checked.
- **`nimble shellenv` works on nimble 0.22.3** (verified 2026-07-12 on this
  machine): emits `export PATH=…` whose entries include
  `pkgs2/nim-2.2.4-…/bin`. It also emits every dep's package dir — long but
  harmless.
- **nimble injects the pinned compiler's bin into PATH for tasks and
  `before build` hooks** — anything nimble invokes gets the pin for free.
  The store-nim rule is only needed OUTSIDE nimble (a bare
  `make mobile-build`), and the blessed shape is reaching make through a
  nimble task alias or a `nimble shellenv` shell — NOT a derived `NIM`
  variable (`nimble path nim` prints two same-version entries; unusable).
- **Manifest-VM hazard**: in the `.nimble` VM, `selfExe()` /
  `querySetting(libPath)` = nimble's evaluator (2.2.10), not the pin; only
  `findExe("nim")` is right there. `nimExe()` in the driver already branches
  correctly (commit b119cf2d6d) — reuse it, never add a second lookup.
- The root Makefile's NBS surface (verified 2026-07-12): `BUILD_SYSTEM_DIR`
  (line ~11), `-include …/variables.mk` (~20) + the USE_SYSTEM_NIM reassert
  dance (~16–24), the NBS-present probe at ~79 (`ifeq ($(wildcard
  …/variables.mk),)` — 0017 rewrote it to not name NIM_PARAMS), `-include
  …/targets.mk` (~112), `ifneq ($(USE_SYSTEM_NIM),1)` (~140),
  `mobile-build: USE_SYSTEM_NIM=1` (~1153). `mobile/Makefile` has NO direct
  NBS reference. `USE_SYSTEM_NIM` itself is an NBS variable — with NBS gone
  it is dead everywhere and should be deleted, including from `desktop-run`
  skill docs? NO — out of scope; note doc references you find as follow-ups
  except BUILDING.md which your issue owns.
- What NBS's `variables.mk`/`targets.mk` actually provide the root Makefile
  today: verbosity (`V`, `HANDLE_OUTPUT`), `.DEFAULT` submodule auto-init,
  and the vendored-nim machinery 0017 already stopped using. Replace only
  what is still consumed — read both NBS makefiles and grep the root
  Makefile for each thing they define before writing the local replacement.
- The 0016 driver bootstrap owns targeted submodule init; there must be no
  `.DEFAULT` auto-init replacement.
- `make pkg-macos`: dmg step needs nix + signing identity — absent here.
  Verify as far as 0017 did (`make -n`, driver dispatch present, bundle
  consumes driver binary) and record the dmg itself as
  not-verifiable-on-this-machine.
- Timings on the idle machine (2026-07-12): driver no-op **3.51–3.89 s**
  (five runs). That is your envelope; do not regress it.

## The nim-free machine proof (criterion 1) — how to do it safely

Fresh clone into a scratch dir (NOT the repo tree; you hold the build lock
but scratch clones are still the right isolation), scrubbed PATH containing
`nimble` but no `nim` (`which nim` must fail; remember `~/.nimble/bin` has a
nim symlink — build the PATH explicitly, don't just subtract). Then
`nimble setup && nimble build`, then `eval "$(nimble shellenv)"` and
`nim app status.nims`. Record the exact PATH. The warm store makes this
fast (no 7.9 GB rebuild — nimbinaries cache is per-HOME and you are NOT
redirecting HOME). A fresh clone will also exercise 0016's bootstrap
(submodule init + bottles) — expect it, and QMAKE must still be exported.

## Compiler-identity proof (criterion 3)

Both front doors must compile with the pin. Suggested evidence: build the
client via `nim app status.nims` and via `nimble build` with a probe that
records the compiler (`nim -v` from inside the hook PATH, or compare
`getCurrentCompilerExe()` logged by config.nims under a debug env var, or
simply `strings`/parity — 0017 proved byte-parity when both used 2.2.4, so
re-running the parity comparison is the strongest form and the method is
documented in 0017's record).

## Pre-identified grill triggers (stop and ask, do not improvise)

- Anything that seems to require touching the shared `.git/modules` or the
  parent checkout.
- The mobile leg needs more from NBS than a PATH nim (an NBS make function,
  a variable with no local equivalent) — do not inline a copy of NBS code
  without asking.
- `status-go-deps`' move into status-go's nimscript collides with the fact
  that vendor/status-go is a store-materialized scratch (whose nimscript
  tasks live in the store copy) — if the right home is ambiguous, ask.
- Deleting `USE_SYSTEM_NIM` changes behavior for any caller that exported
  it expecting NBS semantics (CI files!) — grep ci/ first; 0019 owns CI,
  so ONLY touch ci files where a deleted make target forces it, exactly as
  0017 did.

## Completion protocol (SHARED-i3, plus)

Every criterion verified with evidence or recorded unverifiable → dated
Verification record in the issue → PRD Progress row + progress.txt → amend
SHARED-i3's environment block (QMAKE stays; USE_SYSTEM_NIM dies; state the
bootstrap) → commits (`git -c commit.gpgsign=false commit`,
`feat(nimble/0018): …`, stage only your files, no --amend, no add -A).
Delivery: your plain-text final output is NOT delivered — finish by calling
the SendMessage TOOL with {"to": "team-lead", "summary": "0018 report",
"message": "<commit range, evidence per criterion, surprises, follow-ups>"}.
The orchestrator independently re-verifies everything.
