---
id: 0009
title: Develop-mode core — nimble.paths overlay + develop/undevelop/vendors tasks (statusgo, sds)
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: done (2026-07-07)
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

- [x] `develop sds` → edit an sds Nim source → `nim app status.nims` picks it
  up (in-place build observed) → commit on a branch in `vendor/nim-sds` →
  `undevelop sds` (refuses while unpushed; `--force` documented) → default
  build resolves the store copy again, artifacts byte-identical to pre-develop.
- [x] `develop statusgo` → edit a Go file AND the Nim wrapper → next build
  picks both up (FORCE + cmp observed on the library copy). *(Until 0010
  lands, statusgo is still a submodule — the develop task must detect the
  already-present checkout and only flip the overlay.)*
- [x] Manifest divergence (edit `sds.nimble` requires in the checkout) fails
  the next build loudly with escape-hatch instructions; reverting the edit
  unblocks.
- [x] Overlay state survives `nimble setup` regeneration (stamp invalidation →
  fresh nimble.paths → overlay reapplied deterministically, incl. the
  vendor/status-go derived copy).
- [x] Default mode with no overlay: tracked files byte-identical before/after
  a full develop/undevelop cycle (git status clean except the checkout dir).

## Blockers — grill before implementing

- The 0005 shim was built for the statusgo nimble.paths copy specifically;
  generalizing to the app's own nimble.paths must not fight the setup stamp
  (stamp keyed on manifests + lock; overlay file must join the stamp key).
  If ordering gets circular, grill before restructuring the stamps.

## Blocked by

- 0008 (the driver hosts these tasks).

## What was built (2026-07-07)

- `status.nims`: vendor table (statusgo + sds rows; fields ready for 0011's
  cmake flavor and 0012's seaqt `smo-6.4`/nimqml rows — flavor, developBranch,
  per-vendor FORCE arms), `develop`/`undevelop`/`vendors` tasks, the
  `applyOverlay` internal task, and develop-mode gating in `app`/`run`
  (divergence guard + FORCE arms + stamp re-invalidation when a manual
  `nimble setup` regenerated nimble.paths without the overlay). Pins are
  parsed live from the owning manifest, so 0010's file://→URL#hash flip needs
  zero driver changes.
- Overlay file = `nimble.overlay` (repo root, gitignored, name-per-line).
  Makefile: it joins the setup-stamp key via `$(wildcard)`, and the stamp
  recipe runs `nim applyOverlay status.nims` after every `nimble setup`
  (delegation only — logic stays in nimscript; bare `make` regeneration is
  therefore covered too). Derived copies (vendor/status-go/nimble.paths, the
  mobile rule) inherit through the existing cmp-gated copy rules untouched.
- Divergence guard compares the checkout's manifest against
  `git show <pinRev>:<manifest>` in the checkout's own history (byte-equal,
  modulo leading/trailing whitespace) — identical content to the pinned store
  copy, but immune to store wipes; skipped for interim file:// pins (there
  the checkout IS what resolution reads). Runs in the driver before every
  build AND inside applyOverlay (bare-make regeneration path).
- Rebuild gating while developed (ADR-0003 arm): sds ⇒ the driver touches the
  derived vendor/status-go/nimble.paths (forces the `$(NIMSDS_LIBFILE)`
  recipe every build; the statusgo.nims engine's in-place branch fires for
  the overlaid path) and the engine now cmp-mirrors in-place artifacts
  (`<checkout>/{build,library}` files) into `.sds-build/` — the one layout
  every Makefile reads (submodule commit 95166a5ab). statusgo ⇒ the driver
  removes `vendor/status-go/build/bin/libstatus.*` (the target has no real
  prerequisites; removal is what re-delegates to the internally-incremental
  sub-make) and passes `REBUILD_NIM=true` (the wrapper compiles into the
  client). Default mode (empty overlay) adds nothing — no-op stays ~8 s.

## Verification record (2026-07-07, macOS arm64 host; Qt 6.11.0 macos kit; post-0008 tree)

Env for all runs: `PATH=$PWD/vendor/nimbus-build-system/vendor/Nim/bin:$PATH`,
`QMAKE=~/Qt/6.11.0/macos/bin/qmake USE_SYSTEM_NIM=1`. Store =
`~/.cache/status-desktop-nimbledeps`. Baselines:
libsds.dylib (.sds-build/build) `3cbdd206…`, bin/nim_status_client
`d5d2717b…`, libstatus.dylib `5c06eddb…`.

- **sds cycle (criterion 1)**: `nim develop status.nims sds` reused the
  existing vendor/nim-sds at 5c89d61 ("never clobbered"), wrote
  `nimble.overlay`. Line-shifting comment prepended to `sds/message.nim` (on
  scratch branch claude-0009-scratch). `nim app status.nims` = 1:02 wall:
  stamp regen (`nimble setup` + `applyOverlay: sds → vendor/nim-sds (2 path
  entries)`), derived copy byte-identical to the app's, libsds built IN
  PLACE (`out: …/vendor/nim-sds/build/libsds.dylib` in the log), mirror
  updated `.sds-build/build/libsds.dylib` → `78559df9…`, client untouched
  (`d5d2717b…`, no relink — shared dylib). Develop-mode no-op re-run = 5.9 s:
  sds engine re-ran (FORCE via the derived-paths touch), cmp gate held
  (mirror mtime unchanged). `undevelop sds` REFUSED on the uncommitted edit
  (listed it), then after `git commit` on the scratch branch REFUSED on the
  unpushed commit (listed it), `--force` exited develop mode. Next default
  build = 58 s (stamp regen): nimble.paths back to
  `pkgs2/sds-0.3.0-89a7872a…`, libsds rebuilt from the store scratch —
  **byte-identical to baseline** (`3cbdd206…`), client untouched
  (`d5d2717b…`). Scratch branch deleted; checkout back on fix/nimble-setup
  at 5c89d61, clean.
- **statusgo leg (criterion 2)**: `develop statusgo` detected the submodule
  checkout (HEAD 14b605b81) and only flipped the overlay (its nimble.paths
  entry already points at vendor/status-go under the interim file:// pin —
  rewrite is the identity). Probes: line-shifting `//` comment at
  `mobile/status.go:2` + `#` comment at `status_go/impl.nim:1`. `nim app` =
  2:31 wall, log shows `Building: status-go` (rm-FORCE re-delegated the
  sub-make) and `Building: bin/nim_status_client` (REBUILD_NIM):
  libstatus.dylib `5c06eddb… → 1f2c9717…`, client `d5d2717b… → 2fa3071c…`,
  wrapper module object (`nimcache/release/nim_status_client/
  @pstatus_go.nim.c.o`) regenerated at build time. Probes reverted. On
  desktop the "cmp arm" is structural rather than a copy: the client is
  order-only on the shared libstatus/libsds (no false relinks); the literal
  cmp-copies live in the sds mirror and the mobile `$(STATUS_GO_LIB)` FORCE
  recipe (ADR 0003).
- **divergence guard (criterion 3)**: with sds developed, edited
  `vendor/nim-sds/sds.nimble` (`libp2p >= 1.15.2` → `1.15.3`).
  `nim app status.nims` → exit 1 in seconds with "developed vendor 'sds' has
  a DIVERGED manifest", naming the pinned rev, the exact `git -C … diff/
  checkout` revert commands, and the full file:// escape hatch incl. the
  sibling-#hash-drop and file://-chain walls. Bare-make path equally loud:
  `make nimble-deps` → same message, rc=2 (guard also runs inside
  applyOverlay). `git -C vendor/nim-sds checkout -- sds.nimble` unblocked;
  the follow-up build also exercised the self-heal path (the aborted recipe
  had left a regenerated nimble.paths without the overlay; the driver
  detected the un-applied overlay, re-invalidated the stamp, and the build
  regenerated + applied it: `applyOverlay: sds → vendor/nim-sds`).
- **overlay survives regeneration (criterion 4)**: with sds developed,
  `touch nimble.lock && make nimble-deps` → fresh `nimble setup`, then
  `applyOverlay: sds → vendor/nim-sds (2 path entries)`; both sds entries in
  the new nimble.paths point into vendor/nim-sds and
  `cmp nimble.paths vendor/status-go/nimble.paths` = identical.
- **git hygiene (criterion 5)**: `git status --porcelain` snapshots before
  the first develop and after the final undevelop+default build differ ONLY
  by this issue's own edits (config.nims fix below; vendor/nim-sds is
  gitignored, nimble.overlay is gitignored, vendor/status-go shows only its
  new commit). Default no-op after everything: **7.7 s** (0008 baseline 7 s
  — default mode pays nothing for the new machinery).

### Walls hit (both documented in vendor/status-go/AGENTS.md)

- **Warm re-setups emit dangling srcDir entries for srcDir-hoisted store
  copies** (new wall): materializing setup stores alexjba/isaac hoisted
  (isaac.nim at the entry root) and emits a root path entry; every warm
  re-setup re-derives `<root>/src` from the manifest — which doesn't exist —
  so the first client recompile after any warm re-setup died with `cannot
  open file: isaac`. Pre-existing (0009 merely triggers more setups and, via
  REBUILD_NIM, more client recompiles); proven by wiping only the isaac
  store entry (fresh setup → root entry; second setup → /src). Fix:
  config.nims' isaac hack now points at whichever of `<entry>`/`<entry>-/src`
  exists.
- **Nested-worktree parent config.nims rpath leak** (known, previously fixed
  in the seaqt worktree): the enclosing checkout (release/2.38.x) references
  the pre-rename `STATUSKEYCARDGO_LIBDIR`; empty → bare `-rpath` → ld eats
  the next arg → "file cannot be mmap()ed … bin/StatusQ". Fix: Makefile
  aliases `export STATUSKEYCARDGO_LIBDIR := $(STATUSKEYCARD_QT_LIBDIR)`.

### Notes / follow-ups (not in scope)

- Desktop `libstatus.dylib` is NOT byte-reproducible across identical
  rebuilds (`5c06eddb… → bcecadf0…` after probe-revert rebuild): the desktop
  `statusgo-shared-library` recipe lacks the `-ldflags=-buildid=` the 0004
  work gave the mobile recipes. Harmless today (client is order-only on it);
  becomes 0010's business for the stamp-skip arm.
- Bare `make` with a NON-empty overlay: regeneration and the apply-time
  divergence guard are covered (stamp recipe), but the per-build FORCE arms
  and the per-build guard run only through the driver — `nim app
  status.nims` is the develop-mode front door.
- statusgo develop-mode FORCE cost: sub-make re-delegation + REBUILD_NIM
  client recompile ≈ 2:30 warm per build; sds develop-mode no-op ≈ 6 s.
- `undevelop` "unpushed" = `git log --branches --not --remotes` over ALL
  local branches (a checkout with no remotes refuses everything until
  --force) — intentional: exiting develop mode must never orphan work.
