---
id: 0010
title: status-go full-pin — submodule removed, URL#hash requires, stamp-skip default arm
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`

## What to build

Make status-go "a vendor like any other" (Q6 decision: full-pin end state):

- **User prerequisite**: the local status-go work (statusgo.nimble,
  statusgo.nims, absorbed wrapper, cbindings determinism fixes) is committed
  and pushed by the user to a reachable branch (fork or status-im) — a
  `URL#hash` pin can only bind pushed commits. Coordinate the exact
  URL+SHA with the user; do not push anything yourself.
- App manifest: replace `requires "file:///…/vendor/status-go"` with the
  `URL#hash` pin (comment: interim branch pin until upstream merge).
- Remove the `vendor/status-go` submodule from default mode (staged removal,
  same playbook as Phase 2's 25 submodules; backup ref first). Develop mode
  (0009) materializes the checkout on demand.
- **Store-scratch Go build**: pinned statusgo resolves to a read-only store
  copy; building libstatus/libsds artifacts from it uses a scratch copy
  (extend the proven `.sds-build/` engine pattern to statusgo itself — the
  0002 install proof already built Go from a staged copy). Artifact-dir
  contract (`build/bin`) moves behind the driver: desktop/mobile make rules
  consume driver-exported artifact paths, never `vendor/status-go/...`
  directly.
- **Stamp-skip default arm** (Q9): pinned statusgo + unchanged (store path,
  target triple, flags) + artifact present ⇒ the status-go sub-make is NOT
  invoked at all. Developed statusgo ⇒ today's FORCE + compare-before-copy.
- Go module hygiene: the go.mod replace / local-path assumptions
  (third_party/go-waku etc.) must hold from the scratch copy — verify, and
  grill if the scratch build needs network or breaks replaces.

## Acceptance criteria

- [ ] From a clean clone (no submodule init for status-go), wiped store:
  `nim app status.nims` builds and launches the desktop app with statusgo
  resolved from the pin.
- [ ] Default-mode no-op rebuild does NOT invoke the status-go sub-make
  (verify by absence of its log banner), and total no-op `nim app` wall time
  is seconds-level — record the number against 0008's baseline.
- [ ] Pin bump (amend the #hash) invalidates the stamp and rebuilds from the
  new store copy without manual cleaning.
- [ ] `develop statusgo` (0009) on a repo with no checkout: materializes the
  clone, next build FORCE-delegates and picks up a Go edit; `undevelop`
  returns to stamp-skip with byte-identical artifacts.
- [ ] iOS + Android mobile builds pass from the pinned store copy (the 0004
  matrix re-run, at least one leg each).
- [ ] Platform sentinel (ADR 0003) still cleans shared artifacts across
  desktop↔mobile switches under the new artifact-path contract.

## Blockers — grill before implementing

- Scratch-copy Go builds: status-go's Makefile assumes a writable repo (git
  describe for version stamping, generate targets). Verify what the pinned
  store copy carries (no .git!) — version stamping from a gitless copy needs
  a decided convention (embed pin SHA via the driver?). Grill this; do not
  invent silently.
- nimble.lock interaction: the app lock omitted file:// packages; with a URL
  pin, statusgo + its transitive picks enter the lock — expect the known
  lock-divergence hand-fix pattern and verify against a clean store.

## Blocked by

- 0009 (develop mode must exist before the always-editable submodule is
  removed, or status-go development regresses).
