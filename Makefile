# Copyright (c) 2019-2020 Status Research & Development GmbH. Licensed under
# either of:
# - Apache License, version 2.0
# - MIT license
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

SHELL := bash # the shell used internally by Make

GIT_ROOT ?= $(shell git rev-parse --show-toplevel 2>/dev/null || echo .)

V ?= 0
NIM_PARAMS := $(NIMFLAGS) --verbosity:$(V)
HANDLE_OUTPUT :=
ifeq ($(V), 0)
  NIM_PARAMS += --hints:off
  HANDLE_OUTPUT := >/dev/null
.SILENT:
endif
ifdef LOG_LEVEL
  NIM_PARAMS += -d:chronicles_log_level="$(LOG_LEVEL)"
endif
BUILD_MSG := "\\x1B[92mBuilding:\\x1B[39m"

NIM := $(shell ./scripts/resolve-nim.sh)
export NIM

.PHONY: \
	all \
	fix-wallet-migrations \
	bottles \
	check-qt-dir \
	check-pkg-target-linux \
	check-pkg-target-macos \
	check-pkg-target-windows \
	clean \
	update-translations \
	compile-translations \
	deps \
	nim_status_client \
	seaqt-test \
	nim_windows_launcher \
	pkg \
	pkg-linux \
	pkg-macos \
	pkg-windows \
	run \
	run-linux \
	run-macos \
	run-windows \
	tests-nim \
	tests-nim-linux \
	benches-nim \
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
	update \
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
	nimble-deps

all: nim_status_client

# `qmake` path, either passed explicitely, or as found in PATH
# (makes it possible to override with a custom Qt6 install dir)
QMAKE ?= $(shell which qmake)
ifneq ($(QMAKE),$(shell which qmake))
 # Add it to PATH for external build tools that use qmake directly
 export PATH := $(patsubst %/,%,$(dir $(QMAKE))):$(PATH)
endif
QSPEC := $(shell $(QMAKE) -query QMAKE_XSPEC)
ifeq ($(QSPEC),macx-ios-clang)
mkspecs := ios
else ifeq ($(QSPEC),macx-clang)
mkspecs := macx
else ifeq ($(QSPEC),win32-msvc)
mkspecs := win32
else ifeq ($(QSPEC),linux-g++)
mkspecs := linux
else ifeq ($(QSPEC),android-clang)
mkspecs := android
endif

host_os:=$(shell uname -s | tr '[:upper:]' '[:lower:]')

ifeq ($(mkspecs),)
	$(error Cannot find your Qt installation. Please make sure to export correct Qt installation binaries path to PATH env)
endif

# The user's nimble, resolved before the pinned Nim's bin/ goes on PATH: that
# directory ships the older nimble bundled with Nim, which would shadow it.
NIMBLE := $(or $(shell command -v nimble 2>/dev/null),nimble)

# Sub-builds run a bare `nim` (statusgo.nims, qt-pkgconfig.mk). An empty NIM
# must not put `.` on PATH.
ifneq (,$(NIM))
 export PATH := $(patsubst %/,%,$(dir $(NIM))):$(PATH)
endif

# Link libm by default; the win32 branch below clears it (MSVC has no libm).
NIM_MATH_LIB := --passL:"-lm"

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
 RUN_TARGET := run-macos
 QT_ARCH ?= $(shell uname -m)
else ifeq ($(mkspecs),win32)
 LIB_EXT := dll
 PKG_TARGET := pkg-windows
 QRCODEGEN_MAKE_PARAMS := CC=gcc
 RUN_TARGET := run-windows
 # No libm on Windows/MSVC — math lives in the CRT, and lld-link has no `m.lib`.
 NIM_MATH_LIB :=
 # clang (--target=*-windows-msvc) locates the MSVC toolchain + Windows SDK itself
 # via vswhere, finding the CRT libs/headers with no vcvars setup. But its env probe
 # takes PRECEDENCE over that auto-detection: a LIB/INCLUDE/LIBPATH/VCINSTALLDIR
 # inherited from the shell overrides it with stale paths and breaks the link
 # ("could not open 'msvcrt.lib'") — even a valid VCINSTALLDIR misfires. Strip them
 # so clang always self-detects.
 unexport LIB
 unexport INCLUDE
 unexport LIBPATH
 unexport VCINSTALLDIR
else
 LIB_EXT := so
 PKG_TARGET := pkg-linux
 RUN_TARGET := run-linux
endif

# Fixes OpenGL issues at runtime on non-NixOS Linux distros.
# See See https://github.com/NixOS/nixpkgs/issues/9415
NIXOS := $(shell test -e /etc/NIXOS && echo 1)
ifeq ($(host_os),linux)
	ifndef NIXOS
		ifdef IN_NIX_SHELL
			NIXGL_WRAPPER ?= nixGLIntel
		endif
	endif
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

bottles: $(BOTTLES)
endif

deps: | check-qt-dir nimble-deps bottles

update: | check-qt-dir nimble-deps
	git submodule sync --quiet --recursive
	git submodule update --init --recursive
	+ "$(MAKE)" --no-print-directory qt-pkgconfig

QML_DEBUG ?= false
QML_DEBUG_PORT ?= 49152

ifneq ($(QML_DEBUG), false)
 COMMON_CMAKE_BUILD_TYPE=Debug
 NIM_PARAMS += -d:qmldebug -d:qmlDebugPort:$(QML_DEBUG_PORT) --passC:"-DQT_QML_DEBUG"
else
 COMMON_CMAKE_BUILD_TYPE=Release
endif

MONITORING ?= false
ifneq ($(MONITORING), false)
 STATUSQ_CMAKE_CONFIG_PARAMS += -DMONITORING:BOOL=ON -DMONITORING_QML_ENTRY_POINT:STRING="/../monitoring/Main.qml"
 NIM_PARAMS += -d:monitoring
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

# nimble fetches packages with `git submodule update`, a shell script: on Windows
# it must find Git's own sed first, or a foreign sed on PATH breaks it.
ifeq ($(mkspecs),win32)
 NIMBLE_ENV = PATH="$$(r=$$(cd "$$(git --exec-path)/../../.." && pwd); echo "$${r%/}/usr/bin"):$$PATH"
endif
# The stamp tracks "setup ran for this manifest and lock"; nimble.paths keeps its
# mtime when setup rewrites it unchanged, so libsds and the client are not
# rebuilt for a lock change that did not move anything they use. A failed setup
# leaves no half-written nimble.paths behind to pass for an up-to-date one.
.nimble-setup.stamp: nim_status_client.nimble nimble.lock
	echo -e $(BUILD_MSG) "Nim dependencies (nimble setup)"
	rm -f nimble.paths.prev; test ! -f nimble.paths || mv nimble.paths nimble.paths.prev
	$(NIMBLE_ENV) "$(NIMBLE)" -y setup || { rm -f nimble.paths; test ! -f nimble.paths.prev || mv nimble.paths.prev nimble.paths; \
		echo "ERROR: nimble setup failed. If a manifest changed, regenerate the lock with 'nimble lock' and retry." >&2; exit 1; }
	if cmp -s nimble.paths nimble.paths.prev; then mv nimble.paths.prev nimble.paths; else rm -f nimble.paths.prev; fi
	touch $@
nimble.paths: .nimble-setup.stamp
	@test -f $@ || { rm -f $<; "$(MAKE)" --no-print-directory $<; }
nimble-deps: nimble.paths

# Remade from nimble.paths; make then re-executes this Makefile, so the roots
# below are defined on the second pass.
-include .nimble-resolution.mk
.nimble-resolution.mk: nimble.paths scripts/nimble-resolution.sh
	./scripts/nimble-resolution.sh $< > $@

#-------- PKG_CONFIG wrapper for Qt's .pc files --------
# Included from the read-only store copy: its tool builds go to a repo-local
# scratch, never into the store.
ifneq (,$(PRL_TO_PC_ROOT))
QT_PC_BUILD_DIR := $(CURDIR)/.prl-to-pc-build/.pcwrap
QT_PC_CONSUMER_PATHS := $(CURDIR)/nimble.paths
include $(PRL_TO_PC_ROOT)/qt-pkgconfig.mk
endif
# -----------------------------------------------------

ifneq ($(mkspecs),win32)
 export QT_LIBDIR := $(shell $(QMAKE) -query QT_INSTALL_LIBS 2>/dev/null)
 QT_QMLDIR := $(shell $(QMAKE) -query QT_INSTALL_QML 2>/dev/null)
 # some manually installed Qt instances have wrong paths in their *.pc files, so we pass the right one to the linker here
 ifeq ($(mkspecs),macx)
  NIM_PARAMS += -L:"-framework Foundation -framework AppKit -framework Security -framework IOKit -framework CoreServices -framework LocalAuthentication"
  # Fix for failures due to 'can't allocate code signature data for'
  NIM_PARAMS += --passL:"-headerpad_max_install_names"
  NIM_PARAMS += --passL:"-F$(QT_LIBDIR)"

 else
  NIM_PARAMS += --passL:"-L$(QT_LIBDIR)"
  # GNU ld resolves transitive shared-lib deps (libStatusQ.so -> libQt6WebEngineQuick.so.6)
  # through -rpath-link, not -L; without it linking fails when Qt lives outside the
  # system library paths
  NIM_PARAMS += --passL:"-Wl,-rpath-link,$(QT_LIBDIR)"
 endif
 QT_SEAQT_EXTRA_LIBS = $(shell PKG_CONFIG_PATH="$(QT_PCFILEDIR)" PKG_CONFIG_PREFIX_OVERRIDE="Qt*=$(QT_PC_PREFIX)" $(QT_PC_PKGCONFIG) --libs Qt"$(QT_MAJOR_VERSION)"Core Qt"$(QT_MAJOR_VERSION)"Qml Qt"$(QT_MAJOR_VERSION)"Gui Qt"$(QT_MAJOR_VERSION)"Quick Qt"$(QT_MAJOR_VERSION)"QuickControls2 Qt"$(QT_MAJOR_VERSION)"Widgets Qt"$(QT_MAJOR_VERSION)"Svg Qt"$(QT_MAJOR_VERSION)"Multimedia Qt"$(QT_MAJOR_VERSION)"WebView Qt"$(QT_MAJOR_VERSION)"WebChannel)
else
 WIN_SYS_LIBS := --passL:"-luser32"
 NIM_EXTRA_PARAMS := $(WIN_SYS_LIBS)
endif

ifeq ($(mkspecs),win32)
 COMMON_CMAKE_CONFIG_PARAMS += -A x64
 NIM_PARAMS += -d:sslVersion=3-x64
 NIM_PARAMS += --cc:clang
 REAL_CLANG := $(shell command -v clang 2>/dev/null)
 NIM_PARAMS += --clang.exe:"$(REAL_CLANG)" --clang.linkerexe:"$(REAL_CLANG)"
 NIM_PARAMS += --passC:"--target=x86_64-pc-windows-msvc -fms-runtime-lib=dll"
 NIM_PARAMS += --passL:"--target=x86_64-pc-windows-msvc -fuse-ld=lld -fms-runtime-lib=dll"
endif

ifeq ($(mkspecs),macx)
 ifeq ("$(shell sysctl -nq hw.optional.arm64)","1")
   ifneq ($(QT_ARCH),arm64)
	STATUSGO_MAKE_PARAMS += GOBIN_SHARED_LIB_CFLAGS="CGO_ENABLED=1 GOOS=darwin GOARCH=amd64"
	COMMON_CMAKE_CONFIG_PARAMS += -DCMAKE_OSX_ARCHITECTURES=x86_64
	QRCODEGEN_MAKE_PARAMS += CFLAGS="-target x86_64-apple-macos10.12"
	NIM_PARAMS += --cpu:amd64 --os:MacOSX --passL:"-arch x86_64" --passC:"-arch x86_64"
  endif
 endif
endif

# STATUSGO_SRC (the store copy, or `make STATUSGO_SRC=/path/to/status-go`) is
# never written to: every status-go and libsds output goes under STATUSGO_OUT.
STATUSGO_OUT := .statusgo-build
export STATUSGO_SRC
NIMSDS_BUILD_ROOT := $(CURDIR)/$(STATUSGO_OUT)/.sds-build
NIMSDS_LIBDIR := $(NIMSDS_BUILD_ROOT)/build
# exported for init_app_dir.sh and bundle-flatpak.sh
export NIMSDS_LIBDIR
NIMSDS_INCDIR := $(NIMSDS_BUILD_ROOT)/library
NIMSDS_LIBFILE := $(NIMSDS_LIBDIR)/libsds.$(LIB_EXT)
NIM_EXTRA_PARAMS += --passL:"-L$(NIMSDS_LIBDIR)" --passL:"-lsds"
STATUSGO_MAKE_PARAMS += NIM_SDS_LIB_DIR="$(NIMSDS_LIBDIR)" NIM_SDS_INC_DIR="$(NIMSDS_INCDIR)"
STATUSGO_TASK_ENV := STATUSGO_BUILD_DIR="$(CURDIR)/$(STATUSGO_OUT)" STATUSGO_NIMBLE_PATHS="$(CURDIR)/nimble.paths"

# desktop only; mobile cleanup lives in mobile/Makefile
ifneq ($(filter $(mkspecs),macx linux),)
PLATFORM_TARGET := $(host_os)-$(or $(QT_ARCH),$(shell uname -m))
else ifeq ($(mkspecs),win32)
PLATFORM_TARGET := windows-$(or $(QT_ARCH),$(shell uname -m))
endif

# Order-only prerequisite: delete shared artifacts (qrcodegen, libsds, libstatus) when the build platform/arch changes.
platform-cleanup:
ifneq ($(PLATFORM_TARGET),)
	scripts/platform_pre_build_cleanup.sh "$(PLATFORM_TARGET)"
endif

INCLUDE_DEBUG_SYMBOLS ?= false
ifeq ($(INCLUDE_DEBUG_SYMBOLS),true)
 # We need `-d:debug` to get Nim's default stack traces
 NIM_PARAMS += -d:debug
 # Enable debugging symbols, in case we need GDB backtraces
 CFLAGS += -g
 CXXFLAGS += -g
 RCC_PARAMS = --no-compress
else
 # Additional optimization flags for release builds are not included at present;
 # adding them will involve refactoring config.nims in the root of this repo
 STATUSGO_MAKE_PARAMS += CGO_CFLAGS="-O3"
 NIM_PARAMS += -d:release -d:lto
endif

NIM_PARAMS += --outdir:./bin

# App version
DESKTOP_VERSION = $(shell ./scripts/version.sh)
# A store copy has no .git: its version is the short pin ("dev" under a file:// flip).
# STATUSGO_SRC is empty on a fresh clone's first parse, hence the guard.
STATUSGO_PIN := $(shell ./scripts/status-go-pin.sh 2>/dev/null)
ifneq (,$(STATUSGO_SRC))
 ifneq (,$(wildcard $(STATUSGO_SRC)/.git))
  STATUSGO_VERSION := $(shell $(MAKE) -C "$(STATUSGO_SRC)" version -s)
 endif
endif
STATUSGO_VERSION ?= $(if $(STATUSGO_PIN),$(shell printf '%.10s' "$(STATUSGO_PIN)"),dev)
export STATUSGO_VERSION
NIM_PARAMS += -d:DESKTOP_VERSION="$(DESKTOP_VERSION)"
NIM_PARAMS += -d:STATUSGO_VERSION="$(STATUSGO_VERSION)"

GIT_COMMIT=`git log --pretty=format:'%h' -n 1`
NIM_PARAMS += -d:GIT_COMMIT="$(GIT_COMMIT)"

OUTPUT_CSV ?= false
ifeq ($(OUTPUT_CSV), true)
  NIM_PARAMS += -d:output_csv
  $(shell touch .update.timestamp)
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
	$(NIXGL_WRAPPER) ctest -V --test-dir $(STATUSQ_BUILD_PATH) ${ARGS}

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
	$(NIXGL_WRAPPER) $(STORYBOOK_BINARY) ${ARGS}

run-storybook-tests: storybook-build
	echo -e "\033[92mRunning:\033[39m Storybook Tests"
	$(NIXGL_WRAPPER) ctest -V --test-dir $(STORYBOOK_BUILD_PATH) -E PagesValidator

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
STATUSGO_LIBDIR := $(CURDIR)/$(STATUSGO_OUT)/build/bin
export STATUSGO_LIBDIR

# .source-root and .build-key are rewritten only when their content changes, so
# the libraries rebuild only then. They must be NORMAL prerequisites: a wipe done
# by an order-only one would go unnoticed in the same run.
STATUSGO_BUILD_KEY := desktop-$(LIB_EXT)-$(or $(QT_ARCH),host)-dbg$(INCLUDE_DEBUG_SYMBOLS)
STATUSGO_KEYS := $(STATUSGO_OUT)/.source-root $(STATUSGO_OUT)/.build-key
$(STATUSGO_OUT)/.source-root: FORCE | platform-cleanup
	test -n "$(STATUSGO_SRC)" || { echo "ERROR: no status-go entry in nimble.paths (STATUSGO_SRC is empty); run 'make update'" >&2; exit 1; }
	test -f "$(STATUSGO_SRC)/statusgo.nims" || { echo "ERROR: $(STATUSGO_SRC) is not a status-go tree (no statusgo.nims)" >&2; exit 1; }
	if [ "$$(cat $@ 2>/dev/null)" != "$(STATUSGO_SRC)" ]; then \
		rm -rf $(STATUSGO_OUT) && mkdir -p $(STATUSGO_OUT) && printf '%s\n' "$(STATUSGO_SRC)" > $@; \
	fi
$(STATUSGO_OUT)/.build-key: $(STATUSGO_OUT)/.source-root FORCE
	if [ "$$(cat $@ 2>/dev/null)" != "$(STATUSGO_BUILD_KEY)" ]; then \
		rm -rf $(STATUSGO_OUT)/build $(NIMSDS_BUILD_ROOT) && printf '%s\n' "$(STATUSGO_BUILD_KEY)" > $@; \
	fi
FORCE:
.PHONY: FORCE

$(NIMSDS_LIBFILE): $(STATUSGO_KEYS) nimble.paths | platform-cleanup
	echo -e $(BUILD_MSG) "libsds"
	$(STATUSGO_TASK_ENV) "$(NIM)" libsds "$(STATUSGO_SRC)/statusgo.nims" $(HANDLE_OUTPUT)

# The library target generates its Go sources under STATUS_GO_BUILD_DIR (go build -overlay); needs protoc.
# STATUS_GO_VERSION is the desktop version on purpose (the library reports the product's version).
$(STATUSGO): $(STATUSGO_KEYS) | deps $(NIMSDS_LIBFILE) platform-cleanup
	echo -e $(BUILD_MSG) "status-go"
	# FIXME: Nix shell usage breaks builds due to Glibc mismatch.
	$(STATUSGO_MAKE_PARAMS) $(MAKE) -C "$(STATUSGO_SRC)" statusgo-shared-library SHELL=/bin/sh \
		STATUS_GO_BUILD_DIR="$(CURDIR)/$(STATUSGO_OUT)/build" \
		STATUS_GO_VERSION="$(DESKTOP_VERSION)" \
		SENTRY_CONTEXT_NAME="status-desktop" \
		SENTRY_CONTEXT_VERSION="$(DESKTOP_VERSION)" \
		 $(HANDLE_OUTPUT)

status-go: $(STATUSGO)

status-go-clean:
	echo -e "\033[92mCleaning:\033[39m status-go"
	rm -rf $(STATUSGO_OUT)


##
##	status-keycard-qt (Qt/C++ based keycard library)
##

# Allow using local status-keycard-qt for development
STATUS_KEYCARD_QT_SOURCE_DIR ?= vendor/status-keycard-qt
KEYCARD_QT_SOURCE_DIR ?= ""

# Determine build directory based on platform
ifeq ($(mkspecs),macx)
STATUS_KEYCARD_QT_BUILD_DIR := $(STATUS_KEYCARD_QT_SOURCE_DIR)/build/macos
STATUS_KEYCARD_QT_CMAKE_PARAMS += -DOPENSSL_ROOT_DIR=$(BOTTLES_DIR)/openssl@3 -DOPENSSL_USE_STATIC_LIBS=ON
else ifeq ($(mkspecs),win32)
STATUS_KEYCARD_QT_BUILD_DIR := $(STATUS_KEYCARD_QT_SOURCE_DIR)/build/windows
WIN_OPENSSL_ROOT ?= C:/ProgramData/scoop/apps/openssl-lts/current
STATUS_KEYCARD_QT_CMAKE_PARAMS += -DOPENSSL_ROOT_DIR=$(WIN_OPENSSL_ROOT) -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON
else
STATUS_KEYCARD_QT_BUILD_DIR := $(STATUS_KEYCARD_QT_SOURCE_DIR)/build/linux
endif

ifeq ($(USE_SIMULATED_KEYCARD),true)
STATUS_KEYCARD_QT_BUILD_DIR := $(STATUS_KEYCARD_QT_BUILD_DIR)-simulated-keycard
STATUS_KEYCARD_QT_CMAKE_PARAMS += -DUSE_SIMULATED_KEYCARD=ON
NIM_PARAMS += -d:useSimulatedKeycard
endif

STATUSKEYCARD_QT_LIB_PREFIX := lib
STATUSKEYCARD_QT_LIB_SUBDIR :=
ifeq ($(mkspecs),win32)
STATUSKEYCARD_QT_LIB_PREFIX :=
STATUSKEYCARD_QT_LIB_SUBDIR := /$(COMMON_CMAKE_BUILD_TYPE)
endif
export STATUSKEYCARD_QT_LIBDIR := $(abspath $(STATUS_KEYCARD_QT_BUILD_DIR)$(STATUSKEYCARD_QT_LIB_SUBDIR))
export STATUSKEYCARD_QT_LIB := $(STATUSKEYCARD_QT_LIBDIR)/$(STATUSKEYCARD_QT_LIB_PREFIX)status-keycard-qt.$(LIB_EXT)
STATUSKEYCARD_QT_DYLIB_NAME := $(notdir $(STATUSKEYCARD_QT_LIB))
STATUSKEYCARD_QT_LINKNAME := $(patsubst lib%,%,$(basename $(STATUSKEYCARD_QT_DYLIB_NAME)))

KEYCARD_SIM_SRC_DIR := $(STATUS_KEYCARD_QT_SOURCE_DIR)/test/keycard-simulator
KEYCARD_SIM_RUNTIME_BITS := run.sh libs versions out

keycard-simulator:
	echo -e $(BUILD_MSG) "keycard-simulator (precompile)"
	bash scripts/precompile-keycard-simulator.sh $(KEYCARD_SIM_SRC_DIR)

keycard-simulator-bundle:
	mkdir -p $(KEYCARD_SIM_DEST)
	cp -R $(addprefix $(KEYCARD_SIM_SRC_DIR)/,$(KEYCARD_SIM_RUNTIME_BITS)) $(KEYCARD_SIM_DEST)/

status-keycard-qt: $(STATUSKEYCARD_QT_LIB)
$(STATUSKEYCARD_QT_LIB): | deps check-qt-dir
	echo -e $(BUILD_MSG) "status-keycard-qt"
	  cmake -S "${STATUS_KEYCARD_QT_SOURCE_DIR}" -B "${STATUS_KEYCARD_QT_BUILD_DIR}" \
		-DCMAKE_BUILD_TYPE=$(COMMON_CMAKE_BUILD_TYPE) \
		$(COMMON_CMAKE_CONFIG_PARAMS) \
		$(STATUS_KEYCARD_QT_CMAKE_PARAMS) \
		-DBUILD_TESTING=OFF \
		-DBUILD_EXAMPLES=OFF \
		-DBUILD_SHARED_LIBS=ON \
		-DKEYCARD_QT_SOURCE_DIR=${KEYCARD_QT_SOURCE_DIR} \
		$(HANDLE_OUTPUT)
	cmake --build $(STATUS_KEYCARD_QT_BUILD_DIR) --target status-keycard-qt --config $(COMMON_CMAKE_BUILD_TYPE) $(HANDLE_OUTPUT)

status-keycard-qt-clean:
	echo -e "\033[92mCleaning:\033[39m status-keycard-qt"
	rm -rf $(STATUS_KEYCARD_QT_BUILD_DIR)

ifeq ($(mkspecs),win32)
 # MSVC import libraries for the c-shared DLLs. The client links with clang/lld-
 # link (MSVC ABI, to use Qt's msvc build), and lld-link — unlike mingw's ld —
 # cannot link a .dll directly; it needs an import library. status-go/keycard
 # (Go) and nim-sds ship only .dll + .h, so synthesize the import libs from each
 # header via scripts/gen-import-lib.sh. They're named to match the -l flags in
 # the client link (status/<keycard>/sds.lib) and dropped into the dirs already
 # on -L. (The Qt keycard variant is a CMake shared lib that already emits its
 # own import lib, so only the Go keycard needs this.)
 STATUSGO_IMPLIB := $(STATUSGO_LIBDIR)/status.lib
 NIMSDS_IMPLIB := $(NIMSDS_LIBDIR)/sds.lib
 WIN_IMPORT_LIBS := $(STATUSGO_IMPLIB) $(NIMSDS_IMPLIB)

 $(STATUSGO_IMPLIB): $(STATUSGO)
	echo -e $(BUILD_MSG) "import lib: $(notdir $(STATUSGO_IMPLIB))"
	bash scripts/gen-import-lib.sh "$(STATUSGO_LIBDIR)/libstatus.h" "$(notdir $(STATUSGO))" "$(STATUSGO_IMPLIB)" $(HANDLE_OUTPUT)

 $(NIMSDS_IMPLIB): $(NIMSDS_LIBFILE)
	echo -e $(BUILD_MSG) "import lib: $(notdir $(NIMSDS_IMPLIB))"
	bash scripts/gen-import-lib.sh "$(NIMSDS_INCDIR)/libsds.h" "$(notdir $(NIMSDS_LIBFILE))" "$(NIMSDS_IMPLIB)" $(HANDLE_OUTPUT)

 import-libs: $(WIN_IMPORT_LIBS)
endif

QRCODEGEN := vendor/QR-Code-generator/c/libqrcodegen.a

$(QRCODEGEN): | deps platform-cleanup
	echo -e $(BUILD_MSG) "QR-Code-generator"
	+ cd vendor/QR-Code-generator/c && \
	  $(MAKE) $(QRCODEGEN_MAKE_PARAMS) $(HANDLE_OUTPUT)

# Named alias so callers (ci/Jenkinsfile.linux) don't hardcode the archive path.
qrcodegen: $(QRCODEGEN)


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

$(UI_RESOURCES): $(UI_SOURCES) | check-qt-dir compile-translations
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

# used to override the default number of kdf iterations for sqlcipher
KDF_ITERATIONS ?= 0
ifeq ($(shell test $(KDF_ITERATIONS) -gt 0; echo $$?),0)
  NIM_PARAMS += -d:KDF_ITERATIONS:"$(KDF_ITERATIONS)"
endif

RESOURCES_LAYOUT ?= -d:development

# When modifying files make does not track (see NIM_SOURCES below), e.g. a
# checkout behind a `file://` requires line, `make REBUILD_NIM=true run`
# forces a rebuild of bin/nim_status_client.
REBUILD_NIM ?= false

ifeq ($(REBUILD_NIM),true)
 $(shell touch .update.timestamp)
endif

.update.timestamp:
	touch .update.timestamp

NIM_SOURCES := .update.timestamp nimble.paths $(shell find src -type f)

STATUS_RC_FILE := status.rc

# Building the resource files for windows to set the icon
compile_windows_resources:
	windres $(STATUS_RC_FILE) -o status.o

ifeq ($(mkspecs),win32)
 NIM_STATUS_CLIENT := bin/nim_status_client.exe
 # Build the pkg-config wrapper + ensure the committed Qt .pc tree (rules from the
 # prl-to-pc module) before compiling the nim client, so seaqt's compile-time
 # gorge("pkg-config Qt6Core") resolves. Order-only: their mtimes shouldn't force a relink.
 $(NIM_STATUS_CLIENT): | qt-pkgconfig $(WIN_IMPORT_LIBS)
else
 NIM_STATUS_CLIENT := bin/nim_status_client
 # The pkg-config wrapper + committed .pc must exist before seaqt's compile-time gorge runs.
 $(NIM_STATUS_CLIENT): | qt-pkgconfig
endif

# Writing the QMAKE variable to a file to compare its value from the previous
# make call and forcing linking of NIM_STATUS_CLIENT if the value has changed.

# Define the file to store the previous QMAKE value
QMAKE_PREVIOUS := .qmake_previous

# Check if the QMAKE value has changed
QMAKE_CHANGED := $(shell [ -f $(QMAKE_PREVIOUS) ] && [ "$$(cat $(QMAKE_PREVIOUS))" = "$(QMAKE)" ] && echo "no" || echo "yes")

# Target to store the current QMAKE value
update-qmake-previous:
	@echo $(QMAKE) > $(QMAKE_PREVIOUS)

# Add a dependency on update-qmake-previous if QMAKE has changed
ifeq ($(QMAKE_CHANGED),yes)
$(NIM_STATUS_CLIENT): update-qmake-previous
endif

# Force a rebuild of nim_status_client when USE_SIMULATED_KEYCARD is toggled.
SIMKC_MODE := $(if $(filter true,$(USE_SIMULATED_KEYCARD)),on,off)
SIMKC_PREVIOUS := .use_simulated_keycard_previous
SIMKC_CHANGED := $(shell [ -f $(SIMKC_PREVIOUS) ] && [ "$$(cat $(SIMKC_PREVIOUS))" = "$(SIMKC_MODE)" ] && echo "no" || echo "yes")
update-use-simulated-keycard-previous:
	@echo $(SIMKC_MODE) > $(SIMKC_PREVIOUS)
ifeq ($(SIMKC_CHANGED),yes)
$(NIM_STATUS_CLIENT): update-use-simulated-keycard-previous
endif

STATUSQ_LIB_PATH := $(STATUSQ_INSTALL_PATH)/StatusQ
EXTRA_LIBS_PATH := $(STATUSQ_BUILD_PATH)/lib
ifeq ($(mkspecs),win32)
 STATUSQ_LIB_PATH := $(STATUSQ_BUILD_PATH)/lib/$(COMMON_CMAKE_BUILD_TYPE)
endif
$(NIM_STATUS_CLIENT): NIM_PARAMS += $(RESOURCES_LAYOUT)
# Target-specific so QT_SEAQT_EXTRA_LIBS' $(shell) runs at recipe time (after the
# order-only qt-pkgconfig prereq builds the pkg-config wrapper), not at parse time.
ifneq ($(mkspecs),win32)
$(NIM_STATUS_CLIENT): NIM_PARAMS += --passL:"$(QT_SEAQT_EXTRA_LIBS)"
endif
$(NIM_STATUS_CLIENT): $(NIM_SOURCES) | statusq check-qt-dir $(STATUSGO) $(NIMSDS_LIBFILE) $(STATUSKEYCARD_QT_LIB) $(QRCODEGEN) rcc deps
	echo -e $(BUILD_MSG) "$@"
	$(NIM) c $(NIM_PARAMS) \
		--mm:orc \
		-d:useMalloc \
		--passL:"-L$(STATUSGO_LIBDIR)" \
		--passL:"-lstatus" \
		--passL:"-L$(STATUSQ_LIB_PATH)" \
		--passL:"-L$(EXTRA_LIBS_PATH)" \
		--passL:"-lStatusQ" \
		--passL:"-L$(STATUSKEYCARD_QT_LIBDIR)" \
		--passL:"-l$(STATUSKEYCARD_QT_LINKNAME)" \
		--passL:"$(QRCODEGEN)" \
		$(NIM_MATH_LIB) \
		--parallelBuild:0 \
		$(NIM_EXTRA_PARAMS) src/nim_status_client.nim
ifeq ($(mkspecs),macx)
	install_name_tool -change \
		libstatus.dylib \
		@rpath/libstatus.dylib \
		bin/nim_status_client
	install_name_tool -change \
		$(STATUSKEYCARD_QT_DYLIB_NAME) \
		@rpath/$(STATUSKEYCARD_QT_DYLIB_NAME) \
		bin/nim_status_client
endif

nim_status_client: force-rebuild-status-go statusq $(NIM_STATUS_CLIENT)

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

$(FCITX5_QT): | check-qt-dir deps
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
$(STATUS_CLIENT_APPIMAGE): nim_status_client $(APPIMAGE_TOOL) nim-status.desktop $(FCITX5_QT)
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
$(STATUS_CLIENT_FLATPAK): nim_status_client
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

$(STATUS_CLIENT_DMG): MACOS_OUTER_BUNDLE := tmp/macos/dist/Status.app
$(STATUS_CLIENT_DMG): MACOS_INNER_BUNDLE := $(MACOS_OUTER_BUNDLE)/Contents/Frameworks/QtWebEngineCore.framework/Versions/Current/Helpers/QtWebEngineProcess.app
$(STATUS_CLIENT_DMG): override RESOURCES_LAYOUT := $(PRODUCTION_PARAMETERS)
$(STATUS_CLIENT_DMG): ENTITLEMENTS ?= resources/Entitlements.plist
$(STATUS_CLIENT_DMG): nim_status_client
	rm -rf tmp/macos pkg/*.dmg
	mkdir -p \
		$(MACOS_OUTER_BUNDLE)/Contents/Resources \
		$(MACOS_OUTER_BUNDLE)/Contents/MacOS
	cp -R Info.plist status-macos.svg resources.rcc \
		$(MACOS_OUTER_BUNDLE)/Contents/
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
	macdeployqt \
		$(MACOS_OUTER_BUNDLE) \
		-executable=$(MACOS_OUTER_BUNDLE)/Contents/MacOS/nim_status_client \
		-qmldir=ui \
		-qmlimport=$(QT_QMLDIR)
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
	nix run .#dmgbuild -- \
		-s scripts/dmg-settings.py -D app=$(MACOS_OUTER_BUNDLE) "Status" pkg/Status.dmg
	mv "`ls pkg/*.dmg`" $(STATUS_CLIENT_DMG)

ifdef MACOS_CODESIGN_IDENT
	scripts/sign-macos-pkg.sh $(STATUS_CLIENT_DMG) $(MACOS_CODESIGN_IDENT)
endif

notarize-macos: export CHECK_TIMEOUT ?= 10m
notarize-macos: export MACOS_BUNDLE_ID ?= im.status.ethereum.desktop
notarize-macos:
	scripts/notarize-macos-pkg.sh $(STATUS_CLIENT_DMG)

nim_windows_launcher: | deps
	$(NIM) c -d:debug --outdir:./bin --passL:"-static-libgcc -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive" src/nim_windows_launcher.nim

STATUS_CLIENT_EXE ?= pkg/Status.exe
STATUS_CLIENT_7Z ?= pkg/Status.7z

$(STATUS_CLIENT_EXE): override RESOURCES_LAYOUT := $(PRODUCTION_PARAMETERS)
$(STATUS_CLIENT_EXE): OUTPUT := tmp/windows/dist/Status
$(STATUS_CLIENT_EXE): INSTALLER_OUTPUT := pkg
$(STATUS_CLIENT_EXE): compile_windows_resources nim_status_client nim_windows_launcher
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

# pkg target rebuilds status client
# this is to ensure production version of the app is deployed
pkg:
	rm $(NIM_STATUS_CLIENT) | :
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

clean: | clean-destdir statusq-clean status-go-clean status-keycard-qt-clean storybook-clean clean-translations
	rm -rf bottles/* pkg/* tmp/* nimcache .prl-to-pc-build
	+ $(MAKE) -C vendor/QR-Code-generator/c/ --no-print-directory clean

clean-git:
	./scripts/clean-git.sh

force-rebuild-status-go:
	bash ./scripts/force-rebuild-status-go.sh $(STATUSGO)

# Repair wallet db migration marker: make fix-wallet-migrations <dbpath|datadir> <password>
# Without arguments it lists the wallet migrations the resolved status-go knows.
# Runs `go generate` IN the status-go tree: use a checkout (`make STATUSGO_SRC=... fix-wallet-migrations`), not the store copy.
ifeq (fix-wallet-migrations,$(firstword $(MAKECMDGOALS)))
FIX_WALLET_MIGRATIONS_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(FIX_WALLET_MIGRATIONS_ARGS):;@:)
endif

fix-wallet-migrations:
	cd "$(STATUSGO_SRC)" && go generate ./internal/db/walletdb/migrations/sql && go run ./cmd/fix-wallet-migrations \
		$(if $(FIX_WALLET_MIGRATIONS_ARGS),$(abspath $(word 1,$(FIX_WALLET_MIGRATIONS_ARGS))) $(word 2,$(FIX_WALLET_MIGRATIONS_ARGS)))

run: $(RUN_TARGET)

# Will only work at password login. Keycard login doesn't forward the configuration
# STATUS_PORT ?= 30306
# WAKUV2_PORT ?= 30307

run-linux: nim_status_client
	echo -e "\033[92mRunning:\033[39m bin/nim_status_client"
	LD_LIBRARY_PATH="$(QT_LIBDIR)":"$(NIMSDS_LIBDIR)":"$(STATUSGO_LIBDIR)":"$(STATUSKEYCARD_QT_LIBDIR)":"$(STATUSQ_LIB_PATH)":"$(EXTRA_LIBS_PATH)":"$(LD_LIBRARY_PATH)" \
	$(NIXGL_WRAPPER) ./bin/nim_status_client $(ARGS)

run-linux-gdb: nim_status_client
	echo -e "\033[92mRunning:\033[39m bin/nim_status_client"
	LD_LIBRARY_PATH="$(QT_LIBDIR)":"$(NIMSDS_LIBDIR)":"$(STATUSGO_LIBDIR)":"$(STATUSKEYCARD_QT_LIBDIR)":"$(STATUSQ_LIB_PATH)":"$(EXTRA_LIBS_PATH)":"$(LD_LIBRARY_PATH)" \
	gdb -ex=r ./bin/nim_status_client $(ARGS)

run-macos: nim_status_client
	mkdir -p bin/StatusDev.app/Contents/{MacOS,Resources}
	cp Info.dev.plist bin/StatusDev.app/Contents/Info.plist
	cp status-dev.icns bin/StatusDev.app/Contents/Resources/
	cp resources/macos/dev/Assets.car bin/StatusDev.app/Contents/Resources/
	cp resources.rcc bin/StatusDev.app/Contents/
	# Monitoring tool loads MONITORING_QML_ENTRY_POINT="/../monitoring/Main.qml" relative to the app
	# binary dir (Contents/MacOS -> Contents/monitoring). Copy the QML into the bundle for MONITORING builds.
	[ "$(MONITORING)" = "false" ] || rm -rf bin/StatusDev.app/Contents/monitoring
	[ "$(MONITORING)" = "false" ] || cp -R monitoring bin/StatusDev.app/Contents/monitoring
	cd bin/StatusDev.app/Contents/MacOS && \
		ln -fs ../../../nim_status_client ./
	fileicon set bin/nim_status_client status-dev.icns
	echo -e "\033[92mRunning:\033[39m bin/StatusDev.app/Contents/MacOS/nim_status_client"
	DYLD_LIBRARY_PATH="$(STATUSGO_LIBDIR)":"$(STATUSKEYCARD_QT_LIBDIR)":"$(STATUSQ_LIB_PATH)":"$(EXTRA_LIBS_PATH)":"$(DYLD_LIBRARY_PATH)" \
	./bin/StatusDev.app/Contents/MacOS/nim_status_client $(ARGS)

run-windows: STATUS_RC_FILE = status-dev.rc
run-windows: compile_windows_resources nim_status_client
	echo -e "\033[92mCopying DLLs to bin/\033[39m"
	cp -f -R $(STATUSQ_BUILD_PATH)/bin/$(COMMON_CMAKE_BUILD_TYPE)/* ./bin/
	cp -f $(STATUSGO_LIBDIR)/libstatus.dll ./bin/
	cp -f $(STATUSKEYCARD_QT_LIB) ./bin/
	cp -f $(NIMSDS_LIBDIR)/libsds.dll ./bin/
	cp -f /c/Windows/System32/ucrtbase.dll ./bin/
	cp -f /c/Windows/System32/vcruntime140.dll ./bin/
	cp -f /c/Windows/System32/vcruntime140_1.dll ./bin/
	cp -f /c/Windows/System32/downlevel/api-ms-win-crt-*.dll ./bin/
	echo -e "\033[92mRunning:\033[39m bin/nim_status_client.exe"
	cd bin && ./nim_status_client.exe $(ARGS)

include makefiles/nim-tests.mk

define qmkq
$(shell $(QMAKE) -query $(1))
endef

export PATH := $(call qmkq,QT_INSTALL_BINS):$(call qmkq,QT_HOST_BINS):$(call qmkq,QT_HOST_LIBEXECS):$(PATH)
export QTDIR := $(call qmkq,QT_INSTALL_PREFIX)

mobile-run: qt-pkgconfig nimble-deps
	echo -e "\033[92mRunning:\033[39m mobile app"
	$(MAKE) -C mobile run DEBUG=1 GRADLE_TARGETS=assembleDebug

mobile-profile: qt-pkgconfig nimble-deps
ifeq ($(mkspecs),ios)
	@echo "TODO: iOS profiling is not implemented yet"; exit 1
else
	echo -e "\033[92mRunning:\033[39m mobile app (PROFILE)"
	$(MAKE) -C mobile run \
	    PROFILE=1 \
	    GRADLE_TARGETS=assembleProfile \
	    QML_DEBUG_PORT=$(QML_DEBUG_PORT)
endif

mobile-build: qt-pkgconfig | nimble-deps
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

