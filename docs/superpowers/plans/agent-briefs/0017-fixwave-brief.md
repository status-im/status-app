# Fix-wave brief — issue 0017 review round (2026-07-10)

Two-axis review of commits `994c7913e5..c942984e66` returned the findings
below. You are a fresh implementer applying this one fix wave. Read
`docs/superpowers/plans/agent-briefs/SHARED-i3.md` for ground rules (commits:
`git -c commit.gpgsign=false commit`, messages `fix(nimble/0017): …`, stage
only your own files, never --amend / add -A; DECISION NEEDED protocol if
blocked). Environment: `export QMAKE=~/Qt/6.11.0/macos/bin/qmake
USE_SYSTEM_NIM=1`; do NOT prepend the NBS nim (PATH nim is the 2.2.4 pin).
You HOLD the build lock. Context files: `status_artifacts.nims`,
`status.nims`, `status_env.nims`, `config.nims`, `Makefile`,
`scripts/check-no-nim-compiles.sh`, and issue
`docs/superpowers/issues/0017-driver-owns-nim-compiles.md` (its Verification
record describes what the code claims; keep it truthful as you change code).

## RETRACTED — do NOT do this

The orchestrator had queued adding `--skipParentCfg:on` to the three driver
`nim c` recipes. The spec reviewer refuted it empirically on nim 2.2.4: the
project file is `src/nim_status_client.nim`, so the REPO-ROOT `config.nims`
is itself reached by the parent-dir walk — the flag would strip the client's
entire flag set. The recipes are correct verbatim. The nested-worktree
parent-checkout leak stays covered by the existing fail-fast guard. Do not
touch this; a note in the issue's follow-ups recording the refutation is
welcome.

## Critical

C1. **`contentKey()` dies under dash `/bin/sh`** (Debian/Ubuntu = Linux +
    flatpak CI). `set -o pipefail` is a fatal error in dash's non-interactive
    mode (POSIX special builtin), `2>/dev/null` hides the message → rc=2, no
    digest → every gate fails: nimbleSetupIfStale, buildResources,
    buildLibsds, buildClient. Fix: probe in a subshell —
    `(set -o pipefail) 2>/dev/null && set -o pipefail;` — before the
    pipeline (or dispatch the pipeline via bash explicitly, but the probe is
    smaller). VERIFY with `/bin/dash -c '<the emitted command>'` on this
    machine (macOS ships /bin/dash): digest produced, rc=0; and the existing
    macOS behavior unchanged.

C2. **Empty-input digest looks valid**: `find <nothing> -print0 | xargs -0
    cksum | sort | cksum` → `4294967295 0`, rc=0 — well-formed, so an
    artifact whose inputs all disappear is treated as permanently fresh
    (e.g. resources.rcc never rebuilds again). Treat a `<crc> 0` digest
    (zero bytes hashed / empty set) as a failure or as always-stale; fix the
    docstring's "its disappearance changes the digest" claim to be true.
    VERIFY: point contentKey at an empty-match spec in a scratch dir →
    gate reports stale/fails loudly, not fresh.

C3. **Packaging targets lost their only always-stale prerequisite.**
    `$(STATUS_CLIENT_FLATPAK):` (Makefile ~945) and `$(STATUS_CLIENT_DMG):`
    (~966) now have zero prerequisites; with `pkg/Status.dmg` present,
    `make pkg-macos` is "up to date" and never runs the driver (the old
    `.PHONY nim_status_client` prereq and `pkg:`'s `rm $(NIM_STATUS_CLIENT)`
    are both gone). Same exposure for the AppImage's plain-file prereqs.
    Fix: make the artifact targets depend on a `.PHONY` force prereq (or
    declare them `.PHONY` — pick the smallest change consistent with the
    Makefile's style). VERIFY: `touch pkg/Status.dmg; make -n pkg-macos`
    shows the driver dispatch, not "up to date".

## Important

I1. **Windows `-d:lto` unconditional** (`config.nims` ~400): make's win32 arm
    gave `-d:release -d:lto` only when `INCLUDE_DEBUG_SYMBOLS != true`
    (else `-d:debug`, NO lto). Guard lto with the same release check —
    port fidelity, still recorded ported/unverified.

I2. **`launchHostApp` has no Windows arm** while criterion 6 deleted
    `run-windows` (which staged DOtherSide.dll/libstatus.dll/libsds.dll/
    ucrtbase/vcruntime). Port the staging/launch into a
    `hostOS == "windows"` arm translated from the deleted recipe (git show
    `13545e159d:Makefile` has it), mark ported/unverified in the issue
    record — consistent with how the flag branches were handled.

I3. **`.libsds.key` lands inside `vendor/status-go` when statusgo is
    developed** (buildLibsds writes `statusgoBuildRoot()/.libsds.key`;
    pinned mode = ignored scratch, develop mode = the submodule → permanently
    dirty). Relocate the key file to the repo root (like the other
    `.status-*.key` files) or gitignore it everywhere it can land; also add
    `.libsds.key` to `.gitignore` (record's follow-up 5 claimed the new key
    files are gitignored — only two of three were).

I4. **Shared-definition duplication (rule 3)**: `exportQtPkgConfigEnv`
    (status_artifacts.nims ~722) is a byte-copy of config.nims' env-replay
    case block, and `qtSeaqtExtraLibs` duplicates config.nims' pkg-config
    gorgeEx + error text. Hoist ONE definition into `status_env.nims` (the
    qmlDebug()/buildType() move in this diff is the pattern) and make both
    consumers call it.

I5. **Self-declared divergence already real**: `dotherSideLibDir()` /
    `keycardBuildDir()` comments say "keep in sync with config.nims" and
    they already differ — config.nims appends the per-config `winCfg`
    (`lib/Release|Debug`), the driver copies don't. Hoist to
    `status_env.nims` (one definition) rather than re-syncing comments.

## Minor (apply if trivial+safe, else record as issue follow-ups)

M1. `stale("", [out])` magic-sentinel third spelling — give the degenerate
    form a proper overload or named constant; header updated.
M2. `buildArtifacts` task: `allowForce = true` then `discard t.force` —
    wire it (`buildHostArtifacts(t.force)`) or reject `--force` there and
    fix rejectExtras' error text; `buildHostArtifacts`'s unused `force`
    param should end up either used or gone.
M3. `check-no-nim-compiles.sh`: grep -n numbers index the stripped stream,
    not the file; `nim compile` long form unchecked; the `s/[^\\]#.*$//`
    comment-strip eats the character before `#`.
M4. Dead `NIM_STATUS_CLIENT` var (Makefile ~822) — delete or use.
M5. `forceTouch` is dead (sds was its only user; now covered by the overlay
    check): remove the field + its no-op loop, note in the issue.
M6. Stale docs: `mobile/TROUBLESHOOTING.md:31` still says `make run`;
    BUILDING.md "Get more log output" section lost its content.
M7. `runNimTests` third copy of the macOS frameworks/-headerpad/-d:lto flag
    block; `tests` task re-implements buildHostArtifacts' opening sequence
    (and omits buildWindowsImportLibs — fine on mac, wrong on Windows).
    Extract the shared list if cheap; otherwise record.
M8. `buildWindowsLauncher()` re-reads `taskArgv()` for --compileOnly instead
    of taking the parsed value like runNimTests(only) — align.
M9. Record for 0019 (progress.txt note, no code): both edited Jenkinsfiles
    now invoke bare `nim` and nothing in their Deps stage provides one.
M10. Record follow-up: `make update` no longer forces a client relink
    (`.update.timestamp` left the key); `--force` recovers it.

## Completion

Re-run after changes: `scripts/check-no-nim-compiles.sh` (green),
`nim app status.nims` no-op ×3 (envelope sane), `nim tests status.nims
utils_test` (green), the dash probe (C1), the pkg staleness probe (C3).
Update the issue's Verification record + follow-ups where your fixes change
its statements. Commit in slices. Final message: SendMessage TOOL call to
"main" — commits, evidence per C/I item, what you recorded vs applied.
Plain-text final output is NOT delivered; you MUST use the SendMessage tool.

---

# Addendum — re-review round 2 (2026-07-10, later)

The fix wave's re-review confirmed everything EXCEPT:

R1 (CRITICAL). `contentKey()`'s `<crc> 0` empty-set guard is inert on GNU
xargs: it runs the command ONCE on empty input (`-r` is opt-in), so Linux
gets `cksum </dev/null | sort | cksum` = `3871339299 13` — well-formed,
guard bypassed, empty set reads FRESH forever. Fix: `xargs -0 -r cksum`
(`-r` is a documented no-op on BSD/macOS — verified). Keep the `bytes=="0"`
check. VERIFY on macOS: digest unchanged for a real set; empty set still
fails; and simulate the GNU arm (`cksum </dev/null | sort | cksum` shows
what the guard must reject — with `-r` the cksum never runs, output is
empty → not well-formed → fails, which is correct).

R2 (Important). With a non-empty `extra` list the pipeline's first element
is `{ find …; printf …; }` whose status is printf's → pipefail cannot see a
failing find; only the stderr-merge shape check catches it. Fix:
`{ find … || exit 1; printf …; }`. Amend the docstring claim to match.

R3 (Important — decision: ACCEPT + RECORD, do not re-engineer). The FORCE
prereq makes chained invocations (`make pkg-linux && make tgz-linux`)
re-run linuxdeployqt/appimagetool twice because the artifact mtime always
moves. CI calls the terminal target in one invocation and is unaffected.
Record as a follow-up (dev-only double re-deploy); do NOT interpose a phony
client-binary prereq (a phony prereq marks dependents perpetually stale —
same disease).

R4 (Minor, record-only). Reclassify follow-up 12: the client source has
`when defined(windows): {.link:"../status.o".}` and NO driver step builds
status.o (make's windres rule died with the deleted targets) — so the
Windows CLIENT COMPILE is a known hard gap for the Windows push, not an
icon cosmetic. Amend the issue text accordingly.

R5 (Minor, record-only note in the issue): a failed `cd` still runs the
contentKey pipeline in the wrong cwd (pre-existing shape, unchanged).

Completion: re-run the C1 dash probe, the empty-set probe through the real
code path (as the fix wave did), `scripts/check-no-nim-compiles.sh`, one
`nim app status.nims` no-op, `nim tests status.nims utils_test`. Amend the
issue's Verification record where R1/R2 change its statements. Commit
slices; report via the SendMessage TOOL to "team-lead".
