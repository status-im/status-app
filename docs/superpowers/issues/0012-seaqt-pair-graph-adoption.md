---
id: 0012
title: seaqt pair — feasibility spike, then nimble-graph adoption (spike-gated)
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`

## What to build

Move `seaqt` (vendor/nim-seaqt, branch qt-6.4) and `nimqml`
(vendor/nimqml-seaqt) from special-cased submodules (hardcoded `config.nims`
path switches, lines ~31–32) into the nimble graph as pinned `URL#hash`
requires — the riskiest conversion of the iteration, so it is **spike-gated**:

**Spike first (timeboxed):** from a scratch consumer, `requires
"https://github.com/seaqt/nim-seaqt.git#<qt-6.4 head>"` + nimqml pin; verify
(1) both resolve on nimble 0.22.3 (branch-pinned generated packages; watch the
version-table walls in vendor/status-go/AGENTS.md), (2) a store copy compiles
the seaqt C++ shims (read-only store vs in-package compilation — if writes are
needed, the sds `.sds-build/` scratch pattern is the fallback), (3) the app's
`config.nims` compatibility include path (line ~108) has a store-relative
equivalent, (4) qt-pkgconfig/Qt-flag discovery still works from a store path
(memory: prl-to-pc / qt-pkgconfig.mk machinery). Record findings in the spec
before proceeding.

**If the spike passes:** flip both to pins, delete the two submodules (staged,
Phase 2 playbook) and the special config.nims path switches; vendor-table
entries (nimble-graph flavor) so `develop seaqt` / `develop nimqml` work via
the 0009 overlay.

**If the spike fails:** they stay submodules this iteration; add
vendor-table entries of a third trivial flavor ("submodule": develop = no-op
with an explanatory message, undevelop = refuse) so the `vendors` listing is
complete and honest; file the blocking findings in the spec as upstream/next
iteration work.

## Acceptance criteria

- [x] Spike record written (pass or fail, with evidence) in
  `docs/superpowers/specs/` and linked here —
  **PASS on all four questions** (+ merged app-graph resolution check):
  `docs/superpowers/specs/2026-07-06-seaqt-graph-spike.md` (2026-07-06).
  Conversion NOT started: per the blocker below, the findings go to a
  grill session first (and the conversion itself is blocked by 0009).
- [ ] Pass path: default-mode desktop build with NO seaqt/nimqml checkouts;
  storybook + app launch OK; `develop nimqml` → edit a Nim source in the
  compat layer → next build picks it up → `undevelop` restores the pin.
- [ ] Pass path: mobile leg spot-check (one platform) — seaqt cross-compile
  from store/scratch copy.
- [ ] Fail path: submodule flavor entries in the vendor table + findings
  recorded; default build unchanged.

## Blockers — grill before implementing

- The spike outcome itself IS the grill input: whichever branch it selects,
  run a /grill-with-docs session on the findings before the conversion (pass
  path changes config.nims contracts; fail path changes iteration scope).

## Blocked by

- 0009 (vendor table + overlay).
