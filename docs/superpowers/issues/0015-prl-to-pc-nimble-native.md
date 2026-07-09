---
id: 0015
title: prl-to-pc nimble-native — executed nimscript interface, v0.3.0 pin, env cache
date: 2026-07-09
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: in progress (2026-07-09; everything authored, built and verified —
  the last two criteria are gated on the human pushing prl-to-pc `main` +
  the annotated tag `v0.3.0`, see PUSH HANDOFF)
---

## Parent

PRD: `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md`

## What to build

prl-to-pc's consumer interface today is a **makefile**. A make-free dev flow
cannot consume it, and the app has grown a second, silently-divergent copy of
prl-to-pc's kit-derivation logic (which lacks the System/Generated probe that
now lives upstream).

Give prl-to-pc a **nimscript consumer interface** and make the app consume it
as the single source of truth.

Upstream (prl-to-pc, released as **v0.3.0** cut from `main`) gains
`qt_pkgconfig.nims`, invoked as `nim e <package root>/qt_pkgconfig.nims <cmd>`:

- **`env`** — prints `KEY=VAL` lines describing the pkg-config environment for
  the current Qt kit, or nothing when the kit's own pkg-config data is usable
  (System mode). Owns kit derivation *and* the System/Generated probe.
- **`tools <buildDir> <consumerPaths>`** — builds the pkg-config wrapper and
  the `.pc` generator from package sources, resolving `regex`/`unicodedb`
  through the **consumer's** `nimble.paths`.
- **`generate`** — regenerates a kit's `.pc` tree; refuses when the package
  root is a store copy.

`qt-pkgconfig.mk` is **retained unchanged** in v0.3.0: the interim mobile make
legs and any external make consumer keep working (dual interface; removing the
makefile is a later major-version decision).

The app consumes it through the driver: `buildArtifacts` calls `tools`, then
calls `env` once and **caches** the result to a repo-local, gitignored
artifact keyed on (qmake path, resolved package root, kit). `config.nims`
reads that cache and sets the environment — no subprocess per Nim invocation.
`config.nims` stops deriving the `.pc` tree path and stops asserting that a
wrapper exists (in System mode there is none). `generate` becomes an explicit
driver task, never a build step. The app's `make qt-pkgconfig*` targets are
deleted; the Makefile's own inclusion of `qt-pkgconfig.mk` survives only for
the interim mobile legs.

**The interface must be executed, not included.** The store path is dynamic
(`prl_to_pc-0.2.0-<checksum>`), and `include`/`import` resolve at *parse* time
while `nimble.paths`'s `--path` switches only take effect at script *runtime* —
so no config or driver script can `include` a file from the store. This
constraint is the whole reason for the `nim e` shape.

**Authoring order (this is also the acceptance path):** author in develop mode
(`nim develop status.nims prl-to-pc`, checkout from `main`, not the `v0.2.0`
tag) against the live app build; only once the desktop and iOS legs pass, push
to prl-to-pc `main`, cut the annotated tag `v0.3.0`, `undevelop`, bump the app
pin to `#v0.3.0`, and re-verify from the store.

**PUSH GATE:** the app's pin bump cannot land before v0.3.0 is pushed. Known up
front (unlike 0014, where it was discovered at the end).

## Acceptance criteria

- [x] `nim e <root>/qt_pkgconfig.nims env` prints a correct environment on a
      Generated-mode kit and an empty/no-op environment on a System-mode kit;
      both are covered by prl-to-pc's own `nimble test` harness.
      **Amended (evidence, leg 1):** "empty" is wrong and would be a bug. On a
      System-mode kit `env` still prints `PKG_CONFIG_PATH=<the kit's own
      pkgconfig dir>` — without it `pkg-config` answers from its built-in
      search path (here: brew's Qt at `/opt/homebrew/lib`), i.e. the *wrong Qt*.
      What is empty in System mode is the *generated machinery*: no wrapper, no
      `PATH` prepend, no `PKG_CONFIG_PREFIX_OVERRIDE`, no `PKG_CONFIG_ARCH`,
      nothing built. This is exactly what `qt-pkgconfig.mk` has always exported,
      and the dual interface must not diverge from it.
- [x] `generate` refuses to run against a store copy, with an actionable
      message; it succeeds from a develop checkout. (Legs 2, 6.)
- [x] The app builds and launches on a **Generated-mode kit** (Qt 6.11.0).
      (Legs 4, 6.)
- [x] The app builds on a **System-mode kit** (Qt 6.11.1 or 6.12) — proving
      `config.nims` no longer requires a wrapper to exist. (Leg 5, incl. the
      counter-proof that the OLD `config.nims` fails there.)
- [x] `config.nims` contains no kit derivation (`.pc` path, kit, version) and
      no wrapper assertion; the environment comes from the cached `env` output.
      (Leg 3.)
- [x] The prl-to-pc store entry is **byte-identical** before and after a full
      build (tools land in the repo-local build dir, never in the store).
      (Leg 6: 1161 files, per-file md5.)
- [x] The env cache is regenerated when its key changes (qmake path, package
      root, kit) and dropped on develop-mode flips. (Legs 5, 7.)
- [x] `make qt-pkgconfig`, `qt-pkgconfig-tools` and `qt-pkgconfig-generate` no
      longer exist; the desktop build never invokes them.
      **Scoped (leg 8):** the *app's own* definitions are gone (the stub
      targets); the desktop build has no `qt-pkgconfig` prerequisite anywhere.
      The mk's own targets necessarily survive, because the root Makefile still
      `include`s `qt-pkgconfig.mk` for the two make legs this iteration
      deliberately leaves alone (mobile, `nim-test-run/%`) — which the issue's
      own "the Makefile's inclusion survives" sentence requires. They disappear
      with those legs, not here.
- [ ] prl-to-pc `v0.3.0` is pushed and tagged; the app pin is `#v0.3.0`; a
      wiped store entry re-solves it from the remote.
      **BLOCKED on the human push — see PUSH HANDOFF.** Everything except the
      literal tag is proven: the pin is the exact commit the tag must point at,
      and a wiped store entry re-solves it (leg 6) through the seeded pkgcache
      clone (0014's interim mechanism), producing a store copy whose
      `nimblemeta.json` records the real GitHub URL.
- [x] Develop round-trip: `develop prl-to-pc` → an upstream edit is observed in
      the app build → `undevelop` → build returns to the pinned store entry.
      (Leg 7.)
- [x] `nim app status.nims` and `nimble build` are both green. (Legs 4-6, 9.)

## Blocked by

The human's push of prl-to-pc `main` + the annotated tag `v0.3.0` — for the
final pin bump only. All authoring and verification are done.

## PUSH HANDOFF (the only thing left)

prl-to-pc commit **`4a31fc06e8c8e38fca6a9396d7cedffacecda010`** ("feat:
qt_pkgconfig.nims — an executed consumer interface (v0.3.0)") sits on branch
`main` of `vendor/prl-to-pc` (gitignored) and is mirrored, as a safety net, on
`backup/nimble-0015-v0.3.0` in `.phase2-vendor-backup/prl-to-pc`. It is 1
commit ahead of `origin/main` (`359064f`). From the checkout:

```sh
cd vendor/prl-to-pc
git push origin main
git tag -a v0.3.0 -m "v0.3.0 — qt_pkgconfig.nims, the executed consumer interface"
git push origin v0.3.0
```

**Push the commit as-is.** Amending or rebasing it changes the SHA the app's
interim pin names, and the seeded pkgcache clone
(`~/.nimble/pkgcache/githubcom_statusimprltopcgit_4a31fc06…`) would then be the
only place it exists. Do not delete that pkgcache dir before the push.

Afterwards (agent run 2): bump the pin in `nim_status_client.nimble` from
`#4a31fc06…` to `#v0.3.0`, wipe
`~/.nimble/pkgcache/githubcom_statusimprltopcgit_*` and
`~/.nimble/pkgs2/prl_to_pc-*` plus `nimble.paths`, then `make nimble-deps` to
prove the tag re-solves from the remote, and re-run legs 4/6/7.

## What was built (2026-07-09)

- **prl-to-pc `4a31fc0`** (branch `main`, unpushed):
  - `qt_pkgconfig.nims` — the executed consumer interface. `env [<buildDir>]`
    prints `KEY=VAL` lines (`QT_PC_MODE`, `QT_PC_REASON`, `QT_PC_PREFIX`,
    `PKG_CONFIG_PATH`, and in Generated mode `PKG_CONFIG_PREFIX_OVERRIDE`,
    `PKG_CONFIG_ARCH`, `QT_PC_PATH_PREPEND`); `tools <buildDir>
    <consumerPaths>` builds the wrapper + generator into the CONSUMER's dir;
    `generate [<buildDir> [<consumerPaths>]]` regenerates a kit's committed
    tree and refuses on a store copy. Owns kit derivation and the
    System/Generated probe — one body of knowledge, two front doors.
  - `tests/test_qt_pkgconfig_nims.nim`, wired into `nimble test`: 10 tests over
    the same three fixture kits the mk suite uses.
  - `prl_to_pc.nimble`: version `0.3.0`; the test wiring. Still declares
    neither `bin` nor `srcDir` (0014's walls).
  - README: the new interface documented alongside the mk.
  - `qt-pkgconfig.mk` **untouched** — this is an interface addition.
- **App**: `status.nims` gains `prepareQtPkgconfig()` (called by `app`, `run`,
  `buildArtifacts` on host targets) and the `qtPkgconfigGenerate` task;
  `status_env.nims` gains `qtPkgConfigKey`/`qtPkgConfigEnv` (the cache reader);
  `config.nims` loses ~32 lines of kit derivation and gains a 14-line replay of
  the cache; the Makefile loses the desktop's `qt-pkgconfig` prerequisites, the
  `update:` call and the app-owned stub targets.

### Design notes worth keeping

- The **staleness gate for the tools is content-keyed, not mtime-keyed**:
  nimscript has no mtime API (`os.getLastModificationTime` is an `{.error.}`
  there). `<buildDir>/.<tool>.key` holds `hash(source) + NimVersion + flags`.
  This is strictly better than the mk's mtime rule across a develop/undevelop
  flip: identical sources legitimately reuse the binary, different ones rebuild.
- The driver **validates `env`'s output shape** before caching it, because
  `gorgeEx` merges the child's stderr into the captured stdout — a stray hint
  would otherwise become a cache entry. Verified (leg 7A).
- `prepareQtPkgconfig` needs the resolution before make runs, but a full
  `make nimble-deps` costs a ~2.3 s Makefile parse. It is gated on an mtime
  scan (`test -nt`, ~20 ms) against the same key make's setup stamp uses.
- The driver passes its own compiler (`getCurrentCompilerExe()`) to prl-to-pc
  as `QT_PC_NIM` and uses it to run `nim e`, so the tools are never built by a
  stray `PATH` nim. `NimVersion` is in the tool key, so a compiler flip
  rebuilds them.

## Verification record (2026-07-09, macOS arm64 host; nim 2.2.4 + nimble 0.22.3; store = ~/.nimble)

Env: `PATH=$PWD/vendor/nimbus-build-system/vendor/Nim/bin:$PATH`,
`USE_SYSTEM_NIM=1`, `QMAKE` per leg. Kits, probed (leg 1): **6.11.0 =
Generated** (its `Qt6Core.pc` carries the build-farm libdir
`/Users/qt/work/install/lib`), **6.11.1 and 6.12.0 = System**, **6.11.0/ios and
6.11.0/android_arm64_v8a = Generated** (no `Qt6Core.pc` at all).

1. **The interface, against all five real kits.** `nim e --skipParentCfg:on
   <root>/qt_pkgconfig.nims env <buildDir>` printed, exit 0: 6.11.0 → generated
   + committed tree + `Qt*=<prefix>` + wrapper dir; 6.11.1 and 6.12.0 → system +
   the kit's own pkgconfig dir and nothing else; ios → generated, reason "kit
   ships no Qt6Core.pc"; android_arm64_v8a → the same plus
   `PKG_CONFIG_ARCH=arm64-v8a`. Every value matches what `qt-pkgconfig.mk`
   exports for the same kit. The System-mode env is NOT empty, and must not be:
   `PKG_CONFIG_PATH= pkg-config --variable=libdir Qt6Core` → `/opt/homebrew/lib`
   on this machine.
2. **Subcommand behaviour.** `tools` on 6.11.0 built `pkg-config` + `prl_to_pc`
   into the given dir (2.05 s cold, **0.33 s** warm no-op); on 6.11.1 it printed
   "no tools to build" and did not even create the dir. `generate` on a copy
   carrying `nimblemeta.json` refused (exit 1) naming `nim develop status.nims
   prl-to-pc`; on a checkout copy it regenerated `6.11.0/macos` and the result
   was **byte-identical to the committed tree** (`diff -r`); on 6.11.1 it
   printed "this kit needs no generated .pc tree" and wrote nothing.
3. **prl-to-pc's own suite.** `nimble test` in the checkout: all four suites
   green, including the 10 new `qt_pkgconfig.nims` tests (both probe modes, the
   missing-tree failure, tools-writes-only-into-buildDir, the store refusal in
   both modes, dispatch/usage).
4. **Generated-mode kit, full build** (`QMAKE=~/Qt/6.11.0/macos/bin/qmake`),
   develop mode, `bin/nim_status_client` removed first: `nim app status.nims` =
   **97.9 s**, rc 0. Launch smoke: bare `./bin/nim_status_client` alive after
   12 s, `libstatus.dylib` + `libsds.dylib` + `libStatusQ.dylib` +
   `QtQuick.framework` loaded, `QtCore` resolved from
   `~/Qt/6.11.0/macos/lib/…`, clean SIGTERM.
5. **System-mode kit** (`QMAKE=~/Qt/6.11.1/macos/bin/qmake`), `.pcwrap` deleted
   first: `nim app status.nims` = **123.9 s**, rc 0; **no `.pcwrap` directory
   was created at all**; the env cache re-keyed itself to the new kit and holds
   only `QT_PC_MODE=system` + `PKG_CONFIG_PATH=<kit pcdir>`; the binary links
   `QtCore … current version 6.11.1`. `nimble build` on the same kit = 148.2 s,
   rc 0. **Counter-proof:** `git show HEAD:config.nims` swapped back in place
   and `nimble build` re-run → exit 1, *"status build ERROR: the Qt pkg-config
   wrapper is missing (…/.prl-to-pc-build/.pcwrap/pkg-config)"*. The old
   assertion really was a live bug on a System-mode kit.
6. **Default mode against a real read-only store copy.** Store entries +
   `nimble.paths` + `.prl-to-pc-build` wiped; `make nimble-deps` re-solved in
   **1:07** through the seeded pkgcache clone, materialising
   `prl_to_pc-0.3.0-efc5e3d18f1e6e11e2f3a6b6ed034e84d634771b` (nimblemeta:
   url `https://github.com/status-im/prl-to-pc.git`, vcsRevision `4a31fc06…`,
   `specialVersions ['0.3.0', '#4a31fc06…']`) — and it *carries*
   `qt_pkgconfig.nims`. Full `nim app status.nims` = **65.5 s** rc 0; the tools
   landed in `.prl-to-pc-build/.pcwrap`; the env cache key names the store root.
   **Store byte-identity: per-file md5 of all 1161 files identical before and
   after** (and still identical after the iOS leg + `nimble build` + three
   no-ops). `nim qtPkgconfigGenerate status.nims` against the store copy →
   exit 1 with the develop-and-commit-upstream message. Steady-state no-op
   `nim app`, five runs: **6.78 / 6.80 / 6.80 / 6.92 / 7.25 s** (0014 baseline
   6.95–7.33 s: the driver's 0.33 s `nim e tools` replaced a 2.2 s
   `make qt-pkgconfig` no-op; the first run after any commit costs ~1.5 s more,
   for `git describe`). `nimble build` = 132.1 s, rc 0.
7. **Develop round-trip + cache invalidation.**
   (A) A stray non-`KEY=VAL` line added to the checkout's `cmdEnv` → `nim app`
   exit 1, *"prl-to-pc's `env` printed a line that is not KEY=VAL"*, and the
   cache file was **not** written. Guard works.
   (B) `develop prl-to-pc` → a marker `echo` added to the checkout's `cmdTools`
   → next `nim app` (8.4 s) printed `qt-pkgconfig: DEVELOP-MODE MARKER` and the
   cache key's package-root field became `…/vendor/prl-to-pc`. Edit reverted,
   `undevelop --force` → next `nim app` (76.1 s, incl. the re-solve) no longer
   printed the marker and the cache key's root field was back to the store
   entry. `undevelop` *without* `--force` correctly REFUSED first, listing the
   unpushed `4a31fc0` — the same guard that protects the push handoff.
8. **make surface.** `make -pn nim_status_client`: neither `bin/nim_status_client`
   nor `client-deps` lists `qt-pkgconfig` among its prerequisites; the only
   remaining prerequisites are `mobile-run`, `mobile-profile`, `mobile-build`
   and `nim-test-run/%`. The app's stub targets are gone (`grep -c
   '^qt-pkgconfig qt-pkgconfig-tools qt-pkgconfig-generate:' Makefile` → 0) and
   `update:` no longer shells into `make qt-pkgconfig`. The sole `qt-pkgconfig`
   string in a desktop dry-run is the mk's parse-time `$(info …)` mode report.
9. **Interim mobile leg unaffected** (it still consumes the mk): `nim app
   status.nims --os:ios --cpu:arm64` = **147.1 s** rc 0, mk reported "generated
   mode: kit ships no Qt6Core.pc", `mobile/bin/ios/qt6/Status.app` signed,
   `codesign --verify --deep --strict` OK. Desktop flip-back = 65.6 s.

Timing summary (vs 0014): driver no-op **6.78–7.25 s** (0014: 6.95–7.33);
full default rebuild after a store wipe 65.5 s + 1:07 re-solve (0014: 1:09.95
combined); `nimble build` 132.1 s (0014: 1:37); iOS leg 147.1 s (0014: 149.6);
desktop flip-back 65.6 s (0014: 54.5).

### Not verified / residuals

- **Windows.** `qt_pkgconfig.nims` carries the `.exe` suffix, the `;` path
  separator and `2>nul`, mirroring the mk — none of it is exercised here.
  `nimblePathsStale()` returns `false` on Windows (its `test -nt` probe is
  POSIX-only), so the driver relies on make's stamp there, as it did before.
- **Qt 6.12.0** was probed (leg 1) but not built; 6.11.1 is the System-mode
  build of record.
- Pre-existing noise, unchanged by this issue: the `install_name_tool
  -delete_rpath … no LC_RPATH` lines from StatusQ's cmake_install, and nimble's
  "Multiple dependencies require different special versions" warnings.
- The `nim qtPkgconfigGenerate` refusal prints a nimscript stack trace after
  the (correct, actionable) error, because the driver's `exec` re-raises. Ugly,
  not wrong; a follow-up could capture and re-emit instead.
- **Follow-up recorded, not implemented:** `tools` builds the generator eagerly,
  which the mk's `qt-pkgconfig` aggregate did not. It costs ~1.8 s once and
  makes `regex` a hard requirement of every consumer's first build. If that
  ever bites, split a `wrapper` subcommand out of `tools`.
