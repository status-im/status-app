---
id: 0010
title: status-go full-pin — submodule removed, URL#hash requires, stamp-skip default arm
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: closed
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

- [x] From a clean clone (no submodule init for status-go), wiped store:
  `nim app status.nims` builds and launches the desktop app with statusgo
  resolved from the pin.
- [x] Default-mode no-op rebuild does NOT invoke the status-go sub-make
  (verify by absence of its log banner), and total no-op `nim app` wall time
  is seconds-level — record the number against 0008's baseline.
- [x] Pin bump (amend the #hash) invalidates the stamp and rebuilds from the
  new store copy without manual cleaning.
- [x] `develop statusgo` (0009) on a repo with no checkout: materializes the
  clone, next build FORCE-delegates and picks up a Go edit; `undevelop`
  returns to stamp-skip with byte-identical artifacts.
- [x] iOS + Android mobile builds pass from the pinned store copy (the 0004
  matrix re-run, at least one leg each).
- [x] Platform sentinel (ADR 0003) still cleans shared artifacts across
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

## Implementation notes (2026-07-07)

- **New wall (grilled, user-approved fix):** nimble 0.22.3 builds dependency
  binaries unconditionally during store materialization — statusgo.nimble's
  `bin = @["status_backend"]` forced buildtemp + the before-build hook (full
  host Go build) into every consumer `nimble setup`, and the documented
  hook-cancel (`STATUS_GO_SKIP_GO_BUILD=1` → `return false`) hard-fails the
  whole setup. nimble's "hybrid" support (`installExt`) only whitelists
  install FILES (and any whitelist strips go.mod/Makefile/*.go from the store
  copy) — it cannot skip the build. Fix: statusgo.nimble went SOURCE-ONLY on
  `nimble-phase1-pin` (submodule commit d9281bce9: no bin/installDirs/
  installFiles/hook); status_backend stays buildable from checkouts via
  statusgo.nims. Both walls documented in status-go AGENTS.md. Upstream ask
  (to file): dependency materialization should be able to skip bin builds.
- Version stamping resolved without a status-go change: library targets never
  need git; only the app-side `STATUSGO_VERSION` define did. Pinned mode
  derives it from the store entry's `nimblemeta.json` `vcsRevision` (the pin
  SHA, URL-agnostic); a developed checkout keeps `git describe`.
- go.mod local replaces: none exist on this branch (no `third_party/`), so
  the scratch Go build needs no replace-path handling. Go module downloads
  come from the shared module cache / network as before.
- Scratch engine: `.statusgo-build/` at the repo root (gitignored), owned by
  `nim prepareStatusgo status.nims` — wipe+copy of the store entry keyed on
  (store path [= pin + manifest checksum], caller `--key` flag set); target
  triple flips stay with the platform sentinel. Both Makefiles derive
  `STATUSGO_ROOT` (scratch vs checkout) from `nimble.overlay`, and every
  status-go/sds rule + artifact path (STATUSGO_LIBDIR, NIMSDS_*,
  stub-bindings gen) rides that root — nothing references
  `vendor/status-go/...` directly anymore.
- Mode flips (develop/undevelop) additionally drop `bin/nim_status_client`:
  the desktop client bakes the artifact dir as an rpath, which now differs
  between scratch and checkout.
- The desktop 24h force-rebuild pre-clean (scripts/force-rebuild-status-go.sh)
  is develop-mode-only now — a pinned statusgo cannot go stale.
- Known cosmetic cost kept: any warm re-`nimble setup` rewrites nimble.paths
  with the isaac srcDir variant (documented 0009 wall), which cmp-propagates
  into the scratch and re-runs the libsds task once (~10 s).
- `scripts/bump-status-go.sh` (submodule-era pin bump helper) is obsolete —
  a pin bump is now a one-line `#hash` edit in nim_status_client.nimble.
  Left in place; delete alongside CI migration.

## Verification record (2026-07-07)

Environment: macOS (darwin-arm64), Qt 6.11.0, nim 2.2.4 + nimble 0.22.3 on
PATH, store = ~/.cache/status-desktop-nimbledeps. Until the user pushed
`nimble-phase1-pin`, the pin URL was a loopback dumb-HTTP serve of the local
submodule (`http://127.0.0.1:8417/status-go.git#d9281bce9…`) — store entries
are content-addressed, so every artifact-level result carries over to the
GitHub URL verbatim; the criteria below marked (GitHub re-run) were repeated
against `https://github.com/status-im/status-go.git#d9281bce9…` after the
push.

0. **GitHub-pin re-run:** wiped store + scratch → `make nimble-deps` = 6:59
   (clean solve + fresh GitHub clone of status-go into pkgcache); resolution
   materialized the IDENTICAL content-addressed entry
   (`statusgo-0.1.0-4f85453ac…`, nimblemeta url = github, vcsRevision =
   d9281bce9) → `nim app` 50 s (warm Go cache) produced a libstatus.dylib
   BYTE-IDENTICAL to the loopback-pin build (cmp) → launch smoke: both
   libstatus + libsds loaded from `.statusgo-build/`, clean SIGTERM exit.
   After the submodule removal (below): client relink build 2:45, launch
   smoke again OK, no-op 5.5 s with zero status-go references in the whole
   build log, and `nim vendors status.nims` resolves the sds pin from the
   STORE manifest (no checkout anywhere).
0b. **Lock finding (blocker note resolved):** regenerating the lock is a
   net NEGATIVE and was reverted — URL#hash-required packages (statusgo, and
   transitively sds/libp2p/lsquic/…) never enter `nimble lock`'s output at
   all on 0.22.3 (37 classic packages before and after), so nothing is
   gained; worse, the regen writes isaac's `vcsRevision` as "" (the
   INI-manifest empty-version artifact reaching the lock writer) and drifts
   snappy's pick. The committed lock stays; per the documented wall it never
   constrains solves anyway (clean-store setups above all ran against it).
0c. **Submodule removal (staged playbook):** superproject backup ref
   `backup/nimble-0010-statusgo`; `git config -f .gitmodules
   --remove-section` + `git rm --cached vendor/status-go`; directory
   preserved (NOT deleted) at `.phase2-vendor-backup/status-go` with a
   FUNCTIONAL git dir (module gitdir untouched; `core.worktree` repointed —
   `git status`/`push` keep working from the new location).

1. **Wiped store → desktop build + launch** (criterion 1): `rm -rf
   ~/.cache/status-desktop-nimbledeps nimble.paths .statusgo-build` → `make
   nimble-deps` = 6:31 (clean-store solve included; 0007 baseline 6:17),
   statusgo materialized as `pkgs2/statusgo-0.1.0-4f85453ac…` (58 MB full
   tree, no .git, vcsRevision d9281bce9) → `nim app status.nims` built
   libsds + libstatus.dylib in `.statusgo-build/` and relinked the client
   (rpath → `<repo>/.statusgo-build/build/bin`). `make run`: app process up,
   `lsof` shows libstatus.dylib + libsds.dylib loaded FROM .statusgo-build/,
   clean SIGTERM exit. `make status-go-version` = d9281bce98.
2. **No-op stamp-skip** (criterion 2): zero "Building: status-go"/sds
   banners, zero sub-make invocations (grep-verified):
   - desktop `nim app`: **5.9 s** (0008 baseline: 7 s driver no-op, and that
     baseline still re-entered the sub-make daily via the 24h force-rebuild)
   - iOS `nim app --os:ios --cpu:arm64`: **15.1 s** (0008 baseline: ~70 s
     warm FORCE chain)
   - Android `nim app --os:android --cpu:arm64`: **15.2 s** (same 70 s
     baseline)
   - bare `make -j10 nim_status_client`: **5.9 s** (make targets unchanged)
3. **Pin bump** (criterion 3): amending the manifest #hash to a
   content-changed throwaway commit (7e2122af) re-ran setup, materialized a
   NEW store entry (`statusgo-0.1.0-10eb957f…`), auto-refreshed the scratch
   (`.statusgo-origin` flipped) and rebuilt libsds + libstatus with no manual
   cleaning (1:09 wall, warm Go cache); flipping back to d9281bce9 did the
   same in reverse (1:47) and `make status-go-version` tracked each pin.
   Bonus: an empty-commit bump (identical tree = identical content checksum)
   correctly re-used the existing store entry and did NOT rebuild.
4. **develop statusgo cycle** (criterion 4, run from a true no-checkout
   state — the submodule dir was parked outside the tree for the test):
   `nim develop status.nims statusgo` cloned the pin URL into
   vendor/status-go (8 s local; branch `develop` @ d9281bce9, origin = pin
   URL) and dropped bin/nim_status_client (rpath flip). Next `nim app` =
   3:57: overlay applied (nimble.paths → checkout), FORCE arm rebuilt
   libstatus in the checkout, client relinked (rpath →
   vendor/status-go/build/bin). Go-edit pickup: an exported probe func in
   mobile/status.go was picked up by the next build — first as a build
   BREAK (the cbindings generator wrapped it and its `int` return violated
   the wrapper contract: pickup proven), then, fixed to `string`, as 2
   `StatusGoPinTest0010` symbols in the develop-built dylib (2:47).
   `undevelop` refused while the probe edit was uncommitted (exact dirty
   file listed); after revert it exited cleanly, and the next `nim app`
   (2:59, mostly the client relink) invoked ZERO status-go sub-makes, left
   `.statusgo-build/build/bin/libstatus.dylib` BYTE-IDENTICAL to the
   pre-develop pinned artifact (cmp), relinked the client rpath back to the
   scratch, and the probe symbol is absent from the pinned artifact.
5. **Mobile legs** (criterion 5): iOS device build (signed, codesign
   --deep --strict OK, Mach-O arm64) in **2:47**; Android assembleDebug APK
   in **3:30** with all 5 arm64-v8a native libs (libstatus.so, libsds.so,
   libnim_status_client.so, libstatus_stub.so, libstatus_service.so). Both
   built from the pinned store copy via the scratch (0008 baselines: 2:45 /
   3:28 — parity).
6. **Platform sentinel** (criterion 6): darwin→ios→android→darwin flips each
   fired (`.platform-target` tracked), cleaning `.statusgo-build/build/bin/
   libstatus.*` + `.statusgo-build/.sds-build` under the new artifact-path
   contract; the desktop flip-back rebuilt dylib flavor in 54 s with exactly
   one sub-make invocation.
