# Copyright (c) 2019-2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

SHELL := bash # the shell used internally by Make

GIT_ROOT ?= $(shell git rev-parse --show-toplevel 2>/dev/null || echo .)

# --- this Makefile includes no external makefile (issue 0018) ------------------
# The vendored nimbus-build-system is GONE. Its last two jobs — putting a Nim
# compiler on PATH and auto-initialising submodules — belong to nimble and to
# the driver's bootstrap now:
#
#   nimble setup && source ./env.sh   # the ONE prerequisite (BUILDING.md)
#
# after which `nim` on PATH IS the compiler `nim_status_client.nimble` pins, by
# construction. `deps`, `update`, `deps-common`, `NIM_PARAMS`, the env-script
# wrapper, `.update.timestamp`, `NIM_SOURCES`, `REBUILD_NIM` and `USE_SYSTEM_NIM`
# died with it. What NBS still provided this file — verbosity/output handling and
# the coloured build message — is defined right here:

# verbosity level (V=1 shows every recipe and every sub-build's output)
V ?= 0
HANDLE_OUTPUT :=
ifeq ($(V),0)
 # don't swallow stderr, in case it's important
 HANDLE_OUTPUT := >/dev/null
 # silence the recipes themselves (NBS spelled this `$(SILENT_TARGET_PREFIX).SILENT`)
 .SILENT:
endif

# coloured messages
BUILD_MSG := "\\x1B[92mBuilding:\\x1B[39m"

.PHONY: \
	all \
	fix-wallet-migrations \
	nix-shell \
	bottles \
	check-qt-dir \
	check-pkg-target-linux \
	check-pkg-target-macos \
	check-pkg-target-windows \
	clean \
	clean-nimcache \
	update-translations \
	compile-translations \
	seaqt-test \
	pkg \
	pkg-linux \
	pkg-macos \
	pkg-windows \
	status-go \
	qrcodegen \
	status-keycard-qt \
	keycard-simulator \
	keycard-simulator-bundle \
	statusq-sanity-checker \
	run-statusq-sanity-checker \
	statusq-tests \
	run-statusq-tests \
	qml-lint \
	qml-lint-mobile \
	storybook-build \
	run-storybook \
	run-storybook-tests \
	mobile-run \
	mobile-build \
	mobile-clean \
	mobile-profile \
	flatpak \
	flatpak-install \
	flatpak-run \
	flatpak-clean \
	macos-icon-assets \
	platform-cleanup \
	FORCE

# --- this Makefile never invokes `nim c` / `nim e` (issue 0017) ---------------
# Every Nim compile — the client, the Nim test suite, the Windows launcher —
# belongs to the driver (`nim <task> status.nims`). What survives here is
# packaging, storybook, the StatusQ/QML checks, the interim mobile legs and CI
# helpers; they CONSUME the binary the driver produced. The invariant is
# mechanical and re-runnable:
#
#     scripts/check-no-nim-compiles.sh
#
# `nim <task> status.nims` calls (driver dispatch) are not compiles and are the
# supported way for a packaging recipe to ask for a binary.

# There is no `.DEFAULT` submodule auto-init any more (issue 0018): the driver's
# bootstrap owns submodule initialisation since issue 0016 — targeted at the
# submodules the build actually consumes, not a blanket recursive update.

all:
	nim app status.nims

# An always-out-of-date prerequisite (declared .PHONY above). The packaging
# artifacts further down are real files with real recipes, but their only
# client-producing step is a driver dispatch (`nim app status.nims`), and the
# DRIVER — not make — owns the decision whether the client needs a relink
# (.status-client.key). Without a force prerequisite an existing pkg/Status.dmg
# makes `make pkg-macos` "up to date" and the driver never runs: the old
# `.PHONY nim_status_client` prerequisite and `pkg:`'s `rm $(NIM_STATUS_CLIENT)`
# both died with the client rule in issue 0017.
FORCE:

nix-shell: export NIX_USER_CONF_FILES := $(PWD)/nix/nix.conf
nix-shell:
	nix-shell

# `qmake` path, either passed explicitely, or as found in PATH
# (makes it possible to override with a custom Qt6 install dir)
QMAKE ?= $(shell which qmake)
ifneq ($(QMAKE),$(shell which qmake))
 # Add it to PATH for external build tools that use qmake directly
 export PATH := $(patsubst %/,%,$(dir $(QMAKE))):$(PATH)
endif
QSPEC:=$(shell $(QMAKE) -query QMAKE_XSPEC)
ifeq ($(QSPEC),macx-ios-clang)
mkspecs:=ios
else ifeq ($(QSPEC),macx-clang)
mkspecs:=macx
else ifeq ($(QSPEC),win32-msvc)
mkspecs:=win32
else ifeq ($(QSPEC),linux-g++)
mkspecs:=linux
else ifeq ($(QSPEC),android-clang)
mkspecs:=android
endif

host_os:=$(shell uname -s | tr '[:upper:]' '[:lower:]')

ifeq ($(mkspecs),)
	$(error Cannot find your Qt installation. Please make sure to export correct Qt installation binaries path to PATH env)
endif

ifeq ($(mkspecs),macx)
 CFLAGS := -mmacosx-version-min=14.0
 export CFLAGS
 CGO_CFLAGS := -mmacosx-version-min=14.0
 export CGO_CFLAGS
 LIB_EXT := dylib
  # keep in sync with BOTTLE_MACOS_VERSION
 MACOSX_DEPLOYMENT_TARGET := 14.0
 export MACOSX_DEPLOYMENT_TARGET
 PKG_TARGET := pkg-macos
 QT_ARCH ?= $(shell uname -m)
else ifeq ($(mkspecs),win32)
 LIB_EXT := dll
 PKG_TARGET := pkg-windows
else
 LIB_EXT := so
 PKG_TARGET := pkg-linux
endif

check-qt-dir:
ifeq ($(shell $(QMAKE) -v 2>/dev/null),)
	$(error Cannot find your Qt installation. Please make sure to export correct Qt installation binaries path to PATH env)
endif

check-pkg-target-linux:
ifneq ($(mkspecs),linux)
	$(error The pkg-linux target must be run on Linux)
endif

check-pkg-target-macos:
ifneq ($(mkspecs),macx)
	$(error The pkg-macos target must be run on macOS)
endif

check-pkg-target-windows:
ifneq ($(mkspecs),win32)
	$(error The pkg-windows target must be run on Windows)
endif

ifeq ($(mkspecs),macx)
BOTTLES_DIR := $(shell pwd)/bottles
BOTTLES := $(addprefix $(BOTTLES_DIR)/,openssl@3)
ifeq ($(QT_ARCH),arm64)
# keep in sync with MACOSX_DEPLOYMENT_TARGET
	BOTTLE_MACOS_VERSION := 'arm64_sonoma'
else
	BOTTLE_MACOS_VERSION := 'sonoma'
endif
$(BOTTLES):
	echo -e "\033[92mFetching:\033[39m $(notdir $@) bottle arch $(QT_ARCH) $(BOTTLE_MACOS_VERSION)"
	./scripts/fetch-brew-bottle.sh $(notdir $@) $(BOTTLE_MACOS_VERSION) $(HANDLE_OUTPUT)
endif

# Declared outside the macOS arm: elsewhere $(BOTTLES) is empty and this is a
# no-op, which is what the order-only prerequisites below want. (`deps` — which
# used to carry it — is deleted with NBS: its other halves were `deps-common`
# (NBS), `check-qt-dir` and `status-go-deps`; the driver's bootstrap fetches the
# same bottle for `nim app status.nims`.)
bottles: $(BOTTLES)

QML_DEBUG ?= false
QML_DEBUG_PORT ?= 49152

ifneq ($(QML_DEBUG), false)
 COMMON_CMAKE_BUILD_TYPE=Debug
else
 COMMON_CMAKE_BUILD_TYPE=Release
endif

MONITORING ?= false
ifneq ($(MONITORING), false)
 STATUSQ_CMAKE_CONFIG_PARAMS += -DMONITORING:BOOL=ON -DMONITORING_QML_ENTRY_POINT:STRING="/../monitoring/Main.qml"
endif

# where Qt is installed, depends on the `QMAKE` path
QT_INSTALL_PREFIX := $(shell $(QMAKE) -query QT_INSTALL_PREFIX 2>/dev/null)
# what Qt version are we building against
QT_VERSION := $(shell $(QMAKE) -query QT_VERSION 2>/dev/null)
# referenced in android/qt6/build.gradle
export QT_ANDROID_DIR := $(QT_INSTALL_PREFIX)/src/android/java
# separate StatusQ/storybook/... build dirs, per Qt version
COMMON_CMAKE_CONFIG_PARAMS := -DCMAKE_PREFIX_PATH=$(QT_INSTALL_PREFIX)

# Qt dirs (we can't indent with tabs here)
 QT_MAJOR_VERSION := $(shell $(QMAKE) -query QT_VERSION | head -c 1 2>/dev/null)

ifneq ($(QT_MAJOR_VERSION),6)
 $(error Detected Qt major version $(QT_MAJOR_VERSION), but version 6 is required. Please install Qt 6 and set paths accordingly.)
endif

#-------- PKG_CONFIG wrapper for Qt's .pc files --------
# prl-to-pc is a pinned nimble dependency (issue 0014). Since issue 0015 the
# DESKTOP build no longer consumes it through make at all: the driver executes
# the package's own `qt_pkgconfig.nims` (tools + a cached `env`), and
# config.nims replays that cache. What survives here is the mk interface, for
# the one make leg this iteration deliberately leaves alone — the mobile builds
# (the Nim test suite left with issue 0017). They get the wrapper built and the
# pkg-config env exported at parse time, exactly as before.
#
# The mk is included from the resolved package root: the vendor/prl-to-pc
# checkout when nimble.overlay says it's developed, else the read-only store
# entry named by the generated nimble.paths. Store copies must never be
# written: the tool build is redirected to the same repo-local scratch dir the
# driver uses, and the generator's regex/unicodedb deps come from OUR
# nimble.paths (the mk's consumer-override knobs). status_env.nims derives the
# same root itself (prlToPcRoot) — keep the two derivations in sync.
QT_PC_BUILD_DIR := $(CURDIR)/.prl-to-pc-build/.pcwrap
QT_PC_CONSUMER_PATHS := $(CURDIR)/nimble.paths
PRL_TO_PC_DEVELOPED := $(shell grep -sqx prl-to-pc nimble.overlay 2>/dev/null && echo 1)
ifeq ($(PRL_TO_PC_DEVELOPED),1)
PRL_TO_PC_ROOT := vendor/prl-to-pc
else
PRL_TO_PC_ROOT := $(shell sed -n 's|^--path:"\(.*/pkgs2/prl_to_pc-[^"/]*\)".*|\1|p' nimble.paths 2>/dev/null | head -1)
endif
ifneq (,$(PRL_TO_PC_ROOT))
include $(PRL_TO_PC_ROOT)/qt-pkgconfig.mk
else
# No resolution yet (fresh clone, or the first build after the pin landed):
# an included file with a remake rule makes GNU make build it and RE-EXECUTE
# this Makefile, so the second parse resolves the store root and runs the
# real include above. bootstrap.mk exists only to trigger that mechanism —
# its one prerequisite is the nimble setup product. The desktop build no
# longer depends on the include, so there is nothing to stub out when the
# resolution exists but carries no prl_to_pc entry: the mobile/nim-test legs
# then fail on a missing `qt-pkgconfig` rule, and `make nimble-deps` fixes it.
-include .prl-to-pc-build/bootstrap.mk
.prl-to-pc-build/bootstrap.mk: nimble.paths
	@mkdir -p $(@D)
	@echo '# auto-generated re-exec trigger for the prl-to-pc include (see Makefile)' > $@
endif
# -----------------------------------------------------

# The client's compile/link flags live in config.nims — for EVERY platform since
# issue 0017 (Windows included). What survives here are the values packaging and
# the interim mobile legs still read.
ifneq ($(mkspecs),win32)
 export QT_LIBDIR := $(shell $(QMAKE) -query QT_INSTALL_LIBS 2>/dev/null)
 QT_QMLDIR := $(shell $(QMAKE) -query QT_INSTALL_QML 2>/dev/null)
endif

ifeq ($(mkspecs),win32)
 COMMON_CMAKE_CONFIG_PARAMS += -A x64
endif

ifeq ($(mkspecs),macx)
 ifeq ("$(shell sysctl -nq hw.optional.arm64)","1")
   ifneq ($(QT_ARCH),arm64)
	STATUSGO_MAKE_PARAMS += GOBIN_SHARED_LIB_CFLAGS="CGO_ENABLED=1 GOOS=darwin GOARCH=amd64"
	COMMON_CMAKE_CONFIG_PARAMS += -DCMAKE_OSX_ARCHITECTURES=x86_64
  endif
 endif
endif

# status-go is a pinned URL#hash dependency in the app's single nimble graph
# (nim_status_client.nimble requires it; issue 0010). Since issue 0020 NOTHING
# IS COPIED: status-go and nim-sds keep every build output under a
# caller-chosen directory, so the read-only store copies are compiled in place
# and .statusgo-build holds outputs only. Two roots, and they are no longer
# mode-vs-mode but read-vs-write:
#   STATUSGO_SRC  the tree the sub-builds READ: the resolved store entry, or
#                 the vendor/status-go checkout while developed (`nim develop
#                 status.nims statusgo`, issue 0009). Never written to.
#   STATUSGO_OUT  every artifact. The same directory in both modes, so a
#                 develop checkout stays clean.
# `nim prepareStatusgo status.nims` (the statusgo-out rule below) maintains
# STATUSGO_OUT: it wipes it when the resolved source root changes and drops
# artifacts when the flag key changes, so while both keys hold the status-go
# sub-make is not invoked at all (the stamp-skip default arm). A developed
# statusgo keeps ADR 0003's FORCE + compare-before-copy semantics (driven from
# status.nims).
STATUSGO_DEVELOPED := $(shell grep -sqx statusgo nimble.overlay 2>/dev/null && echo 1)
STATUSGO_OUT := .statusgo-build
ifeq ($(STATUSGO_DEVELOPED),1)
STATUSGO_SRC = vendor/status-go
else
# The statusgo store entry from the generated resolution (status.nims'
# statusgoSourceRoot answers the same question for the driver — keep them in
# sync). Recursively expanded: nimble.paths may not exist yet at parse time.
STATUSGO_SRC = $(shell sed -n 's|^--path:"\(.*/pkgs2/statusgo-[^/"]*\).*|\1|p' nimble.paths 2>/dev/null | head -1)
endif
# libsds is built by status-go's own nimble tasks (see statusgo.nimble in
# $(STATUSGO_SRC)); the workspace feeds the artifacts back via
# NIM_SDS_LIB_DIR/NIM_SDS_INC_DIR. statusgo.nimble pins nim-sds by URL#hash,
# so nimble resolves sds into the shared store, and status-go's sds tasks build
# THAT copy in place (no vendor/nim-sds checkout is needed), writing artifacts
# to $(STATUSGO_OUT)/.sds-build/build and the header contract to
# $(STATUSGO_OUT)/.sds-build/library.
NIMSDS_BUILD_ROOT := $(CURDIR)/$(STATUSGO_OUT)/.sds-build
NIMSDS_LIBDIR := $(NIMSDS_BUILD_ROOT)/build
# Linux packaging scripts (init_app_dir.sh, bundle-flatpak.sh) bundle
# libsds.so from here.
export NIMSDS_LIBDIR
NIMSDS_INCDIR := $(NIMSDS_BUILD_ROOT)/library
NIMSDS_LIBFILE := $(NIMSDS_LIBDIR)/libsds.$(LIB_EXT)
STATUSGO_MAKE_PARAMS += NIM_SDS_LIB_DIR="$(NIMSDS_LIBDIR)" NIM_SDS_INC_DIR="$(NIMSDS_INCDIR)"
# statusgo.nims takes the resolution from STATUSGO_NIMBLE_PATHS — the app's
# OWN nimble.paths, by path. It used to be COPIED next to statusgo.nims, which
# for a store copy is a write into the shared package store. Entries are
# absolute, so the file is valid from any directory. (The former per-status-go
# dependency cache, ~/.cache/statusgo-nimbledeps, and its second multi-minute
# solve went away with issue 0010.)
STATUSGO_TASK_ENV := STATUSGO_BUILD_DIR="$(CURDIR)/$(STATUSGO_OUT)" STATUSGO_NIMBLE_PATHS="$(CURDIR)/nimble.paths"

# desktop only; mobile cleanup lives in mobile/Makefile
ifneq ($(filter $(mkspecs),macx linux),)
PLATFORM_TARGET := $(host_os)-$(or $(QT_ARCH),$(shell uname -m))
else ifeq ($(mkspecs),win32)
PLATFORM_TARGET := windows-$(or $(QT_ARCH),$(shell uname -m))
endif

# Order-only prerequisite: delete shared vendor artifacts (nim-sds, libstatus) when the build platform/arch changes.
platform-cleanup:
ifneq ($(PLATFORM_TARGET),)
	scripts/platform_pre_build_cleanup.sh "$(PLATFORM_TARGET)"
endif

# Nimble-managed Nim dependencies (nimble.lock -> nimble's DEFAULT store,
# ~/.nimble). One store for every front door (issue 0013): `nimble build` /
# `nimble run` always resolve against the default store and nimble has no
# per-project store mechanism, so a dedicated dir would force every nimble
# command through developer-exported env — the opposite of out-of-the-box.
# The default store still satisfies the out-of-tree constraint (`nimble
# setup` builds dependency binaries, and Nim's parent-dir config walk would
# poison in-tree builds with this repo's config.nims). Override with the
# NIMBLE_DIR env var (nimble reads it natively) for CI/clean-room runs; the
# former dedicated store (~/.cache/status-desktop-nimbledeps) is retired and
# can be deleted. nimble.paths at the repo root is the setup product make
# tracks; it is regenerated from the lock plus every manifest in the single
# graph — status-go participates as a dependency (and carries the nim-sds
# pin), so editing those manifests must re-run the app's one resolution.
# There is no separate status-go solve.
NIMBLE_SETUP_STAMP := nimble.paths
# The develop-mode overlay (issue 0009, ADR 0007) joins the stamp key: a
# develop/undevelop flip rewrites the gitignored nimble.overlay, which
# schedules regeneration; after every `nimble setup` the driver rewrites the
# developed vendors' entries in the fresh nimble.paths to their checkouts
# (logic lives in status.nims — make only delegates). Derived copies
# (vendor/status-go/nimble.paths below) inherit through their cmp-gated rules.
NIMBLE_OVERLAY := nimble.overlay
$(NIMBLE_SETUP_STAMP): nimble.lock nim_status_client.nimble $(wildcard vendor/status-go/statusgo.nimble) $(wildcard $(NIMBLE_OVERLAY))
	@command -v nimble >/dev/null 2>&1 || { echo "ERROR: nimble not found on PATH (see BUILDING.md)" >&2; exit 1; }
	nimble setup || { echo "ERROR: nimble setup failed. If a .nimble manifest changed, regenerate the lock with 'nimble lock' (full solve, takes minutes) and retry." >&2; exit 1; }
	nim applyOverlay status.nims
	touch $@

nimble-deps: $(NIMBLE_SETUP_STAMP)
.PHONY: nimble-deps

# desktop only; mobile cleanup lives in mobile/Makefile
ifneq ($(filter $(mkspecs),macx linux),)
PLATFORM_TARGET := $(host_os)-$(or $(QT_ARCH),$(shell uname -m))
else ifeq ($(mkspecs),win32)
PLATFORM_TARGET := windows-$(or $(QT_ARCH),$(shell uname -m))
endif

# Order-only prerequisite: delete shared vendor artifacts (qrcodegen, nim-sds, libstatus) when the build platform/arch changes.
platform-cleanup:
ifneq ($(PLATFORM_TARGET),)
	scripts/platform_pre_build_cleanup.sh "$(PLATFORM_TARGET)"
endif

INCLUDE_DEBUG_SYMBOLS ?= false
ifeq ($(INCLUDE_DEBUG_SYMBOLS),true)
 # Enable debugging symbols in the C/C++ deps, in case we need GDB backtraces
 CFLAGS += -g
 CXXFLAGS += -g
 RCC_PARAMS = --no-compress
else
 STATUSGO_MAKE_PARAMS += CGO_CFLAGS="-O3"
endif

# App version
DESKTOP_VERSION = $(shell ./scripts/version.sh)
# statusgo version: a developed checkout has git history (`git describe`); a
# pinned store copy has NO .git, so the version is the pin revision, read from
# the store entry's nimblemeta.json (vcsRevision — URL-agnostic and exactly
# what resolution bound). Lazily expanded: nimble.paths exists by the time any
# recipe uses it.
ifeq ($(STATUSGO_DEVELOPED),1)
STATUSGO_VERSION = $(shell make -C vendor/status-go version -s)
else
STATUSGO_VERSION = $(shell sed -n 's|^--path:"\(.*/pkgs2/statusgo-[^"/]*\)".*|\1|p' nimble.paths 2>/dev/null | head -1 | xargs -I{} sed -n 's|.*"vcsRevision": "\([0-9a-f]*\)".*|\1|p' {}/nimblemeta.json 2>/dev/null | cut -c1-10)
endif
##
## Versioning
##

version:
	@echo $(DESKTOP_VERSION)

status-go-version:
	@echo $(STATUSGO_VERSION)


##
##	StatusQ
##

STATUSQ_SOURCE_PATH := ui/StatusQ
STATUSQ_BUILD_PATH := ui/StatusQ/build/Qt$(QT_VERSION)
export STATUSQ_INSTALL_PATH := $(shell pwd)/bin
STATUSQ_CMAKE_CACHE := $(STATUSQ_BUILD_PATH)/CMakeCache.txt

$(STATUSQ_CMAKE_CACHE): | check-qt-dir
	echo -e "\033[92mConfiguring:\033[39m StatusQ"
	cmake \
		-DCMAKE_INSTALL_PREFIX=$(STATUSQ_INSTALL_PATH) \
		-DCMAKE_BUILD_TYPE=$(COMMON_CMAKE_BUILD_TYPE) \
		-DSTATUSQ_BUILD_SANITY_CHECKER=OFF \
		-DSTATUSQ_BUILD_TESTS=OFF \
		$(COMMON_CMAKE_CONFIG_PARAMS) \
		$(STATUSQ_CMAKE_CONFIG_PARAMS) \
		-B $(STATUSQ_BUILD_PATH) \
		-S $(STATUSQ_SOURCE_PATH) \
		-Wno-dev \
		$(HANDLE_OUTPUT)

statusq-configure: | $(STATUSQ_CMAKE_CACHE)

statusq-build: | statusq-configure
	echo -e "\033[92mBuilding:\033[39m StatusQ"
	cmake --build $(STATUSQ_BUILD_PATH) \
		--target StatusQ \
		--config $(COMMON_CMAKE_BUILD_TYPE) \
		$(HANDLE_OUTPUT)

statusq-install: | statusq-build
	echo -e "\033[92mInstalling:\033[39m StatusQ"
	cmake --install $(STATUSQ_BUILD_PATH) \
		$(HANDLE_OUTPUT)

statusq: | statusq-install

statusq-clean:
	echo -e "\033[92mCleaning:\033[39m StatusQ"
	rm -rf $(STATUSQ_BUILD_PATH)
	rm -rf $(STATUSQ_INSTALL_PATH)/StatusQ

##
##	Catch invalid QML
##
qml-lint:
	echo -e "\033[92mRunning:\033[39m QML Lint"
	./scripts/validate-qml.sh

# Run qmllint against mobile Qt modules to catch missing imports
qml-lint-mobile:
	echo -e "\033[92mRunning:\033[39m QML Lint (Mobile)"
	QT_QML_PATH=$(QT_MOBILE_DIR)/qml ./scripts/validate-qml.sh

statusq-sanity-checker:
	echo -e "\033[92mConfiguring:\033[39m StatusQ SanityChecker"
	cmake \
		-DSTATUSQ_BUILD_SANITY_CHECKER=ON \
		-DSTATUSQ_BUILD_TESTS=OFF \
		$(COMMON_CMAKE_CONFIG_PARAMS) \
		-B $(STATUSQ_BUILD_PATH) \
		-S $(STATUSQ_SOURCE_PATH) \
		$(HANDLE_OUTPUT)
	echo -e "\033[92mBuilding:\033[39m StatusQ SanityChecker"
	cmake \
		--build $(STATUSQ_BUILD_PATH) \
		--target SanityChecker \
		$(HANDLE_OUTPUT)

run-statusq-sanity-checker: statusq-sanity-checker
	echo -e "\033[92mRunning:\033[39m StatusQ SanityChecker"
	$(STATUSQ_BUILD_PATH)/bin/SanityChecker

statusq-tests:
	echo -e "\033[92mConfiguring:\033[39m StatusQ Unit Tests"
	cmake \
		-DSTATUSQ_BUILD_SANITY_CHECKER=OFF \
		-DSTATUSQ_BUILD_TESTS=ON \
		-DSTATUSQ_SHADOW_BUILD=OFF \
		$(COMMON_CMAKE_CONFIG_PARAMS) \
		-B $(STATUSQ_BUILD_PATH) \
		-S $(STATUSQ_SOURCE_PATH) \
		$(HANDLE_OUTPUT)
	echo -e "\033[92mBuilding:\033[39m StatusQ Unit Tests"
	cmake \
		--build $(STATUSQ_BUILD_PATH) \
		$(HANDLE_OUTPUT)

run-statusq-tests: export QTWEBENGINE_CHROMIUM_FLAGS := "${QTWEBENGINE_CHROMIUM_FLAGS} --disable-seccomp-filter-sandbox"
run-statusq-tests: statusq-tests
	echo -e "\033[92mRunning:\033[39m StatusQ Unit Tests"
	ctest -V --test-dir $(STATUSQ_BUILD_PATH) ${ARGS}

##
##	Storybook
##

STORYBOOK_SOURCE_PATH := storybook
STORYBOOK_BUILD_PATH := $(STORYBOOK_SOURCE_PATH)/build/Qt$(QT_VERSION)
STORYBOOK_CMAKE_CACHE := $(STORYBOOK_BUILD_PATH)/CMakeCache.txt
ifeq ($(mkspecs),macx)
 STORYBOOK_BINARY := $(STORYBOOK_BUILD_PATH)/bin/Storybook.app/Contents/MacOS/Storybook
else
 STORYBOOK_BINARY := $(STORYBOOK_BUILD_PATH)/bin/Storybook
endif

$(STORYBOOK_CMAKE_CACHE): | check-qt-dir
	echo -e "\033[92mConfiguring:\033[39m Storybook"
	cmake \
		-DCMAKE_INSTALL_PREFIX=$(STORYBOOK_INSTALL_PATH) \
		-DCMAKE_BUILD_TYPE=$(COMMON_CMAKE_BUILD_TYPE) \
		-DSTATUSQ_SHADOW_BUILD=OFF \
		$(COMMON_CMAKE_CONFIG_PARAMS) \
		-B $(STORYBOOK_BUILD_PATH) \
		-S $(STORYBOOK_SOURCE_PATH) \
		-Wno-dev \
		$(HANDLE_OUTPUT)

storybook-configure: | $(STORYBOOK_CMAKE_CACHE)

storybook-build: | storybook-configure
	echo -e "\033[92mBuilding:\033[39m Storybook"
	cmake --build $(STORYBOOK_BUILD_PATH) \
		--config $(COMMON_CMAKE_BUILD_TYPE) \
		$(HANDLE_OUTPUT)

run-storybook: storybook-build
	echo -e "\033[92mRunning:\033[39m Storybook"
	$(STORYBOOK_BINARY) ${ARGS}

run-storybook-tests: storybook-build
	echo -e "\033[92mRunning:\033[39m Storybook Tests"
	ctest -V --test-dir $(STORYBOOK_BUILD_PATH) -E PagesValidator

# repeat because of https://bugreports.qt.io/browse/QTBUG-92236 (Qt < 5.15.4)
run-storybook-pages-validator: storybook-build
	echo -e "\033[92mRunning:\033[39m Storybook Pages Validator"
	ctest -V --test-dir $(STORYBOOK_BUILD_PATH) -R PagesValidator --repeat until-pass:3

storybook-clean:
	echo -e "\033[92mCleaning:\033[39m Storybook"
	rm -rf $(STORYBOOK_BUILD_PATH)

##
##	status-go
##

STATUSGO := $(STATUSGO_OUT)/build/bin/libstatus.$(LIB_EXT)
STATUSGO_LIBDIR := $(shell pwd)/$(STATUSGO_OUT)/build/bin
export STATUSGO_LIBDIR

# Maintain the output directory before anything writes into it: wiped on a pin
# bump (the resolved source root moves), artifacts dropped on a flag-set change
# — the pinned-mode rebuild stamp lives in status.nims. Developed mode: no-op
# (ADR 0003's FORCE arm owns it). Ordered after the platform sentinel so the
# two never race under -j.
statusgo-out: $(NIMBLE_SETUP_STAMP) | platform-cleanup
ifneq ($(STATUSGO_DEVELOPED),1)
	nim prepareStatusgo status.nims --key:"desktop-$(LIB_EXT)-$(or $(QT_ARCH),host)-dbg$(INCLUDE_DEBUG_SYMBOLS)" $(HANDLE_OUTPUT)
endif
.PHONY: statusgo-out

# statusgo.nimble carries the nim-sds pin: a pin bump must invalidate the built
# lib. In pinned mode the bump changes the resolved store path, which makes
# statusgo-out wipe the whole output directory; nimble.paths is the resolution
# the task builds against, so it joins the prerequisites directly (it is no
# longer copied anywhere).
$(NIMSDS_LIBFILE): $(wildcard vendor/status-go/statusgo.nimble) nimble.paths | statusgo-out platform-cleanup
	echo -e $(BUILD_MSG) "libsds"
	$(STATUSGO_TASK_ENV) nim libsds $(STATUSGO_SRC)/statusgo.nims $(HANDLE_OUTPUT)

# GENERATE_PREREQ=: status-go commits the generated Go sources its library
# build needs, so no protoc/mockgen is required here — and `make generate`
# would try to write into the read-only store copy. STATUS_GO_VERSION is the
# DESKTOP version on purpose: see buildLibstatus() in status_artifacts.nims.
$(STATUSGO): | check-qt-dir bottles $(NIMSDS_LIBFILE) statusgo-out platform-cleanup
	echo -e $(BUILD_MSG) "status-go"
	# FIXME: Nix shell usage breaks builds due to Glibc mismatch.
	$(STATUSGO_MAKE_PARAMS) $(MAKE) -C $(STATUSGO_SRC) statusgo-shared-library SHELL=/bin/sh \
		STATUS_GO_BUILD_DIR="$(CURDIR)/$(STATUSGO_OUT)/build" \
		GENERATE_PREREQ= \
		STATUS_GO_VERSION="$(DESKTOP_VERSION)" \
		SENTRY_CONTEXT_NAME="status-desktop" \
		SENTRY_CONTEXT_VERSION="$(DESKTOP_VERSION)" \
		 $(HANDLE_OUTPUT)

status-go: $(STATUSGO)

status-go-clean:
	echo -e "\033[92mCleaning:\033[39m status-go"
	rm -f $(STATUSGO)
	rm -rf $(STATUSGO_OUT)


##
##	status-keycard-qt (Qt/C++ based keycard library)
##

# status-keycard-qt is a pinned CMake FetchContent vendor (issue 0011): the
# pin lives in cmake/status-keycard-qt/CMakeLists.txt and the pinned sources
# land under the build tree (_deps) — no vendor checkout exists in default
# mode. `nim develop status.nims status-keycard-qt` / `… keycard-qt` (issues
# 0009/0011) materializes vendor/<name> and the recipe below redirects the
# matching FetchContent to it; develop state is derived from nimble.overlay
# (same pattern as STATUSGO_SRC above). Both knobs stay user-overridable
# (?=) to point at any local folder, matching the pre-0011 behavior.
STATUS_KEYCARD_QT_DEVELOPED := $(shell grep -sqx status-keycard-qt nimble.overlay 2>/dev/null && echo 1)
KEYCARD_QT_DEVELOPED := $(shell grep -sqx keycard-qt nimble.overlay 2>/dev/null && echo 1)
ifeq ($(STATUS_KEYCARD_QT_DEVELOPED),1)
STATUS_KEYCARD_QT_SOURCE_DIR ?= vendor/status-keycard-qt
else
STATUS_KEYCARD_QT_SOURCE_DIR ?=
endif
ifeq ($(KEYCARD_QT_DEVELOPED),1)
KEYCARD_QT_SOURCE_DIR ?= vendor/keycard-qt
else
KEYCARD_QT_SOURCE_DIR ?=
endif

# Determine build directory based on platform (out of the source tree; the
# pre-0011 location was inside the submodule)
ifeq ($(mkspecs),macx)
STATUS_KEYCARD_QT_BUILD_DIR := build/status-keycard-qt/macos
STATUS_KEYCARD_QT_CMAKE_PARAMS += -DOPENSSL_ROOT_DIR=$(BOTTLES_DIR)/openssl@3 -DOPENSSL_USE_STATIC_LIBS=ON
else ifeq ($(mkspecs),win32)
STATUS_KEYCARD_QT_BUILD_DIR := build/status-keycard-qt/windows
WIN_OPENSSL_ROOT ?= C:/ProgramData/scoop/apps/openssl-lts/current
STATUS_KEYCARD_QT_CMAKE_PARAMS += -DOPENSSL_ROOT_DIR=$(WIN_OPENSSL_ROOT) -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON
else
STATUS_KEYCARD_QT_BUILD_DIR := build/status-keycard-qt/linux
endif

ifeq ($(USE_SIMULATED_KEYCARD),true)
STATUS_KEYCARD_QT_BUILD_DIR := $(STATUS_KEYCARD_QT_BUILD_DIR)-simulated-keycard
STATUS_KEYCARD_QT_CMAKE_PARAMS += -DUSE_SIMULATED_KEYCARD=ON
endif

STATUSKEYCARD_QT_LIB_PREFIX := lib
STATUSKEYCARD_QT_LIB_SUBDIR :=
ifeq ($(mkspecs),win32)
STATUSKEYCARD_QT_LIB_PREFIX :=
STATUSKEYCARD_QT_LIB_SUBDIR := /$(COMMON_CMAKE_BUILD_TYPE)
endif
# Note: config.nims derives the same STATUSKEYCARD_QT_LIBDIR itself (issue 0013);
# these exports are what the mobile legs and the packaging scripts still read.
# Absolute (issue 0013): config.nims derives the same value, and the client
# bakes it as an rpath — a relative rpath only resolves from the repo root.
export STATUSKEYCARD_QT_LIBDIR := $(CURDIR)/$(STATUS_KEYCARD_QT_BUILD_DIR)$(STATUSKEYCARD_QT_LIB_SUBDIR)
# Alias under the variable's pre-rename spelling: in a nested git worktree
# Nim's parent-dir config walk also evaluates the ENCLOSING checkout's
# config.nims, and on branches still using STATUSKEYCARDGO_LIBDIR an empty
# value emits a bare `-rpath` — ld then eats the next linker arg and fails
# with "file cannot be mmap()ed" on bin/StatusQ.
export STATUSKEYCARDGO_LIBDIR := $(STATUSKEYCARD_QT_LIBDIR)
export STATUSKEYCARD_QT_LIB := $(STATUSKEYCARD_QT_LIBDIR)/$(STATUSKEYCARD_QT_LIB_PREFIX)status-keycard-qt.$(LIB_EXT)

KEYCARD_SIM_SRC_DIR := $(STATUS_KEYCARD_QT_SOURCE_DIR)/test/keycard-simulator
KEYCARD_SIM_RUNTIME_BITS := run.sh libs versions out

keycard-simulator:
	echo -e $(BUILD_MSG) "keycard-simulator (precompile)"
	bash scripts/precompile-keycard-simulator.sh $(KEYCARD_SIM_SRC_DIR)

keycard-simulator-bundle:
	mkdir -p $(KEYCARD_SIM_DEST)
	cp -R $(addprefix $(KEYCARD_SIM_SRC_DIR)/,$(KEYCARD_SIM_RUNTIME_BITS)) $(KEYCARD_SIM_DEST)/

status-keycard-qt: $(STATUSKEYCARD_QT_LIB)
# The FETCHCONTENT_SOURCE_DIR_* pair is ALWAYS passed (empty value = pinned
# fetch; verified: cmake treats an empty cache value as unset) so a develop /
# undevelop flip can never leave a stale redirect in the cmake cache.
$(STATUSKEYCARD_QT_LIB): | check-qt-dir bottles
	echo -e $(BUILD_MSG) "status-keycard-qt"
	  cmake -S cmake/status-keycard-qt -B "${STATUS_KEYCARD_QT_BUILD_DIR}" \
		-DCMAKE_BUILD_TYPE=$(COMMON_CMAKE_BUILD_TYPE) \
		$(COMMON_CMAKE_CONFIG_PARAMS) \
		$(STATUS_KEYCARD_QT_CMAKE_PARAMS) \
		-DBUILD_TESTING=OFF \
		-DBUILD_EXAMPLES=OFF \
		-DBUILD_SHARED_LIBS=ON \
		"-DFETCHCONTENT_SOURCE_DIR_STATUS-KEYCARD-QT=$(if $(STATUS_KEYCARD_QT_SOURCE_DIR),$(abspath $(STATUS_KEYCARD_QT_SOURCE_DIR)))" \
		"-DFETCHCONTENT_SOURCE_DIR_KEYCARD-QT=$(if $(KEYCARD_QT_SOURCE_DIR),$(abspath $(KEYCARD_QT_SOURCE_DIR)))" \
		$(HANDLE_OUTPUT)
	cmake --build $(STATUS_KEYCARD_QT_BUILD_DIR) --target status-keycard-qt --config $(COMMON_CMAKE_BUILD_TYPE) $(HANDLE_OUTPUT)

status-keycard-qt-clean:
	echo -e "\033[92mCleaning:\033[39m status-keycard-qt"
	rm -rf $(STATUS_KEYCARD_QT_BUILD_DIR)

# The Windows MSVC import libraries (status.lib, sds.lib, synthesized from the
# c-shared headers by scripts/gen-import-lib.sh) are built by the driver since
# issue 0017 — `genImportLib` in status_artifacts.nims, keyed on the DLL's
# content. They exist for the client link, which the driver owns.

# QR-Code-generator has no target here since issue 0016: the Nim wrapper that
# binds it ({.compile.} in src/app/global/utils/qrcodegen.nim) compiles the C
# source into whatever binary consumes it. The mobile Makefile still builds its
# own libqrcodegen.a; that leg is untouched this iteration.
# Named no-op alias kept so ci/Jenkinsfile.linux's `make qrcodegen` step keeps
# working until the pipelines move onto the driver (issue 0019).
qrcodegen:

# When modifying files that are not tracked in UI_SOURCES (see below),
# e.g. ui/shared/img/*.svg, REBUILD_UI=true can be supplied to `make` to ensure
# a rebuild of resources.rcc: `make REBUILD_UI=true run`
REBUILD_UI ?= false

ifeq ($(REBUILD_UI),true)
 $(shell touch ui/main.qml)
endif

ifeq ($(host_os),darwin)
 UI_SOURCES := $(shell find -E ui -type f -iregex '.*(qmldir|qml|qrc|js)$$' -not -iname 'resources.qrc')
else
 UI_SOURCES := $(shell find ui -type f -regextype egrep -iregex '.*(qmldir|qml|qrc|js)$$' -not -iname 'resources.qrc')
endif

UI_RESOURCES := resources.rcc

# `compile-translations` is NOT a prerequisite since issue 0016: it is a
# maintainer command (`nim compileTranslations status.nims`), not a build step.
# The .qm catalogs it produces are picked up by ui/generate-rcc.go when present.
$(UI_RESOURCES): $(UI_SOURCES) | check-qt-dir
	echo -e $(BUILD_MSG) "resources.rcc"
	rm -f ./resources.rcc
	rm -f ./ui/resources.qrc ./ui/resources_webscripts.qrc
	go run ui/generate-rcc.go -source=ui -output=ui/resources.qrc -webscripts-output=ui/resources_webscripts.qrc
	rcc -binary $(RCC_PARAMS) ui/resources.qrc ui/resources_webscripts.qrc -o ./resources.rcc

rcc: $(UI_RESOURCES)

TS_SOURCE_DIR := ui/i18n
TS_BUILD_DIR := $(TS_SOURCE_DIR)/build
# QT_INSTALL_PREFIX points to the target (android_arm64_v8a) Qt which lacks LinguistTools.
QT_HOST_PREFIX := $(shell $(QMAKE) -query QT_HOST_PREFIX 2>/dev/null)
TS_CMAKE_PARAMS := -DCMAKE_PREFIX_PATH=$(or $(QT_HOST_PREFIX),$(QT_INSTALL_PREFIX))

log-update-translations:
	echo -e "\033[92mUpdating:\033[39m translations"

update-translations: | log-update-translations
	cmake -S $(TS_SOURCE_DIR) -B $(TS_BUILD_DIR) -Wno-dev $(TS_CMAKE_PARAMS) $(HANDLE_OUTPUT)
	cmake --build $(TS_BUILD_DIR) --target update_application_translations $(HANDLE_OUTPUT)

log-compile-translations:
	echo -e "\033[92mCompiling:\033[39m translations"

compile-translations: | update-translations log-compile-translations
	cmake -S $(TS_SOURCE_DIR) -B $(TS_BUILD_DIR) -Wno-dev $(TS_CMAKE_PARAMS) $(HANDLE_OUTPUT)
	cmake --build $(TS_BUILD_DIR) --target compile_application_translations $(HANDLE_OUTPUT)

clean-translations:
	rm -rf $(TS_BUILD_DIR)

# used to override the default number of kdf iterations for sqlcipher; read by
# config.nims (which owns the client's flag set since issue 0013).
KDF_ITERATIONS ?= 0

RESOURCES_LAYOUT ?= -d:development

# REBUILD_NIM is gone with the client rule (issue 0017). Its two jobs are now
#   - `nim app status.nims --force`            (the human's explicit rebuild)
#   - a developed vendor whose Nim sources compile INTO the client, which the
#     driver forces by itself (applyDevelopModeArms).

STATUS_RC_FILE := status.rc

# Building the resource files for windows to set the icon
compile_windows_resources:
	windres $(STATUS_RC_FILE) -o status.o

# --- the client binary: built by the driver, consumed here --------------------
#
# `nim app status.nims` compiles the client (issue 0016) with the flag set
# config.nims owns for EVERY platform (issue 0013 + 0017's Windows port), gates
# the relink on `.status-client.key` (which absorbed `.qmake_previous`), and
# orchestrates every artifact it links. The Makefile's own client rule, its
# `NIM_PARAMS` flag soup, `.qmake_previous`, `NIM_SOURCES`, `.update.timestamp`
# and `REBUILD_NIM` are gone with it.
#
# Packaging recipes therefore ASK the driver for a binary — `nim app
# status.nims`, with the production RESOURCES_LAYOUT exported — instead of
# carrying a second compile. That is a driver dispatch, not a Nim compile: the
# invariant (scripts/check-no-nim-compiles.sh) forbids `nim c` / `nim e` /
# $(ENV_SCRIPT), which no longer appear anywhere in this file.
STATUSQ_LIB_PATH := $(STATUSQ_INSTALL_PATH)/StatusQ
EXTRA_LIBS_PATH := $(STATUSQ_BUILD_PATH)/lib
ifeq ($(mkspecs),win32)
 STATUSQ_LIB_PATH := $(STATUSQ_BUILD_PATH)/lib/$(COMMON_CMAKE_BUILD_TYPE)
endif
# config.nims prefers an exported value and derives the identical one without it
# (STATUS_BUILD_ENV_ASSERT=1 turns the preference into a hard comparison). These
# exports keep the packaging recipes and the mobile legs authoritative for the
# knobs a release sets.
export RESOURCES_LAYOUT
export INCLUDE_DEBUG_SYMBOLS
export KDF_ITERATIONS
export OUTPUT_CSV
export QT_ARCH

# The driver build a packaging target asks for. RESOURCES_LAYOUT is part of the
# client key, so flipping it to -d:production relinks by construction — the old
# `rm bin/nim_status_client` dance is unnecessary. Every artifact that runs this
# takes the `FORCE` prerequisite, so make can never skip the dispatch.
STATUS_CLIENT_BUILD := nim app status.nims

ifdef IN_NIX_SHELL
APPIMAGE_TOOL := appimagetool
else
APPIMAGE_TOOL := tmp/linux/tools/appimagetool
endif

_APPIMAGE_TOOL := appimagetool-x86_64.AppImage
$(APPIMAGE_TOOL):
ifndef IN_NIX_SHELL
	echo -e "\033[92mFetching:\033[39m appimagetool"
	rm -rf tmp/linux
	mkdir -p tmp/linux/tools
	wget -nv https://github.com/AppImage/appimagetool/releases/download/continuous/$(_APPIMAGE_TOOL)
	mv $(_APPIMAGE_TOOL) $(APPIMAGE_TOOL)
	chmod +x $(APPIMAGE_TOOL)
endif

STATUS_CLIENT_APPIMAGE ?= pkg/Status.AppImage
STATUS_CLIENT_TARBALL ?= pkg/Status.tar.gz
STATUS_CLIENT_TARBALL_FULL ?= $(shell realpath $(STATUS_CLIENT_TARBALL))

ifeq ($(mkspecs),linux)
 export FCITX5_QT := vendor/fcitx5-qt/build/qt$(QT_MAJOR_VERSION)/platforminputcontext/libfcitx5platforminputcontextplugin.so
 FCITX5_QT_CMAKE_PARAMS := -DCMAKE_BUILD_TYPE=Release -DBUILD_ONLY_PLUGIN=ON -DENABLE_QT4=OFF
 FCITX5_QT_CMAKE_PARAMS += -DENABLE_QT5=OFF -DENABLE_QT6=ON
 FCITX5_QT_BUILD_CMD := cmake --build . --config Release $(HANDLE_OUTPUT)
endif

$(FCITX5_QT): | check-qt-dir bottles
	echo -e $(BUILD_MSG) "fcitx5-qt"
	+ cd vendor/fcitx5-qt && \
		mkdir -p build && \
		cd build && \
		rm -f CMakeCache.txt && \
		cmake $(FCITX5_QT_CMAKE_PARAMS) \
			.. $(HANDLE_OUTPUT) && \
		$(FCITX5_QT_BUILD_CMD)

PRODUCTION_PARAMETERS ?= -d:production

export APP_DIR := tmp/linux/dist

$(STATUS_CLIENT_APPIMAGE): override RESOURCES_LAYOUT := $(PRODUCTION_PARAMETERS)
$(STATUS_CLIENT_APPIMAGE): $(APPIMAGE_TOOL) nim-status.desktop $(FCITX5_QT) FORCE
	$(STATUS_CLIENT_BUILD)
	rm -rf pkg/*.AppImage
	chmod -R u+w tmp || true

ifeq ($(USE_SIMULATED_KEYCARD),true)
	$(MAKE) keycard-simulator
endif
	scripts/init_app_dir.sh
ifeq ($(USE_SIMULATED_KEYCARD),true)
	$(MAKE) keycard-simulator-bundle KEYCARD_SIM_DEST=$(APP_DIR)/usr/share/keycard-simulator
endif

	echo -e $(BUILD_MSG) "AppImage"

	linuxdeployqt $(APP_DIR)/nim-status.desktop \
		-no-copy-copyright-files \
		-qmldir=ui -qmlimport=$(QT_QMLDIR) \
		-bundle-non-qt-libs \
		-exclude-libs=libgmodule-2.0.so.0,libgthread-2.0.so.0,libqsqlmimer,libqsqlmysql,libqsqlibase,libqsqloci \
		-verbose=1 \
		-executable=$(APP_DIR)/usr/bin/pcscd \
		-executable=$(APP_DIR)/usr/libexec/QtWebEngineProcess

	scripts/fix_app_dir.sh

	rm $(APP_DIR)/AppRun
	cp AppRun $(APP_DIR)/.

	mkdir -p pkg
	$(APPIMAGE_TOOL) $(APP_DIR) $(STATUS_CLIENT_APPIMAGE)

# Fix rpath and interpreter for AppImage
ifdef IN_NIX_SHELL
	patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 $(STATUS_CLIENT_APPIMAGE)
	patchelf --remove-rpath $(STATUS_CLIENT_APPIMAGE)
endif

# if LINUX_GPG_PRIVATE_KEY_FILE is not set then we don't generate a signature
ifdef LINUX_GPG_PRIVATE_KEY_FILE
	scripts/sign-linux-file.sh $(STATUS_CLIENT_APPIMAGE)
endif

$(STATUS_CLIENT_TARBALL): $(STATUS_CLIENT_APPIMAGE)
	cd $(shell dirname $(STATUS_CLIENT_APPIMAGE)) && \
	tar czvf $(STATUS_CLIENT_TARBALL_FULL) --ignore-failed-read \
		$(shell basename $(STATUS_CLIENT_APPIMAGE)){,.asc}
ifdef LINUX_GPG_PRIVATE_KEY_FILE
	scripts/sign-linux-file.sh $(STATUS_CLIENT_TARBALL)
endif

# Flatpak build configuration. Defined here so scripts/bundle-flatpak.sh
# can read them from the environment without its own defaults.
#   STATUS_CLIENT_FLATPAK : final single-file bundle produced by `flatpak build-bundle`
#   FLATPAK_BUILD_DIR     : flatpak-builder's working dir; mirrors the in-sandbox /app at build time
#   FLATPAK_REPO_DIR      : OSTree repo populated by flatpak-builder; input to `flatpak build-bundle`
export STATUS_CLIENT_FLATPAK ?= pkg/status-desktop.flatpak
export FLATPAK_BUILD_DIR     ?= tmp/linux/flatpak/build-dir
export FLATPAK_REPO_DIR      ?= tmp/linux/flatpak/repo

flatpak: $(STATUS_CLIENT_FLATPAK)
$(STATUS_CLIENT_FLATPAK): FORCE
	$(STATUS_CLIENT_BUILD)
	echo -e $(BUILD_MSG) "Flatpak"
	DESKTOP_VERSION="$(DESKTOP_VERSION)" scripts/bundle-flatpak.sh

flatpak-install: $(STATUS_CLIENT_FLATPAK)
	flatpak install --user -y --reinstall $(STATUS_CLIENT_FLATPAK)

flatpak-run: flatpak-install
	flatpak run app.status.desktop

flatpak-clean:
	rm -rf tmp/linux/flatpak pkg/*.flatpak

# Regenerates the precompiled macOS app icons (resources/macos/*Assets.car) from the Icon Composer documents (resources/macos/*.icon)
macos-icon-assets:
	xcrun actool resources/macos/Status.icon --compile resources/macos \
		--platform macosx --minimum-deployment-target 12.0 \
		--app-icon Status --output-partial-info-plist /dev/null
	rm -f resources/macos/Status.icns
	xcrun actool resources/macos/StatusDev.icon --compile resources/macos/dev \
		--platform macosx --minimum-deployment-target 12.0 \
		--app-icon StatusDev --output-partial-info-plist /dev/null
	rm -f resources/macos/dev/StatusDev.icns

MACOS_OUTER_BUNDLE := tmp/macos/dist/Status.app
MACOS_INNER_BUNDLE := $(MACOS_OUTER_BUNDLE)/Contents/Frameworks/QtWebEngineCore.framework/Versions/Current/Helpers/QtWebEngineProcess.app

STATUS_CLIENT_DMG ?= pkg/Status.dmg

$(STATUS_CLIENT_DMG): override RESOURCES_LAYOUT := $(PRODUCTION_PARAMETERS)
$(STATUS_CLIENT_DMG): ENTITLEMENTS ?= resources/Entitlements.plist
$(STATUS_CLIENT_DMG): FORCE
	$(STATUS_CLIENT_BUILD)
	rm -rf tmp/macos pkg/*.dmg
	mkdir -p $(MACOS_OUTER_BUNDLE)/Contents/MacOS
	mkdir -p $(MACOS_OUTER_BUNDLE)/Contents/Resources
	cp Info.plist $(MACOS_OUTER_BUNDLE)/Contents/
	cp bin/nim_status_client $(MACOS_OUTER_BUNDLE)/Contents/MacOS/
	cp status.icns $(MACOS_OUTER_BUNDLE)/Contents/Resources/
	cp resources/macos/Assets.car $(MACOS_OUTER_BUNDLE)/Contents/Resources/
	cp status-macos.svg $(MACOS_OUTER_BUNDLE)/Contents/
	cp -R resources.rcc $(MACOS_OUTER_BUNDLE)/Contents/

ifeq ($(USE_SIMULATED_KEYCARD),true)
	$(MAKE) keycard-simulator
	$(MAKE) keycard-simulator-bundle KEYCARD_SIM_DEST=$(MACOS_OUTER_BUNDLE)/Contents/Resources/keycard-simulator
endif

	echo -e $(BUILD_MSG) "app"
	MAC_QTQMLDIR=$(shell $(QMAKE) -query QT_INSTALL_QML) && \
	macdeployqt \
		$(MACOS_OUTER_BUNDLE) \
		-executable=$(MACOS_OUTER_BUNDLE)/Contents/MacOS/nim_status_client \
		-qmldir=ui \
		-qmlimport=$$MAC_QTQMLDIR \
	macdeployqt \
		$(MACOS_INNER_BUNDLE) \
		-executable=$(MACOS_INNER_BUNDLE)/Contents/MacOS/QtWebEngineProcess

	# if MACOS_CODESIGN_IDENT is not set then the outer and inner .app
	# bundles are not signed
ifdef MACOS_CODESIGN_IDENT
	scripts/sign-macos-pkg.sh $(MACOS_OUTER_BUNDLE) $(MACOS_CODESIGN_IDENT) \
		--entitlements $(ENTITLEMENTS)
endif
	echo -e $(BUILD_MSG) "dmg"
	mkdir -p pkg
	nix shell .#dmgbuild \
		-c dmgbuild -s scripts/dmg-settings.py -D app=$(MACOS_OUTER_BUNDLE) "Status" pkg/Status.dmg
	mv "`ls pkg/*.dmg`" $(STATUS_CLIENT_DMG)

ifdef MACOS_CODESIGN_IDENT
	scripts/sign-macos-pkg.sh $(STATUS_CLIENT_DMG) $(MACOS_CODESIGN_IDENT)
endif

notarize-macos: export CHECK_TIMEOUT ?= 10m
notarize-macos: export MACOS_BUNDLE_ID ?= im.status.ethereum.desktop
notarize-macos:
	scripts/notarize-macos-pkg.sh $(STATUS_CLIENT_DMG)

# The Windows launcher is a driver task (issue 0017):
#     nim windowsLauncher status.nims
STATUS_CLIENT_EXE ?= pkg/Status.exe
STATUS_CLIENT_7Z ?= pkg/Status.7z

$(STATUS_CLIENT_EXE): override RESOURCES_LAYOUT := $(PRODUCTION_PARAMETERS)
$(STATUS_CLIENT_EXE): OUTPUT := tmp/windows/dist/Status
$(STATUS_CLIENT_EXE): INSTALLER_OUTPUT := pkg
$(STATUS_CLIENT_EXE): compile_windows_resources FORCE
	$(STATUS_CLIENT_BUILD)
	nim windowsLauncher status.nims
	rm -rf pkg/*.exe tmp/windows/dist
	mkdir -p $(OUTPUT)/bin $(OUTPUT)/resources $(OUTPUT)/vendor $(OUTPUT)/bin/plugins/tls
	cat windows-install.txt | unix2dos > $(OUTPUT)/INSTALL.txt
	cp status.ico status.png resources.rcc $(OUTPUT)/resources/
	cp cacert.pem $(OUTPUT)/bin/cacert.pem
	cp bin/nim_status_client.exe $(OUTPUT)/bin/Status.exe
	cp bin/nim_windows_launcher.exe $(OUTPUT)/Status.exe
	rcedit $(OUTPUT)/bin/Status.exe --set-icon $(OUTPUT)/resources/status.ico
	rcedit $(OUTPUT)/Status.exe --set-icon $(OUTPUT)/resources/status.ico
	cp $(STATUSGO) $(STATUSKEYCARD_QT_LIB) $(NIMSDS_LIBFILE) $(STATUSQ_LIB_PATH)/* $(STATUSQ_BUILD_PATH)/bin/$(COMMON_CMAKE_BUILD_TYPE)/* $(OUTPUT)/bin/
	cp "$(shell which libstdc++-6.dll)"     $(OUTPUT)/bin/
	cp "$(shell which libgcc_s_seh-1.dll)"  $(OUTPUT)/bin/
	cp "$(shell which libwinpthread-1.dll)" $(OUTPUT)/bin/
	cp "$(shell which libcrypto-3-x64.dll)" $(OUTPUT)/bin/
	cp "$(shell which libssl-3-x64.dll)"    $(OUTPUT)/bin/
ifeq ($(USE_SIMULATED_KEYCARD),true)
	$(MAKE) keycard-simulator
	$(MAKE) keycard-simulator-bundle KEYCARD_SIM_DEST=$(OUTPUT)/resources/keycard-simulator
endif
	echo -e $(BUILD_MSG) "deployable folder"
	VCINSTALLDIR="$(VCINSTALLDIR)" windeployqt --compiler-runtime --qmldir ui --release \
		tmp/windows/dist/Status/bin/Status.exe
	mv tmp/windows/dist/Status/bin/vc_redist.x64.exe tmp/windows/dist/Status/vendor/
	cp status.iss $(OUTPUT)/status.iss
	cp $(QT_INSTALL_PREFIX)/plugins/tls/qopensslbackend.dll $(OUTPUT)/bin/plugins/tls/
# if WINDOWS_CODESIGN_PFX_PATH is not set then DLLs, EXEs are not signed
ifdef WINDOWS_CODESIGN_PFX_PATH
	scripts/sign-windows-bin.sh ./tmp/windows/dist/Status
endif
	echo -e $(BUILD_MSG) "exe"
	mkdir -p $(INSTALLER_OUTPUT)
	ISCC \
	   -O"$(INSTALLER_OUTPUT)" \
	   -D"BaseName=$(shell basename $(STATUS_CLIENT_EXE) .exe)" \
	   -D"Version=$(DESKTOP_VERSION)" \
	   $(OUTPUT)/status.iss
ifdef WINDOWS_CODESIGN_PFX_PATH
	scripts/sign-windows-bin.sh $(INSTALLER_OUTPUT)
endif

$(STATUS_CLIENT_7Z): OUTPUT := tmp/windows/dist/Status
$(STATUS_CLIENT_7Z): $(STATUS_CLIENT_EXE)
	echo -e $(BUILD_MSG) "7z"
	7z a $(STATUS_CLIENT_7Z) ./$(OUTPUT)

# pkg builds the production flavor of the client: RESOURCES_LAYOUT is part of
# the driver's client key, so the -d:production flip relinks by itself.
pkg:
	$(MAKE) $(PKG_TARGET)

pkg-linux: check-pkg-target-linux $(STATUS_CLIENT_APPIMAGE)

tgz-linux: $(STATUS_CLIENT_TARBALL)

clean-libsds-cache:
	@echo "Cleaning libsds_d from cache..."
	rm -rf ~/.cache/nim/libsds_d
pkg-macos: clean-libsds-cache check-pkg-target-macos $(STATUS_CLIENT_DMG)

pkg-windows: check-pkg-target-windows $(STATUS_CLIENT_EXE)

zip-windows: check-pkg-target-windows $(STATUS_CLIENT_7Z)

clean-destdir:
	rm -rf bin/*

# What survives of NBS's `clean-common`: the nimcache. (Its other targets — the
# vendored compiler, the fake vendor/.nimble link dir, the nat-traversal C libs —
# no longer exist.)
clean-nimcache:
	rm -rf nimcache

# The driver's REPO-ROOT key files are all named `.status-<artifact>.key`
# (status_artifacts.nims states the convention), so this glob is total and there
# is no second list here to drift out of step with those consts (issue 0018
# review, I2). Key files that live inside a build tree (.status-cmake.key,
# .statusgo-artifact-key) go with the tree their vendor-clean target removes.
clean: | clean-nimcache clean-destdir statusq-clean status-go-clean status-keycard-qt-clean storybook-clean clean-translations
	rm -rf bottles/* pkg/* tmp/*
	rm -f .status-*.key
	rm -f .libsds.key   # legacy: the libsds key's pre-convention name (0018 fix wave)

clean-git:
	./scripts/clean-git.sh

force-rebuild-status-go:
	bash ./scripts/force-rebuild-status-go.sh $(STATUSGO)

# Repair wallet db migration marker: make fix-wallet-migrations <dbpath|datadir> <password>
# Without arguments it lists the wallet migrations the resolved status-go knows
# ($(STATUSGO_SRC): the resolved store copy, or the develop-mode checkout).
# NOTE: this recipe runs `go generate` IN the statusgo tree, so it needs a
# writable one — run it under `nim develop status.nims statusgo`. Against a
# store copy it will fail on a read-only filesystem (issue 0020).
ifeq (fix-wallet-migrations,$(firstword $(MAKECMDGOALS)))
FIX_WALLET_MIGRATIONS_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(FIX_WALLET_MIGRATIONS_ARGS):;@:)
endif

fix-wallet-migrations:
	cd $(STATUSGO_SRC) && go generate ./internal/db/walletdb/migrations/sql && go run ./cmd/fix-wallet-migrations \
		$(if $(FIX_WALLET_MIGRATIONS_ARGS),$(abspath $(word 1,$(FIX_WALLET_MIGRATIONS_ARGS))) $(word 2,$(FIX_WALLET_MIGRATIONS_ARGS)))

# `run`, `run-linux`, `run-linux-gdb`, `run-macos`, `run-windows` are DELETED
# (issue 0017): the driver's `run` task has owned the launch environment since
# issue 0013, and keeping both perpetuated two ways to run the app.
#
#     nim run status.nims          # build if needed + launch
#     nim app status.nims --force  # what `make REBUILD_NIM=true run` was
#
# The surviving `run-*` targets (run-storybook*, run-statusq-*) launch OTHER
# products and invoke no Nim compile; they stay.
#
# `tests-nim-linux` / `nim-test-run/%` are DELETED too — the Nim suite is a
# driver task that owns the library-path environment the suite needs:
#
#     nim tests status.nims                 # whole suite
#     nim tests status.nims utils_test      # one suite

define qmkq
$(shell $(QMAKE) -query $(1))
endef

export PATH := $(call qmkq,QT_INSTALL_BINS):$(call qmkq,QT_HOST_BINS):$(call qmkq,QT_HOST_LIBEXECS):$(PATH)
export QTDIR := $(call qmkq,QT_INSTALL_PREFIX)

mobile-run: qt-pkgconfig | $(NIMBLE_SETUP_STAMP)
	echo -e "\033[92mRunning:\033[39m mobile app"
	$(MAKE) -C mobile run DEBUG=1 GRADLE_TARGETS=assembleDebug

mobile-profile: qt-pkgconfig | $(NIMBLE_SETUP_STAMP)
ifeq ($(mkspecs),ios)
	@echo "TODO: iOS profiling is not implemented yet"; exit 1
else
	echo -e "\033[92mRunning:\033[39m mobile app (PROFILE)"
	$(MAKE) -C mobile run \
	    PROFILE=1 \
	    GRADLE_TARGETS=assembleProfile \
	    QML_DEBUG_PORT=$(QML_DEBUG_PORT)
endif

mobile-build: qt-pkgconfig | $(NIMBLE_SETUP_STAMP)
	echo -e "\033[92mBuilding:\033[39m mobile app ($(or $(PACKAGE_TYPE),default))"
ifeq ($(PACKAGE_TYPE),aab)
	$(MAKE) -C mobile aab
else ifeq ($(PACKAGE_TYPE),apk)
	$(MAKE) -C mobile apk
else ifeq ($(PACKAGE_TYPE),apk-aab)
	$(MAKE) -C mobile apk-aab
else
	$(MAKE) -C mobile all
endif

mobile-clean:
	echo -e "\033[92mCleaning:\033[39m mobile app"
	$(MAKE) -C mobile clean
