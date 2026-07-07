---
id: 0013
title: nimble-native build/run OOTB — env-independent config, artifact hook, one store
date: 2026-07-07
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: done (2026-07-08)
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`
(extends the front door; groundwork for a future `nimble install Status`).

## Goal

`nimble run` (and `nimble build`) work out of the box in a fresh clone with
the documented kit env — same engine, same artifacts, same correctness as
`nim app status.nims`. nimble becomes a first-class facade over the build
engine; the `.nims` driver remains the fast daily path (nimble's ~1-min
dispatch tax is upstream ask #4).

Motivating failure (2026-07-07): `nimble run` today compiles the bin with
nimble's own paths into the default store — no native artifacts, no make
env for config.nims, second dependency graph in `~/.nimble`, and (in nested
worktrees) parent-checkout source leakage. It fails minutes deep instead of
working or failing fast.

## Decisions (grilled 2026-07-07, user-approved)

- **One store: nimble's default (`~/.nimble`).** The dedicated
  `~/.cache/status-desktop-nimbledeps` (`APP_NIMBLE_DIR`) is retired; make's
  setup/stamp flow adopts the default store. There is no per-project nimbleDir
  mechanism, so fighting the default means every nimble command needs
  developer-exported env — not OOTB. The default store satisfies the
  out-of-tree constraint (parent-config wall) the dedicated dir was built
  for. Store-wipe verification becomes per-package (or a temporary
  NIMBLE_DIR override for clean-room tests).
- Kit env (QMAKE, SDK/NDK, team) stays a documented prerequisite —
  fail-fast validation, never auto-provisioned (standing PRD decision).
- `bin = @["nim_status_client"]` stays in the manifest (required for
  nimble build/run and the future install layer).
- Nested-worktree parent-config leakage stays out of scope (normal clones
  are the OOTB target; the wall is documented).

## Phases

**A. Env-independent config.nims.** Every make-exported variable config.nims
reads (QT_LIBDIR, STATUSGO_LIBDIR, STATUSKEYCARD_QT_LIBDIR,
STATUSQ_INSTALL_PATH, NIMSDS dirs, …) becomes self-derived: repo layout +
nimble.paths/nimble.overlay parsing (both already exist in config.nims /
status.nims — share the logic) + `qmake -query` via staticExec for Qt paths
(QMAKE env or PATH probe, matching the driver's qmakeExe()). Make keeps
exporting; config.nims prefers env when present (identical values —
assert-compare during bring-up) and derives otherwise. After A, any bare
`nim c src/nim_status_client.nim` from the repo root gets correct flags.

**B. Artifact hook.** `before build` hook in nim_status_client.nimble
(declarative-safe) → new internal driver task (e.g.
`nim buildArtifacts status.nims`) that runs the existing engine for
everything EXCEPT the client compile: StatusQ cmake, statusgo/sds store
scratch, keycard FetchContent, rcc/resources/translations. Idempotent and
stamp-gated exactly like `app` (a no-op hook run must be seconds). Escape
hatch env switch to skip the hook (source-only workflows), mirroring
STATUS_GO_SKIP_GO_BUILD precedent — but hook-cancel fails installs (known
wall), so the switch must produce a successful no-op, not `return false`.

**C. Run leg (spike first).** Determine whether the bare
`bin/nim_status_client` launches correctly post-A (absolute rpaths baked;
QML/plugin/resource discovery). If yes: `nimble run` works directly. If
not: the hook (or an `after build` hook) assembles StatusDev.app and `bin`
becomes a thin launcher that opens the bundle — converging with the
`nimble install Status` launcher design. Record the spike either way.

**D. Store migration.** Makefiles: APP_NIMBLE_DIR → default store (drop the
--nimbleDir overrides; keep an env override for CI/clean-room). Migration
note for developers (old cache dir can be deleted). Verify the setup stamp,
overlay application, and derived nimble.paths copies all behave identically
against the default store. Guard: the default store may contain STALE
globally-installed packages (the confutils incident) — verify compiles use
ONLY nimble.paths/--path entries (--noNimblePath already set) so ambient
store content cannot leak.

## Acceptance criteria

- [x] Fresh clone + kit env, empty `~/.nimble`: `nimble run` → app builds
  (native artifacts included) and launches. `nimble build` → runnable build.
- [x] `nim app status.nims` / `make nim_status_client` produce byte-identical
  behavior against the same (default) store; no second dependency graph
  anywhere.
- [x] No-op `nimble build` re-run: hook overhead seconds-level past nimble's
  own dispatch tax (record both numbers).
- [x] Develop mode composes: `nim develop status.nims sds` + `nimble build`
  picks up vendor edits (overlay honored via nimble.paths + hook).
- [x] Missing kit env: `nimble build` fails fast (<5 s past dispatch) with
  the exact-variable message (hook runs the same validation as `app`).
- [x] config.nims env-vs-derived parity: with make env present, derived
  values match exported ones (bring-up assertion documented, then relaxed
  to prefer-env).
- [x] Stale-store immunity: a deliberately planted stale package in
  `~/.nimble/pkgs2` (not in nimble.paths) does not enter the compile.

## Blockers — grill before implementing

- Hook ↔ nimble compile contract: verify empirically what nimble's bin
  compile passes on its command line (paths, defines, --nimbleDir) in vNext
  run/build mode, and that config.nims' nimble.paths include + nimble's own
  --path flags coexist against ONE store without duplicate-path type
  identity issues. If they conflict, grill before suppressing either side.
- The C spike outcome (bare-exec vs launcher+bundle) — grill the result
  before building the launcher (it reshapes the future install layer).
- Any make target that embeds APP_NIMBLE_DIR semantics beyond setup (grep
  first; mobile Makefile included).

## Blocked by

Nothing (iteration-2 issues all closed). Holds the in-tree build lock.

## Verification record (2026-07-08)

Store: `~/.nimble` (default, post-phase-D). Host kit: `QMAKE=~/Qt/6.11.0/
macos/bin/qmake`. Nested-worktree caveat: `nimble build`/`run` inside THIS
dev tree additionally export QT_LIBDIR/STATUSGO_LIBDIR/STATUSKEYCARD_QT_
LIBDIR/STATUSKEYCARDGO_LIBDIR/STATUSQ_INSTALL_PATH — the ENCLOSING checkout's
old config.nims emits bare `-rpath` link args when they're absent (parent-
config wall, out of scope per Decisions; normal clones need none of it —
proven by the clean-room leg below).

1. **`nimble build` → runnable build** — rc=0 in 89 s warm (dispatch +
   hook + client compile+link); `before build` hook drove `nim
   buildArtifacts status.nims` → `make client-deps` (StatusQ, statusgo
   scratch + libsds, keycard, qrcodegen, DOtherSide, rcc, translations,
   qt-pkgconfig), `after build` hook applied the install_name fixups;
   binary at `bin/nim_status_client` (binDir). `nimble run` rebuilt and
   LAUNCHED the app (QML Onboarding up, killed clean).
2. **Byte-identical behavior make vs nimble against one store** — after two
   parity fixes this pass found (release-define ordering had silently
   stripped make's debug map: 133k vs 415k symbols; missing
   MACOSX_DEPLOYMENT_TARGET at link flipped ObjC section placement):
   `__text`/`__const`/`__cstring` section hashes IDENTICAL, `__data` equal,
   symbol SETS and addresses identical (nm md5 equal), load commands
   identical. Residual delta = 14,783 bytes: LC_UUID (16 B, the only
   pre-__LINKEDIT difference), 839 OSO stab mtimes (0 path diffs; stabs
   track nimcache .o mtimes — 0009/0012 documented), and the code signature
   over those pages. make-vs-make relink with unchanged .o files is fully
   byte-identical (0 differing bytes) — the residue is relink-time
   nondeterminism, not a flag asymmetry. One graph: compile json shows 21
   store entries, ALL from nimble.paths; zero old-store references.
3. **No-op `nimble build` re-run: hook overhead vs dispatch tax** — hook
   no-op (`nim buildArtifacts status.nims`) = **6.55 s** (make client-deps
   5.8 s + ~0.7 s driver eval; 0008/0010 baselines: no-op app 5.9–7 s).
   nimble dispatch tax ≈ **78 s** on this manifest (fail-fast run minus
   ~1.5 s hook = pure revalidation; documented upstream ask #4 class).
   Client compile+link re-runs unconditionally under nimble
   (needsRebuild=true for build/run) ≈ 35–45 s warm on top.
4. **Develop mode composes** — `nim develop status.nims sds` +
   `nimble build`: the hook's stamp re-ran setup + applyOverlay
   ("sds → vendor/nim-sds (2 path entries)"), probe string added to
   `vendor/nim-sds/library/libsds.nim` appeared in BOTH the in-place
   artifact and `.statusgo-build/.sds-build/build/libsds.dylib` (cmp-mirror
   engine); `nim undevelop status.nims sds` + `nimble build` returned to the
   pin (probe gone, nimble.paths back to 2 store sds entries).
5. **Missing kit env fails fast** — `env -i HOME=$HOME
   PATH=$HOME/.nimble/bin:/usr/bin:/bin nimble build` → rc=1 with the
   driver's exact message ("QMAKE is not set and no qmake is on PATH" +
   kit-hint block) ≈ 1–2 s past dispatch (total 79.9 s, dispatch ≈ 78 s;
   budget: <5 s past dispatch).
6. **config.nims env-vs-derived parity** — every phase-D/A build ran with
   `STATUS_BUILD_ENV_ASSERT=1` (hard-fails on env≠derived): full make chain
   incl. two forced client relinks, all green. Relaxed default = prefer-env
   (assert stays available).
7. **Stale-store immunity** — `~/.nimble/pkgs2` deliberately contains a
   whole divergent graph (libp2p-1.15.3, websock-0.3.0, lsquic-0.0.1 + more,
   installed by the phase-D bad solve and left in place) NOT in
   nimble.paths: the client compile json references 21 store entries, all
   ∈ nimble.paths, zero references to any planted entry
   (--noNimblePath + explicit paths only).

8. **Fresh clone + kit env + EMPTY store (clean-room)** — `git clone` of
   this branch into the scratch area, `NIMBLE_DIR=~/.nb0013` (fresh, empty;
   short path per the NAME_MAX wall; pkgcache shared per nimble's own
   env-NIMBLE_DIR semantics), env = kit only (`QMAKE`, macos kit), NO
   parent-leak exports (the clone is a normal, non-nested tree):
   `nimble build` → rc=0 in **9:54** — submodule bootstrap (make .DEFAULT),
   store solve+install (graph matches the verified one: libp2p-2.0.0,
   websock-0.4.0), every artifact, client at `bin/nim_status_client`.
   `nimble run` launched the app (QML up, killed clean). OOTB criterion
   met with zero repo-specific env.
   *One-time hiccup, self-healing, follow-up:* the SECOND nimble invocation
   in the clean room failed its link once — `prepareStatusgo` decided to
   refresh the scratch mid-run (`.statusgo-origin` drift left by the
   bootstrap pass) and make's already-cached stat of `$(STATUSGO)` skipped
   the status-go rebuild, so `-lstatus` vanished for that one build; the
   third invocation rebuilt status-go and the tree is stable/idempotent
   since (origin verified unchanged across subsequent builds). Default
   `nim app` flow unaffected. Noted for a bootstrap-ordering follow-up.
9. **Mobile regression leg** — `nim app status.nims --os:ios --cpu:arm64`
   (ios kit + team env) against the new default store: rc=0 in **139 s**,
   signed `Status.app`, `codesign --verify --deep --strict` OK.

Timing summary (record beside 0008's baselines): driver no-op 5.9–7 s;
hook no-op 6.55 s; nimble build warm total ≈ 89 s (≈78 s dispatch tax +
6.5 s hook + compile); clean-room full bootstrap 9:54; iOS leg 139 s;
make no-op unchanged.

## Implementation notes

### Pre-work empirics (2026-07-07, nimble 0.22.3 @42ef70c2 source + tiny-package experiments)

The hook ↔ bin-compile contract, verified before phase A (blocker 1 in this
issue) — scratch package with a `before build` hook, a file:// dep, a
config.nims path override, and a probe module present in both path sets:

- **Bin compile command** (vNext `build`/`run`):
  `<store nim> c --colors:X --noNimblePath -d:release [user flags]
  -d:NimblePkgVersion=<v> --path:<every solution pkg> [--hints:off]
  -o:<pkgdir>/[binDir/]<bin> <src>` — run with cwd = package dir, env =
  plain process inheritance. `-d:release` is UNCONDITIONAL for root builds
  (vnext.nim `buildPkg`); the nim used is the STORE-resolved nim
  (`pkgs2/nim-2.2.4-<checksum>/bin/nim` — on this machine byte-the-same
  install as the PATH nim).
- **config.nims `--path` beats nimble's command-line `--path`** for module
  resolution (probe resolved to the config-supplied dir). Consequence: the
  ADR-0004 overlay (applied to nimble.paths, included by config.nims) wins
  over nimble's own store paths — develop mode composes with `nimble build`
  with no extra machinery. No ambiguity error: first match wins silently.
- **CLI `-d:X=v` beats config `switch("define", "X=v")`** (nim processes the
  command line before AND after configs; defines re-apply). So config-derived
  defines are pure fallbacks — prefer-invoker semantics for free.
- **`putEnv` in config.nims propagates to compile-time `gorge`** in modules
  of the same compile — seaqt's `gorge("pkg-config Qt6...")` can be fed the
  wrapper env without make.
- **Hooks**: `before build` fires for BOTH `nimble build` and `nimble run`
  (run builds the root through the same vnext buildFromDir), cwd = package
  dir, full env inheritance; the hook nimscript is evaluated via a temp shim
  under the system tmp, so the repo's config.nims does NOT run for the hook
  itself. A hook whose `exec` fails does NOT stop the action (execHook
  swallows script failures — `res.success=false` → continue), so the hook
  catches the failure and `return false`s explicitly (that IS the legitimate
  use of hook-cancel; the skip switch is the successful-no-op arm).
- **`binDir = "bin"`** in the manifest lands nimble's binary exactly at
  `bin/nim_status_client` (make's location).
- **No-op `nimble build` re-runs the client compile** (needsRebuild returns
  true for actionBuild/actionRun; only install-type actions honor
  `--noRebuild`) — nim's own caching applies, but the nim front-end + link
  always run. The seconds-level no-op criterion applies to the HOOK (past
  dispatch); the compile re-run is nimble's own behavior, recorded as such.
- `-d:lto` has zero consumers repo-wide (vestigial next to `-d:release`) —
  the client compile drops it; make's NIM_PARAMS keeps it for the nim tests
  only.
- The 66 stray `githubcom_*` dirs at the repo root (motivating-failure
  session, 2026-07-07 19:30–19:31) are pkgcache-shaped clones written by a
  nimble invocation whose `pkgCachePath` was empty (`"" / <name>` = cwd);
  our target flows write to `<nimbleDir>/pkgcache` — watch for recurrence.

### Phase D migration incident (2026-07-07): the default store's pkgcache
### solved a DIFFERENT graph — carried the known-good table over

First `nimble setup` against the default store resolved **libp2p 1.15.3 /
websock 0.3.0 / lsquic 0.0.1(special)** — dropping boringssl, npeg and
protobuf_serialization, and flipping jwt/snappy/bearssl_pkey_decoder to
other revisions — instead of the documented-correct **libp2p 2.0.0 /
websock 0.4.0 / lsquic 0.5.4** graph. Cause: the version-table wall
(status-go AGENTS.md, "version tables are nondeterministic across days") —
`~/.nimble/pkgcache` held listing clones from the 2026-07-07 failed-`nimble
run` session (libp2p 2.1.x listings, a websock 0.3.0 key, an lsquic-0.0.1
special clone) whose candidate tables steer the pre-binding walls
differently than the retired store's pkgcache, and the lock never
constrains solves (wall #6). Fix: `mv ~/.nimble/pkgcache
~/.nimble/pkgcache.bak-0013` + copy the retired store's pkgcache in, re-run
`make nimble-deps`, assert the entry set matches the pre-migration
resolution exactly (modulo store root; the isaac root-vs-/src warm-setup
wobble is expected).

Standing risk (pre-existing, NOT introduced by the store move): any truly
fresh machine can land on a different graph than the one this repo was
verified against, because URL#hash roots force full re-solves and the lock
gates nothing (upstream asks #4/#6/#8). The divergent store entries the bad
solve installed stay in `~/.nimble/pkgs2` as inert content-addressed junk —
they double as a natural stale-store-immunity probe (criterion 7: not in
nimble.paths ⇒ must never enter a compile).

### Phase C spike record (2026-07-07): bare exec WORKS — no launcher needed

Post-A binary (`bin/nim_status_client`, built by make with the parity assert
on), executed BARE from the repo root — no `DYLD_LIBRARY_PATH`, no bundle:

- All four `@rpath` dylib references resolve from the six baked absolute
  rpaths (`lsof`: libstatus, libsds, libStatusQ from their build dirs;
  status-keycard-qt confirmed by its PC/SC init logs). 39 Qt frameworks
  loaded from the kit's lib dir rpath.
- `resources.rcc` found via `applicationDirPath/../resources.rcc` (absolute,
  cwd-independent); QML engine rendered the Onboarding UI (same dev-noise
  warnings as `make run` smokes); keycard detection thread up; clean SIGTERM.

Outcome per the issue's decision fork: `nimble run` executes the binary
directly (`binDir = "bin"` → `bin/nim_status_client`) — the launcher/bundle
alternative is NOT built, so there is nothing reshaping the future install
layer (the grill gate applied only to building the launcher). The
StatusDev.app bundle remains `make run` / `nim run status.nims` polish
(dock icon/name); the two rpaths added in phase A (libsds, StatusQ cmake
libdir) are what closed the gap to DYLD-free execution.
