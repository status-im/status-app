# Agent brief — issue 0010: status-go full-pin

Read `docs/superpowers/plans/agent-briefs/SHARED.md` first, then your issue:
`docs/superpowers/issues/0010-statusgo-full-pin.md`, plus the 0009
verification record + ADR 0007 (the overlay you now build on).

## Your role

Implementer of issue 0010. **You HOLD the in-tree build lock.** Agent 0011
runs survey-only in parallel and must not build or edit `status.nims` until
your completion commit (containing `0010`) lands — you own those files until
then.

## The pin

`https://github.com/status-im/status-go.git#<current submodule HEAD>`
(branch `nimble-phase1-pin`). Issue 0009 added commits in the submodule
(cmp-mirror engine), so the pin SHA = `git -C vendor/status-go rev-parse
HEAD` (f46571f3b… at brief-writing time). FIRST STEP: verify reachability —
`git -C vendor/status-go ls-remote origin nimble-phase1-pin` must equal the
local HEAD. If it doesn't, the user hasn't pushed yet: `cmux notify --title
"0010: push needed" --body "push vendor/status-go nimble-phase1-pin to
origin"` and do submodule-independent prep (read the store-copy contents,
version.sh, go.mod replaces) until it lands. The pin equals the submodule's
HEAD, so the conversion changes WHERE status-go comes from, never WHAT is
built — byte-identical artifacts are your strongest acceptance signal.

## Key state and constraints

- App manifest currently requires statusgo via absolute `file://` — replace
  with the URL#hash above (comment: interim branch pin until upstream merge).
  Expect lock regeneration + the documented hand-fix pattern; statusgo and
  its transitive picks now ENTER the lock. Always re-verify from a wiped
  store (`~/.cache/status-desktop-nimbledeps`). Remember the walls: URL#hash
  pins bind directly (good); pkgcache staleness may hide the fresh branch —
  flush `~/.nimble/pkgcache/*status?go*` clones if the SHA isn't found.
- Submodule removal: staged, Phase 2 playbook (backup ref
  `backup/nimble-0010-statusgo` first; dir preserved out-of-tree, NOT
  deleted). After removal, `develop statusgo` (0009) must materialize a
  fresh clone from the pin URL — that flow's first real exercise; the 0009
  vendor table was designed so you only change the pin-source row.
- Store-scratch Go build: pinned statusgo resolves to a read-only store copy
  with NO `.git`. Two known consequences to solve (grill-flagged in the
  issue):
  1. Version stamping — status-go's Makefile shells `scripts/version.sh`
     (git describe). Decide per the issue's blocker note: verify what the
     store copy contains, prefer deriving the version from the pin SHA via
     the driver/env if version.sh has a documented env override (check
     status-go's Makefile first — read before inventing; if genuinely
     unanswerable from code, grill the user per SHARED).
  2. `go.mod` local replaces (`third_party/go-waku`) — confirm the store
     copy carries the replaced dirs (installDirs whitelist semantics! sds
     needed `installDirs` for `library/`; statusgo.nimble may need the same
     for `third_party/`, `vendor/`-go, etc. — check what setup materializes
     vs what install-action would; AGENTS.md "Install action and setup
     materialize DIFFERENT store contents").
- Extend the `.sds-build/` scratch pattern for the Go build (wipe+copy →
  build → artifacts out). Mind macOS filename limits with long store paths
  and keep the scratch OUTSIDE any config-walk-poisoned tree if it compiles
  Nim (Go is immune to nim parent configs, but libsds inner builds are not).
- Stamp-skip arm (the headline): pinned statusgo + unchanged (store path,
  target triple, flags) + artifacts present ⇒ do NOT invoke the status-go
  sub-make at all. Developed statusgo ⇒ today's FORCE + cmp. Wire it where
  the 0009 mode logic decides gating; measure and record mobile no-op
  before/after (baseline: FORCE chain ~70 s warm — 0008 record).
- Artifact contract: desktop/mobile make rules must stop referencing
  `vendor/status-go/build/bin` directly — they consume driver/Make-exported
  paths valid for both store-scratch (pinned) and checkout (developed).

## Acceptance = the issue's six checkboxes

Plus: record no-op timings (desktop + one mobile leg) in the verification
record next to 0008's baselines. Follow the SHARED completion protocol; your
completion commit MUST contain `0010`.
