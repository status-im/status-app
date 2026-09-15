# Agent brief — issue 0014: prl-to-pc into the nimble graph (tag pin)

Read `docs/superpowers/plans/agent-briefs/SHARED.md` first, then your issue:
`docs/superpowers/issues/0014-prl-to-pc-graph-adoption.md` (Decisions and
Design-constraints sections are user-approved — do not relitigate), plus
the 0012 conversion brief + verification record (your playbook), ADR 0007,
and the walls doc (`.phase2-vendor-backup/status-go/AGENTS.md`).

## Your role

Implementer of issue 0014. **You HOLD the in-tree build lock** (no other
agents active; the 0013 agent is done). Work in
`/Users/alexjbanca/Repos/status-desktop/.claude/worktrees/nimble-migration`.

## Context you'd otherwise rediscover

- `vendor/prl-to-pc` is currently a submodule with LOCAL-ONLY state: branch
  `fix/lockfile-nimblepath` (efcd65a mk fix + abb3604 v0.2.0 bump) and
  annotated tag `v0.2.0`, neither pushed. origin =
  https://github.com/status-im/prl-to-pc.git (main is at 71d599b). Anything
  you change in prl-to-pc = commits on that same local branch.
- Because the tag is unpushed, `nimble setup` CANNOT resolve the new pin
  from the URL yet. Bring-up path: keep resolution working via the
  ADR-0004 overlay (nimble.overlay → the local checkout/backup), exactly
  how develop mode already composes; the manifest still lands the final
  `#v0.2.0` string. The 0013 field notes in the issue file describe the
  pattern; `status.nims` `develop`/`applyOverlay` are your tools.
- 2026-07-08 wall (issue 0013 notes): nim disables its default nimblepath
  when the compile CWD has a nimble.lock — this repo does. Explicit --path
  everywhere; never rely on ambient store resolution.
- `config.nims` lines ~283-298 (pkg-config wrapper env) and the Makefile
  `include vendor/prl-to-pc/qt-pkgconfig.mk` are the two consumer seams.
  `status_env.nims` is shared by driver + config.nims — put `prlToPcRoot()`
  there.
- Grill rule (SHARED.md): manifest/store/resolution compromises the docs
  and nimble source cannot answer → stop, `cmux notify`, one question at a
  time with a recommendation. The tag-ref blocker in the issue is the one
  pre-identified grill trigger.
- No GH. No pushes. Commits with `git -c commit.gpgsign=false commit`.
  Superproject commits must contain `0014`.

## Verification pointers

- Wiped-store re-verify is NOT fully possible pre-push (the pin is
  unresolvable from the remote); verify overlay-mode default build +
  develop/undevelop round-trip + store-copy-untouched instead, and write
  the post-push flip command into the verification record.
- Watch the `.pcwrap` relocation: after your change, a build must leave the
  store entry byte-identical (hash the entry dir before/after).
- Re-run one `nimble build` end-to-end (hook included) and `nim app
  status.nims`; record timings next to 0013's.

Follow the SHARED completion protocol (verification record in the issue,
PRD row for 0014, progress ledger, `cmux notify` on completion or grill).
