---
id: 0011
title: Keycard pair — FetchContent pins + FETCHCONTENT_SOURCE_DIR develop redirect
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`

## What to build

Bring the CMake vendor flavor online for `status-keycard-qt` and its nested
FetchContent dependency `keycard-qt`:

- Convert the `vendor/status-keycard-qt` submodule to a CMake FetchContent
  pin (`GIT_TAG` = today's submodule SHA) in the app's CMake orchestration
  (the Makefile keycard target already drives cmake; the existing
  `STATUS_KEYCARD_QT_SOURCE_DIR ?=` knob is the natural seam). Submodule
  removal follows the Phase 2 staged playbook.
- `keycard-qt` is already FetchContent'd by status-keycard-qt — pin audit
  only (ensure a fixed `GIT_TAG`, not a branch).
- Vendor-table entries (0009 driver) for both, flavor = cmake: `develop
  status-keycard-qt` / `develop keycard-qt` clone the repo into
  `vendor/<name>` at the pin and export
  `FETCHCONTENT_SOURCE_DIR_<NAME>` (the proven MobileUI pattern in
  buildStatusQ.sh) for all subsequent builds; `undevelop` drops the redirect.
  Nested develop (keycard-qt) must work WITHOUT developing status-keycard-qt.
- Default-mode gating: FetchContent at a fixed GIT_TAG + cmake's own
  incrementality already skip unnecessary work; verify no per-build network
  fetch (FetchContent caches; `FETCHCONTENT_UPDATES_DISCONNECTED` if needed).

## Acceptance criteria

- [ ] Default mode, no `vendor/status-keycard-qt` checkout: full desktop
  build passes with both keycard libs fetched at their pins; second build
  performs no network access and no keycard recompilation.
- [ ] `develop status-keycard-qt` → edit a C++ source → next `nim app` build
  recompiles and relinks the dependent → `undevelop` returns to the pin.
- [ ] `develop keycard-qt` alone (parent stays pinned) → C++ edit picked up
  through status-keycard-qt's build.
- [ ] Keycard functionality smoke on desktop build (app launches; keycard
  service initializes — no deeper hardware test required).
- [ ] `nim vendors status.nims` reports both, with pin + state.

## Blockers — grill before implementing

- Where the FetchContent declaration for status-keycard-qt lives (StatusQ
  CMake vs a new top-level CMakeLists vs the Makefile's cmake invocation) —
  survey the current keycard make target first; grill if the natural seam is
  contested.

## Blocked by

- 0009 (vendor table + develop UX).

## Survey findings (2026-07-07, phase A — read-only; implementation gated on 0010's completion commit)

### Current chain, end to end

- **Pins (recorded).** `vendor/status-keycard-qt` submodule =
  `a6cbdd052251f0dd01f4ce1b3d77016df7c1d4d7` ("chore: lib clean-up"; checkout
  clean at that SHA; `.gitmodules` URL
  `https://github.com/status-im/status-keycard-qt`). Nested `keycard-qt`
  GIT_TAG inside its CMakeLists.txt:64–75 = **already a fixed SHA**
  `df00b931185ceef4e5f0de701ae2047c40e9aabb`
  (`https://github.com/status-im/keycard-qt`) — pin audit PASSES, no branch
  fix needed. Both SHAs verified reachable on GitHub (gh api, read-only).
  Default branch of both repos: `master`.
- **Desktop make target** (`Makefile:633–686`): `STATUS_KEYCARD_QT_SOURCE_DIR
  ?= vendor/status-keycard-qt` (the local-dev knob), platform build dir
  `$(SOURCE_DIR)/build/{macos,windows,linux}` — i.e. INSIDE the submodule —
  recipe = `cmake -S $(SOURCE_DIR) -B $(BUILD_DIR)` with
  `-DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF
  -DKEYCARD_QT_SOURCE_DIR=$(KEYCARD_QT_SOURCE_DIR)` (`?= ""`, second knob,
  already plumbed for a local nested checkout) + per-OS OpenSSL params
  (macOS: brew bottle root + static; win: scoop root), then `cmake --build
  --target status-keycard-qt`. The lib target `$(STATUSKEYCARD_QT_LIB): |
  deps check-qt-dir` has **order-only prereqs — the recipe runs only when
  the lib file is missing** (that IS the default-mode stamp-skip; a no-op
  build never invokes cmake, hence no network trivially).
- **Consumers.** Only `nim_status_client` links it
  (`-L$(STATUSKEYCARD_QT_LIBDIR) -lstatus-keycard-qt`, Makefile:853–854;
  order-only prereq, macOS install_name_tool rewrite to @rpath:864–867).
  Nim side calls it through the `keycard_go` package — a *nimble-graph* pin
  (`nim_status_client.nimble:63`, status-im/nim-keycard-go#c8a39e8d) — gated
  by `featureGuard KEYCARD_ENABLED` (src/nim_status_client.nim:19). StatusQ
  does NOT consume it. Runtime legs: run-{linux,macos,windows} put
  `$(STATUSKEYCARD_QT_LIBDIR)` on the loader path (run-windows copies the
  DLL); Windows pkg copies the lib (Makefile:1050); config.nims:71 emits
  `-rpath $STATUSKEYCARD_QT_LIBDIR` (exported by make, incl. the
  STATUSKEYCARDGO_LIBDIR alias for the nested-worktree wall). It is a SHARED
  library on desktop → C++ edits need no client relink (sds-like), so
  `clientRebuild=false` for both vendor rows.
- **Mobile leg** (builds keycard: YES, both OSes, `FLAG_KEYCARD_ENABLED ?=
  1`): `mobile/Makefile:131–134` → `buildStatusKeycardQt.sh` with
  `STATUS_KEYCARD_QT ?= $(STATUS_DESKTOP)/vendor/status-keycard-qt`
  (Common.mk:36) and `BUILD_DIR=$(BUILD_PATH)` = `mobile/build/<OS>/qt6`
  (the shared mobile cmake tree; `_deps/keycard-qt-src` confirmed there —
  FetchContent already fetches the nested dep on mobile today).
  keycard-qt is built STATIC and bundled into libstatus-keycard-qt
  (libtool/ar POST_BUILD). OpenSSL for iOS/Android is passed manually
  (`OPENSSL_CRYPTO_LIBRARY` + BUILD/SOURCE include dirs — the script derives
  them from mobile's own openssl build; CMakeLists hard-requires them on
  mobile). The script already implements the local-keycard-qt redirect via
  `-DKEYCARD_QT_SOURCE_DIR` when the dir exists. Prereq
  `STATUS_KEYCARD_QT_FILES := $(shell find $(STATUS_KEYCARD_QT) …)` is
  guarded (`|| echo ""`) → empty when no checkout exists.
- **Root mobile targets** delegate `$(MAKE) -C mobile …`; command-line make
  vars propagate to sub-makes via MAKEFLAGS (how REBUILD_NIM-style driver
  args already travel).

### Empirical results (scratch probes, cmake 3.26.3)

- **Redirect var casing**: for `FetchContent_Declare(keycard-qt …)` the
  override cache var is exactly `FETCHCONTENT_SOURCE_DIR_KEYCARD-QT`
  (TOUPPER, **hyphens preserved**); proven — configure used the local dir,
  no network attempted. Parent (`status-keycard-qt`) ⇒
  `FETCHCONTENT_SOURCE_DIR_STATUS-KEYCARD-QT`.
- **Cache semantics** (undevelop-critical): the var is a CACHE entry —
  omitting `-D` on a later configure keeps the redirect (sticky); passing it
  **empty** (`-DFETCHCONTENT_SOURCE_DIR_KEYCARD-QT=`) restores pin-fetch
  behavior (empty == unset for FetchContent); `-U` also clears it. ⇒ always
  pass the pair explicitly (mode's current value, possibly empty) whenever
  the recipe configures — deterministic, no stale-cache leaks.

### Design (against the grilled decisions)

- **Seam**: FetchContent *wraps* — a new app-owned wrapper CMake project,
  `cmake/status-keycard-qt/CMakeLists.txt` (project LANGUAGES NONE;
  `FetchContent_Declare(status-keycard-qt GIT_REPOSITORY
  https://github.com/status-im/status-keycard-qt GIT_TAG a6cbdd05…)` +
  `FetchContent_MakeAvailable`). The pin for status-keycard-qt lives THERE
  (the app's CMake orchestration, per the issue); keycard-qt's pin stays
  owned by status-keycard-qt's own CMakeLists (audit-only). Rejected: StatusQ
  CMake (wrong consumer/lifecycle, no OpenSSL plumbing, separate mobile
  build) and "Makefile cmake invocation" alone (cmake cannot FetchContent
  from the CLI; a CMakeLists must exist — the Makefile keeps driving cmake,
  only `-S` flips to the wrapper). All existing `-D` options pass through
  unchanged (FetchContent = add_subdirectory in the same cache scope). Not
  contested after reading → no grill needed.
- **Build dir moves out of the checkout**: `build/status-keycard-qt/{macos,
  windows,linux}` at the repo root (mode-independent; the checkout stays a
  pure source dir; StatusQ precedent keeps build trees near sources but the
  submodule dir will no longer exist by default). Mobile keeps
  `BUILD_DIR=$(BUILD_PATH)` (unchanged layout, `_deps` already there).
- **Develop/undevelop (vendor-table rows, flavor = cmake)**:
  - `develop status-keycard-qt` → clone pin URL into
    `vendor/status-keycard-qt` at the pin on branch `develop` (reuse,
    never clobber — 0009 semantics), record in `nimble.overlay`.
  - `develop keycard-qt` (nested, WITHOUT parent) → clone into
    `vendor/keycard-qt`; redirect only
    `FETCHCONTENT_SOURCE_DIR_KEYCARD-QT` — no parent cascade (PRD).
  - Driver arm (developModeMakeArgs, vfCmake): pass the redirect(s) as make
    vars (Makefile recipe forwards them as the two `-DFETCHCONTENT_SOURCE_
    DIR_*` args, always-pass semantics incl. empty) + **forceRemove the
    built lib** — the target has no real prereqs, so removal is what re-runs
    cmake (configure ~seconds, build incremental; same pattern as statusgo's
    rm-FORCE). cmake reads the checkout's own CMakeLists when redirected ⇒
    ADR-0004-style divergence guard is NOT needed for cmake flavor (edits to
    the vendor's build config take effect — no silent-drift mode exists).
  - `undevelop` → drop overlay entry + remove the lib; next build
    reconfigures with empty redirect ⇒ pin. Per 0009 precedent the per-build
    arms are driver-only (`nim app` is the develop-mode front door); bare
    make stays default-mode correct because the recipe only runs when the
    lib is missing.
  - `vendors`: cmake-flavor pin parser reads GIT_REPOSITORY/GIT_TAG from the
    pin-owning CMakeLists. keycard-qt's owner is located dynamically:
    `vendor/status-keycard-qt` checkout → else
    `build/status-keycard-qt/<platform>/_deps/status-keycard-qt-src` → else
    report "pin owned by status-keycard-qt (visible after first build)".
    `develop keycard-qt` needs the same lookup for its clone URL+rev (clear
    error naming the fallback when neither source exists yet).
- **Submodule removal** (Phase 2 staged playbook): backup = SHA recorded
  here + dir moved to `.phase2-vendor-backup/` (not rm); `git config -f
  .gitmodules --remove-section submodule.vendor/status-keycard-qt`; `git rm
  --cached vendor/status-keycard-qt`; gitignore `/vendor/status-keycard-qt/`
  + `/vendor/keycard-qt/` + `/build/status-keycard-qt/` (develop checkouts
  and build tree; matches `/vendor/nim-sds/` precedent). Note: a later
  `develop status-keycard-qt` must be a FRESH clone (the submodule's gitdir
  pointer into `.git/modules` must not be reused).
- **No-network-on-second-build**: layer 1 — make never re-invokes cmake
  when the lib exists (order-only target). Layer 2 — on reconfigure, a
  fixed-SHA GIT_TAG lets cmake skip the fetch when `_deps` already holds
  that SHA; verify empirically (offline-proxy env trick or cmake trace) and
  set `FETCHCONTENT_UPDATES_DISCONNECTED=ON` in the wrapper if any fetch
  survives.
- **Mobile changes kept minimal** (targets must keep working, PRD story 10):
  Common.mk `STATUS_KEYCARD_QT` default → the wrapper dir;
  buildStatusKeycardQt.sh `-S` unchanged semantics + always-pass redirect
  pair. Mobile keycard develop-verification is NOT in this issue's
  acceptance (desktop-only checkboxes); noted as residual.

### Phase B checklist (maps to acceptance)

1. Wrapper CMakeLists + desktop Makefile flip (-S/-B/new -D pass-throughs) +
   mobile script flip; full desktop build with NO vendor/status-keycard-qt
   checkout; second build: no cmake invocation, no network, no recompile.
2. Vendor-table rows + vfCmake legs in develop/undevelop/vendors +
   driver FORCE arm; staged submodule removal (backup first).
3. Develop cycle parent: C++ edit → `nim app` → lib mtime/relink observed
   (0004 probe pattern) → undevelop → pinned rebuild.
4. Develop cycle nested alone: edit in vendor/keycard-qt picked up through
   the parent's build.
5. Keycard smoke: app launches, keycard service initializes.
6. `nim vendors status.nims` lists both with pin + state.
