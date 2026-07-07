---
id: 0012
title: seaqt pair — feasibility spike, then nimble-graph adoption (spike-gated)
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: closed (2026-07-07, pass path)
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
- [x] Pass path: default-mode desktop build with NO seaqt/nimqml checkouts;
  storybook + app launch OK; `develop nimqml` → edit a Nim source in the
  compat layer → next build picks it up → `undevelop` restores the pin.
  (Verification record below, 2026-07-07.)
- [x] Pass path: mobile leg spot-check (one platform) — seaqt cross-compile
  from store/scratch copy. (iOS device leg; record below.)
- [x] Fail path: n/a — the spike passed and the pass path shipped; no
  submodule-flavor entries needed (`vendors` lists the pair as nimble-graph).

## Blockers — grill before implementing

- The spike outcome itself IS the grill input: whichever branch it selects,
  run a /grill-with-docs session on the findings before the conversion (pass
  path changes config.nims contracts; fail path changes iteration scope).
- GRILLED 2026-07-07 (spike findings session, user-approved): take the PASS
  path with the CURRENT submodule SHAs — nim-seaqt `2d95808` (branch
  `smo-6.4`, the Status-specific generation; the repo's only tag
  `qt-6.4-seaqt-gen-5bc1bc58…` points exactly at it — durable ref) and
  nimqml `c5e5831`. Record branch `smo-6.4` in the vendor-table entry so
  `develop seaqt` checks out the right line. Any pin bump is a SEPARATE
  later decision: upstream `qt-6.4` is force-pushed and untagged (SHA pins
  there are fragile; its head drops the QVariantConstPointer include, i.e.
  the seaqt_compat shim), and a `qt-6.11` branch now exists matching the
  actual Qt kit — both are follow-up candidates with app-wide API-churn
  risk, needing their own compile/QA pass and ideally an upstream tag.
  Conversion remains blocked by 0009.

## Blocked by

- 0009 (vendor table + overlay).

## What was built (2026-07-07)

- `nim_status_client.nimble`: `requires "https://github.com/seaqt/
  nim-seaqt.git#2d95808bdd9f6dd2c212b69a57af4618da241d37"` (branch smo-6.4
  per the grill) + `requires "https://github.com/seaqt/nimqml-seaqt.git#
  c5e5831ae7d71e09f7061bc7735a8f3e1adc8fb3"`. Pure-source packages — the
  C++ shims compile via `{.compile.}` into the client nimcache, straight
  from the read-only store (no scratch engine; spike Q2).
- `config.nims`: the two hardcoded path switches (ex lines 38–39) deleted —
  `nimble.paths` carries the roots; the isaac srcDir-hoist hack generalized
  to a `["isaac", "nimqml"]` loop (nimqml declares `srcDir = "src"` and its
  store copy is hoisted — same wall class). `seaqt_compat` include kept
  app-owned, unchanged (spike Q3).
- `status.nims`: two vfNimbleGraph vendor rows — `seaqt` (developBranch
  `smo-6.4`) and `nimqml` (developBranch `master`), both
  `clientRebuild: true` (their sources compile INTO the client;
  REBUILD_NIM is the whole FORCE arm, no vendor artifacts). New Vendor
  field `srcDir`: `rewriteEntries` remaps a hoisted store ROOT entry onto
  `<checkout>/<srcDir>` so the overlay points at the checkout's real module
  root (nimqml store copies are hoisted, the checkout keeps `src/`).
- Submodules removed ×2 (staged playbook): backup branches
  `backup/nimble-0012-pin` in both module gitdirs; `.gitmodules` sections
  removed; `git rm --cached`; directories preserved with FUNCTIONAL git
  dirs at `.phase2-vendor-backup/{nim-seaqt,nimqml-seaqt}` (`core.worktree`
  repointed; status/branch verified from there). `.gitignore` gains
  `/vendor/nim-seaqt/` + `/vendor/nimqml-seaqt/` (develop checkouts).
- BUILDING.md: seaqt-pair paragraph (pinned, pure-source, develop UX);
  submodule list shrinks to the C/C++-only set.
- `nimble.lock` intentionally NOT regenerated: URL#hash-required packages
  never enter the lock on 0.22.3 and regen is a net negative (0010 lock
  finding; the lock never constrains solves — documented wall).

### Playbook gotchas (new, for future removals)

- `git rm --cached <submodule>` refuses until the `.gitmodules` edit is
  staged — stage `.gitmodules` first.
- Once the working dir is moved, `git -C <newdir> config core.worktree …`
  fails (git validates the dangling worktree before running config); write
  through the module gitdir instead:
  `git config --file <gitdir>/config core.worktree <abs-new-path>`.

## Verification record (2026-07-07, macOS arm64 host; Qt 6.11.0 kits; nim 2.2.4 + nimble 0.22.3)

Env: `PATH=$PWD/vendor/nimbus-build-system/vendor/Nim/bin:$PATH`,
`QMAKE=~/Qt/6.11.0/macos/bin/qmake USE_SYSTEM_NIM=1` (iOS leg:
`QMAKE=~/Qt/6.11.0/ios/bin/qmake IPHONE_SDK=iphoneos
QMAKE_DEVELOPMENT_TEAM=8B5X2M6H2Y`). Store =
`~/.cache/status-desktop-nimbledeps`.

0. **Resolution + store shape** (submodules still present, warm store):
   `nimble setup` = 1:03, both pins resolved to the exact spike entries
   (`pkgs2/seaqt-0.6.4.0-4b05762909…`, `pkgs2/nimqml-0.9.2-1d366a53b…`,
   nimqml hoisted). Warm client rebuild (2:11): nimcache json shows 142
   store-seaqt + 2 store-nimqml source references and ZERO
   `vendor/nim-seaqt|nimqml-seaqt` references — the submodules were already
   inert before removal; `-I<repo>/seaqt_compat` visible on the
   `gen_qvariant.cpp` compile line (Q3 in production).
1. **Wiped-store default build, NO checkouts** (criterion 1): submodules
   removed, `rm -rf ~/.cache/status-desktop-nimbledeps nimble.paths` +
   dropped client → `nim app status.nims` = **9:10** end-to-end (clean
   solve included; usual special-version warnings only) → launch smoke:
   process up, onboarding QML rendered, StatusKeycardQt/PC-SC init in log,
   `lsof` shows libstatus + libsds from `.statusgo-build/` and keycard lib
   from `build/status-keycard-qt/macos`, clean SIGTERM exit.
   `make storybook-build` = **1:35**, pass. Default no-op `nim app` =
   **7.7 s** (final, end-of-issue: 6.3 s).
2. **srcDir-hoist wall check** (the isaac wall, nimqml exposure): a warm
   re-setup flips isaac to the dangling `<entry>/src` variant as documented,
   but seaqt/nimqml KEPT their root entries — direct root-level `URL#hash`
   requires re-derive differently from transitive range picks. The nimqml
   arm of the config.nims hack is therefore a safety net, not load-bearing
   today; post-warm-resetup import probe (`import NimQml`/`import isaac`)
   resolves.
3. **develop nimqml cycle** (criterion 1b): `develop nimqml` cloned the pin
   URL → `vendor/nimqml-seaqt`, local branch `master` @ c5e5831. Next
   `nim app` (2:56): `applyOverlay: nimqml → vendor/nimqml-seaqt (1 path
   entry)` and the rewritten entry is `<repo>/vendor/nimqml-seaqt/src` —
   the srcDir remap observed working. Probe (exportc proc appended to
   `src/seaqt/private/metaobjectgen.nim`) compiled into the linked unit:
   `nm` of `@pseaqt@sprivate@smetaobjectgen.nim.c.o` shows
   `T _nimqml_0012_probe` (LTO internalizes it out of the final
   executable); client hash changed (26d0a82f… → 0bf3ccb4…) = relink.
   `undevelop` REFUSED while dirty (named the exact file); after revert it
   exited cleanly (no unpushed refusal — local master at the pin is an
   ancestor of origin/master, correct semantics). Next build (2:55)
   restored the store entry in nimble.paths; probe gone from the recompiled
   unit. **cmp vs pre-develop baseline: NOT byte-identical** — size
   17758096 → 17758160 (+64 B) and a fresh LC_UUID; expected and explained:
   Mach-O mints a new UUID on every relink and the stabs (N_OSO) reference
   nimcache object mtimes — the desktop client was never
   relink-reproducible (0009 note); the INPUTS are the identical store
   paths again.
4. **Mobile spot-check, iOS device** (criterion 2): `nim app status.nims
   --os:ios --cpu:arm64` = 2:33, rebuilt `libnim_status_client.a` with 222
   fresh `@pseaqt` C++-shim units + `@pnimqml` at the shared nimcache; the
   LTO bitcode of `@pseaqt@sQtCore@sgen_qvariant.cpp.o` embeds
   `arm64-apple-ios17.0.0` and the STORE source path
   (`…/pkgs2/seaqt-0.6.4.0-4b05762…/seaqt/QtCore/gen_qvariant.cpp`) — the
   cross-compile consumed the store copy, and the `seaqt_compat` shim works
   on the iOS kit too (gen_qvariant compiles). Signed `Status.app` built;
   `codesign --verify --deep --strict` OK. A follow-up lib-drop rebuild
   relinked from cached units in 1:30. NOTE for readers of the shared
   nimcache: pre-conversion `@m..@svendor@snim-seaqt…` units linger with
   old mtimes — inert; the fresh units are the `@pseaqt…` set.
5. **Divergence guard, right manifest per vendor** (brief item 3):
   `develop seaqt` cloned → branch **smo-6.4** @ 2d95808b (the grilled
   developBranch). Appending a requires to `vendor/nim-seaqt/seaqt.nimble`
   failed the next `nim app` in seconds: "developed vendor 'seaqt' has a
   DIVERGED manifest", naming `seaqt.nimble`, pin 2d95808b, the exact
   revert commands and the file:// escape hatch. Revert + `undevelop`
   clean. Both checkouts deleted afterwards (default mode = no checkouts).
6. **`nim vendors status.nims`** (criterion: all six): lists statusgo, sds,
   seaqt, nimqml (nimble-graph) + status-keycard-qt, keycard-qt (cmake),
   each with pin URL#rev and default/develop state; seaqt + nimqml report
   "no checkout" in default mode.
7. **Platform sentinel**: the ios→desktop flip-back rebuilt the desktop
   flavors (libsds, status-go dylib, client relink; 3:27) with the sentinel
   firing as designed; final default no-op **6.3 s**.

### Residuals / notes

- The nested-worktree parent checkout carries a stale `nimble.paths` (a
  `~/.nimble` store with a DIFFERENT nimqml copy) on nim's parent-config
  walk; empirically the worktree's own resolution wins on both desktop
  (compile json) and iOS (bitcode source path). If the parent ever grows a
  conflicting seaqt pin, watch module-shadowing.
- Pin bumps (upstream `qt-6.4` force-push drops the compat shim; `qt-6.11`
  branch matches the actual kit) remain a SEPARATE decision per the grill —
  app-wide API churn, needs its own compile/QA pass and ideally an
  upstream tag.
- Android leg not exercised (one-platform spot-check per acceptance); the
  committed `.pc` trees cover `android_arm64_v8a` (spike Q4).
