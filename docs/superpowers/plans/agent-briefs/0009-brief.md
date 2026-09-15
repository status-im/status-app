# Agent brief — issue 0009: develop-mode core (overlay + develop/undevelop/vendors)

Read `docs/superpowers/plans/agent-briefs/SHARED.md` first, then your issue:
`docs/superpowers/issues/0009-develop-mode-core-overlay.md`, then ADR 0007.

## Your role

Implementer of issue 0009. **You HOLD the in-tree build lock** (0007/0008 are
done; no other agent builds until you announce completion with a commit
containing `0009` + `cmux notify`).

## State you inherit (post-0007/0008, commits a30e7706e5 + 367de99fc2)

- `status.nims` exists at the repo root: working `app`/`run` tasks
  (delegation-only, make frozen — read it fully, match its style and its
  fail-fast error conventions), plus fail-fast STUBS for
  `develop`/`undevelop`/`vendors` that you now implement. Its Phase-A spike
  findings (in issue 0008) document nimscript argv parsing — reuse that
  machinery for `<vendor>` args.
- sds is pinned: `statusgo.nimble` requires
  `https://github.com/alexjba/nim-sds.git#5c89d61f…`; the store copy builds
  via `vendor/status-go/.sds-build/` scratch. A local `vendor/nim-sds`
  checkout still EXISTS at exactly 5c89d61 — your `develop sds` must detect
  and reuse it (never clobber), which is also your best test fixture.
- statusgo is still a submodule consumed via the interim absolute `file://`
  requires (0010 flips it to a URL pin). For `develop statusgo` TODAY this
  means: checkout already present; entering develop mode flips only the
  overlay/bookkeeping. Design the vendor table so 0010 only changes the pin
  source, not your code: per-vendor fields ~ {name, pin owner manifest,
  checkout dir, clone URL+rev derivation, flavor}. Include the table shape
  ready for 0011 (cmake flavor) and 0012 (seaqt `smo-6.4`, nimqml — see the
  grilled decision in issue 0012), but implement ONLY statusgo + sds rows.
- `nimble setup` stamp: `nimble.paths` keyed on lock + the three manifests
  (`make nimble-deps`). Your overlay file must JOIN that stamp key, and
  overlay application must run after every regeneration — including the
  derived copy `vendor/status-go/nimble.paths` (cmp-gated copy in the
  Makefiles; find that rule before touching anything).

## Design constraints (from the grill session — do not relitigate)

- Overlay = gitignored file recording developed vendors; applied by
  rewriting the vendor's entries in the generated nimble.paths (+ derived
  copies) to the checkout path. Tracked files must stay byte-identical
  across a develop/undevelop cycle.
- Divergence guard: at overlay-apply time, compare the checkout's `.nimble`
  manifest against the pinned store copy's; on divergence FAIL loudly with
  file://-escape-hatch instructions (AGENTS.md walls: sibling-#hash drop,
  chain rule). Never silently drift.
- `undevelop` refuses on uncommitted OR unpushed work unless `--force`;
  checkout dir stays in place, inert.
- Gating: developed vendor ⇒ FORCE + compare-before-copy (today's ADR-0003
  path — for sds this likely means the statusgo.nims engine's existing
  in-place branch; verify it fires for an overlaid path). The pinned
  stamp-skip arm is 0010's job — do NOT build it here, but don't preclude it.
- The nimble store may serve a REAL resolution need even while overlaid
  (transitive deps still come from the store) — the overlay replaces path
  entries only, never re-resolves. Editing a developed vendor's requires is
  exactly the divergence-guard case.

## Acceptance = the issue's five checkboxes. Notes:

- The sds cycle test (checkbox 1): after `undevelop sds`, artifacts must be
  byte-identical to pre-develop (the 0004 reproducibility work makes this a
  real `cmp`, not a hope). Use a scratch git branch inside vendor/nim-sds
  for the commit/refusal legs, then clean up.
- For the statusgo leg (checkbox 2), a Go edit = line-shifting comment near
  the top of `vendor/status-go/mobile/status.go` (the 0004 probe pattern);
  wrapper edit = any `status_go/impl.nim` comment. Both revert after.
- git-state hygiene test (checkbox 5): `git status --porcelain` identical
  before/after the full cycle (modulo the checkout dir itself).

Follow the SHARED completion protocol (verification record in the issue,
PRD row, progress.txt, commit with `0009`, notify).
