---
id: 0016
title: buildArtifacts goes native — cmake proc, qrcodegen {.compile.}, rcc, bootstrap, stale()
date: 2026-07-09
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: done
---

## Parent

PRD: `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md`

## What to build

`buildArtifacts` — already the `nimble build` prebuild hook — currently
delegates to make's `client-deps`, which fans out to every non-Nim artifact
the client links against. Make it do the work itself, so the dev flow has no
make in its process tree.

A new nimscript include (sibling of the shared env include) holds one
procedure per artifact; `buildArtifacts` becomes an ordered call list. The
hook contract with nimble does not change.

What moves:

- **cmake artifacts** — StatusQ, DOtherSide, the status-keycard-qt wrapper and
  the translations project all go through **one generic configure/build
  procedure**. The **build** step is invoked unconditionally: cmake's own
  incrementality is the no-op path (this is already how these behave under
  make). The 0011 `FETCHCONTENT_SOURCE_DIR_<NAME>` redirect-pair contract is
  preserved verbatim — always pass the pair, empty value means pinned.

  **Amended 2026-07-10 (user-adjudicated).** The original wording said the
  whole procedure was "invoked unconditionally". Measured, the three
  *configures* cost 5.26 s (StatusQ) + 0.57 s (DOtherSide) + 1.13 s (keycard),
  putting the no-op at **14–17 s** against this issue's own ~7 s criterion. So
  the **configure** step is gated by the key-file pattern on its argument list.
  This is not a loss of correctness, it is a gain:
  - `cmake --build` re-runs the configure *itself* when a `CMakeLists.txt`
    changes — every generator emits a check-build-system rule. That is cmake's
    incrementality, and it still owns the no-op path.
  - The only input cmake cannot see is a change in its own configure
    ARGUMENTS: a develop `FETCHCONTENT_SOURCE_DIR_*` flip, a build-type flip,
    another Qt kit. Keying exactly that makes the redirect flip safe *by
    construction*, where the make rule it replaces relied on the artifact
    happening to have been deleted first.
- **DOtherSide gets no investment**: it is dead on `origin/master` (`chore:
  Drop DOtherSide`) and simply rides the generic procedure until this branch
  merges master.
- **QR-Code-generator** is Nim-only — no StatusQ consumer. Its C source is
  compiled into the client by the Nim wrapper that already binds it, via
  `{.compile.}`. Delete the static-library target, its link flag, and its
  entanglement with the platform-sentinel cleanup. Cross-arch flags come free
  from the client compile.
- **Translations** are cmake-driven (Qt LinguistTools) and are *not* part of
  the client's artifact set: `compile-translations` becomes a driver **task**,
  not a build step. The lokalise fixup script stays inside the update task.
- **Brew bottles** (macOS) and **submodule initialisation** move into the
  driver's bootstrap. Submodule init is targeted, not blanket-recursive.
- **The setup stamp** is relocated, not preserved: the driver gates `nimble
  setup` on `nimble.paths` being stale with respect to the lock, the manifests
  and the develop overlay.

Exactly **two gating patterns** may exist afterwards, both documented in the
driver header:

1. `stale(outputs, inputs)` — an mtime scan with make's semantics. This is the
   prefactor that 0017's client compile will reuse; land it first.
2. The existing **key-file** pattern for keyed invalidation (store path, target
   triple, flags), as established by the status-go scratch engine.

`client-deps` is deleted. The mobile Makefile keeps its own path this
iteration and is untouched here.

**Scope note, 2026-07-10 (user-adjudicated).** Criterion 1 ("no `make` in the
tree") cannot be met while `nim app status.nims` still shells to
`make nim_status_client`, so the **client compile** (`buildClient()`) and the
**launch** (`launchHostApp()`) were pulled forward from issue 0017 into this
slice, together with the `REBUILD_NIM` → `applyDevelopModeArms()` replacement.
0017's remaining scope shrinks accordingly, to: the Nim test suite, the Windows
launcher, deleting the `run-*` and `nim_status_client` make targets (plus
`.qmake_previous`), pointing packaging at the driver-built binary, the explicit
force flag on `app`, the Windows flag branches, and a portable (content-key)
`stale()`.

## Acceptance criteria

- [x] `nim app status.nims` builds a runnable app with **no `make` process in
      the tree** (verifiable by removing make from `PATH` for the run).
      *Adjudicated met per its own method; two residual `make` sources are
      accepted — see criterion 1 in the verification record.*
- [x] No-op rebuild stays within the established envelope (~7 s desktop).
- [x] Full build from a wiped store succeeds.
- [x] The client links a QR code generator compiled via `{.compile.}`; the
      static library, its link flag and its platform-cleanup entry are gone.
- [x] `rcc` output is regenerated when its inputs change and skipped otherwise.
- [x] A fresh clone with uninitialised submodules bootstraps and builds.
- [x] `nimble setup` is not re-run when the lock, manifests and overlay are
      unchanged.
- [x] `compile-translations` is reachable as a driver task and is not run
      during a normal build.
- [x] Develop-mode round trip still works for a cmake Vendor
      (status-keycard-qt) and a nimble-graph Vendor.
- [x] Platform sentinel flip (desktop → iOS → desktop) still cleans shared
      artifacts correctly.
- [x] Only `stale()` and the key-file pattern are used for gating; both are
      documented.
- [x] `client-deps` no longer exists.
- [x] `nim app status.nims` and `nimble build` are both green.

## Blocked by

- 0015 (soft): 0015 reworks the `config.nims` environment block that this slice
  builds around. Running them in parallel means a merge conflict there.

---

## Verification record — 2026-07-10

Machine: macOS arm64 (M-series), Qt 6.11.0 macOS kit (Generated pkg-config
mode), Qt 6.11.0 iOS kit. `~/.nimble/bin/nim` = **2.2.4** (the manifest pin;
the NBS 2.2.10 was NOT put on PATH — see SHARED-i3). Store = default
`~/.nimble` unless stated.

    export QMAKE=~/Qt/6.11.0/macos/bin/qmake USE_SYSTEM_NIM=1

Commits: `f19b0479d3` (engine + driver rewire), `a7017dbfd5` (qrcodegen
`{.compile.}`, `client-deps` and the static-lib target deleted), `0f913789c9`
(gating audit fixes).

### 1. `nim app status.nims` builds a runnable app with no `make` process in the tree

**Met.** *Adjudicated 2026-07-10: accepted as met per its own stated
verification method. The two residual `make` sources below (cmake's generator,
cold-libstatus) are accepted residuals; the Ninja switch and a status-go
shared-library nimscript task stay as recorded follow-ups.*

*The criterion's own verification method passes.* With `make` stripped from
`PATH` (`/usr/bin` removed, every other needed `/usr/bin` tool re-exposed
through a shim dir):

    make on PATH? -> NO
    cmake? /opt/homebrew/bin/cmake; go? .../go; git? /tmp/nomake-bin/git
    nim app status.nims  →  rc=0, 12.5 s

*But `make` processes still appear.* Sampling `ps -Ao pid,ppid,comm` every
150 ms for the duration of a `nim app status.nims` that had real work to do
(`touch ui/StatusQ/src/StatusQ/Components/StatusBadge.qml`):

    nim app rc=0
    === processes whose comm is exactly make/gmake ===
      31 /Applications/Xcode.app/Contents/Developer/usr/bin/make
    === any invoking THIS repo's Makefile? ===
      none

They are spawned by **cmake's `Unix Makefiles` generator**, which is cmake's
default on macOS/Linux and was equally in play when the root Makefile drove
the same `cmake --build`:

    $ grep CMAKE_MAKE_PROGRAM ui/StatusQ/build/Qt6.11.0/CMakeCache.txt
    CMAKE_MAKE_PROGRAM:FILEPATH=/usr/bin/make
    $ grep '^CMAKE_GENERATOR:' ui/StatusQ/build/Qt6.11.0/CMakeCache.txt
    CMAKE_GENERATOR:INTERNAL=Unix Makefiles

Removing `make` from `PATH` does **not** prove its absence: cmake locates
`/usr/bin/make` outside `PATH` at configure time (verified on a throwaway
project — `cmake -S . -B b` with `make` off `PATH` → `configure rc=0`).

The second (and last) source is **status-go's own vendored Makefile** on a
cold `libstatus`: `statusgo-shared-library` exists only there, not as a
nimscript task (`statusgo.nims` exposes `libstatus` = the *static* flavor,
plus the `libsds*` tasks). The driver treats status-go exactly like a cmake
vendor — it decides *when*, status-go decides *how*.

What **is** guaranteed and verified: **no target of this repository's Makefile
is invoked by the host dev flow.** `client-deps` is gone (criterion 12), there
is no `make -C <repo>` anywhere under `nim app` / `nimble build`, and both are
green with `make` off `PATH`. Both residual sources are recorded in the walls
doc and as follow-ups below.

### 2. No-op rebuild within the established envelope (~7 s)

Five consecutive `nim app status.nims` no-ops after the 2026-07-10 review
fixes (which added six env vars to the client key and rewrote the rcc prune):

    real 4.37 / 4.57 / 4.45 / 4.61 / 4.71

and, before them, `5.48 / 5.17 / 4.91 / 4.92 / 4.78` and `5.27 / 4.98 / 4.61 /
4.96 / 4.98`. **4.37–5.57 s** across fifteen runs — inside the 6.78–7.25 s
envelope, and faster than the pre-change `make`-delegating baseline measured on
this machine the same session (`8.10 / 8.06 / 8.25 s`).

Two things bought it, and both are load-bearing:

- **the cmake configure is key-file gated** (the spec's "invoked
  unconditionally" wording was amended for this; user-adjudicated 2026-07-10).
  Measured per phase:
  `statusq configure 5.26 s` / `statusq build 2.56 s` / `install 0.23 s`,
  `dos configure 0.57 s` / `build 0.42 s`, `keycard configure 1.13 s` /
  `build 0.61 s`. Running all three configures unconditionally put the no-op at
  **14.1–17.7 s**. `cmake --build` re-runs the configure itself when a
  CMakeLists changes (`touch ui/StatusQ/CMakeLists.txt` → `nim app` printed
  cmake's own `-- Configuring done (4.8s)` with no driver "Configuring:" line),
  so the only input cmake cannot see is its own argument list — which is what
  the key file holds.
- **the rcc input scan prunes what `ui/generate-rcc.go` prunes.** make's
  `UI_SOURCES` glob covers `ui/StatusQ/**`, and StatusQ's *configure* rewrites
  `ui/StatusQ/build/Qt6.11.0/TestConfig.generated.qrc` every run → `resources.rcc`
  was permanently stale (observed: rebuilt on every no-op).

### 3. Full build from a wiped store

Empty store via `NIMBLE_DIR=~/.nb0016` (`pkgs2` entries: 0), plus every
artifact dropped — `bin/*`, `resources.rcc`, `ui/resources.qrc`,
`.statusgo-build`, `build/status-keycard-qt`, `ui/StatusQ/build`,
`vendor/DOtherSide/build`, `.prl-to-pc-build`, `nimble.paths`,
`.status-client.key`, `.platform-target`. (`bottles/` kept: fetching it needs a
GitHub token. Submodule bootstrap is exercised separately in criterion 6.)

    nim app status.nims  →  583.60s user 169.32s system 138% cpu  9:04.14 total

Phases, in order, from the log:

    Resolving: nimble graph (lock/manifests/overlay changed)
    Building: libsds
    Building: status-go
    Configuring: StatusQ      Building: StatusQ
    Configuring: DOtherSide   Building: DOtherSide
    Configuring: status-keycard-qt   Building: status-keycard-qt
    Building: resources.rcc
    Building: nim_status_client

    46 store entries materialized in ~/.nb0016/pkgs2
    47 nimble.paths entries point at the scratch store
    bin/nim_status_client, bin/StatusQ/libStatusQ.dylib, resources.rcc,
    .statusgo-build/build/bin/libstatus.dylib,
    .statusgo-build/.sds-build/build/libsds.dylib,
    build/status-keycard-qt/macos/libstatus-keycard-qt.dylib   — all present

Launch smoke on the produced binary (bare exec, no DYLD_LIBRARY_PATH): still
running after 8 s, `starting application...` in the log. A no-op against the
scratch store: `real 6.38`, `nimble setup` not re-run. Default store restored
afterwards (`touch nim_status_client.nimble; nim app` → 3:39.34, 47
`~/.nimble/pkgs2` entries, 0 `.nb0016` entries); `~/.nb0016` deleted.

### 4. QR code generator via `{.compile.}`; static library, link flag and sentinel entry gone

    $ ls nimcache/release/nim_status_client/ | grep -i qrcode
    @m..@svendor@sQR-Code-generator@sc@sqrcodegen.c.o
    @m..@svendor@sQR-Code-generator@sc@sqrcodegen.sha1

    $ nm bin/nim_status_client | grep " T _qrcodegen" | head -5
    00000001000a775c T _qrcodegen_calcSegmentBufferSize
    00000001000a7eb8 T _qrcodegen_encodeBinary
    00000001000a7f30 T _qrcodegen_encodeSegments
    00000001000a505c T _qrcodegen_encodeSegmentsAdvanced
    00000001000a4d9c T _qrcodegen_encodeText

    $ grep -c libqrcodegen nimcache/release/nim_status_client/*.json
    0                       # nothing on the link line

    $ ./bin/nim_status_client --help   →  rc=0

Deleted: `$(QRCODEGEN)` target + `QRCODEGEN_MAKE_PARAMS` (root Makefile), its
`--passL` in `config.nims`, in the Windows `NIM_CLIENT_COMPILE` and in
`nim-test-run/%`, its `make clean` recursion, and its entry in
`scripts/platform_pre_build_cleanup.sh`. ADR 0003's registry amended.

`mobile/Makefile` still builds its own `libqrcodegen.a` and still passes
`-lqrcodegen`; the iOS leg (criterion 10) linked clean —
`grep -ic "duplicate symbol" ios.log → 0` — because the linker never pulls an
archive member whose symbols are already defined.

### 5. rcc regenerated on input change, skipped otherwise

    # unchanged inputs
    resources.rcc mtime before=1783679911 after=1783679911   (skipped)
    # touch ui/main.qml
    1084 resources added                                     (regenerated)
    # nim compileTranslations status.nims  (writes ui/i18n/*.qm)
    1084 resources added                                     (regenerated)

The last one is a deliberate addition: `.qm` joined the input pattern, because
`ui/generate-rcc.go` embeds the catalogs and translations stopped being a build
step in this issue.

The prune now matches the generator's `filepath.SkipDir`-on-a-basename exactly,
with `*/<name>/*` per pruned name (commit `c072056813`). Review raised the
depth-limited form as a correctness bug; it was not one — find's `-path` uses
`fnmatch` **without** `FNM_PATHNAME`, so its `*` already crossed `/`:

    $ find ui -type f -path 'ui/*/vendor/*'   # ui/a/b/vendor/x.qml → 1 match
    $ find ui -type f -path '*/vendor/*'      # ui/a/b/vendor/x.qml → 1 match

Re-verified on a synthetic depth-3 pruned file (`ui/app/mainui/vendor/Probe.qml`,
which `generate-rcc.go` also skips): touching it leaves rcc skipped; touching
`ui/main.qml` regenerates it. The new spelling says what it means rather than
relying on that fnmatch detail.

### 6. Fresh clone with uninitialised submodules

    $ git submodule deinit -f vendor/DOtherSide vendor/QR-Code-generator vendor/SortFilterProxyModel
    $ rm -rf vendor/DOtherSide/build
    vendor/DOtherSide: 0 entries   vendor/QR-Code-generator: 0 entries
    vendor/SortFilterProxyModel: 0 entries

    $ nim app status.nims
    Bootstrapping: submodules vendor/DOtherSide vendor/QR-Code-generator vendor/SortFilterProxyModel
    Building: StatusQ / DOtherSide / status-keycard-qt
    rc=0, 1:14.89
    vendor/DOtherSide: 13   vendor/QR-Code-generator: 9   vendor/SortFilterProxyModel: 22

Init is targeted (`git submodule update --init -- <those three>`), never
blanket-recursive.

### 7. `nimble setup` not re-run when the lock, manifests and overlay are unchanged

    nim app status.nims  →  no "Resolving:" line; nimble.paths mtime unchanged
                            (before=1783598696 after=1783598696)
    touch nim_status_client.nimble; nim buildArtifacts status.nims
                         →  nimble.paths mtime bumped to 1783680601

The overlay arm is exercised by criterion 9b: `nim develop status.nims
prl-to-pc` rewrote `nimble.overlay`, and the very next `nim app` printed
`Resolving: nimble graph (lock/manifests/overlay changed)`. `applyOverlay`
still runs immediately after `nimble setup`, inside the same gate.

### 8. `compile-translations` reachable as a task, not run during a build

    $ nim help status.nims | grep -i translations
    compileTranslations  Compile the Qt translation catalogs (ui/i18n/*.qm) — a maintainer command, NOT a build step (issue 0016)
    updateTranslations   Re-extract translatable strings into ui/i18n/*.ts and run the lokalise fixup

    $ rm ui/i18n/qml_cs.qm && nim app status.nims
    after a normal build: ls: ui/i18n/qml_cs.qm: No such file or directory
    $ nim compileTranslations status.nims
    Configuring: translations / Building: translations
    after the task: -rw-r--r--  656484  ui/i18n/qml_cs.qm

The lokalise fixup (`go run fixup-base-ts-for-lokalise.go`) lives in
`updateTranslations` only. The root `make compile-translations` target survives
because `mobile/Makefile` still calls it.

### 9. Develop-mode round trip

**9a — cmake Vendor (status-keycard-qt).**

    nim develop status.nims status-keycard-qt
    .status-cmake.key before: -DFETCHCONTENT_SOURCE_DIR_STATUS-KEYCARD-QT=
    nim app status.nims
    .status-cmake.key after:  -DFETCHCONTENT_SOURCE_DIR_STATUS-KEYCARD-QT=<repo>/vendor/status-keycard-qt
    CMakeCache.txt:           FETCHCONTENT_SOURCE_DIR_STATUS-KEYCARD-QT:PATH=<repo>/vendor/status-keycard-qt

    touch vendor/status-keycard-qt/src/c_api.cpp; nim app status.nims
    [ 70%] Building CXX object .../status-keycard-qt.dir/src/c_api.cpp.o
    [ 72%] Linking CXX shared library ../../libstatus-keycard-qt.dylib     ← the edit reaches the build

    nim undevelop status.nims status-keycard-qt --force; nim app status.nims  → rc=0
    .status-cmake.key: -DFETCHCONTENT_SOURCE_DIR_STATUS-KEYCARD-QT=
    CMakeCache.txt:    FETCHCONTENT_SOURCE_DIR_STATUS-KEYCARD-QT:PATH=
    nim vendors:       status-keycard-qt  [cmake, default]

The flip is now driven by the configure **key**, not by deleting the artifact —
strictly safer than the make rule it replaces.

**9b — nimble-graph Vendor (prl-to-pc).**

    nim develop status.nims prl-to-pc
    nim app status.nims  →  "Resolving: nimble graph (lock/manifests/overlay changed)"
                            rc=0, 1:52.52
    nimble.paths: 1 entry → vendor/prl-to-pc
    .prl-to-pc-build/qt-pkgconfig.env: key=…|<repo>/vendor/prl-to-pc|…   (env cache re-keyed)

    nim undevelop status.nims prl-to-pc --force; nim app status.nims  → rc=0
    nimble.paths: pkgs2/prl_to_pc-0.3.0-efc5e3d18f1e6e11e2f3a6b6ed034e84d634771b
                  0 entries pointing at vendor/prl-to-pc
    env cache:    key=…|~/.nimble/pkgs2/prl_to_pc-0.3.0-efc5e3d1…|…

### 10. Platform sentinel flip (desktop → iOS → desktop)

    sentinel before: darwin-arm64
      .statusgo-build/build/bin/libstatus.dylib      present
      .statusgo-build/.sds-build/build/libsds.dylib  present

    QMAKE=~/Qt/6.11.0/ios/bin/qmake IPHONE_SDK=iphoneos QMAKE_DEVELOPMENT_TEAM=…
    nim app status.nims --os:ios --cpu:arm64   → rc=0, 3:45.21
      "platform changed (darwin-arm64 -> ios-arm64); cleaning shared artifacts"
      sentinel after: ios-arm64
      .statusgo-build/build/bin/libstatus.dylib  → No such file  (cleaned)
      Built .../mobile/bin/ios/qt6/Status.app
      grep -ic "duplicate symbol" → 0

    nim app status.nims                        → rc=0, 1:32.50
      "platform changed (ios-arm64 -> darwin-arm64); cleaning shared artifacts"
      sentinel after: darwin-arm64
      libstatus.dylib + libsds.dylib rebuilt; launch smoke OK

The sentinel is now invoked by the driver (`platformCleanup()`), before any
shared artifact is touched, with a key byte-identical to the root Makefile's
`$(host_os)-$(or $(QT_ARCH),$(shell uname -m))` — the still-make-driven mobile
legs write the same `.platform-target` file.

### 11. Only `stale()` and the key-file pattern gate anything; both documented

Full audit of every rebuild decision in `status_artifacts.nims`:

Rewritten after the 2026-07-10 review round (commit `c072056813`): every
rebuild decision now uses one of the two spellings, and there is **no bare
`fileExists` gate left in the file**.

| what | gate | pattern |
|------|------|---------|
| cmake configure | `keyStale(.status-cmake.key, <argument list>, witness = CMakeCache.txt)` | key file |
| `nimble setup` | `stale([nimble.paths], [lock, manifests, overlay])` | `stale()` |
| statusgo scratch tree | `keyStale(.statusgo-origin, <store path>, witness = statusgo.nims)` | key file |
| statusgo artifacts | `keyStale(.statusgo-artifact-key, <flag set>)` | key file |
| libsds | `stale([libsds], [statusgo nimble.paths, statusgo.nimble])` | `stale()` |
| libstatus | `stale([libstatus], [])` | `stale()` |
| resources.rcc | `stale([resources.rcc], uiSources())` | `stale()` |
| the client binary | `keyStale(.status-client.key, clientKey())` + `stale([bin], clientSources())` | both |
| submodules, brew bottles | presence | **bootstrap, not gating** — see below |

`keyStale(keyFile, key, witness)` is the single key-file spelling. `witness` is
the artifact whose existence the key vouches for, so a key file that outlived
an `rm -rf` of its build tree cannot read fresh:

    $ rm -f ui/StatusQ/build/Qt6.11.0/CMakeCache.txt   # key file survives
    $ nim app status.nims
      Configuring: StatusQ                              ← witness gone ⇒ stale

    $ echo /nonexistent/store/path > .statusgo-build/.statusgo-origin
    $ nim buildArtifacts status.nims
      prepareStatusgo: refreshing .statusgo-build from ~/.nimble/pkgs2/statusgo-0.1.0-4f85453a…

**Bootstrap is not gating.** `initSubmodules()` and `fetchBottles()` materialize
inputs a fresh clone lacks and that nothing in the build can invalidate — a git
submodule tracks its own revision, a brew bottle is content-addressed by its
flavor. Presence is the only question they can ask, so they are deliberately
outside the two patterns and outside this table. The header says so.

Both patterns, their semantics and their limits (second granularity;
`stale()` always true on Windows) are documented in the header of
`status_artifacts.nims`, together with the reason `stale()` may never move into
`status_env.nims`. `libstatus`'s "the artifact exists ⇒ it is fresh" check is
spelled `stale(outputs, [])` rather than a bare `fileExists` (commit
`0f913789c9`).

The client key (fix E, commit `c072056813`) covers **every** environment
variable `config.nims` reads inside its `isDesktopClient` block that moves a
compile or link flag — `envOr(NAME, derived)` prefers an exported value, so any
of them changes the binary while leaving every file `stale()` watches untouched:

    $ cat .status-client.key | tr '|' '\n'
    /Users/…/Qt/6.11.0/macos/bin/qmake
    INCLUDE_DEBUG_SYMBOLS=      QT_ARCH=                  RESOURCES_LAYOUT=
    KDF_ITERATIONS=             OUTPUT_CSV=               QT_LIBDIR=
    STATUSGO_LIBDIR=            NIMSDS_LIBDIR=            STATUSQ_INSTALL_PATH=
    STATUSKEYCARD_QT_LIBDIR=    DOTHERSIDE_LIBDIR=        MACOSX_DEPLOYMENT_TARGET=14.0

    nim app status.nims                          → not relinked
    export STATUSGO_LIBDIR=…/build/bin; nim app  → relinked   (moves -L and an rpath)
    unset STATUSGO_LIBDIR;             nim app   → relinked
    nim app status.nims                          → not relinked   (stable again)

`prl-to-pc`'s cached `env` joined `clientSources()` for the same reason: it
decides what `pkg-config --libs Qt6…` puts on the link line.

### 12. `client-deps` no longer exists

    $ make client-deps
    make: *** No rule to make target `client-deps'.  Stop.

    $ grep -rn client-deps .   # outside docs/ and vendor/
    status_artifacts.nims:8:# … instead of a delegation to make's `client-deps`.   (a comment)

Every reference was checked, CI files included: the only consumer was
`nim buildArtifacts status.nims` (the manifest's `before build` hook), which
now calls `buildHostArtifacts()`.

### 13. `nim app status.nims` and `nimble build` both green

    $ nim app status.nims        →  rc=0
    $ nimble build               →  rc=0, 2:17.35 (nimble always recompiles the client)
    $ ./bin/nim_status_client --datadir=/tmp/status-0016-smoke
      still running after 8 s; "starting application..." in the log

### Disclosed regression: Windows rebuilds everything, every build

Not a gap in verification — a **known, accepted regression**, adjudicated
2026-07-10. `stale()` shells out to the POSIX `test -nt`, which Windows has no
shell for, so it returns `true` unconditionally: `nimble setup` and every
`stale()`-gated artifact (resources.rcc, libsds, the client binary) rebuild on
every Windows build.

It trades **slow-but-correct** for the **fast-but-wrong** behaviour it
replaces. The old `nimblePathsStale()` returned `false` on Windows — it
declared the resolution fresh without looking, and relied on make's stamp rule
(which this issue deletes) to catch a changed lock or manifest. A Windows
developer who bumped a pin would silently have built against the old store.

Fixed by 0017's portable `stale()`: the content-key variant the walls doc
already describes (`hash(readFile(src))` + compiler version + flags, written to
a key file), which is also what 0017 wants for the client compile across
develop flips. Recorded as follow-up 4. The Windows client compile separately
still carries its make-owned flag soup — ported, unverified, as 0012 did.

### Not verified
- **Linux.** The `run` task's `LD_LIBRARY_PATH` launch arm, the `sonoma`
  (non-arm64) bottle flavor and the `linux` keycard build dir are code-review
  only; no Linux host here.
- **Android.** Untouched (`app --os:android` still delegates to
  `make mobile-build`), and the `{.compile.}` + `-lqrcodegen` coexistence is
  argued from the iOS evidence and the linker's archive-member semantics, not
  from an Android link.
- **`make run` / `make nim_status_client`** still work (the Makefile parses,
  `make -n nim_status_client` is clean) but were not run end-to-end: the driver
  owns those paths now and 0017 deletes them.

### Follow-ups recorded (not implemented — no scope creep)

1. **Fresh clones lose the compiled translation catalogs.** `ui/i18n/*.qm` are
   gitignored and produced by cmake; they used to be built by `rcc`'s
   `compile-translations` prerequisite. With translations out of the artifact
   set (a user-approved decision of this issue), a fresh clone's
   `resources.rcc` embeds no catalogs until someone runs
   `nim compileTranslations status.nims`. The app builds and runs; it is
   untranslated. Decide whether to commit the `.qm`, or to run the task once in
   `bootstrap()`, or to accept it.
2. **`make` is still spawned by cmake's `Unix Makefiles` generator.** Switching
   the generic cmake procedure to `-G Ninja` would make criterion 1 literally
   true, at the cost of a `ninja` prerequisite and a packaging re-check.
3. **`statusgo-shared-library` has no nimscript task.** While it does not, a
   cold `libstatus` runs status-go's own Makefile. 0018 already moves
   `status-go-deps` into status-go's nimscript tasks; the shared-library target
   belongs in the same move.
4. **`stale()` on Windows.** The walls doc's content-key variant
   (`hash(readFile(src))` + compiler version + flags) is the portable fix, and
   0017 will want it anyway for the client compile across develop flips.
5. **`run-*` make targets are now dead** (the driver's `run` task assembles and
   launches natively). 0017 deletes them, as planned.
6. **`.qmake_previous`** is superseded by `.status-client.key` but the make
   rule that writes it still exists; it dies with 0017's client-compile move.
7. **The brew bottle's flavor is not keyed.** `fetchBottles()` gates on the
   directory's presence, so a cross-desktop flip (`QT_ARCH=x86_64`, which wants
   the `sonoma` bottle rather than `arm64_sonoma`) reuses the wrong bottle.
   Pre-existing — make's `$(BOTTLES)` file target had the identical hole — and
   deliberately not fixed here: keying it would force a one-time network
   refetch on every existing tree and CI agent.
8. **0017's scope shrank.** `buildClient()` and `launchHostApp()` landed here
   because criterion 1 required them. What remains for 0017: the Nim test
   suite, the Windows launcher, deleting the `run-*` / `nim_status_client` make
   targets and `.qmake_previous`, packaging against the driver-built binary,
   the explicit force flag on `app`, the Windows flag branches, and the
   portable `stale()` of follow-up 4.
