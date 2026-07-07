# Agent brief — issue 0012 CONVERSION: seaqt pair into the nimble graph

Read `docs/superpowers/plans/agent-briefs/SHARED.md` first, then:
issue `docs/superpowers/issues/0012-seaqt-pair-graph-adoption.md` (including
the GRILLED 2026-07-07 decision in its Blockers section — it is binding),
the spike record `docs/superpowers/specs/2026-07-06-seaqt-graph-spike.md`,
and the 0009/0010/0011 verification records (playbooks you reuse).

## Your role

Implementer of the 0012 PASS path. **You HOLD the in-tree build lock** (all
other agents are done). This is the iteration's last conversion.

## The grilled decision (do not relitigate)

Pins at the CURRENT submodule SHAs: nim-seaqt = `2d95808` on branch
`smo-6.4` (durable ref: tag `qt-6.4-seaqt-gen-5bc1bc58…` points at it),
nimqml = `c5e5831`. Record `developBranch: smo-6.4` in nim-seaqt's vendor
row so `develop seaqt` checks out the right line. Any pin bump (upstream
qt-6.4 is force-pushed and drops seaqt_compat; qt-6.11 branch exists) is a
SEPARATE later decision — not this issue.

## The work

1. **Graph the pair**: `URL#hash` requires in `nim_status_client.nimble`
   (they are app-level deps): `https://github.com/seaqt/nim-seaqt.git#2d95808…`
   + `https://github.com/seaqt/nimqml-seaqt.git#c5e5831…` (full SHAs from
   the submodules before removing them). Package names per their manifests:
   `seaqt`, `nimqml`. Remove the hardcoded `config.nims` path switches
   (~lines 31–32) — nimble.paths now carries them — and convert the compat
   include path (~line 108) to the store-relative form the spike validated
   (Q3). Expect the usual clean-store re-verify + pkgcache staleness flush.
2. **Submodule removal ×2**: staged playbook exactly as 0010 did it
   (backup refs, `.gitmodules` section removal, `git rm --cached`, directory
   preserved at `.phase2-vendor-backup/<name>` with FUNCTIONAL git dir —
   repoint `core.worktree`, verify `git status` works from there).
3. **Vendor-table rows** (nimble flavor): `seaqt` (developBranch smo-6.4)
   and `nimqml`. Both compile INTO the client (static Nim deps, unlike the
   sds/keycard shared libs) — the develop-mode FORCE arm must force the
   client Nim rebuild (`REBUILD_NIM=true`, the statusgo-wrapper precedent
   from 0009), i.e. `clientRebuild=true` where 0011 recorded the field.
   Divergence guard: their manifests are `seaqt.nimble`/`nimqml.nimble` —
   confirm the guard picks the right file per vendor.
4. **Read-only store friction**: the spike answered how the C++ shims
   compile (Q2) — follow its verdict; if any in-package write shows up that
   the spike missed, the `.sds-build`-style scratch pattern is the fallback
   (grill only if neither fits).

## Acceptance = the issue's pass-path checkboxes

- Default-mode desktop build with NO seaqt/nimqml checkouts (wiped store
  re-verify) + storybook build + app launch smoke.
- `develop nimqml` → edit a Nim source in the compat layer → next
  `nim app status.nims` picks it up (client relinked) → `undevelop`
  restores the pin (byte-identical client is NOT expected here if nim
  embeds paths — record what cmp shows and explain it either way).
- Mobile spot-check, one platform (iOS or Android leg from the store copy).
- `nim vendors status.nims` lists all six vendors with pins + state.

Follow the SHARED completion protocol; completion commit MUST contain
`0012`. Also update the PRD Progress row to done and check the remaining
issue checkboxes.
