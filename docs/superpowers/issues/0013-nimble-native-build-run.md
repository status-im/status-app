---
id: 0013
title: nimble-native build/run OOTB — env-independent config, artifact hook, one store
date: 2026-07-07
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
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

- [ ] Fresh clone + kit env, empty `~/.nimble`: `nimble run` → app builds
  (native artifacts included) and launches. `nimble build` → runnable build.
- [ ] `nim app status.nims` / `make nim_status_client` produce byte-identical
  behavior against the same (default) store; no second dependency graph
  anywhere.
- [ ] No-op `nimble build` re-run: hook overhead seconds-level past nimble's
  own dispatch tax (record both numbers).
- [ ] Develop mode composes: `nim develop status.nims sds` + `nimble build`
  picks up vendor edits (overlay honored via nimble.paths + hook).
- [ ] Missing kit env: `nimble build` fails fast (<5 s past dispatch) with
  the exact-variable message (hook runs the same validation as `app`).
- [ ] config.nims env-vs-derived parity: with make env present, derived
  values match exported ones (bring-up assertion documented, then relaxed
  to prefer-env).
- [ ] Stale-store immunity: a deliberately planted stale package in
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
