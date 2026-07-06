# Nimble Migration Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the sibling-clone nim-sds build (owned by status-go's Makefile) with a workspace-owned build driven by a nimble-provisioned pinned Nim compiler, feeding status-go prebuilt libsds via its existing `NIM_SDS_LIB_DIR`/`NIM_SDS_INC_DIR` external mode, with the version pin living in a new `statusgo.nimble` in the status-go repo.

**Architecture:** Two new shared make includes (`scripts/nimble-toolchain.mk`, `scripts/nimsds.mk`) used by both the root and mobile Makefiles. `nim_status_client.nimble` pins the workspace Nim version; nimble ≥ 0.22 self-provisions that compiler. nim-sds is checked out into `vendor/nim-sds` (gitignored, pin-driven clone) and built by **its own** Makefile (`USE_SYSTEM_NIM=1`) with the workspace compiler on PATH. status-go never builds Nim code again in this repo's flows. PR #21356 (platform sentinel) is absorbed first as the base.

**Tech Stack:** GNU Make, bash, nimble 0.22.3 (standalone release binary), Nim 2.2.4, nim-sds v0.2.5 (contains the iOS `ld -r` symbol-localization fix), Go/cgo (status-go).

**Spec:** `docs/superpowers/specs/2026-07-02-nimble-migration-architecture-design.md`

## Global Constraints

- Workspace Nim pin: **`nim == 2.2.4`** — declared once in `nim_status_client.nimble`; every make recipe greps it from there (never hardcode elsewhere).
- Nimble version: **0.22.3**, standalone binary in `build/toolchain/` — never `nimble install nimble`, never touch the user's `~/.nimble/bin`.
- nim-sds pin: **`v0.2.5`** — declared once as `const nimSdsVersion = "v0.2.5"` in `vendor/status-go/statusgo.nimble`; both status-go's and status-desktop's Makefiles grep it from there.
- libsds build flags: nim-sds's own Makefile targets with `USE_SYSTEM_NIM=1`; desktop additionally `NIMFLAGS=-d:noSignalHandler` (matches what status-go passed).
- No Nix anywhere in the required path. No changes to status-go's standalone (server/CI) build paths — `clone-nim-sds` + `NIM_SDS_BUILD_FROM_SOURCE=true` must keep working.
- The app build itself stays on nimbus-build-system in Phase 1 (Nim 2.2.4 vendored). Only libsds moves to the new toolchain.
- vendor/status-go edits are committed **inside the submodule** on branch `nimble-phase1-pin`; do NOT commit a submodule-pointer bump in status-app (upstream status-go PR comes later).
- This worktree: all paths under `/Users/alexjbanca/Repos/status-desktop/.claude/worktrees/nimble-migration/`. Never edit the parent checkout.

## Build environment (used by several tasks)

macOS desktop build env (from PR #21356 demo + `reference_desktop_build_gotchas`):

```bash
export QTDIR="$HOME/Qt/6.11.0/macos"
export PATH="$QTDIR/bin:$PATH"
export QMAKE="$QTDIR/bin/qmake"
```

iOS build env:

```bash
export QTDIR="$HOME/Qt/6.11.0/ios"
export PATH="$QTDIR/bin:$HOME/Qt/6.11.0/macos/libexec:$HOME/Qt/6.11.0/macos/bin:$PATH"
export QTTARGET=ios
export QT_HOST_PATH="$HOME/Qt/6.11.0/macos"
export QMAKE_DEVELOPMENT_TEAM=8B5X2M6H2Y
export QMAKE="$QTDIR/bin/qmake"
export IPHONE_SDK=iphoneos
export ARCH=arm64
```

Android build env:

```bash
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/27.2.12479018"
export ARCH=arm64
export OS=android
export QTDIR="$HOME/Qt/6.11.0/android_arm64_v8a"
export QT_HOST_PATH="$HOME/Qt/6.11.0/macos"
export PATH="$QTDIR/bin:$QT_HOST_PATH/bin:$QT_HOST_PATH/libexec:$PATH"
export QMAKE="$QTDIR/bin/qmake"
export QT_ANDROID_DIR="$QTDIR/src/android/java"
export CGO_LDFLAGS_ALLOW='.*'
```

Acceptance for Android includes: **no manual `CGO_LDFLAGS="... -lsds"` needed** (status-go derives it from `NIM_SDS_LIB_DIR`).

---

### Task 0: Workspace prep — submodules + absorb PR #21356

**Files:**
- Modify: `.gitignore`, `Makefile`, `mobile/Makefile`, `mobile/scripts/buildNimStatusClient.sh`
- Create: `scripts/platform_pre_build_cleanup.sh`, `docs/adr/0003-platform-sentinel-ownership.md`
(all created/modified by applying the PR diff)

**Interfaces:**
- Produces: post-#21356 Makefile state that Tasks 4/6 edit — notably the `platform-cleanup` phony target, `$(NIMSDS_LIBFILE): | platform-cleanup` rule in the root Makefile, and `$(STATUS_GO_LIB): FORCE | platform-cleanup` in `mobile/Makefile`.

- [ ] **Step 1: Initialize submodules in this worktree**

The worktree has no vendor checkouts; submodule git dirs are shared with the main repo (`.git/modules`), so this is mostly checkout, not download:

```bash
cd /Users/alexjbanca/Repos/status-desktop/.claude/worktrees/nimble-migration
git submodule update --init --recursive 2>&1 | tail -5
```

Expected: exits 0; `ls vendor/status-go/Makefile vendor/nimbus-build-system/makefiles/variables.mk` both exist.

- [ ] **Step 2: Apply PR #21356 (minus its status-go submodule bump)**

```bash
gh pr diff 21356 --repo status-im/status-app > /tmp/pr21356.diff
# strip the submodule-pointer hunk (last hunk, file `vendor/status-go`)
python3 - <<'EOF'
import re
d = open('/tmp/pr21356.diff').read()
d = re.sub(r'diff --git a/vendor/status-go b/vendor/status-go.*?(?=diff --git|\Z)', '', d, flags=re.S)
open('/tmp/pr21356-nosub.diff','w').write(d)
EOF
git apply --index /tmp/pr21356-nosub.diff
chmod +x scripts/platform_pre_build_cleanup.sh
```

Expected: `git status --short` shows M `.gitignore` `Makefile` `mobile/Makefile` `mobile/scripts/buildNimStatusClient.sh`, A `scripts/platform_pre_build_cleanup.sh` `docs/adr/0003-platform-sentinel-ownership.md`; `git diff --cached --stat | grep -c status-go` prints 0.

- [ ] **Step 3: Verify the Makefile still parses**

```bash
make -n status-go-deps >/dev/null && echo PARSE_OK
```

Expected: `PARSE_OK`.

- [ ] **Step 4: Commit**

```bash
git commit -m "build: absorb PR #21356 (platform sentinel + first-class libsds target)

Base for nimble migration Phase 1. Excludes the PR's status-go submodule bump.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" --no-gpg-sign
```

---

### Task 1: Nimble bootstrap (standalone binary)

**Files:**
- Create: `scripts/install_nimble.sh`
- Create: `scripts/nimble-toolchain.mk`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `scripts/nimble-toolchain.mk` defining `NIMBLE_BIN` (path var), phony `nimble-bootstrap`, and (Task 2 extends it) `nim-toolchain` + `WORKSPACE_NIM_BINDIR`. Consumed by `scripts/nimsds.mk` (Task 4) via `include`.

- [ ] **Step 1: Write `scripts/install_nimble.sh`**

```bash
#!/usr/bin/env bash
# Download a standalone nimble release binary. Never touches ~/.nimble/bin.
set -euo pipefail

VERSION="${1:?usage: install_nimble.sh <version> <dest-dir>}"
DEST="${2:?usage: install_nimble.sh <version> <dest-dir>}"

case "$(uname -s)" in
  Darwin)               os=macosx ;;
  Linux)                os=linux ;;
  MINGW*|MSYS*|CYGWIN*) os=windows ;;
  *) echo "install_nimble.sh: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  arm64|aarch64) arch=aarch64 ;;
  x86_64)        arch=x64 ;;
  *) echo "install_nimble.sh: unsupported arch $(uname -m)" >&2; exit 1 ;;
esac
# nimble ships no windows arm64 asset
[ "$os" = windows ] && arch=x64

bin="$DEST/nimble"
[ "$os" = windows ] && bin="$DEST/nimble.exe"

if [ -x "$bin" ] && "$bin" --version 2>/dev/null | grep -q "nimble v$VERSION"; then
  exit 0
fi

mkdir -p "$DEST"
url="https://github.com/nim-lang/nimble/releases/download/v$VERSION/nimble-${os}_${arch}.tar.gz"
echo "Downloading nimble v$VERSION ($os/$arch)" >&2
curl -fsSL "$url" | tar xz -C "$DEST"
"$bin" --version | grep -q "nimble v$VERSION"
```

```bash
chmod +x scripts/install_nimble.sh
```

- [ ] **Step 2: Write `scripts/nimble-toolchain.mk`**

```make
# Nimble-provisioned Nim toolchain for building Nim C libraries (libsds, ...).
# Spec: docs/superpowers/specs/2026-07-02-nimble-migration-architecture-design.md
# Included by the root Makefile and mobile/Makefile. Self-contained: derives its
# own root path, defines no default goal side effects (includers must save and
# restore .DEFAULT_GOAL, see root Makefile).
NIMBLE_TOOLCHAIN_MK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
WORKSPACE_ROOT := $(abspath $(NIMBLE_TOOLCHAIN_MK_DIR)/..)

NIMBLE_VERSION := 0.22.3
NIMBLE_TOOLCHAIN_DIR := $(WORKSPACE_ROOT)/build/toolchain
ifneq (,$(findstring MINGW,$(shell uname -s 2>/dev/null)))
 NIMBLE_BIN := $(NIMBLE_TOOLCHAIN_DIR)/nimble.exe
else
 NIMBLE_BIN := $(NIMBLE_TOOLCHAIN_DIR)/nimble
endif

# Workspace-local package dir (never ~/.nimble). Note: nimble still caches
# provisioned compilers in ~/.nimble/nimbinaries; pkgs2 entries land here.
NIMBLEDEPS := $(WORKSPACE_ROOT)/nimbledeps

# Single source of truth for the workspace Nim version.
NIM_PIN = $(shell sed -n 's/^requires "nim == \(.*\)"$$/\1/p' $(WORKSPACE_ROOT)/nim_status_client.nimble)
# Recursively expanded: re-evaluates after provisioning creates the dir.
WORKSPACE_NIM_BINDIR = $(firstword $(wildcard $(NIMBLEDEPS)/pkgs2/nim-$(NIM_PIN)-*/bin))

$(NIMBLE_BIN):
	bash $(WORKSPACE_ROOT)/scripts/install_nimble.sh "$(NIMBLE_VERSION)" "$(NIMBLE_TOOLCHAIN_DIR)"

.PHONY: nimble-bootstrap
nimble-bootstrap: $(NIMBLE_BIN)
```

(`nim-toolchain` is added in Task 2 — it needs the manifest change first.)

- [ ] **Step 3: Add ignores**

Append to `.gitignore`:

```
/build/toolchain/
/nimbledeps/
nimble.develop
/vendor/nim-sds/
```

- [ ] **Step 4: Test bootstrap**

```bash
make -f scripts/nimble-toolchain.mk nimble-bootstrap
build/toolchain/nimble --version
```

Expected: downloads once, then `nimble v0.22.3 compiled at ...`. Run twice; second run does nothing (idempotent).

- [ ] **Step 5: Commit**

```bash
git add scripts/install_nimble.sh scripts/nimble-toolchain.mk .gitignore
git commit -m "build: bootstrap standalone nimble 0.22.3 toolchain

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" --no-gpg-sign
```

---

### Task 2: Workspace manifest + pinned Nim provisioning

**Files:**
- Modify: `nim_status_client.nimble`
- Modify: `scripts/nimble-toolchain.mk`

**Interfaces:**
- Consumes: `NIMBLE_BIN`, `NIMBLEDEPS` from Task 1.
- Produces: phony target `nim-toolchain` and variable `WORKSPACE_NIM_BINDIR` (absolute dir containing the provisioned `nim` binary). Task 4's recipes prepend `$(WORKSPACE_NIM_BINDIR)` to PATH.

- [ ] **Step 1: Rewrite `nim_status_client.nimble`**

Replace the whole file with:

```nim
# Package

version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Desktop client for the Status Network built with Nim and Qt"
license       = "MPL2"
srcDir        = "src"
bin           = @["nim_status_client"]
skipExt       = @["nim"]

# Toolchain pin — the single source of truth for the workspace Nim version.
# `make nim-toolchain` provisions exactly this compiler via nimble (>= 0.22)
# and uses it to build Nim C libraries (libsds, ...). The app itself still
# builds with nimbus-build-system's vendored Nim in Phase 1 (same version).
# Phase 2 of the nimble migration adds the app's library dependencies here.
requires "nim == 2.2.4"
```

(The old `requires "nim >= 1.0.0", "stint", ...` line was vestigial — nimbus-build-system resolves deps from git submodules, not from requires. Verify: `grep -rn "nim_status_client.nimble" Makefile scripts/ vendor/nimbus-build-system/` must show no consumer parsing requires.)

- [ ] **Step 2: Add `nim-toolchain` target to `scripts/nimble-toolchain.mk`**

Append:

```make
.PHONY: nim-toolchain
nim-toolchain: $(NIMBLE_BIN)
	@test -n "$(NIM_PIN)" || { echo "ERROR: no 'requires \"nim == X\"' pin in nim_status_client.nimble" >&2; exit 1; }
	@test -x "$(WORKSPACE_NIM_BINDIR)/nim" || \
		(cd $(WORKSPACE_ROOT) && $(NIMBLE_BIN) --nimbleDir:$(NIMBLEDEPS) install "nim@$(NIM_PIN)")
	@bindir="$$(ls -d $(NIMBLEDEPS)/pkgs2/nim-$(NIM_PIN)-*/bin 2>/dev/null | head -1)"; \
	 test -x "$$bindir/nim" || { echo "ERROR: workspace nim $(NIM_PIN) provisioning failed" >&2; exit 1; }; \
	 "$$bindir/nim" --version | head -1
```

- [ ] **Step 3: Test provisioning**

```bash
make -f scripts/nimble-toolchain.mk nim-toolchain
ls -d nimbledeps/pkgs2/nim-2.2.4-*/bin
nimbledeps/pkgs2/nim-2.2.4-*/bin/nim --version | head -1
```

Expected: `Nim Compiler Version 2.2.4`. **Contingency:** if `nimble install nim@2.2.4` errors (the verified-by-spike mechanism was build-triggered provisioning, not direct install), replace the install line in the recipe with the spike pattern: create `build/toolchain/probe/probe.nimble` (`version="0.1.0"`, `author="x"`, `description="x"`, `license="MIT"`, `srcDir="src"`, `bin=@["probe"]`, `requires "nim == $(NIM_PIN)"` — write NIM_PIN literally via a sed in the recipe) plus `build/toolchain/probe/src/probe.nim` containing `echo NimVersion`, then run `cd build/toolchain/probe && $(NIMBLE_BIN) --nimbleDir:$(NIMBLEDEPS) build`. Verify the same `pkgs2/nim-2.2.4-*/bin/nim` assertion afterward.

- [ ] **Step 4: Re-run for idempotence**

```bash
make -f scripts/nimble-toolchain.mk nim-toolchain
```

Expected: no download/build, prints the nim version line, exits 0.

- [ ] **Step 5: Commit**

```bash
git add nim_status_client.nimble scripts/nimble-toolchain.mk
git commit -m "build: pin workspace nim 2.2.4 in manifest; provision via nimble

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" --no-gpg-sign
```

---

### Task 3: status-go — statusgo.nimble pin + external-mode gating (submodule)

**Files:**
- Create: `vendor/status-go/statusgo.nimble`
- Modify: `vendor/status-go/Makefile` (NIM_SDS_VERSION default ~line 108; `build-libsds-android` / `build-libsds-ios` recipes ~lines 320-333)

**Interfaces:**
- Produces: `statusgo.nimble` with the greppable line `const nimSdsVersion = "v0.2.5"` — consumed by status-go's Makefile AND by `scripts/nimsds.mk` (Task 4). External mode (`NIM_SDS_LIB_DIR`+`NIM_SDS_INC_DIR` set) must now be honored by ALL platforms including android/ios targets.

- [ ] **Step 1: Create a branch in the submodule**

```bash
cd vendor/status-go && git checkout -b nimble-phase1-pin
```

- [ ] **Step 2: Write `vendor/status-go/statusgo.nimble`**

```nim
# Package
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "status-go: the Status protocol node (Go); owns the pins of the Nim libraries status-go links via cgo"
license       = "MPL-2.0"

# Consumers (status-desktop) and status-go's own Makefile read the pins below
# from this file, so the version is declared in exactly one place.

# Nim library pins (single source of truth; greppable).
# NOTE: nim-sds v0.2.5 predates its nimble migration and is not consumable as a
# nimble package, so this is a version constant rather than `requires "sds == ..."`.
# Switch to a requires-clause (and let the nimble solver unify versions) when the
# pin reaches a nimble-native nim-sds.
const nimSdsVersion = "v0.2.5"
```

- [ ] **Step 3: Make the Makefile read the pin**

In `vendor/status-go/Makefile`, replace:

```make
NIM_SDS_VERSION ?= v0.2.4
```

with:

```make
# Pin lives in statusgo.nimble (single source of truth, also read by consumers).
NIM_SDS_VERSION ?= $(shell sed -n 's/^const nimSdsVersion = "\(.*\)"$$/\1/p' $(GIT_ROOT)/statusgo.nimble)
```

- [ ] **Step 4: Gate the android/ios libsds recipes on `NIM_SDS_BUILD_FROM_SOURCE`**

Currently `build-libsds-android` / `build-libsds-ios` recipes run unconditionally (only `clone-nim-sds` and `$(LIBSDS)` are gated). Wrap both recipes:

```make
build-libsds-android: clone-nim-sds
ifeq ($(NIM_SDS_BUILD_FROM_SOURCE),true)
	@echo "Building nim-sds for Android" $(LIBSDS)
	$(MAKE) -C $(NIM_SDS_SOURCE_DIR) libsds-android ARCH=$(SDSARCH) ANDROID_NDK_ROOT=$(ANDROID_NDK_ROOT) USE_SYSTEM_NIM=1 SHELL=$(MAKE_SHELL)
else
	@test -f $(LIBSDS) || (echo "Error: libsds not found at $(LIBSDS)" && exit 1)
endif

build-libsds-ios: clone-nim-sds
ifeq ($(NIM_SDS_BUILD_FROM_SOURCE),true)
	@echo "Building nim-sds for iOS" $(LIBSDS)
	$(MAKE) -C $(NIM_SDS_SOURCE_DIR) libsds-ios USE_SYSTEM_NIM=$(USE_SYSTEM_NIM) SHELL=$(MAKE_SHELL)
else
	@test -f $(LIBSDS) || (echo "Error: libsds not found at $(LIBSDS)" && exit 1)
endif
```

(Keep the existing `build-libsds-android: SDSARCH = ...` target-specific variable line above it, unchanged.)

- [ ] **Step 5: Test pin resolution and gating**

```bash
cd vendor/status-go
# Pin resolves from statusgo.nimble:
make -n clone-nim-sds NIM_SDS_SOURCE_DIR=/tmp/sds-test 2>/dev/null | grep "checkout v0.2.5" && echo PIN_OK
# External mode skips build (no nim-sds make invoked), fails on missing lib:
make build-libsds-ios NIM_SDS_LIB_DIR=/tmp/nolib NIM_SDS_INC_DIR=/tmp/noinc 2>&1 | grep "libsds not found" && echo GATE_OK
# From-source mode unchanged (dry run shows delegation):
make -n build-libsds-ios NIM_SDS_SOURCE_DIR=/tmp/sds-test 2>/dev/null | grep -q "libsds-ios" && echo SOURCE_OK
```

Expected: `PIN_OK`, `GATE_OK`, `SOURCE_OK`.

- [ ] **Step 6: Commit inside the submodule**

```bash
cd vendor/status-go
git add statusgo.nimble Makefile
git commit -m "build: own nim-sds pin in statusgo.nimble; honor external libsds on mobile

- statusgo.nimble is the single source of truth for nimSdsVersion (v0.2.5,
  includes the iOS symbol-localization fix); Makefile greps it.
- build-libsds-android/ios now respect NIM_SDS_BUILD_FROM_SOURCE=false so
  consumers can supply a prebuilt libsds via NIM_SDS_LIB_DIR/NIM_SDS_INC_DIR.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" --no-gpg-sign
cd ../..
```

Do NOT `git add vendor/status-go` in the outer repo.

---

### Task 4: Workspace-owned libsds build (desktop) + status-go external-mode wiring

**Files:**
- Create: `scripts/checkout_nim_sds.sh`
- Create: `scripts/nimsds.mk`
- Modify: `Makefile` (the `NIM_SDS_SOURCE_DIR` block ~line 283 and the `$(NIMSDS_LIBFILE)` rule added by #21356 ~line 550)

**Interfaces:**
- Consumes: `nim-toolchain` + `WORKSPACE_NIM_BINDIR` (Task 2); `statusgo.nimble` pin (Task 3); `platform-cleanup` (Task 0).
- Produces: `scripts/nimsds.mk` defining `NIM_SDS_SOURCE_DIR`, `NIM_SDS_PIN`, `NIMSDS_LIBDIR`, `NIMSDS_INCDIR`, and phony targets `nim-sds-src`, `libsds-desktop`, `libsds-ios`, `libsds-android` — consumed by root Makefile (this task) and mobile/Makefile (Task 6).

- [ ] **Step 1: Write `scripts/checkout_nim_sds.sh`**

```bash
#!/usr/bin/env bash
# Materialize the nim-sds checkout at the pinned revision.
# The pin is owned by vendor/status-go/statusgo.nimble (see scripts/nimsds.mk).
set -euo pipefail

VERSION="${1:?usage: checkout_nim_sds.sh <version> <dir>}"
DIR="${2:?usage: checkout_nim_sds.sh <version> <dir>}"
URL="https://github.com/logos-messaging/nim-sds.git"

if [ ! -d "$DIR/.git" ]; then
  git clone --quiet "$URL" "$DIR"
fi
if ! git -C "$DIR" rev-parse --verify --quiet "$VERSION^{commit}" >/dev/null; then
  git -C "$DIR" fetch --tags --quiet origin
fi
if [ "$(git -C "$DIR" rev-parse HEAD)" != "$(git -C "$DIR" rev-parse "$VERSION^{commit}")" ]; then
  git -C "$DIR" checkout --quiet "$VERSION"
fi
echo "nim-sds @ $VERSION ($(git -C "$DIR" rev-parse --short HEAD))"
```

```bash
chmod +x scripts/checkout_nim_sds.sh
```

- [ ] **Step 2: Write `scripts/nimsds.mk`**

```make
# Workspace-owned nim-sds build. The version pin is read from status-go's
# statusgo.nimble (ownership inversion — status-go declares its Nim deps).
# Spec: docs/superpowers/specs/2026-07-02-nimble-migration-architecture-design.md
NIMSDS_MK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
include $(NIMSDS_MK_DIR)/nimble-toolchain.mk

NIM_SDS_SOURCE_DIR ?= $(WORKSPACE_ROOT)/vendor/nim-sds
NIM_SDS_PIN = $(shell sed -n 's/^const nimSdsVersion = "\(.*\)"$$/\1/p' $(WORKSPACE_ROOT)/vendor/status-go/statusgo.nimble)
NIMSDS_LIBDIR := $(NIM_SDS_SOURCE_DIR)/build
NIMSDS_INCDIR := $(NIM_SDS_SOURCE_DIR)/library

.PHONY: nim-sds-src
nim-sds-src:
	@test -n "$(NIM_SDS_PIN)" || { echo "ERROR: nimSdsVersion not found in vendor/status-go/statusgo.nimble (submodule initialized? Task 3 applied?)" >&2; exit 1; }
	bash $(WORKSPACE_ROOT)/scripts/checkout_nim_sds.sh "$(NIM_SDS_PIN)" "$(NIM_SDS_SOURCE_DIR)"

# nim-sds v0.2.x is nimbus-build-system-based internally; USE_SYSTEM_NIM=1 makes
# it use the workspace-provisioned compiler from PATH. `update` inits its own
# vendor submodules. Switch these to pure nimble tasks when the pin reaches a
# nimble-native nim-sds (v0.4.x era).
.PHONY: libsds-desktop libsds-ios libsds-android
libsds-desktop: nim-sds-src nim-toolchain
	PATH="$(WORKSPACE_NIM_BINDIR):$$PATH" $(MAKE) -C $(NIM_SDS_SOURCE_DIR) update USE_SYSTEM_NIM=1
	PATH="$(WORKSPACE_NIM_BINDIR):$$PATH" $(MAKE) -C $(NIM_SDS_SOURCE_DIR) libsds USE_SYSTEM_NIM=1 NIMFLAGS=-d:noSignalHandler SHELL=/bin/sh

libsds-ios: nim-sds-src nim-toolchain
	PATH="$(WORKSPACE_NIM_BINDIR):$$PATH" $(MAKE) -C $(NIM_SDS_SOURCE_DIR) update USE_SYSTEM_NIM=1
	PATH="$(WORKSPACE_NIM_BINDIR):$$PATH" $(MAKE) -C $(NIM_SDS_SOURCE_DIR) libsds-ios USE_SYSTEM_NIM=1 SHELL=/bin/sh

# nim-sds uses 'amd64' for both x86 and x86_64 (mapping mirrored from status-go's Makefile)
libsds-android: SDSARCH=$(strip $(if $(filter arm64,$(ARCH)),arm64,$(if $(filter arm,$(ARCH)),arm,$(if $(filter amd64 x86 x86_64,$(ARCH)),amd64,$(error Unsupported ARCH '$(ARCH)' for libsds-android)))))
libsds-android: nim-sds-src nim-toolchain
	PATH="$(WORKSPACE_NIM_BINDIR):$$PATH" $(MAKE) -C $(NIM_SDS_SOURCE_DIR) update USE_SYSTEM_NIM=1
	PATH="$(WORKSPACE_NIM_BINDIR):$$PATH" $(MAKE) -C $(NIM_SDS_SOURCE_DIR) libsds-android ARCH=$(SDSARCH) ANDROID_NDK_ROOT=$(ANDROID_NDK_ROOT) USE_SYSTEM_NIM=1 SHELL=/bin/sh
```

- [ ] **Step 3: Rewire the root `Makefile`**

Replace the block (post-#21356 state, ~line 283):

```make
NIM_SDS_SOURCE_DIR ?= $(GIT_ROOT)/vendor/nim-sds
export NIM_SDS_SOURCE_DIR
NIMSDS_LIBDIR := $(NIM_SDS_SOURCE_DIR)/build
NIMSDS_LIBFILE := $(NIMSDS_LIBDIR)/libsds.$(LIB_EXT)
NIM_EXTRA_PARAMS += --passL:"-L$(NIMSDS_LIBDIR)" --passL:"-lsds"
STATUSGO_MAKE_PARAMS += NIM_SDS_SOURCE_DIR="$(NIM_SDS_SOURCE_DIR)"
```

with:

```make
# nim-sds is built by this workspace (nimble-provisioned toolchain), and fed to
# status-go prebuilt via its external-lib mode. See scripts/nimsds.mk.
PREV_DEFAULT_GOAL := $(.DEFAULT_GOAL)
include scripts/nimsds.mk
.DEFAULT_GOAL := $(PREV_DEFAULT_GOAL)
export NIM_SDS_SOURCE_DIR
NIMSDS_LIBFILE := $(NIMSDS_LIBDIR)/libsds.$(LIB_EXT)
NIM_EXTRA_PARAMS += --passL:"-L$(NIMSDS_LIBDIR)" --passL:"-lsds"
STATUSGO_MAKE_PARAMS += NIM_SDS_LIB_DIR="$(NIMSDS_LIBDIR)" NIM_SDS_INC_DIR="$(NIMSDS_INCDIR)"
```

And replace the `$(NIMSDS_LIBFILE)` rule that #21356 added (~line 550):

```make
# Rebuild libsds independently after platform switch cleanup deletes vendor/nim-sds/build.
$(NIMSDS_LIBFILE): | platform-cleanup
	echo -e $(BUILD_MSG) "nim-sds"
	$(STATUSGO_MAKE_PARAMS) $(MAKE) -C vendor/status-go build-libsds SHELL=/bin/sh $(HANDLE_OUTPUT)
```

with:

```make
# Rebuild libsds independently after platform switch cleanup deletes vendor/nim-sds/build.
# Built by the workspace toolchain (scripts/nimsds.mk), NOT by status-go.
$(NIMSDS_LIBFILE): | platform-cleanup
	echo -e $(BUILD_MSG) "nim-sds ($(NIM_SDS_PIN))"
	+ $(MAKE) libsds-desktop $(HANDLE_OUTPUT)
```

- [ ] **Step 4: Test libsds desktop build**

```bash
export QTDIR="$HOME/Qt/6.11.0/macos"; export PATH="$QTDIR/bin:$PATH"; export QMAKE="$QTDIR/bin/qmake"
make V=1 vendor/nim-sds/build/libsds.dylib 2>&1 | tail -20
ls -la vendor/nim-sds/build/libsds.dylib
nm -gU vendor/nim-sds/build/libsds.dylib | grep -c "_Sds" # exported API present
lipo -info vendor/nim-sds/build/libsds.dylib               # host arch
```

Expected: dylib exists, `_Sds*` symbols exported, correct arch. The nim-sds checkout lands at v0.2.5 (`git -C vendor/nim-sds describe --tags` → `v0.2.5`).

- [ ] **Step 5: Test status-go consumes it in external mode**

```bash
make V=1 status-go 2>&1 | tee /tmp/statusgo-build.log | tail -5
ls -la vendor/status-go/build/bin/libstatus.dylib
# Prove status-go never built/cloned nim-sds itself (external mode active):
grep -c "Cloning or updating nim-sds" /tmp/statusgo-build.log || echo NO_CLONE_OK
otool -L vendor/status-go/build/bin/libstatus.dylib | grep sds
```

Expected: libstatus.dylib builds and links `libsds.dylib`; `NO_CLONE_OK` (zero clone messages in the build log).

- [ ] **Step 6: Commit**

```bash
git add scripts/checkout_nim_sds.sh scripts/nimsds.mk Makefile
git commit -m "build: workspace-owned libsds via nimble toolchain; status-go external mode

nim-sds is checked out to vendor/nim-sds at the pin declared in status-go's
statusgo.nimble and built with the nimble-provisioned nim 2.2.4. status-go
receives NIM_SDS_LIB_DIR/NIM_SDS_INC_DIR and no longer builds Nim code.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" --no-gpg-sign
```

---

### Task 5: Desktop macOS end-to-end acceptance

**Files:** none (verification only)

- [ ] **Step 1: Confirm no sibling-clone references remain**

```bash
grep -rn '\.\./nim-sds' Makefile mobile/ scripts/ --include='*.mk' --include='Makefile' --include='*.sh' | grep -v vendor/ || echo NO_SIBLING_REFS
```

Expected: `NO_SIBLING_REFS` (status-go's own Makefile keeps its default for standalone use — that's out of scope and correct).

- [ ] **Step 2: Full client build**

```bash
export QTDIR="$HOME/Qt/6.11.0/macos"; export PATH="$QTDIR/bin:$PATH"; export QMAKE="$QTDIR/bin/qmake"
make -j16 nim_status_client 2>&1 | tail -10
```

Expected: `bin/nim_status_client` exists. (~10-30 min on first build.)

- [ ] **Step 3: Launch and verify SDS is live**

Use the desktop-run flow (`make run` or the StatusDev.app launch used by the desktop-run skill). App must reach the login screen without `dyld: Library not loaded ... libsds.dylib`. Check the bundle contains libsds:

```bash
otool -L bin/nim_status_client | grep -E "sds|status"
```

Expected: `libsds.dylib` and `@rpath/libstatus.dylib` referenced; app launches.

- [ ] **Step 4: Commit is not needed (no changes); mark acceptance in the plan checklist.**

---

### Task 6: Mobile wiring (Android + iOS makefiles)

**Files:**
- Modify: `mobile/Makefile` (include + `$(STATUS_GO_LIB)` recipe, post-#21356 state)
- Modify: `mobile/scripts/Common.mk:37` (remove the now-duplicated `NIM_SDS_SOURCE_DIR` default)

**Interfaces:**
- Consumes: `libsds-ios`, `libsds-android`, `NIMSDS_LIBDIR`, `NIMSDS_INCDIR` from `scripts/nimsds.mk` (Task 4); status-go external-mode gating (Task 3).

- [ ] **Step 1: Include nimsds.mk in `mobile/Makefile`**

Immediately AFTER the line `default: makedir all` (so the default goal is not hijacked), add:

```make
# Workspace-owned nim-sds build (shared with root Makefile).
PREV_DEFAULT_GOAL := $(.DEFAULT_GOAL)
include ../scripts/nimsds.mk
.DEFAULT_GOAL := $(PREV_DEFAULT_GOAL)
```

- [ ] **Step 2: Remove the duplicate default from `mobile/scripts/Common.mk`**

Delete line 37 (`NIM_SDS_SOURCE_DIR ?= $(STATUS_DESKTOP)/vendor/nim-sds`) — `nimsds.mk` owns it now. Note Common.mk is included before nimsds.mk; since both use `?=` with the same value this is cleanup, not behavior change.

- [ ] **Step 3: Rewrite the `$(STATUS_GO_LIB)` recipe (post-#21356 it is `$(STATUS_GO_LIB): FORCE | platform-cleanup`)**

```make
# Always delegate to status-go's PHONY sub-make (it owns incremental rebuild, see issue #18377), then copy only on change.
# libsds is built by the workspace toolchain (../scripts/nimsds.mk) and passed to status-go prebuilt.
$(STATUS_GO_LIB): FORCE | platform-cleanup
	@echo "Building nim-sds mobile library"
ifeq ($(OS),android)
	+$(MAKE) libsds-android ARCH=$(ARCH)
else ifeq ($(OS),ios)
	+$(MAKE) libsds-ios
endif
	@echo "Building status-go mobile library"
	@mkdir -p $(LIB_PATH)
ifeq ($(OS),android)
	  CC="$(CC)" $(MAKE) -C ../vendor/status-go statusgo-android-library \
		ARCH=$(ARCH) \
		ANDROID_NDK_ROOT="$(ANDROID_NDK_ROOT)" \
		ANDROID_API="$(ANDROID_API)" \
		HOST_OS="$(HOST_OS)" \
		NIM_SDS_LIB_DIR="$(NIMSDS_LIBDIR)" \
		NIM_SDS_INC_DIR="$(NIMSDS_INCDIR)" \
		GO_GENERATE_CMD="go generate" \
		SHELL=/bin/sh
else ifeq ($(OS),ios)
	$(MAKE) -C ../vendor/status-go statusgo-ios-library \
		ARCH=$(ARCH) \
		IPHONE_SDK="$(IPHONE_SDK)" \
		IOS_TARGET="$(IOS_TARGET)" \
		NIM_SDS_LIB_DIR="$(NIMSDS_LIBDIR)" \
		NIM_SDS_INC_DIR="$(NIMSDS_INCDIR)" \
		SHELL=/bin/sh
endif
	@echo "Copying library to mobile lib directory"
	@cmp -s $(NIM_SDS_SOURCE_DIR)/build/libsds$(LIB_EXT) $(LIB_PATH)/libsds$(LIB_EXT) || cp $(NIM_SDS_SOURCE_DIR)/build/libsds$(LIB_EXT) $(LIB_PATH)/libsds$(LIB_EXT)
	@cmp -s ../vendor/status-go/build/bin/libstatus$(LIB_EXT) $(LIB_PATH)/libstatus$(LIB_EXT) || cp ../vendor/status-go/build/bin/libstatus$(LIB_EXT) $(LIB_PATH)/libstatus$(LIB_EXT)
```

(Drops `NIM_SDS_SOURCE_DIR=`/`USE_SYSTEM_NIM=` from both sub-make invocations — status-go no longer builds Nim.)

- [ ] **Step 4: Parse test both OS modes**

```bash
cd mobile
make -n makedir OS=ios ARCH=arm64 >/dev/null && echo IOS_PARSE_OK
make -n makedir OS=android ARCH=arm64 >/dev/null && echo ANDROID_PARSE_OK
cd ..
```

Expected: both OK lines, and `make -n` for the default goal still resolves to `default` (`cd mobile && make -np 2>/dev/null | grep '^.DEFAULT_GOAL' `→ `default`).

- [ ] **Step 5: Commit**

```bash
git add mobile/Makefile mobile/scripts/Common.mk
git commit -m "build(mobile): workspace-built libsds; pass prebuilt lib to status-go

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" --no-gpg-sign
```

---

### Task 7: iOS end-to-end acceptance (symbol localization + sentinel)

**Files:** none (verification only)

- [ ] **Step 1: Build libsds for iOS and audit symbols**

```bash
# iOS env exports from the "Build environment" section above
cd mobile && make libsds-ios && cd ..
nm -gU vendor/nim-sds/build/libsds.a | grep -v "_Sds" | grep " T \| S \| D " || echo ONLY_SDS_GLOBALS
nm -gU vendor/nim-sds/build/libsds.a | grep -c "_Sds"
```

Expected: `ONLY_SDS_GLOBALS` (the v0.2.5 `ld -r -exported_symbol '_Sds*'` localization worked — no global Nim runtime symbols), and a nonzero `_Sds*` count.

- [ ] **Step 2: Full iOS build**

```bash
make -j10 V=3 mobile-build USE_SYSTEM_NIM=1 2>&1 | tail -10
```

Expected: app links with no duplicate-symbol warnings for Nim runtime symbols. (~30+ min.)

- [ ] **Step 3: Platform-switch sentinel check (the #21356 demo, abbreviated)**

```bash
cat .platform-target                    # ios-arm64
# now a desktop libsds build must clean + rebuild for macOS:
export QTDIR="$HOME/Qt/6.11.0/macos"; export PATH="$QTDIR/bin:$PATH"; export QMAKE="$QTDIR/bin/qmake"
make vendor/nim-sds/build/libsds.dylib >/dev/null 2>&1
lipo -info vendor/nim-sds/build/libsds.dylib   # macOS arch, not iOS
cat .platform-target                    # darwin-<arch>
```

Expected: sentinel flips, libsds.dylib is a fresh macOS binary.

---

### Task 8: Android end-to-end acceptance (no manual CGO_LDFLAGS)

**Files:** none (verification only)

- [ ] **Step 1: Full Android build WITHOUT the manual `-lsds` CGO_LDFLAGS workaround**

```bash
# Android env exports from the "Build environment" section above (note: no CGO_LDFLAGS except page-size)
make -j10 V=3 mobile-build USE_SYSTEM_NIM=1 CGO_LDFLAGS="-Wl,-z,max-page-size=16384 -lc++_shared" 2>&1 | tail -10
```

Expected: build succeeds — status-go derives `-L.../vendor/nim-sds/build -lsds` from `NIM_SDS_LIB_DIR` itself (this removes the workaround documented in PR #21356's demo script). Verify:

```bash
ls mobile/lib/android-arm64/libsds.so mobile/lib/android-arm64/libstatus.so 2>/dev/null || ls mobile/lib/*/libsds.so
file vendor/nim-sds/build/libsds.so | grep aarch64
```

- [ ] **Step 2: Optional smoke deploy** (if a device is connected): use the mobile-deploy/mobile-run flow and confirm login screen + no service-process crash in logcat.

---

### Task 9: Docs + final sync

**Files:**
- Modify: `BUILDING.md` (or `docs/` build docs — locate the section describing nim-sds/status-go prerequisites)
- Modify: `docs/superpowers/specs/2026-07-02-nimble-migration-architecture-design.md` (only if implementation deviated)

- [ ] **Step 1: Document the new flow in BUILDING.md**

Add a short section:

```markdown
## Nim toolchain and Nim C libraries (nimble)

Nim libraries linked by status-go (nim-sds) are built by this repo's workspace
toolchain, not by status-go:

- `make nimble-bootstrap` — installs a standalone nimble (version pinned in
  `scripts/nimble-toolchain.mk`) into `build/toolchain/`.
- `make nim-toolchain` — provisions the exact Nim compiler pinned in
  `nim_status_client.nimble` (`requires "nim == X"`).
- The nim-sds version pin lives in `vendor/status-go/statusgo.nimble`
  (`const nimSdsVersion`); the checkout is materialized at `vendor/nim-sds`.

These run automatically as part of `make nim_status_client` / mobile builds.
No sibling `../nim-sds` clone is needed or used.
```

- [ ] **Step 2: Reconcile the spec** — if any mechanism changed during implementation (e.g. the Task 2 contingency was used), update the spec's "Verified spikes"/Phase 1 wording accordingly.

- [ ] **Step 3: Final commit + summary**

```bash
git add BUILDING.md docs/
git commit -m "docs: nimble toolchain + workspace-built nim libs (Phase 1)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>" --no-gpg-sign
git log --oneline master..HEAD
```

Report: list of commits, acceptance results per platform, and the pending upstream work (status-go PR from the `nimble-phase1-pin` submodule branch; coordination with open PRs #21356/#7583).

---

## Known risks / contingencies

- **`nimble install nim@2.2.4` syntax unverified** — Task 2 Step 3 carries the exact spike-verified fallback (probe package + `nimble build`).
- **nim-sds `make update` inside v0.2.5** initializes its own NBS vendor submodules (network fetch on first run; several minutes).
- **PR #21356 may land upstream while this branch is in flight** — Task 0 committed its diff verbatim, so a later `git rebase master` will either drop our copy cleanly (identical) or need a trivial conflict resolution.
- **status-go submodule pointer**: this plan intentionally leaves status-app pointing at the recorded status-go SHA while the working tree has local submodule commits. CI for the branch will fail on the submodule until the status-go PR lands and the pointer is bumped — expected and acceptable for Phase 1 development.
- **Windows/Linux**: covered by design (install_nimble.sh handles both; make logic is platform-neutral) but verified only in CI, not locally.
- **logos-storage-nim** (opt-in via `USE_LOGOS_STORAGE`, off in desktop builds): intentionally NOT migrated in this plan. When it's enabled, it follows the identical pattern — add `const logosStorageVersion` to `statusgo.nimble`, a `libstorage` target to `scripts/nimsds.mk`, and pass `LOGOS_STORAGE_LIB_DIR`/`LOGOS_STORAGE_INC_DIR` (status-go's external mode for it already exists).
