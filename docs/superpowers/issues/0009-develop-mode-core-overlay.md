---
id: 0009
title: Develop-mode core — nimble.paths overlay + develop/undevelop/vendors tasks (statusgo, sds)
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`
Mechanism ADR: `docs/adr/0004-develop-mode-via-paths-overlay.md`

## What to build

The develop-mode engine in the `status.nims` driver, covering the two
nimble-graph vendors that matter most (statusgo, sds):

- **Vendor table** in the driver: name → pin-owning manifest → checkout dir
  (`vendor/<name>`) → flavor (nimble-graph | cmake). This issue implements the
  nimble-graph flavor; 0011 adds the cmake flavor entries.
- `nim develop status.nims <vendor>`: clone the vendor's pin URL into
  `vendor/<name>` (origin = pin URL, checked out at the pinned revision, on a
  branch), record it in a gitignored overlay file, invalidate the setup stamp.
  Idempotent: re-entry reports state; an existing dirty checkout is NEVER
  clobbered (reuse it, just flip the overlay).
- **Overlay application**: after any (stamp-gated) `nimble setup`, rewrite the
  developed vendor's entries in the app's `nimble.paths` — and every derived
  copy (vendor/status-go's nimble.paths) — to the checkout path. Build engines
  already build non-store paths in place (statusgo.nims sds engine), giving
  next-build pickup for Nim/C++/Go edits with no extra machinery.
- **Divergence guard**: at setup/overlay time, compare the checkout's manifest
  (`.nimble`) against the pinned store copy; on divergence FAIL the build with
  a message explaining the file:// escape hatch (temporarily flipping the
  requires; see AGENTS.md walls — sibling-#hash drop, chain rule) and how to
  return.
- `nim undevelop status.nims <vendor>`: remove the overlay entry + restore
  store resolution; refuse when the checkout has uncommitted or unpushed work
  unless `--force`. The checkout dir is left in place (inert) unless the user
  deletes it.
- `nim vendors status.nims`: list vendors, pins, and develop state.
- Rebuild gating (with 0010): developed vendor ⇒ FORCE + compare-before-copy
  (ADR 0003 arm); pinned vendor ⇒ stamp-skip.

## Acceptance criteria

- [ ] `develop sds` → edit an sds Nim source → `nim app status.nims` picks it
  up (in-place build observed) → commit on a branch in `vendor/nim-sds` →
  `undevelop sds` (refuses while unpushed; `--force` documented) → default
  build resolves the store copy again, artifacts byte-identical to pre-develop.
- [ ] `develop statusgo` → edit a Go file AND the Nim wrapper → next build
  picks both up (FORCE + cmp observed on the library copy). *(Until 0010
  lands, statusgo is still a submodule — the develop task must detect the
  already-present checkout and only flip the overlay.)*
- [ ] Manifest divergence (edit `sds.nimble` requires in the checkout) fails
  the next build loudly with escape-hatch instructions; reverting the edit
  unblocks.
- [ ] Overlay state survives `nimble setup` regeneration (stamp invalidation →
  fresh nimble.paths → overlay reapplied deterministically, incl. the
  vendor/status-go derived copy).
- [ ] Default mode with no overlay: tracked files byte-identical before/after
  a full develop/undevelop cycle (git status clean except the checkout dir).

## Blockers — grill before implementing

- The 0005 shim was built for the statusgo nimble.paths copy specifically;
  generalizing to the app's own nimble.paths must not fight the setup stamp
  (stamp keyed on manifests + lock; overlay file must join the stamp key).
  If ordering gets circular, grill before restructuring the stamps.

## Blocked by

- 0008 (the driver hosts these tasks).
