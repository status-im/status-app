---
id: 0018
title: NBS deleted — nimble is the only prerequisite, the store compiler is the compiler
date: 2026-07-09
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: done
---

## Parent

PRD: `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md`

## What to build

Delete the vendored nimbus-build-system. After 0017 its only remaining jobs are
to put a Nim compiler on `PATH` and to auto-init submodules — and the app
manifest already pins `nim == 2.2.4`, which nimble materialises in its own
store.

- **The machine prerequisite becomes nimble alone.** Post-clone bootstrap is
  `nimble setup && eval "$(nimble shellenv)"`, after which `nim` on `PATH` *is*
  the pinned compiler, by construction. No version guard is added — a
  bootstrapped shell cannot drift.

  *Spiked 2026-07-09*: with `PATH` scrubbed of both `~/.nimble/bin` and NBS
  (`which nim` → nothing), `nimble setup` resolved and used
  `pkgs2/nim-2.2.4-<checksum>/bin/nim`, and `nimble shellenv` emitted that
  `bin/` directory on `PATH`.

- **Internal `nim` invocations resolve the store compiler.** *Revised
  2026-07-09 by spike (record in `progress.txt`); the original sketch was
  broader than the evidence warrants:*
  - nimble **injects the pinned compiler's `bin/` into PATH** for tasks and for
    `before build` hooks. Anything nimble invokes — and any `make`/`nim` child
    that inherits that PATH — already gets the pinned compiler for free. No
    rule needed there.
  - The rule is therefore needed only **outside** nimble: a bare
    `make mobile-build` on a nim-free agent. Preferred fix is to reach make
    through a nimble task alias (or a `nimble shellenv` shell) rather than
    deriving a `NIM` variable — `nimble path nim` is unusable (it prints two
    same-version store entries).
  - **Context hazard:** in the `.nimble` manifest VM, `selfExe()` and
    `querySetting(libPath)` return nimble's *evaluator* compiler (measured:
    2.2.10), not the pin. Only `findExe("nim")` is correct there.
    `getCurrentCompilerExe()` (from `std/os`) is correct in `.nims` scripts run
    by `nim`. Since the manifest `include`s `status.nims`, any compiler lookup
    reachable from both must branch on context.

- **Pre-existing divergence this issue closes** (found 2026-07-09): the NBS
  vendored compiler is **2.2.10** while the manifest pins **2.2.4**, so today
  `nim app status.nims` and `nimble build` compile the client with *different
  compilers*. Deleting NBS is what makes the pin authoritative.

- **The submodule is removed** with the established backup-ref playbook
  (functional git dir preserved under the phase-2 vendor backup).

- **The root Makefile becomes self-contained**: local verbosity/output defines
  replace the NBS includes; there is no submodule auto-init `.DEFAULT` (the
  driver's bootstrap owns it since 0016).

- **Deleted with it**: `deps`, `update`, `deps-common`, `NIM_PARAMS`, the
  env-script wrapper, `.update.timestamp`, `NIM_SOURCES`, `REBUILD_NIM`. `make
  update` is **not** preserved as a shim — a shim perpetuates the front door
  being removed. `BUILDING.md` teaches the bootstrap and the driver instead.

- **`status-go-deps`** (a Go tool install) moves into status-go's own nimscript
  tasks.

The remaining C/C++ submodules (SortFilterProxyModel, QR-Code-generator,
fcitx5-qt, mobile openssl, and DOtherSide until master merges) are **pins, not
Vendors**, and stay submodules. `CONTEXT.md`'s end-state has been amended to
say so.

## Acceptance criteria

- [x] **Nim-free machine proof**: from a fresh clone, with a `PATH` containing
      `nimble` and **no `nim`**, `nimble setup && nimble build` produces a
      runnable app; then `eval "$(nimble shellenv)" && nim app status.nims`
      succeeds. Recorded with the exact scrubbed `PATH`.
- [x] Cold-store materialisation of the pinned compiler is verified (not just
      warm-store reuse). **Done 2026-07-09 by orchestrator spike**: with `HOME`
      redirected (the only way to defeat the `~/.nimble/nimbinaries` cache,
      which survives a `NIMBLE_DIR` override) and PATH scrubbed of both
      `~/.nimble/bin` and NBS, `nimble setup` on a `requires "nim == 2.2.4"`
      package built the compiler and used it: 5:18 wall, 7.9 GB, warm re-run
      0.57 s, store checksum identical to this machine's
      (`nim-2.2.4-b4bb510b…`).
- [x] The compiler that builds the client is the pinned one on **both** paths
      (`nim app status.nims` and `nimble build`) — closing the 2.2.10/2.2.4
      divergence.
- [x] The nimbus-build-system submodule is gone; a backup ref preserves it.
- [x] The root Makefile includes no external makefile and defines its own
      verbosity/output handling.
- [x] `deps`, `update`, `deps-common`, `NIM_PARAMS`, the env-script wrapper,
      `.update.timestamp`, `NIM_SOURCES` and `REBUILD_NIM` no longer appear in
      either Makefile.
- [x] The interim mobile make legs compile with the store compiler (no `PATH`
      Nim), proving the nimble-only-agent contract for `make mobile-build`.
- [ ] `make pkg-macos` still produces a signed dmg. **Not verifiable on this
      machine** (no `nix`/`dmgbuild`, no signing identity) — verified as far as
      0017 did; see the record's §8.
- [x] `BUILDING.md` documents the nimble-only prerequisite and the bootstrap;
      no instruction references NBS or `make update`.
- [x] `nim app status.nims` and `nimble build` are both green.

## Blocked by

- 0017 (hard: it removes the last consumers of the NBS env-script wrapper; NBS
  cannot be deleted while the Makefile still compiles Nim through it).

---

## Verification record — 2026-07-12

Machine: macOS arm64 (M-series), Qt 6.11.0 macOS kit (Generated pkg-config mode);
iOS kit `~/Qt/6.11.0/ios` for the mobile leg. Store = default `~/.nimble`.
`~/.nimble/bin/nim` → `pkgs2/nim-2.2.4-b4bb510bd58b8fccf53a122a42699d8070b92c3e/bin/nim`
— the manifest pin, and the same store checksum the cold-store spike recorded.

Two environments are used below, and the difference between them is the point of
this issue:

    # A — the developer env (what SHARED-i3 now teaches)
    export QMAKE=~/Qt/6.11.0/macos/bin/qmake        # USE_SYSTEM_NIM is GONE
    # + nimble (and, for commands outside nimble, `eval "$(nimble shellenv)"`)

    # B — the nim-free machine (criterion 1 and the mobile leg)
    export PATH="/tmp/0018/nimble-only-bin:/opt/homebrew/bin:/opt/homebrew/sbin:\
    /usr/local/go/bin:$HOME/go/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    export QMAKE=~/Qt/6.11.0/macos/bin/qmake
    # /tmp/0018/nimble-only-bin holds exactly ONE entry: a symlink to `nimble`.
    # (~/.nimble/bin cannot simply be dropped from PATH — it carries a `nim`
    #  symlink; the PATH is therefore built up, not subtracted from.)
    $ command -v nim     → (nothing)
    $ command -v nimble  → /tmp/0018/nimble-only-bin/nimble   (v0.22.3)

### Commits

    96d76723d4  the root Makefile includes no external makefile
                (also carries the .gitmodules edit + the submodule's gitlink
                 deletion — they were staged first, per the P2 playbook, and the
                 commit that was meant to hold them therefore had nothing left)
    d33f5c1071  the store compiler is the compiler, on PATH (env.sh, mobile script)
    4598f6b35d  callers of the deleted make targets bootstrap with nimble (ci/, fdroid, container)
    cd31c00a6f  BUILDING.md teaches the nimble-only prerequisite
    (+ the shellenv-shadowing fix and the docs commits that follow this record)

### 1. Nim-free machine proof — fresh clone, `PATH` with nimble and no nim

Fresh `git clone` of this branch into `/tmp/0018/clone/status-desktop` (all
submodules uninitialised), environment **B** above.

    $ command -v nim                                   → (nothing)
    $ nimble setup
      Info: using /Users/alexjbanca/.nimble/pkgs2/nim-2.2.4-b4bb510b…/bin/nim
            for compilation                            ← nimble names the pin itself
      Info: "nimble.paths" is generated.
      rc=0, 52.9 s

    $ nimble build
      Bootstrapping: submodules vendor/DOtherSide vendor/QR-Code-generator
                     vendor/SortFilterProxyModel        ← the driver's bootstrap (0016)
      Fetching: openssl@3 bottle (arm64_sonoma)
      Resolving: … / Building: libsds / status-go / StatusQ / DOtherSide /
                 status-keycard-qt / resources.rcc / nim_status_client
      rc=0, 5:55.8      bin/nim_status_client, 30,219,664 bytes

    # the compiler nimble spawned for the client, caught in `ps` mid-compile:
    $ ps -eo command | grep 'pkgs2/nim-2.2.4.*bin/nim c'
    /Users/alexjbanca/.nimble/pkgs2/nim-2.2.4-b4bb510bd58b8fccf53a122a42699d8070b92c3e/bin/nim c
      --colors:off --noNimblePath -d:release -d:NimblePkgVersion=0.1.0 …

    $ source ./env.sh          # = eval "$(nimble shellenv)" + the fix in §7
    $ command -v nim  → …/pkgs2/nim-2.2.4-b4bb510b…/bin/nim
    $ nim -v          → Nim Compiler Version 2.2.4 [MacOSX: arm64]
    $ nim app status.nims                                rc=0, 53.8 s

**One thing the sandbox could not do**: the bottle fetch needs
`GITHUB_USER`/`GITHUB_TOKEN` (BUILDING.md says so; this environment has neither),
so `scripts/fetch-brew-bottle.sh` got `curl: (56) … 401` and the first `nimble
build` died there — *inside the driver's bootstrap, after it had initialised the
submodules*, i.e. the build system behaved correctly. The bottle was copied from
this worktree's `bottles/` (it is content-addressed by flavour) and the run above
is the re-run. **The bottle fetch is a pre-existing GitHub-credentials
prerequisite, not an NBS-removal regression** — the same call ran under `make
deps` before.

### 2. Cold-store materialisation — already ticked

Orchestrator spike, 2026-07-09 (HOME-redirect + scrubbed PATH → `nimble setup`
BUILT `pkgs2/nim-2.2.4-b4bb510b…`, 5:18, 7.9 GB). Not repeated. This session
independently confirms the store entry it produced is the one every front door
now uses: same checksum, `nim-2.2.4-b4bb510bd58b8fccf53a122a42699d8070b92c3e`.

### 3. Both front doors compile the client with the pin

The 2.2.10-vs-2.2.4 divergence this issue exists to close needed the NBS
compiler; there is no longer any other compiler on the machine to diverge to.

**`nim app status.nims`** — the client compile prints its own config chain:

    Building: nim_status_client
    Hint: used config file '/Users/alexjbanca/.nimble/pkgs2/nim-2.2.4-b4bb510b…/config/nim.cfg' [Conf]
    Hint: used config file '/Users/alexjbanca/.nimble/pkgs2/nim-2.2.4-b4bb510b…/config/config.nims' [Conf]

**`nimble build`** — nimble prints `Info: using …/pkgs2/nim-2.2.4-b4bb510b…/bin/nim
for compilation`, and the process it forks for the client compile IS that binary
(the `ps` capture in §1, taken on the machine that has NO other nim).

**And the two binaries agree.** 0017's parity method, re-run driver-vs-nimble
(`nim app status.nims --force`, then `nimble build`, same tree):

    section content hashes (otool -s, header line stripped)
      __TEXT,__text      IDENTICAL
      __TEXT,__const     IDENTICAL
      __TEXT,__cstring   IDENTICAL
      __DATA,__data      IDENTICAL
    nm md5   e17529d38a0c3803edafb487700378d6   (both — and the same md5 0017
                                                 recorded for the make/driver pair)
    byte diff: 15 279 bytes → LC_UUID + ad-hoc signature + OSO stab mtimes,
               the documented parity floor (0017 §2)

Same code bytes ⇒ same compiler and same flag set through both doors.

### 4. The submodule is gone; a backup ref preserves it

    $ git submodule status
     636dfadc70… mobile/vendors/openssl (openssl-3.5.0)
     3dc2d46c7e… vendor/DOtherSide
     d1c87af693… vendor/QR-Code-generator
     6477b1e465… vendor/SortFilterProxyModel
     2a86c5b7b7… vendor/fcitx5-qt              ← no nimbus-build-system
    $ grep -c '^\[submodule' .gitmodules       → 5

Playbook (P2 precedent), in this order:

1. `git -C vendor/nimbus-build-system branch backup/nimble-0018-nbs HEAD`
   (HEAD = `f34e2130c14e527e62fc1118de2fc2d7d6fdcb4a`)
2. `.gitmodules` edited and **staged first**, then `git rm --cached vendor/nimbus-build-system`
3. working tree moved to `.phase2-vendor-backup/nimbus-build-system` (gitignored),
   `core.worktree` repointed with `git config --file <gitdir>/config`
4. **the git dir itself was NOT touched**:

       $ git -C .phase2-vendor-backup/nimbus-build-system rev-parse --short HEAD   → f34e213
       $ git -C .phase2-vendor-backup/nimbus-build-system branch --list 'backup/*'  → backup/nimble-0018-nbs
       $ git -C .phase2-vendor-backup/nimbus-build-system status --short            → (clean)

**Nothing under the shared git modules directory was pruned, deleted or
rewritten.** This worktree's module lives at
`<git-common-dir>/worktrees/nimble-migration/modules/vendor/nimbus-build-system`;
the parent checkout's own `<git-common-dir>/modules/vendor/nimbus-build-system`
was verified still present afterwards, and the parent working tree was never
touched. `.git/config`'s `submodule.vendor/nimbus-build-system.*` section is left
in place (inert), exactly as the earlier removals left theirs.

Also deleted from the tree: the stale NBS artifacts `.update.timestamp`,
`nimbus-build-system.paths`, `vendor/.nimble/` (and their `.gitignore` entries).

### 5. The root Makefile includes no external makefile

    $ grep -n 'include' Makefile | grep -v qt-pkgconfig | grep -v '^#'
    (the only include left is prl-to-pc's qt-pkgconfig.mk — a resolved nimble
     package's file, for the interim mobile leg; issue 0015)

Defined locally now, replacing exactly what NBS's `variables.mk`/`targets.mk`
still provided this file: `V` (default 0), `HANDLE_OUTPUT`, the `.SILENT` recipe
silencing (NBS spelled it `$(SILENT_TARGET_PREFIX).SILENT`) and `BUILD_MSG`.
Nothing else in either makefile referenced NBS: `mobile/Makefile` defines its own
`V`/`HANDLE_OUTPUT` in `scripts/Common.mk`.

    $ make -n all                    → nim app status.nims          rc=0
    $ scripts/check-no-nim-compiles.sh
      ok: a Nim compile (`nim c`/`nim compile`) — absent
      ok: a nimscript eval (`nim e`) — absent
      ok: the NBS env-script wrapper — absent
      ok: NIM_PARAMS — absent                                        rc=0
    $ for t in pkg-macos status-go rcc statusq storybook-build clean \
               nimble-deps compile-translations; do make -n $t; done → all rc=0

### 6. The deleted surface is really gone

    $ for t in deps update status-go-deps deps-common update-common clean-common; do make -n $t; done
    make: *** No rule to make target `deps'.  Stop.
    make: *** No rule to make target `update'.  Stop.
    make: *** No rule to make target `status-go-deps'.  Stop.
    make: *** No rule to make target `deps-common'.  Stop.
    make: *** No rule to make target `update-common'.  Stop.
    make: *** No rule to make target `clean-common'.  Stop.

    $ git grep -nE 'USE_SYSTEM_NIM|NIM_PARAMS|NIM_SOURCES|REBUILD_NIM|\.update\.timestamp|BUILD_SYSTEM_DIR' -- Makefile mobile/Makefile
    Makefile:802,819,820,1104   ← comments only, explaining what died and where it went

`USE_SYSTEM_NIM` no longer appears in any build file (only in `mobile/DEV_SETUP.md`
— a doc, recorded as follow-up 3). The **NBS env-script wrapper's last consumer**
was `mobile/scripts/buildNimStatusClient.sh` (`./vendor/nimbus-build-system/
scripts/env.sh nim c …`), now a plain `nim c`: with `USE_SYSTEM_NIM=1` — the only
mode this repo ever ran — that wrapper's whole effect was to echo
`[using system Nim]` and exec the same `nim` from PATH.

Also removed: `status.nims`' `--force` → `REBUILD_NIM=true` pass-through to the
mobile make leg. REBUILD_NIM has not existed since 0017, so the flag named a dead
variable (follow-up 2).

### 7. WALL — `nimble shellenv` lists `$NIMBLE_DIR/bin` BEFORE the pinned compiler

Found while proving criterion 3. `nimble shellenv`'s PATH is:

    1: ~/.nimble/bin          ← whatever `nim` symlink lives here WINS
    …
    7: ~/.nimble/pkgs2/nim-2.2.4-b4bb510b…/bin      ← the pin
    8: (again)
    9: ~/.nimble/bin

`~/.nimble/bin/nim` is normally the pin (nimble's own `setup` installs the pinned
compiler as a package and links it there — that is why the fresh-clone proof
above still resolved 2.2.4). But choosenim, or a later `nimble install nim@X`,
repoints that one symlink — and then a "bootstrapped" shell would compile the
client with X, not with the pin. The issue's claim that *"a bootstrapped shell
cannot drift"* is therefore true only by luck of that symlink.

Fix (this issue): `env.sh` — the repo's bootstrap wrapper — evals `nimble
shellenv` and then **hoists `pkgs2/nim-<ver>-<checksum>/bin` to the front of
PATH**. BUILDING.md, SHARED-i3 and every caller (fdroid, container builds) now
teach `source ./env.sh`, not a bare `eval "$(nimble shellenv)"`.

    $ command -v nim                            → (nothing)
    $ source ./env.sh
    $ command -v nim → /Users/alexjbanca/.nimble/pkgs2/nim-2.2.4-b4bb510b…/bin/nim
    $ nim -v         → Nim Compiler Version 2.2.4

The residual exposure — a developer who types `eval "$(nimble shellenv)"` by hand
AND has a foreign `~/.nimble/bin/nim` — is recorded as follow-up 1 (a compiler
guard is a PRD-level decision: the PRD says no version guard is needed, and this
is the one case where it would bite).

### 8. `make pkg-macos` — NOT verifiable here (unchanged from 0017)

Run from a bootstrapped shell whose base PATH has no nim, with no
`USE_SYSTEM_NIM` anywhere:

    $ command -v nix dmgbuild   → (nothing);  MACOS_CODESIGN_IDENT unset
    $ make pkg-macos
      Building: StatusQ / DOtherSide / status-keycard-qt
      Building: nim_status_client        ← the driver relinks with -d:production
      Building: app                      ← macdeployqt
      Building: dmg
      bash: line 1: nix: command not found
      make: *** [pkg/Status.dmg] Error 127

Everything up to the dmg works post-NBS, and the bundle carries the driver's
binary:

    bin/nim_status_client                       __TEXT,__text md5 18eee625a145beb2a48ec0733c72b2d5
    tmp/macos/dist/Status.app/…/nim_status_client __TEXT,__text md5 18eee625a145beb2a48ec0733c72b2d5
    .status-client.key: … RESOURCES_LAYOUT=-d:production …

**Checkbox left unticked**, exactly as in 0017: no `nix`/`dmgbuild`, no signing
identity on this machine.

### 9. The mobile make leg compiles with the store compiler — no PATH nim

The nimble-only-agent contract for `make mobile-build`, on the **iOS device**
target (the leg 0016 verified; Android needs an SDK/NDK this machine lacks):

    $ source /tmp/0018/nimfree-env.sh          # environment B: nimble, NO nim
    $ export QMAKE=~/Qt/6.11.0/ios/bin/qmake IPHONE_SDK=iphoneos \
             QMAKE_DEVELOPMENT_TEAM=8B5X2M6H2Y
    $ echo "nim before: $(command -v nim || echo '<none>')"    → <none>
    $ source ./env.sh
    $ echo "nim after : $(command -v nim)"
      /Users/alexjbanca/.nimble/pkgs2/nim-2.2.4-b4bb510b…/bin/nim
    $ nim -v   → Nim Compiler Version 2.2.4

    $ make mobile-build V=3
      Building iOS libsds library / status-go mobile library / StatusQ /
      DOtherSide / OpenSSL / QRCodeGen / status-keycard-qt / rcc
      Building Status Desktop Lib
      + env FLAG_DAPPS_ENABLED=1 … nim c --app:staticlib -d:ios --os:ios …
                              ↑ a plain `nim c` — the NBS env.sh wrapper is gone
      Hint: used config file
        '/Users/alexjbanca/.nimble/pkgs2/nim-2.2.4-b4bb510b…/config/nim.cfg' [Conf]
                              ↑ the iOS client was compiled BY THE PIN
      Build Succeeded
      Built …/mobile/bin/ios/qt6/Status.app
      rc=0, 3:46.6

No `USE_SYSTEM_NIM` anywhere in that run (the variable does not exist any more).

### 10. Both front doors green, and the no-op envelope holds

    $ nim app status.nims        rc=0   (client relink 31.8 s after --force)
    $ nimble build               rc=0   1:41.7   (nimble always recompiles the client)
    $ nim app status.nims ×3     rc=0   3.42 / 3.96 / 4.10 s  — no client, no rcc
      (0018 brief's envelope: 3.51–3.89 s on an idle machine; another agent was
       building a Nim compiler on this box during part of the session, which is
       inside the noise here)

Platform-sentinel flip after the iOS leg (ADR 0003), i.e. the tree is left green:

    $ nim app status.nims
      platform changed (ios-arm64 -> darwin-arm64); cleaning shared artifacts
      Building: libsds / status-go / StatusQ / DOtherSide / status-keycard-qt /
                nim_status_client
      rc=0, 1:34.3

### Not verified

- **`make pkg-macos`'s dmg + signature** — no `nix`/`dmgbuild`, no identity
  (§8). Unchanged from 0017; the checkbox stays unticked.
- **The Android mobile leg** — no `ANDROID_SDK_ROOT`/`ANDROID_NDK_ROOT` on this
  machine. The compiler path it exercises is the SAME line of
  `mobile/scripts/buildNimStatusClient.sh` the iOS leg just ran (the platform
  branch only changes flags), and the NBS wrapper it lost is the only thing this
  issue changed there.
- **CI** — `ci/Jenkinsfile.*`, `fdroid/build-app.sh` and
  `mobile/ContainerBuilds.mk` were edited only because this issue deleted the
  targets they called (`make update` / `make deps`). Jenkins cannot run here.
  **Issue 0019 owns CI**, including the gap 0017's follow-up 10 already named:
  nothing carries the bootstrapped PATH across Jenkins `sh` steps yet, so a later
  stage's `nim app status.nims` still needs CI to be taught `source ./env.sh`.
- **Linux / Windows** — no hosts. The Makefile changes there are: `bottles`
  became a cross-platform no-op target (it was undefined off macOS, so the old
  `deps` rule could not even parse a `bottles` prerequisite there), and
  `clean-common` → `clean-nimcache`.
- **A machine whose `~/.nimble/bin/nim` is NOT the pin** (§7's wall). The
  shadowing is proven from the PATH order; the *consequence* was not reproduced,
  because doing so would mean installing a second Nim on this machine.

### Follow-ups recorded (not implemented)

1. **A compiler guard is now a live question (§7).** The PRD says none is needed
   because "a bootstrapped shell cannot drift" — true only while
   `~/.nimble/bin/nim` is the pin. `env.sh` closes it for anyone who uses the
   documented bootstrap; a hand-typed `eval "$(nimble shellenv)"` on a machine
   with a choosenim-managed `~/.nimble/bin/nim` still compiles the client with
   the wrong compiler, silently. Cheapest guard: `config.nims` (or the driver)
   compares `getCurrentCompilerExe()` against the `pkgs2/nim-…` entry the
   resolution names, and fails fast. **PRD-level decision — not taken here.**
2. **`--force` has no effect on the mobile legs.** The `REBUILD_NIM=true`
   pass-through in `status.nims`' `app` task named a variable deleted in 0017;
   it is gone, and the task now says so. mobile/Makefile's client rule is
   prerequisite-driven, so edits still rebuild; a forced mobile rebuild is
   `make -C mobile clean-nim-status-client`. Give the mobile leg a real force arm
   when the mobile follow-on lands.
3. **Docs outside BUILDING.md still name dead knobs** (out of scope, per the
   brief): `mobile/DEV_SETUP.md` documents `USE_SYSTEM_NIM=1`; every
   `ci/Jenkinsfile.*` describes `V` as "verbosity based on nimbus-build-system
   setup"; `scripts/clean-git.sh`'s header comment mentions NBS. The `desktop-run`
   / `mobile-*` skill docs likely do too.
4. **`status-go-deps`' true home.** The issue asks for it to move into
   status-go's own nimscript tasks. That needs a commit **in status-go** (a new
   task in `statusgo.nims`) plus a pin bump — and status-go is a pinned URL#hash
   dependency whose only tree here is a read-only store copy / scratch. Pushing
   to status-go is forbidden by SHARED-i3. What was done instead: the make target
   is deleted and its one line (`go install …/protoc-gen-go@v1.34.1`) is inlined
   in the `$(STATUSGO)` recipe — which is exactly what the driver's
   `buildLibstatus()` has already been doing since 0016, so both front doors now
   install it the same way and no behaviour changed. The status-go-side move is a
   separate, push-bearing task.
5. **The brew-bottle fetch needs GitHub credentials** (§1). Not new — but it is
   now the *only* step of a fresh-clone bootstrap that can fail for a reason
   unrelated to the code, and the error surfaces as a `curl: (56) … 401` deep
   inside the driver. A friendlier fail-fast ("export GITHUB_USER/GITHUB_TOKEN,
   see BUILDING.md") would pay for itself.
