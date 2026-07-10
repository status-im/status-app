---
id: 0017
title: driver owns every Nim compile — client, tests, launcher; make never invokes nim
date: 2026-07-09
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md`

## What to build

Three places still shell into `nim` from the root Makefile: the client compile,
the Nim test suite, and the Windows launcher. Move all three into the driver,
making **"the root Makefile never invokes `nim`"** a mechanically checkable
invariant.

- **Client** — the driver compiles it directly. `config.nims` has owned the
  full flag set since 0013 (parity-asserted), so this is a recipe move, not a
  flag move.
- **Nim tests** — become a driver task that owns the library-path environment
  the suite needs.
- **Windows launcher** — becomes a driver task; the Windows packaging target
  calls it.
- **`run-*` make targets are deleted.** The driver's `run` task has owned the
  launch environment since 0013; keeping both perpetuates two ways to run the
  app.
- **Packaging targets consume the driver-produced binary.** Signing,
  notarisation and dmg/AppImage/flatpak assembly are untouched — they simply
  stop depending on a make-built binary.
- **Windows flag branches are ported into `config.nims`** (the clang/msvc
  target flags, ssl version define, import-lib hooks). They are recorded as
  **ported, unverified** — a real Windows build belongs to the Windows push.
  Leaving them in make would restore the two-owners-of-one-flag-set problem
  this iteration exists to end.

`REBUILD_NIM` is replaced by two things: a developed nimble-graph Vendor skips
the `stale()` gate and always invokes the compiler, and an explicit force flag
on the `app` task serves humans.

**Invariant scope:** during this iteration the check applies to the **root**
Makefile only. The mobile Makefile still compiles the client for iOS/Android
(0018 makes it use the store compiler); it joins the invariant at the mobile
follow-on.

## Acceptance criteria

- [x] The root Makefile contains **no `nim` invocation** — asserted by a grep
      check over `nim c`, `nim e` and the removed env-script wrapper. The check
      is recorded so it can be re-run.
- [x] `nim app status.nims` compiles the client directly; the produced binary
      matches the pre-migration binary to the established parity floor
      (identical text/const/symbols; `LC_UUID`, OSO stab mtimes and signature
      excepted). *Exceeded: 0 differing bytes.*
- [x] `nim tests status.nims` runs the Nim suite green, with no make.
- [x] The Windows launcher builds through a driver task (compile verified as
      far as a non-Windows host allows; recorded as ported, unverified).
- [ ] `make pkg-macos` produces a signed dmg from the driver-built binary.
      **Not verifiable on this machine** — `nix` (which supplies `dmgbuild`) is
      absent and no signing identity exists. What IS verified: the dmg target's
      only client-producing step is the driver, and the `.app` it assembles
      carries the driver-built binary byte-for-byte in `__TEXT,__text`.
- [x] `run-*` make targets no longer exist; `nim run status.nims` launches the
      app. *Scope: the app-launch `run` targets. `run-storybook*` /
      `run-statusq-*` launch other products, contain no `nim` invocation, and
      stay — see the scope note in the record.*
- [x] Windows flag branches exist in `config.nims` and nowhere else; the
      Makefile has no `NIM_PARAMS`. *(Ported, unverified: no Windows host.)*
- [x] Forcing a full client rebuild works via the `app` task's force flag, and
      a developed Vendor's source change always reaches the binary.
- [x] `nim app status.nims` and `nimble build` are both green.

## Blocked by

- 0016 (`buildArtifacts` must own the artifacts before the driver can own the
  compile that consumes them; `stale()` lands there and is reused here).

---

## Verification record — 2026-07-10

Machine: macOS arm64 (M-series), Qt 6.11.0 macOS kit (Generated pkg-config
mode). `~/.nimble/bin/nim` = **2.2.4**, the manifest pin (the NBS 2.2.10 was NOT
put on PATH). Store = default `~/.nimble`.

    export QMAKE=~/Qt/6.11.0/macos/bin/qmake USE_SYSTEM_NIM=1

**Environment caveat that affects every wall-clock number below.** Six orphaned
`qmlprofiler` processes (ppid 1, started 22 h–2 days before this session, ~65 %
CPU each) plus 201 `WebKit.WebContent` processes were saturating the machine:
`load average 109`. Absolute timings are therefore not comparable to 0016's;
where timing matters an **A/B on the same loaded tree** is reported instead, and
CPU time (load-insensitive) alongside wall time.

### 0. Ordering: the parity comparison ran BEFORE the make targets were deleted

`make nim_status_client` still existed and parsed at that point. Both binaries
were produced at the same HEAD (`13545e159d`) against the same `nimcache`, i.e.
the "make-vs-make relink with unchanged `.o` files" scenario 0013 documented.

*First attempt compared a driver binary left over from commit `eee60af62d`, and
`__TEXT,__const` differed. It decoded to the `DESKTOP_VERSION` /`GIT_COMMIT`
`{.strdefine.}` strings (`2.39.0-dev-170-geee60af62d` vs `…-171-g13545e159d`) —
a stale artifact, not a flag asymmetry. Neither make's `NIM_SOURCES` nor the
driver's source key watches git HEAD; recorded as follow-up 3.*

### 1. The root Makefile contains no `nim` invocation

Re-runnable, and it is a committed script rather than a one-liner in a doc:

    $ scripts/check-no-nim-compiles.sh
    ok: a Nim compile (`nim c`/`nim compile`) — absent
    ok: a nimscript eval (`nim e`) — absent
    ok: the NBS env-script wrapper — absent
    ok: NIM_PARAMS — absent
    check-no-nim-compiles: <repo>/Makefile is clean

It strips `#` comments first (the Makefile's own comments name the forbidden
tokens) and it passes a driver dispatch (`nim app status.nims`) deliberately —
that is how a packaging recipe asks for a binary. Negative control, on a copy
with a re-introduced compile appended:

    $ ./scripts/check-no-nim-compiles.sh /tmp/0017/mk-probe
    FAIL: /tmp/0017/mk-probe still carries a Nim compile (`nim c`/`nim compile`):
    1173:	$(ENV_SCRIPT) nim compile src/x.nim
    FAIL: … still carries the NBS env-script wrapper:  1173:…
    FAIL: … still carries NIM_PARAMS:                  1174:	NIM_PARAMS += -d:x
    rc=1

**Amended 2026-07-10 (review round).** As first written the script had three
defects: `grep -n` numbered the *stripped* stream (whose blank lines had been
filtered out), so every reported line number was wrong; `nim compile` — the long
form of `nim c` — was unchecked; and the comment strip `s/[^\\]#.*$//` ate the
character before an unescaped `#` (`A=x#y` → `A=`). All three fixed; the numbers
above are the probe file's real ones (`grep -n` agrees).

`ifeq ($(NIM_PARAMS),)` — the NBS-was-included probe at the top of the Makefile
— became `ifeq ($(wildcard $(BUILD_SYSTEM_DIR)/makefiles/variables.mk),)`, which
asks the same question without naming the variable. Scope is the ROOT Makefile;
`mobile/Makefile` still compiles the client and joins at the mobile follow-on.

### 2. Binary parity with the pre-migration (make-built) client

Method: 0013's. `nim app status.nims` relinked the client from the `.o` files
`make nim_status_client` had just produced (`grep -c '^CC:' → 0`), so the two
binaries differ only by relink-time nondeterminism.

    driver-client2 = nim app status.nims      make-client = make nim_status_client
                                              (run with STATUS_BUILD_ENV_ASSERT=1)

    == section content hashes (otool -s, header lines stripped) ==
    __TEXT,__text              lines= 687632 IDENTICAL
    __TEXT,__const            lines= 103047 IDENTICAL
    __TEXT,__cstring          lines=  19577 IDENTICAL
    __TEXT,__unwind_info      lines=      0 IDENTICAL
    __TEXT,__gcc_except_tab   lines=   8413 IDENTICAL
    __DATA,__data             lines=  11048 IDENTICAL
    __DATA_CONST,__const      lines=  56397 IDENTICAL
    __DATA,__bss              lines=      1 IDENTICAL
    __DATA_CONST,__got        lines=   2755 IDENTICAL
    __TEXT,__stubs            lines=   2552 IDENTICAL

    byte diff count:  0
    nm    md5  e17529d38a0c3803edafb487700378d6  (both)
    nm -a md5  07206c8be94fd6ca90e65f501ba43ef8  (both)   # incl. OSO stabs
    UUID: E3C77A06-353F-3D85-81DF-5DB982865BD1  (both)
    otool -l (uuid masked): IDENTICAL

**Zero differing bytes** — the floor is not merely met, the documented residue
(LC_UUID, OSO stab mtimes, signature) is absent too, because the `.o` set is
identical and both front doors now use the same compiler (2.2.4; the 0015-era
2.2.10/2.2.4 divergence died with the "don't prepend the NBS nim" rule).

The make run carried `STATUS_BUILD_ENV_ASSERT=1`, so every value `config.nims`
derives was hard-compared against make's export. The driver exports none of
`QT_LIBDIR` / `STATUSGO_LIBDIR` / … and still linked byte-identically.

### 3. `nim tests status.nims` runs the Nim suite green, with no make

    $ nim tests status.nims
    …
    Nim tests: 8 suite(s) green
    rc=0, 15:26.15   ([OK] lines: 59, FAILED: 0)

    $ nim tests status.nims utils_test      # single-suite selector
    rc=0, 1:04

Suites: activity, chat_section_model, collectibles_model,
collectibles_types_conversions, member_model, message_model, utils,
wallet_connect.

**The make path this replaces did not work on macOS.** Reproduced before
deleting it:

    $ make nim-test-run/test/nim/utils_test.nim
    dyld[75117]: Library not loaded: @rpath/libsds.dylib
      Referenced from: …/bin/utils_test
    make: *** [nim-test-run/test/nim/utils_test.nim] Error 1

make's recipe exported `LD_LIBRARY_PATH` (a no-op on macOS) and `config.nims`
bakes an rpath only for env vars that are *set*; `NIMSDS_LIBDIR` is not among
the ones the non-client arm reads. The driver task therefore separates compile
from run and gives the run the same library path `launchHostApp` gives the app
(`DYLD_LIBRARY_PATH` on macOS, `LD_LIBRARY_PATH` elsewhere). That is what the
brief meant by "the driver `tests` task must own the library-path environment".

Flag set = make's, minus `-d:DESKTOP_VERSION` / `-d:GIT_COMMIT` /
`-d:STATUSGO_VERSION`: they are `{.strdefine.}`s with defaults
(`src/constants.nim`) that no test asserts on, and re-deriving them would be a
second copy of `config.nims`' derivation. `--mm:refc`, `-d:release -d:lto`, the
frameworks, DOtherSide's static lib, `QT_SEAQT_EXTRA_LIBS` (via `pkg-config`
under prl-to-pc's cached env), `-lstatus`, `-lsds` are all preserved.

`ci/Jenkinsfile.tests-nim` now runs `nim tests status.nims` instead of
`make tests-nim-linux V=1` (a direct consequence of the deletion, not new work).

### 4. The Windows launcher is a driver task

    $ nim windowsLauncher status.nims --compileOnly
    Building: nim_windows_launcher
    rc=0        # 19 C sources emitted into nimcache/windows-launcher

    $ nim windowsLauncher status.nims          # the full cross link
    rc=1
    …/syncio.nim.c:115:10: fatal error: 'io.h' file not found
    …/system.nim.c:116:10: fatal error: 'windows.h' file not found

**Ported, unverified.** `--os:windows --cpu:amd64` reaches the C backend and
emits Windows sources — the Nim half is exercised. The link needs an
`x86_64-w64-mingw32` toolchain this host does not carry, which is exactly "as
far as a non-Windows host allows". `make pkg-windows` calls
`nim windowsLauncher status.nims`.

The launcher is built with the DEFAULT cc (mingw/gcc). That is why the client's
clang/MSVC-ABI flags live inside `config.nims`' `isDesktopClient` block: the
launcher must not inherit them.

*Review round: the task now parses `--compileOnly` and passes the VALUE to
`buildWindowsLauncher(compileOnly)`, instead of the builder re-reading
`taskArgv()` — the shape `runNimTests(only)` already had.*

    $ nim windowsLauncher status.nims --compileOnly   rc=0 (18 windows C sources)
    $ nim windowsLauncher status.nims --bogus         rejected

### 5. `make pkg-macos` — NOT verifiable here; what was verified

    $ command -v nix dmgbuild   → (nothing)
    $ echo $MACOS_CODESIGN_IDENT → <unset>

    $ make pkg-macos
    …
    Building: dmg
    bash: line 1: nix: command not found
    make: *** [pkg/Status.dmg] Error 127

The dmg step is `nix shell .#dmgbuild -c dmgbuild …`; without nix there is no
dmg, and without an identity there is no signature. **Recorded as
not-verifiable-on-this-machine, checkbox left unticked.**

Everything up to it is verified:

    $ make -n pkg-macos | grep -E 'nim |cp bin'
    nim app status.nims                                     ← the ONLY client-producing step
    cp bin/nim_status_client tmp/macos/dist/Status.app/Contents/MacOS/

**Amended 2026-07-10 (review round): that dispatch could be skipped entirely.**
`$(STATUS_CLIENT_DMG)` and `$(STATUS_CLIENT_FLATPAK)` were left with **zero**
prerequisites when the `.PHONY nim_status_client` prereq died, and the AppImage's
are all plain files — so make considered an existing `pkg/Status.dmg` up to date
and never ran the driver (`pkg:`'s old `rm $(NIM_STATUS_CLIENT)` is gone too):

    # HEAD's Makefile, pkg/Status.dmg present:
    $ make -f /tmp/0017/mk-old -n pkg-macos
    echo "Cleaning libsds_d from cache..."      ← and nothing else
    rm -rf ~/.cache/nim/libsds_d

    # fixed:
    $ touch pkg/Status.dmg && make -n pkg-macos
    nim app status.nims

All four packaging artifacts (AppImage, flatpak, dmg, exe) now take a `FORCE`
phony prerequisite — defined *after* `all:` so it cannot become the default goal
(`make -n` still resolves to `all:` → `nim app status.nims`). They stay real
files for their own dependents; the driver's key file decides the relink.

    client key after the run:   RESOURCES_LAYOUT=-d:production
    (the -d:production flip is part of clientKey(), so it relinks BY CONSTRUCTION;
     make's old `rm $(NIM_STATUS_CLIENT)` dance in the `pkg` target is deleted)

    macdeployqt bundled 86 frameworks; the bundle's executable is the driver's:
      __TEXT,__text md5   bin/nim_status_client              18eee625a145beb2a48ec0733c72b2d5
      __TEXT,__text md5   …/Status.app/…/nim_status_client   18eee625a145beb2a48ec0733c72b2d5
    (sizes differ — 30.3 MB vs 16.8 MB — because macdeployqt/codesign strip
     __LINKEDIT: 15.9 MB → 2.5 MB. The code is bit-for-bit the same.)

`pkg-linux` (AppImage) and `pkg-windows` were re-pointed the same way and are
statically reviewed only, per the PRD.

### 6. `run-*` make targets no longer exist

    $ for t in run run-macos run-linux run-windows nim_status_client \
               nim_windows_launcher tests-nim-linux; do make -n $t; done
    make: *** No rule to make target `run'.  Stop.
    make: *** No rule to make target `run-macos'.  Stop.
    make: *** No rule to make target `run-linux'.  Stop.
    make: *** No rule to make target `run-windows'.  Stop.
    make: *** No rule to make target `nim_status_client'.  Stop.
    make: *** No rule to make target `nim_windows_launcher'.  Stop.
    make: *** No rule to make target `tests-nim-linux'.  Stop.

    $ make -n run-storybook; make -n run-statusq-tests; make -n run-statusq-sanity-checker
    rc=0  rc=0  rc=0            # these survive

**Scope decision, matching the orchestrator's reading of the criterion.** The
PRD's rationale is "two ways to run THE APP". `run-storybook`,
`run-storybook-tests`, `run-storybook-pages-validator`, `run-statusq-tests` and
`run-statusq-sanity-checker` launch OTHER products, contain no `nim` invocation
(so the grep invariant is untouched), are invoked by `ci/Jenkinsfile.tests-ui`,
and this iteration replaces none of them. They stay. Deleted: `run`,
`run-linux`, `run-linux-gdb`, `run-macos`, `run-windows`, and `RUN_TARGET`.
`nim run status.nims` is the app's one front door (0016 verified `launchHostApp`;
`run` is unchanged here beyond gaining `--force`).

**Amended 2026-07-10 (review round).** `launchHostApp` had **no Windows arm**,
so deleting `run-windows` deleted the DLL staging it did (Windows has no rpath:
the loader searches the .exe's directory). Ported from `13545e159d:Makefile`
into a `hostOS == "windows"` arm — StatusQ's `bin/<cfg>/*`, `DOtherSide.dll`,
`libstatus.dll`, `status-keycard-qt.dll`, `libsds.dll`, `ucrtbase.dll`,
`vcruntime140{,_1}.dll`, `api-ms-win-crt-*.dll`, then `cd bin && ./nim_status_client.exe`.
**Ported, unverified** (no Windows host), consistent with how the flag branches
were handled. Its `status-dev.rc` icon step is *not* ported — see follow-up 12.

Also deleted with them: `nim_status_client` (+ `$(NIM_STATUS_CLIENT)` rule),
`nim_windows_launcher`, `nim-test-run/%`, `tests-nim-linux`, `.qmake_previous`
+ `update-qmake-previous` + `QMAKE_CHANGED`, `NIM_SOURCES`, `.update.timestamp`
(rule), `REBUILD_NIM`, `NIM_CLIENT_COMPILE`, `NIM_CLIENT_PRECLEAN`,
`NIM_EXTRA_PARAMS`, `NIM_MATH_LIB`, `WIN_SYS_LIBS`, `QT_SEAQT_EXTRA_LIBS`,
`STATUSKEYCARD_QT_LINKNAME`, `STATUSKEYCARD_QT_DYLIB_NAME`, the Windows
import-lib rules, and every `NIM_PARAMS` assignment. `all:` now runs the driver.
`ci/Jenkinsfile.flatpak`'s `make nim_status_client` became `nim app status.nims`.

### 7. Windows flag branches live in `config.nims` and nowhere else

`isDesktopClient` lost its `hostOS != "windows"` guard, and the win32 arms of
`NIM_PARAMS` / `NIM_CLIENT_COMPILE` / `NIM_EXTRA_PARAMS` moved into a
`hostOS == "windows"` branch of the client block: `-d:lto`, `-d:sslVersion=3-x64`,
`--cc:clang` + `--clang.exe`/`--clang.linkerexe` (from `findExe("clang")`), the
`--target=x86_64-pc-windows-msvc -fms-runtime-lib=dll` passC/passL pair,
`delEnv` of `LIB`/`INCLUDE`/`LIBPATH`/`VCINSTALLDIR` (make's `unexport`), the
`DOtherSide.lib` import library, `-lstatus`/`-lStatusQ`/`-lstatus-keycard-qt`/
`-lsds`/`-luser32`, the per-config cmake lib dirs (`lib/Release`), and the
absence of `-lm` and of `QT_SEAQT_EXTRA_LIBS` (neither of which the win32
Makefile branch passed).

`qmlDebug()` / `buildType()` moved into `status_env.nims` so `config.nims` and
the driver derive the SAME cmake flavor for those `lib/<Release|Debug>` paths —
one definition, two consumers.

The `status.lib` / `sds.lib` import libraries (synthesized by
`scripts/gen-import-lib.sh` from the c-shared headers) are now produced by the
driver (`genImportLib`, keyed on the DLL's content), because they exist for the
client link and the driver owns that link.

**Ported, unverified** — no Windows host. Verified only that the file parses and
that the macOS/Linux arms are unaffected (criteria 2, 3, 9).

### 8. The force flag, and a developed Vendor's source change

    $ nim app status.nims                 # bin mtime unchanged  → SKIPPED
    $ nim app status.nims --force         # bin mtime bumped     → REBUILT, rc=0
    $ nim vendors status.nims --force
      status.nims ERROR: 'vendors' does not accept --force (only 'app', 'run'
      and 'buildArtifacts' do — it forces the client compile).
    $ nim app status.nims --nope
      status.nims ERROR: unrecognized arguments for 'app': --nope

`--force` is parsed by `parseTarget()`/`rejectExtras()` — the driver's existing
argument parser — not a second one. `app`/`run` compute
`applyDevelopModeArms() or t.force`.

See "develop round trip" below for the developed-Vendor arm.

### 9. `nim app status.nims` and `nimble build` both green

    $ nim app status.nims   → rc=0
    $ nimble build          → rc=0, 7:07.57   (nimble always recompiles the client)
    $ nim tests status.nims → rc=0

### 10. The portable, content-keyed `stale()` (user adjudication 1)

0016's `stale()` was an mtime scan over the shell's `test -nt` builtin and
returned **unconditionally true on Windows**. The walls doc's prescribed fix is
a content key. The obvious spelling of it is unaffordable:

    # hash(readFile(f)) per input, in the nimscript VM
    inputs: 1762 files / 11.7 MB   →  12.96 s user, 15.8 s wall

against a whole-build no-op budget of ~5 s: the VM's string hash runs one byte
at a time. (This is the brief's pre-identified grill trigger, "the content-key
`stale()` cannot be expressed without shelling out per compile". It is not
blocking: the answer shells out ONCE per gate — the same subprocess count the
mtime scan already spent — not once per compile.)

The digest is produced where the input list is already produced:

    find <spec> -print0 | xargs -0 cksum | sort | cksum      →  "<crc> <bytes>"

    src set (690 files, 3.9 MB)   real 0.20 s
    ui  set (1072 files, 7.7 MB)  real 1.11 s

`sort` makes it readdir-order independent; the output shape is validated
(`gorgeEx` merges stderr) and `set -o pipefail` is requested best-effort so a
broken `find` cannot yield a well-formed digest of a truncated set.

**Amended 2026-07-10 (review round) — two defects in that one shell line.**

1. `set -o pipefail 2>/dev/null; …` **killed the whole scan under dash**
   (`/bin/sh` on Debian/Ubuntu, i.e. the flatpak CI image): `set` is a POSIX
   *special builtin*, so an unknown option to it is a fatal error in a
   non-interactive shell, and the redirect merely hid the message. rc=2, no
   digest — and every gate (nimbleSetupIfStale, buildResources, buildLibsds,
   buildClient) died. The fix probes the option in a **subshell** first:

       $ /bin/dash -c 'cd … && set -o pipefail 2>/dev/null; { find src … } | …'
       rc=2                                                  (no output at all)
       $ /bin/dash -c 'cd … && (set -o pipefail) 2>/dev/null && set -o pipefail; …'
       2310363601 47390     rc=0
       $ /bin/sh -c '…same…'   2310363601 47390   rc=0     # macOS, unchanged
       $ /bin/bash -c '…same…' 2310363601 47390   rc=0     # and pipefail IS set:
       $ /bin/bash -c '… (set -o pipefail) … ; find nosuchdir … | …'  rc=1

2. **The empty-input digest looked valid.** `find <nothing> -print0 | xargs -0
   cksum | sort | cksum` prints `4294967295 0` with rc=0 — well-formed, so an
   artifact whose inputs all disappeared recorded a stable key and read FRESH
   forever (resources.rcc would never regenerate again). The digest's second
   field is the byte count of the `cksum` lines, so `<crc> 0` means "zero files
   hashed" exactly: `contentKey` now **fails loudly** on it, and on an `extra`
   set none of whose paths exist (which used to return an empty key, i.e. the
   "exists ⇒ fresh" gate). Verified by pointing `uiFindCmd()` at an empty
   directory:

       $ nim buildArtifacts status.nims
       status.nims ERROR: the content-key scan matched NO files (digest
       '4294967295 0'):
         cd <repo> && (set -o pipefail) … find empty-probe -type f -print0 …
       Every input of this artifact has disappeared; the tree is broken (or the
       scan's spec is wrong).

   This guard is also what protects the shells that *have* no `pipefail`: there
   a broken `find` still exits 0 with exactly this empty digest (reproduced on
   `/bin/dash`), and only the empty-set check catches it.

The docstring's claim that a vanished `extra` path "changes the digest" is now
true in every case, including the all-vanished one.

**Amended 2026-07-10 (review round 2) — the round-1 fixes above were confirmed
except for two shell-portability holes in the same line.**

R1 (CRITICAL). The `<crc> 0` empty-set guard was **inert on GNU xargs**. GNU
xargs runs its utility ONCE even on empty input unless `--no-run-if-empty`
(`-r`) is given; the round-1 line lacked it. So on Linux a vanished set ran
`cksum </dev/null` → `4294967295 0`, and the outer `cksum` of that one non-empty
line yielded `3871339299 13` — well-formed, bytes≠0, guard bypassed, empty set
FRESH forever. macOS/BSD xargs already skips the utility on empty input, which
is why round 1 (verified only on macOS) missed it. Fix: `xargs -0 -r cksum`
(`-r` is a documented no-op on BSD/macOS — verified accepted on this host).
Evidence — the two arms of GNU xargs, reproduced on macOS by hand:

    # GNU WITHOUT -r (xargs runs cksum on empty stdin):
    $ cksum </dev/null | sort | cksum          → 3871339299 13   (bytes≠0, BYPASSED)
    # GNU WITH -r (pipeline stays empty):
    $ printf '' | sort | cksum                 → 4294967295 0    (bytes=0, guard FIRES)
    # macOS xargs, empty set, both with and without -r:
    $ printf '' | xargs -0 -r cksum | sort | cksum → 4294967295 0 (already skips)

R2 (Important). With a non-empty `extra` list the emitted pipe stage is a brace
group `{ find … -print0; printf … }`, whose exit status is its LAST command's —
`printf`'s — so a **failing `find` was masked** and pipefail never saw it; only
the empty-set shape check could catch a *fully* truncated scan, not a partial
one. Fix: `{ find … -print0 || exit 1; printf … }`. Evidence, bash+pipefail:

    # WITHOUT the fix — find fails, printf survives → truncated digest ACCEPTED:
    $ { find /nonexistent -print0; printf '%s\0' src/constants.nim; } \
        | xargs -0 -r cksum | sort | cksum   → 1362895266 34   rc=0   (silent truncation)
    # WITH the fix — find's failure aborts the stage → pipefail rejects:
    $ { find /nonexistent -print0 || exit 1; printf '%s\0' src/constants.nim; } \
        | xargs -0 -r cksum | sort | cksum   → 4294967295 0    rc=1   (rejected)

Both fixes re-verified through the REAL code path (`uiFindCmd()` pointed at an
empty dir → `nim buildArtifacts status.nims`): the gate fails loudly with the
empty-set error, and the printed command now carries both `-print0 || exit 1`
and `xargs -0 -r cksum`. The C1 dash probe still yields `2310363601 47390`,
rc=0, and is unchanged on `/bin/sh` and `/bin/bash`. The line 409 sketch above
(`xargs -0 cksum`) is superseded by `xargs -0 -r cksum`.

Semantics, verified:

    touch src/nim_status_client.nim ; nim app  →  SKIPPED  (mtime gate rebuilt)
    edit  src/constants.nim         ; nim app  →  Building: nim_status_client
    revert                          ; nim app  →  rebuilt, key back to its old value

    touch ui/main.qml               ; nim app  →  rcc SKIPPED   key 2479389131 75755
    edit  ui/main.qml               ; nim app  →  rcc REBUILT   key  405517859 75757
    revert                          ; nim app  →  rcc REBUILT   key 2479389131 75755

Cost, A/B on the same (heavily loaded) tree, `nim buildArtifacts status.nims`
five times each, switching only the four driver files:

    NEW (content key)  real 13.07 13.02 15.92 17.81 21.44   cpu 13.00 13.20 13.53 13.76 14.08
    OLD (0016 mtime)   real 16.14 18.34 22.12 19.40 17.21   cpu 13.54 13.57 14.23 14.15 13.89

CPU time is load-insensitive: **the content key costs no more than the mtime
scan it replaced** (13.0–14.1 s vs 13.5–14.2 s). The absolute figures are 3×
0016's recorded 4.37–5.57 s because of the machine load documented at the top —
under either engine. Attribution of a single no-op on this machine:
`cmake --build` StatusQ 4.27 s + keycard 1.33 s + DOtherSide 0.80 s + install
0.24 s, prl-to-pc's `tools` `nim e` 1.95 s, the two digests 1.31 s.
**Re-measure the envelope on an idle machine before trusting any absolute
number in this record.**

Consequences, all deliberate:

- The Windows arm is no longer "always stale". It is **ported, unverified**: the
  digest still needs a POSIX shell with `find`/`xargs`/`sort`/`cksum` — so does
  the input enumeration it subsumes, so does every `scripts/*.sh` the build
  runs, and so does the Makefile's own `SHELL := bash`. On Windows that is
  msys2, which the Windows build has always required. What is gone is the `-nt`
  **builtin** dependency, which was the mechanism of the regression.
- `test -nt`'s second granularity is gone; a content key has no granularity.
- A develop/undevelop flip that restores identical sources now correctly reuses
  the binary.
- The walls doc's `applyOverlay` trap is closed: `nimble.paths` is no longer the
  setup stamp (`.status-setup.key` is), so a hand-run `nimble setup` /
  `nim applyOverlay status.nims` can no longer make the next build skip
  resolution.
- **`forceTouch` stopped working, by construction, and was replaced.** The sds
  Vendor's FORCE arm was a `touch` of the derived `nimble.paths`, which a
  content key ignores. `buildLibsds()` now forces on `"sds" in readOverlay()`.
  This is the one behavioural trap the change introduced; it is verified below.
  *(Review round: the dead field, its values and its loop are now DELETED, not
  merely unused — a `@[]`-only field with an ineffective loop is a trap for the
  next reader.)*
- **A second dead `touch` was found in the review round, and it was not
  cosmetic.** `applyDevelopModeArms()` re-invalidated the setup stamp by
  `touch`ing `nimble.overlay` when it noticed that a hand-run `nimble setup` had
  regenerated `nimble.paths` without the overlay. Under a content key that touch
  changes nothing: the next build would find `.status-setup.key` current, skip
  resolution, never apply the overlay — and silently compile a developed vendor
  against its **PIN**. That is ADR 0004's one forbidden failure mode, so the
  "`applyOverlay` trap is closed" bullet above was only half true when written.
  It now `rmFile`s `.status-setup.key`, which is what invalidating a key-file
  stamp means.

Gating audit after the change (0016's criterion 11 still holds — two spellings,
no bare `fileExists`):

| what | gate | key source |
|------|------|-----------|
| cmake configure | `keyStale(.status-cmake.key, <argument list>, witness = CMakeCache.txt)` | configuration |
| `nimble setup` | `stale(.status-setup.key, [nimble.paths], contentKey(lock, manifests, overlay))` | content |
| statusgo scratch tree | `keyStale(.statusgo-origin, <store path>, witness = statusgo.nims)` | configuration |
| statusgo artifacts | `keyStale(.statusgo-artifact-key, <flag set>)` | configuration |
| libsds | `stale(<repo>/.libsds.key, [libsds], contentKey(...))` + force when sds is developed | content |
| libstatus | `stale([libstatus])` — the one-arg overload: exists ⇒ fresh | — |
| resources.rcc | `stale(.status-rcc.key, [resources.rcc], contentKey(uiFindCmd()))` | content |
| windows import libs | `stale(<lib>.key, [lib], contentKey(dll))` | content |
| the client binary | `stale(.status-client.key, [bin], clientKey() & contentKey(src…))` | both, one key file |
| submodules, brew bottles | presence | **bootstrap, not gating** |

### 11. Develop round trip with a `clientRebuild` Vendor (+ the sds force arm)

0016 proved the round trip for a cmake Vendor and for prl-to-pc — neither of
which has `clientRebuild`. This issue's criterion needs a Vendor whose Nim
sources compile INTO the client, so: **nimqml** (`clientRebuild: true`) together
with **sds** (whose FORCE arm was a `touch`, which the content key ignores).

    $ nim develop status.nims nimqml     # cloned to vendor/nimqml-seaqt @ pin
    $ nim develop status.nims sds        # reused the existing clean checkout

**build 1** — re-resolve, overlay applied to both, everything forced:

    Resolving: nimble graph (lock/manifests/overlay changed)
    applyOverlay: nimqml → vendor/nimqml-seaqt (1 path entry)
    applyOverlay: sds → vendor/nim-sds (2 path entries)
    Building: libsds / StatusQ / DOtherSide / status-keycard-qt / nim_status_client
    rc=0, 7:01

**build 2** — *no edit at all*. Both FORCE arms must still fire:

    Building: libsds                 ← the arm that replaced sds' forceTouch
    Building: nim_status_client      ← applyDevelopModeArms() ⇒ buildClient(force)
    client  mtime 1783693726 -> 1783693878     REBUILT
    libsds  mtime 1783693412 -> 1783693412     re-run, artifact unchanged

The libsds *sub-build* ran (its line is printed by the driver's force arm); the
*artifact* did not move because statusgo.nims' sds engine is compare-before-copy
(ADR 0003) — an unchanged rebuild is byte-identical and is not re-copied. That
is the contract, and it is why "did the mtime move?" is the wrong question for
libsds and the right one for the client.

**build 3** — an edit in the developed checkout must reach the compile:

    $ printf '\nstatic: echo "NIMQML-0017-PROBE-REACHED-THE-COMPILE"\n' \
        >> vendor/nimqml-seaqt/src/nimqml.nim
    $ nim app status.nims
    Building: nim_status_client
    NIMQML-0017-PROBE-REACHED-THE-COMPILE      ← printed by the Nim VM, from the checkout

**build 4** — restore, undevelop both, back to the pins:

    $ git -C vendor/nimqml-seaqt checkout -- src/nimqml.nim
    $ nim undevelop status.nims nimqml --force ; nim undevelop status.nims sds --force
    $ nim app status.nims
    Resolving: nimble graph (lock/manifests/overlay changed)
    Building: libsds / … / nim_status_client
    rc=0, 7:10

    nimble.overlay:                       0 entries
    nimble.paths → vendor/nimqml-seaqt:   0
    nimble.paths → vendor/nim-sds:        0
    nimble.paths → pkgs2/nimqml-…:        1
    nim vendors: nimqml [nimble-graph, default] / sds [nimble-graph, default]

Together with criterion 8's `--force` evidence, this closes the criterion:
*"forcing a full client rebuild works via the `app` task's force flag, and a
developed Vendor's source change always reaches the binary."*

### Fix wave — 2026-07-10 (review round)

A two-axis review of `994c7913e5..c942984e66` found three criticals and five
important items. All are applied; each is evidenced in the amended sections
above. Same machine, same environment.

| # | what | where |
|---|------|-------|
| C1 | `contentKey()` died under dash (`set -o pipefail` is a special builtin) | §10 |
| C2 | the empty-input digest `4294967295 0` read as permanently fresh | §10 |
| C3 | packaging targets had lost their only always-stale prerequisite | §5 |
| I1 | Windows `-d:lto` was unconditional (make gated it on the release flavor) | §7 |
| I2 | `launchHostApp` had no Windows arm (the deleted `run-windows` staging) | §6 |
| I3 | `.libsds.key` landed inside `vendor/status-go` in develop mode | follow-up 5 |
| I4 | env replay + seaqt link libs were byte-copies of config.nims | §7 |
| I5 | `dotherSideLibDir`/`keycardBuildDir` had already drifted from config.nims | §7 |
| M1–M8 | see the fix-wave brief; M9/M10 recorded as follow-ups 10/11 | — |

Plus one defect the review did not name, found while deleting `forceTouch`: the
develop-mode **overlay re-invalidation was the same dead `touch`**, which could
silently build a developed vendor against its pin (§10, second amended bullet).

Regression set re-run after the wave:

    $ scripts/check-no-nim-compiles.sh                       rc=0, all four ok
    $ nim app status.nims                                    rc=0, 84.9 s (relink:
        config.nims + status_env.nims are inputs of clientSourcesKey)
    $ nim app status.nims                                    rc=0, 11.6 s  no-op
    $ nim app status.nims                                    rc=0, 11.7 s  no-op
        (no client / rcc / libsds rebuild; the three cmake `--build` no-ops are
         the documented envelope. Machine no longer saturated: cf. §10's 13–21 s)
    $ nim tests status.nims utils_test                       rc=0, 62.3 s, 9 [OK]
    $ nim windowsLauncher status.nims --compileOnly          rc=0, 18 C sources
    $ nim buildArtifacts status.nims --force                 rejected (M2)
    $ touch pkg/Status.dmg && make -n pkg-macos              nim app status.nims
    $ /bin/dash -c '<the emitted contentKey command>'        digest, rc=0

### Fix wave — round 2 (2026-07-10, later)

The round-1 wave's re-review confirmed everything except two shell-portability
holes in `contentKey()`'s one command line, plus three record-only items.

| # | what | disposition | where |
|---|------|-------------|-------|
| R1 | `<crc> 0` empty-set guard inert on GNU xargs (`-r` was missing → runs `cksum` once on empty input) | fixed: `xargs -0 -r cksum` | §10 |
| R2 | failing `find` masked by trailing `printf` in the brace group → truncated digest accepted | fixed: `find … -print0 \|\| exit 1` | §10 |
| R3 | FORCE phony prereq → chained make invocations re-deploy twice (dev-only) | recorded (accept, no re-engineer) | follow-up 15 |
| R4 | Windows client compile is a hard gap — `status.o` has no producer | reclassified | follow-up 12 |
| R5 | a failed `cd` still runs the pipeline in the wrong cwd (pre-existing) | recorded | follow-up 16 |

Both code fixes are in `status_artifacts.nims`'s `contentKey()` (the emit line
and the pipeline line); the docstring was amended to match. Regression set
re-run after round 2 (same machine; the six orphaned `qmlprofiler` processes of
§10 are gone, so the no-op envelope is back near the round-1 numbers):

    $ scripts/check-no-nim-compiles.sh                       rc=0, all four ok
    $ <empty-set through real path: uiFindCmd → empty dir>   loud empty-set error,
        emitted cmd carries `-print0 || exit 1` and `xargs -0 -r cksum`
    $ nim app status.nims                                    rc=0, 25.4 s (relink)
    $ nim app status.nims                                    rc=0, no-op (client/rcc
        SKIPPED; only the three cmake `--build` no-ops)
    $ nim tests status.nims utils_test                       rc=0, 66.0 s, 9 [OK]
    $ /bin/dash -c '<emitted contentKey cmd, src set>'       2310363601 47390, rc=0
    $ /bin/sh   -c '<same>'                                  2310363601 47390, rc=0
    $ /bin/bash -c '<same>'                                  2310363601 47390, rc=0
    # R2 demonstrated on macOS bash+pipefail (find /nonexistent + printf):
    #   without || exit 1 → 1362895266 34, rc=0  (truncated set silently accepted)
    #   with    || exit 1 → 4294967295 0, rc=1   (rejected)

### Not verified
- **`make pkg-macos`'s dmg + signature** (criterion 5): no `nix`, no identity.
- **The fix wave's Windows arms**: `launchHostApp`'s staging (I2) and the `-d:lto`
  guard (I1) are ported, unverified — as is `contentKey` under msys2.
- **Windows**, everywhere: the client flag branches, the launcher link, the
  import libraries, `contentKey` under msys2. Ported, unverified.
- **Linux**: the AppImage/flatpak re-point and `run`'s `LD_LIBRARY_PATH` arm are
  code-review only; no Linux host.
- **Absolute no-op timing**: the machine was saturated by processes this session
  did not start (see the caveat above). The A/B is sound; the absolute is not.
- **`ci/Jenkinsfile.tests-nim` / `ci/Jenkinsfile.flatpak`**: edited because this
  issue deleted the targets they invoked. Jenkins cannot run here (0019 owns CI).

### Follow-ups recorded (not implemented — no scope creep)

1. **The client is not rebuilt when git HEAD moves.** `DESKTOP_VERSION` and
   `GIT_COMMIT` are `{.strdefine.}`d into the binary from `git describe` /
   `git log`, but neither make's `NIM_SOURCES` nor the driver's `contentKey`
   watches `.git`. Pre-existing; it cost this issue a confusing first parity
   run. Fix shape: fold `gitOut("describe --tags")` + the short commit into
   `clientKey()`.
2. **`prepareQtPkgconfig()` runs prl-to-pc's `tools` on every build** (a `nim e`,
   1.95 s of the no-op). The tool build is itself key-gated inside prl-to-pc;
   the driver could skip the dispatch entirely on a warm key.
3. **The no-op is now dominated by `cmake --build` no-ops** (6.6 s of ~13 s CPU,
   StatusQ alone 4.3 s, mostly automoc). 0016's follow-up 2 (`-G Ninja`) would
   help here too.
4. **`REBUILD_UI=true` has no driver equivalent.** It existed to force `rcc`
   when a non-tracked input (e.g. `ui/shared/img/*.svg`) changed. The content
   key still does not watch those files. Either widen `uiFindCmd()` to the set
   `ui/generate-rcc.go` actually embeds, or add `--force` to a `resources` task.
5. **`.status-setup.key`, `.status-rcc.key`, `.libsds.key`** are new gitignored
   key files. A tree built by an older commit has none; the first build after
   this lands re-runs `nimble setup`, `rcc` and `libsds` once. Expected, cheap.
   *(Review round: only two of the three were actually gitignored, and
   `.libsds.key` was written under `statusgoBuildRoot()` — the vendor/status-go
   CHECKOUT in develop mode, leaving the submodule permanently dirty. It now
   lives at the repo root beside the others, and `.gitignore` covers it. Fixed,
   not a follow-up.)*
6. **`make all` now shells to the driver.** It is the last root-Makefile target
   that builds the app; 0018 may delete it outright rather than keep a shim.
7. **`nim run status.nims` forwards no application arguments.** `make run
   ARGS="-d=./dir"` did. `launchHostApp(args)` already takes them; `run` passes
   `""` and `rejectExtras` would refuse them. BUILDING.md now tells the reader
   to invoke the built binary directly. A `--` passthrough in `parseTarget()`
   would restore the front door.
8. **`nim tests status.nims` costs ~15 min** because each test file gets its own
   `nimcache/release/<name>` and re-compiles the whole app dependency tree with
   `-d:release -d:lto` (make's flag set, kept for fidelity). Dropping `-d:lto`
   from the test compile is a free win if CI cares.

### Follow-ups added by the 2026-07-10 review round

9. **`--skipParentCfg:on` must NOT be added to the driver's three `nim c`
   recipes.** The orchestrator queued it (to stop a nested worktree from
   inheriting an enclosing checkout's `config.nims`); it was refuted
   empirically on nim 2.2.4. The client's project file is
   `src/nim_status_client.nim`, so the **repo-root `config.nims` is itself
   reached by the parent-dir walk** — the flag would strip the client's entire
   flag set. The recipes are correct verbatim; the nested-worktree leak stays
   covered by config.nims' existing fail-fast guard. (Recorded so the next agent
   does not re-propose it.)
10. **Both edited Jenkinsfiles now invoke a bare `nim`** (`Jenkinsfile.tests-nim`
    runs `nim tests status.nims`, `Jenkinsfile.flatpak` runs `nim app
    status.nims`) and nothing in their Deps stage provides one — the NBS nim
    they used to build is what 0018 deletes. **0019 (CI) owns this**; noted here
    because 0017 created the dependency.
11. **`make update` no longer forces a client relink.** It used to bump
    `.update.timestamp`, which was a prerequisite of the client rule; the rule
    and the stamp both died here. `nim app status.nims --force` recovers it. Fix
    shape: fold the vendored-dependency revision set into `clientKey()`.
12. **The Windows CLIENT COMPILE is a known hard gap — `status.o` has no
    producer.** *(Reclassified 2026-07-10, review round 2: this is not an icon
    cosmetic, it blocks the Windows client link.)* `src/nim_status_client.nim`
    contains `when defined(windows): {.link: "../status.o".}`, so the client
    link REQUIRES `status.o`. That object was built by make's
    `compile_windows_resources` rule (from `status-dev.rc` for `run-windows`,
    `status.rc` for packaging, via windres) — and that rule died with the
    deleted make targets. **No driver step now produces `status.o`**, so a real
    Windows client build would fail to link (missing `status.o`), not merely
    ship the wrong icon. The ported Windows arms cover DLL staging and launch,
    not this resource compile. Fix shape: a `windowsResources(rc)` driver step
    that runs windres before `buildClient` on Windows and feeds the `{.link.}`;
    `make pkg-windows` supplies `status.rc`. This belongs to the Windows push;
    unverifiable here (no Windows host) either way.
13. **The macOS test-compile flag block is the third copy** of the
    frameworks / `-headerpad_max_install_names` / `-F$QT_LIBDIR` / `-d:lto`
    list (config.nims' client arm, config.nims' non-client arm, `runNimTests`).
    Not extracted: config.nims emits them through `switch()` while the driver
    builds a command line, so the shared thing would be a list of strings that
    each consumer re-spells anyway. The env replay and the seaqt link libs —
    which *were* byte-identical — were hoisted into `status_env.nims` instead.
14. **`buildHostArtifacts()` no longer takes `force`** and `buildArtifacts`
    rejects `--force`: nothing in that task compiles the client, which is the
    only thing `--force` ever forced. `rejectExtras`' error text follows.

### Follow-ups added by the 2026-07-10 review round 2

15. **The FORCE phony prereq makes chained make invocations re-deploy twice**
    (dev-only; decision: ACCEPT + RECORD, do NOT re-engineer). C3's fix gave the
    four packaging artifacts a `FORCE` phony prerequisite so an existing
    `pkg/Status.*` can no longer read "up to date" and skip the driver. Because
    a phony prereq is always out of date, the artifact recipe's own
    `linuxdeployqt`/`appimagetool`/`macdeployqt` step re-runs on every make
    invocation — so `make pkg-linux && make tgz-linux` re-deploys the AppImage
    twice, since the first target's mtime bump does not satisfy the second. CI
    is unaffected: it calls the terminal packaging target in a single invocation.
    The rejected alternative — interposing a phony *client-binary* prereq instead
    — has the same disease (it would mark every dependent perpetually stale), so
    the FORCE-on-the-artifact shape stays. Cost is a dev-only double re-deploy,
    not a correctness bug.
16. **A failed `cd` still runs the contentKey pipeline in the wrong cwd**
    (pre-existing shape, unchanged by this wave). `contentKey`'s command is
    `cd <repo> && (set -o pipefail) … ; { find … } | …`. The `&&` guards only the
    pipefail probe; the `find | xargs | cksum` pipeline is separated by `;`, so a
    failing `cd` (repo path deleted mid-build, etc.) would still run `find`
    against whatever the process's cwd happens to be and could produce a
    plausible digest of the wrong tree. Not observed in practice (the driver
    always runs from a valid `thisDir()`), and unchanged by R1/R2 — recorded so a
    future hardening pass can chain the pipeline behind the `cd` with `&&`.
