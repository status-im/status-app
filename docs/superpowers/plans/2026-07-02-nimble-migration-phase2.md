# Nimble Migration Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the pure-Nim vendor submodules with nimble-resolved, lock-pinned dependencies (revision-identical to today's submodule SHAs), build the app with the developer's PATH Nim instead of the NBS-vendored compiler, and stage (never commit) the submodule removals.

**Architecture:** `nim_status_client.nimble` declares every needed Nim package as a git-URL + exact-SHA `requires`; `nimble lock` freezes the graph into `nimble.lock`; `nimble setup --localdeps` materializes packages under `nimbledeps/` and generates `nimble.paths`, included from `config.nims` behind `--noNimblePath` (which disables the old `NIMBLE_DIR`/nimble-link mechanism entirely). Kept Nim submodules (nimqml-seaqt, nim-seaqt, prl-to-pc) get explicit `--path` entries. `USE_SYSTEM_NIM=1` becomes the default so NBS stops building/using its vendored compiler. Make remains the orchestrator; nimbus-build-system stays included (retired in Phase 3).

**Tech Stack:** GNU Make, nimble 0.22.3 (PATH), Nim 2.2.4 (PATH, choosenim), git.

**Spec:** `docs/superpowers/specs/2026-07-02-nimble-migration-architecture-design.md`
**Facts base:** Phase 2 fact-finding report (submodule inventory with URL/SHA/package-name/kind — reproduced in the tables below).

## Global Constraints

- **ABSOLUTELY NO `git commit`** — anywhere, including submodules. All work lands as working-tree + staged (index) changes for human review. Task "completion" = report file written, changes present in `git status`.
- Dependency graph must be **revision-identical**: every migrated package pinned at the exact SHA its submodule has today (extract SHAs mechanically from `git submodule status`, never retype).
- Workspace Nim pin stays `requires "nim == 2.2.4"` in `nim_status_client.nimble`; the app builds with PATH nim (2.2.4 via choosenim). If nimble insists on provisioning its own copy despite a matching PATH nim, that is acceptable (it lands in `nimbledeps/`), but record it.
- Keep as submodules (do NOT migrate/remove): `nimbus-build-system`, `status-go`, `DOtherSide`, `SortFilterProxyModel`, `QR-Code-generator`, `status-keycard-qt`, `fcitx5-qt`, `prl-to-pc` (its `qt-pkgconfig.mk` is `include`d by the Makefile at parse time), `nim-seaqt`, `nimqml-seaqt` (actively developed in the seaqt migration), `mobile/vendors/openssl`.
- Version-conflict policy: if nimble's resolver rejects a pinned SHA (transitive floor unsatisfied), STOP and report the exact conflict — do NOT silently bump any dependency; bumping changes behavior and is the human's call (controller may approve a minimal bump and must record it in the ledger and final summary).
- Builds strictly serialized — never two builds at once.
- All paths relative to `/Users/alexjbanca/Repos/status-desktop/.claude/worktrees/nimble-migration`.

## Migration tables (from the fact-finding report)

**Migrate to nimble deps (git URL + current SHA).** `pkg` = nimble package name (registry-independent since we use URLs):

| submodule dir | pkg | URL |
|---|---|---|
| vendor/nim-chronicles | chronicles | https://github.com/status-im/nim-chronicles.git |
| vendor/nim-chronos | chronos | https://github.com/status-im/nim-chronos.git |
| vendor/nim-stew | stew | https://github.com/status-im/nim-stew.git |
| vendor/nim-stint | stint | https://github.com/status-im/nim-stint.git |
| vendor/nim-json-serialization | json_serialization | https://github.com/status-im/nim-json-serialization.git |
| vendor/nim-serialization | serialization | https://github.com/status-im/nim-serialization.git |
| vendor/nim-faststreams | faststreams | https://github.com/status-im/nim-faststreams.git |
| vendor/nim-json-rpc | json_rpc | https://github.com/status-im/nim-json-rpc.git |
| vendor/nim-web3 | web3 | https://github.com/status-im/nim-web3.git |
| vendor/nim-eth | eth | https://github.com/status-im/nim-eth.git |
| vendor/nim-secp256k1 | secp256k1 | https://github.com/status-im/nim-secp256k1.git |
| vendor/nim-bearssl | bearssl | https://github.com/status-im/nim-bearssl.git |
| vendor/nim-metrics | metrics | https://github.com/status-im/nim-metrics.git |
| vendor/nim-http-utils | httputils | https://github.com/status-im/nim-http-utils.git |
| vendor/nim-zlib | zlib | https://github.com/status-im/nim-zlib.git |
| vendor/nim-taskpools | taskpools | https://github.com/status-im/nim-taskpools.git |
| vendor/nim-result | results | https://github.com/arnetheduck/nim-result.git |
| vendor/nim-regex | regex | https://github.com/nitely/nim-regex.git |
| vendor/nim-unicodedb | unicodedb | https://github.com/nitely/nim-unicodedb.git |
| vendor/nim-intops | intops | https://github.com/vacp2p/nim-intops.git |
| vendor/nimcrypto | nimcrypto | https://github.com/cheatfate/nimcrypto.git |
| vendor/uuids | uuids | https://github.com/pragmagic/uuids.git |
| vendor/isaac | isaac | https://github.com/pragmagic/isaac.git |
| vendor/nim-status-go | status_go | https://github.com/status-im/nim-status-go.git |
| vendor/nim-keycard-go | keycard_go | https://github.com/status-im/nim-keycard-go.git |

(Repo-name ≠ package-name traps: nim-result→**results**, nim-http-utils→httputils, hyphens→underscores for json_rpc/json_serialization/status_go/keycard_go.)

**Remove without replacement (zero importers in src/ and across vendor Nim packages — the build is the final proof):**
vendor/chroma, vendor/edn.nim, vendor/semver.nim, vendor/nimage, vendor/nimPNG, vendor/nim-confutils, vendor/nim-websock.

**C sources inside Nim deps:** bearssl / secp256k1 / zlib compile their bundled C via `{.compile.}` pragmas from within the package dir — works identically from `nimbledeps/pkgs2/`; no make recipes needed.

---

### Task 1: Manifest + lock + localdeps resolution

**Files:**
- Modify: `nim_status_client.nimble`
- Create (generated): `nimble.lock` (staged for review), `nimble.paths` + `nimbledeps/` (gitignored)
- Modify: `.gitignore`

**Interfaces:**
- Produces: `nimble.lock` + populated `nimbledeps/pkgs2/` + `nimble.paths`; a `# BEGIN Nimble config`/`# END Nimble config` stanza that `nimble setup` appends to `config.nims` (Task 2 owns verifying/positioning it).

- [x] **Step 1: Generate the requires list mechanically**

```bash
git submodule status | awk '{print $1, $2}'   # SHA + path — the source of truth
```

Rewrite `nim_status_client.nimble`: keep the existing header (version/author/description/license/srcDir/bin/skipExt) and `requires "nim == 2.2.4"`; then one `requires "<URL>#<full-SHA>"` line per row of the migration table above, each with a trailing comment naming the package, e.g.:

```nim
requires "https://github.com/status-im/nim-chronicles.git#<sha-of-vendor/nim-chronicles>"  # chronicles
```

Do NOT add requires for the keep-as-submodule packages (nimqml/seaqt/prl_to_pc) or the remove-without-replacement list.

- [x] **Step 2: Ignore the generated artifacts**

Append to `.gitignore`:

```
/nimbledeps/
/nimble.paths
```

- [x] **Step 3: Resolve + lock + localdeps**

```bash
nimble lock 2>&1 | tail -20        # writes nimble.lock; THIS is where resolver conflicts appear
nimble setup --localdeps 2>&1 | tail -10   # populates nimbledeps/, writes nimble.paths, appends config.nims stanza
```

Expected: `nimble.lock` exists listing every package with `vcsRevision` equal to the submodule SHA; `nimbledeps/pkgs2/` contains ~25 package dirs; `nimble.paths` lists their paths. On resolver conflict: STOP, report the exact package/constraint per the Global Constraints policy.

- [x] **Step 4: Verify revision identity**

```bash
python3 - <<'EOF'
import json, subprocess
lock = json.load(open('nimble.lock'))
subs = {p.split('/')[-1]: sha.lstrip('+-U') for sha, p in
        (l.split()[:2][::-1] for l in subprocess.check_output(['git','submodule','status']).decode().splitlines())}
# manual spot-check output: print package -> vcsRevision for eyeballing against git submodule status
for name, meta in sorted(lock.get('packages', lock).items()):
    if isinstance(meta, dict) and 'vcsRevision' in meta:
        print(f"{name}: {meta['vcsRevision']}")
EOF
git submodule status | awk '{print $2, $1}'
```

Compare: every migrated package's `vcsRevision` must equal its submodule SHA. List any mismatch in the report (transitive deps not in our table may appear in the lock — fine, but record them).

- [x] **Step 5: Stage (no commit)**

```bash
git add nim_status_client.nimble nimble.lock .gitignore
git status --short | head
```

---

### Task 2: Wire the build — config.nims paths + PATH nim + desktop build

**Files:**
- Modify: `config.nims` (stanza position + `--noNimblePath` + kept-submodule paths)
- Modify: `Makefile` (USE_SYSTEM_NIM default, deps hook for `nimble setup`)

**Interfaces:**
- Consumes: `nimble.paths` + stanza from Task 1.
- Produces: a desktop build that resolves all migrated deps from `nimbledeps/` using PATH nim. Mobile (Task 3) relies on the same `config.nims` mechanism.

- [x] **Step 1: config.nims wiring**

Verify/move the nimble-generated stanza to the TOP of `config.nims` (before anything that might import/require dep resolution), shaped like:

```nim
# BEGIN Nimble config (version 2)
--noNimblePath
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# END Nimble config
```

Immediately after it, add explicit paths for the kept Nim submodules (verify each package's source layout first — `create_nimble_link.sh` appended `/src` only when a `src/` dir exists; check `vendor/nimqml-seaqt` and `vendor/nim-seaqt` for their actual import roots and use those):

```nim
# Nim packages that remain git submodules (actively developed / not migrated):
switch("path", thisDir() & "/vendor/nimqml-seaqt/<src-or-root>")
switch("path", thisDir() & "/vendor/nim-seaqt/<src-or-root>")
```

(prl-to-pc is build-tooling only — add a path entry ONLY if the build errors on a missing `prl_to_pc` import; record either way.)

- [x] **Step 2: Makefile — system nim + deps hook**

In the root `Makefile`, before the NBS include (`variables.mk` at ~line 16), set:

```make
# Phase 2: the developer environment owns the Nim toolchain (see BUILDING.md).
# NBS must not build or use its vendored compiler.
USE_SYSTEM_NIM ?= 1
export USE_SYSTEM_NIM
```

Add a stamp-gated setup target and hook it into the build (near the nimsds include block):

```make
# Nimble-managed Nim dependencies (nimble.lock -> nimbledeps/). Stamp keyed on the lock.
NIMBLE_SETUP_STAMP := nimbledeps/.setup-stamp
$(NIMBLE_SETUP_STAMP): nimble.lock
	@command -v nimble >/dev/null 2>&1 || { echo "ERROR: nimble not found on PATH (see BUILDING.md)" >&2; exit 1; }
	nimble setup --localdeps
	touch $@

nimble-deps: $(NIMBLE_SETUP_STAMP)
.PHONY: nimble-deps
```

and add `$(NIMBLE_SETUP_STAMP)` as an order-only prerequisite of `$(NIM_STATUS_CLIENT)` (alongside its existing `| ... rcc deps` list).

- [x] **Step 3: Desktop build proof**

```bash
export QTDIR="$HOME/Qt/6.11.0/macos"; export PATH="$QTDIR/bin:$PATH"; export QMAKE="$QTDIR/bin/qmake"
rm -rf nimcache bin/nim_status_client
make -j16 nim_status_client 2>&1 | tail -15
```

Expected: builds clean. Then PROVE the resolution source and compiler:
- `grep -c "nimbledeps/pkgs2" nimble.paths` > 20.
- Vendored compiler unused: `ls vendor/nimbus-build-system/vendor/Nim/bin/nim` may exist from an old build — verify the build log or `make V=1` shows the PATH nim (`which nim` → `~/.nimble/bin/nim`); simplest: temporarily `mv vendor/nimbus-build-system/vendor/Nim/bin/nim{,.bak}` before the build and restore after — the build must succeed without it.
- Nim-version proof: `nim --version` → 2.2.4.

- [x] **Step 4: Nim tests target**

Locate the nim test target in the Makefile (`tests-nim` or similar; it compiles with `--mm:refc`) and run it. Expected: compiles and runs as before. If a test imports one of the "remove without replacement" packages, STOP and report (the dead-package list would be wrong).

- [x] **Step 5: Stage (no commit)**

```bash
git add config.nims Makefile
```

---

### Task 3: Mobile build proof

**Files:** none beyond what earlier tasks changed (report-only unless a mobile-specific gap emerges; if `mobile/scripts/buildNimStatusClient.sh` needs an edit — e.g. it bypasses `config.nims` via `--skipParentCfg` or similar — make the minimal edit and stage it).

- [x] **Step 1: Android client-library compile** (cheapest full-Nim mobile proof)

Use the Android env (ANDROID_SDK_ROOT/NDK, QTDIR android_arm64_v8a, QT_HOST_PATH, QMAKE, OS=android ARCH=arm64 — see Phase 1 plan's env block) and build the mobile Nim client library step: `make -C mobile nim-status-client OS=android ARCH=arm64 USE_SYSTEM_NIM=1` (the `nim-status-client` target reaches `buildNimStatusClient.sh`; it needs the prebuilt dep libs from a prior full mobile build, which exist from Phase 1 acceptance — if any are missing, fall back to Step 2 directly). Expected: `libnim_status_client.so` produced; imports resolve via the same `config.nims` stanza.

- [x] **Step 2: Full platform sanity (pick ONE, iOS or Android; do not run both)**

`make -j10 V=3 mobile-build USE_SYSTEM_NIM=1` with that platform's env. Expected: full app assembles as in Phase 1 acceptance.

- [x] **Step 3: Report** — status, logs (trimmed), any staged mobile edits.

---

### Task 4: Staged submodule removals + no-vendor-dirs proof

**Files:**
- Modify (staged): `.gitmodules`, index entries for all 32 migrated+dead submodules
- The submodule *directories* are moved aside (not deleted) to prove the build no longer needs them.

- [x] **Step 1: Stage removal of each migrated + dead submodule**

For every submodule in BOTH tables (25 migrated and 7 dead = 32 total; NOT the keep list):

```bash
git config -f .gitmodules --remove-section submodule.vendor/<name>
git rm --cached vendor/<name>
```

Then `git add .gitmodules`. Expected `git status`: `deleted:` (staged) per submodule + modified .gitmodules.

- [x] **Step 2: Move the directories aside (reversible, NOT rm)**

```bash
mkdir -p .phase2-vendor-backup
# all 32 dirs from Step 1 (25 migrated + 7 dead), e.g.:
for d in nim-chronicles nim-chronos nim-stew nim-stint nim-json-serialization \
         nim-serialization nim-faststreams nim-json-rpc nim-web3 nim-eth \
         nim-secp256k1 nim-bearssl nim-metrics nim-http-utils nim-zlib \
         nim-taskpools nim-result nim-regex nim-unicodedb nim-intops \
         nimcrypto uuids isaac nim-status-go nim-keycard-go \
         chroma edn.nim semver.nim nimage nimPNG nim-confutils nim-websock; do
  mv "vendor/$d" .phase2-vendor-backup/
done
rm -rf vendor/.nimble
echo ".phase2-vendor-backup/" >> .gitignore && git add .gitignore
```

- [x] **Step 3: Clean-tree rebuild proof (desktop)**

```bash
rm -rf nimcache bin/nim_status_client
make -j16 nim_status_client 2>&1 | tail -10
```

Expected: builds clean with the vendor dirs gone — the definitive proof that resolution comes from `nimbledeps/`. If ANY import error appears naming a "dead" package, restore that one submodule (mv back + `git restore --staged` + re-add to .gitmodules) and record it.

- [x] **Step 4: Launch smoke** — start the app (make run / direct binary), confirm login screen, no dyld errors, then quit.

- [x] **Step 5: Report** — status, the final `git status --short` snapshot, and an explicit note that `.phase2-vendor-backup/` + `.git/modules` cleanup is a post-commit human step (provide the exact commands in the report, do not run them).

---

### Task 5: Docs + spec sync (uncommitted)

**Files:**
- Modify: `BUILDING.md` (deps section: nimble.lock/nimbledeps flow, `nimble setup --localdeps`, PATH-nim prerequisite now covers the app build too)
- Modify: `docs/superpowers/specs/2026-07-02-nimble-migration-architecture-design.md` (Phase 2 section: mark delivered; record deviations — e.g. dead-package removals, any approved version bumps, kept-submodule path wiring)
- Modify: `docs/superpowers/plans/2026-07-02-nimble-migration-phase2.md` (tick checkboxes)

- [x] Update docs; stage everything; final `git status --short` + `git diff --stat` + `git diff --cached --stat` in the report for the human review handoff.

---

## Known risks / contingencies

- **Resolver conflicts on exact SHAs** (a transitive floor like `eth >= 0.9.0` vs our pinned SHA's declared version): expected failure mode; policy is stop-and-report, human approves any bump. logos-delivery needed code fixes in the same situation.
- **nimble may provision its own nim 2.2.4** into nimbledeps even with a matching PATH nim — acceptable, record which nim actually compiled the app.
- **`nimble setup` appends its stanza to `config.nims`** — Task 2 must ensure it ends up before other logic and that repeated setup runs don't duplicate it.
- **Windows/Linux + CI**: not locally testable; CI needs choosenim/nimble preinstall from this phase on (CI work is out of scope here).
- **`git rm --cached` on initialized submodules** leaves `.git/modules` entries and worktree dirs; cleanup is deliberately deferred to post-commit (commands provided in Task 4's report).
- **seaqt/nimqml import roots** must be verified, not assumed (`/src` vs root).
- **Deliberately out of scope** (record in the Task 5 spec sync): the spec's Phase 2 bullets on C-source make recipes (moot — bearssl/secp256k1/zlib compile via `{.compile.}` pragmas from the package dir) and ELF symbol-localization hardening for libsds (belongs upstream in nim-sds's own build, tracked as a follow-up; Linux is not locally testable here anyway).
