SHELL:=/bin/bash
STATUS_DESKTOP := $(shell git rev-parse --show-toplevel)
OS?=android
QT_MAJOR?=6

# verbosity level
V := 0
ifeq ($(V), 0)
  HANDLE_OUTPUT := >/dev/null 2>&1
endif

# compile macros
ifeq ($(USE_QML_SERVER),)
  export APP_VARIANT := $(OS)/qt$(QT_MAJOR)
else
  export APP_VARIANT := $(OS)/qt$(QT_MAJOR)/qmlserver-$(USE_QML_SERVER)
endif

# path macros
ROOT_DIR := $(STATUS_DESKTOP)/mobile
BIN_PATH := $(ROOT_DIR)/bin/$(APP_VARIANT)
LIB_PATH := $(ROOT_DIR)/lib/$(APP_VARIANT)
BUILD_PATH := $(ROOT_DIR)/build/$(APP_VARIANT)

SCRIPTS_PATH := $(ROOT_DIR)/scripts

export LIB_DIR=$(LIB_PATH)

WRAPPER_APP?=$(ROOT_DIR)/wrapperApp
STATUS_DESKTOP?=$(ROOT_DIR)/vendors/status-desktop
STATUSQ?=$(STATUS_DESKTOP)/ui/StatusQ
# statusgo is a pinned URL#hash nimble dependency (issue 0010). Since issue
# 0020 nothing is copied: STATUS_GO is the tree the sub-builds READ (the
# resolved store entry, or the vendor/status-go checkout under `develop
# statusgo`, issue 0009) and STATUS_GO_OUT is where every artifact lands, the
# same directory in both modes. `nim prepareStatusgo status.nims` maintains it.
STATUSGO_DEVELOPED := $(shell grep -sqx statusgo $(STATUS_DESKTOP)/nimble.overlay 2>/dev/null && echo 1)
STATUS_GO_OUT ?= $(STATUS_DESKTOP)/.statusgo-build
ifeq ($(STATUSGO_DEVELOPED),1)
STATUS_GO?=$(STATUS_DESKTOP)/vendor/status-go
else
# The statusgo store entry from the generated resolution (status.nims'
# statusgoSourceRoot answers the same question for the driver). Recursively
# expanded: nimble.paths may not exist yet at parse time.
STATUS_GO = $(shell sed -n 's|^--path:"\(.*/pkgs2/statusgo-[^/"]*\).*|\1|p' $(STATUS_DESKTOP)/nimble.paths 2>/dev/null | head -1)
endif
OPENSSL?=$(ROOT_DIR)/vendors/openssl
QRCODEGEN?=$(STATUS_DESKTOP)/vendor/QR-Code-generator/c
# status-keycard-qt is a pinned CMake FetchContent vendor (issue 0011): the
# -S dir is the app-owned wrapper project that carries the pin; the pinned
# sources land under the cmake build tree (_deps). Develop mode (issues
# 0009/0011) materializes vendor/status-keycard-qt / vendor/keycard-qt and
# redirects the matching FetchContent to it (derived from nimble.overlay;
# same pattern as STATUS_GO above).
STATUS_KEYCARD_QT?=$(STATUS_DESKTOP)/cmake/status-keycard-qt
STATUS_KEYCARD_QT_DEVELOPED := $(shell grep -sqx status-keycard-qt $(STATUS_DESKTOP)/nimble.overlay 2>/dev/null && echo 1)
KEYCARD_QT_DEVELOPED := $(shell grep -sqx keycard-qt $(STATUS_DESKTOP)/nimble.overlay 2>/dev/null && echo 1)
ifeq ($(STATUS_KEYCARD_QT_DEVELOPED),1)
STATUS_KEYCARD_QT_SOURCE_DIR ?= $(STATUS_DESKTOP)/vendor/status-keycard-qt
else
STATUS_KEYCARD_QT_SOURCE_DIR ?=
endif
ifeq ($(KEYCARD_QT_DEVELOPED),1)
KEYCARD_QT ?= $(STATUS_DESKTOP)/vendor/keycard-qt
else
KEYCARD_QT ?=
endif

# compile macros: pr -> StatusPR, release -> Status
ifeq ($(BUILD_VARIANT),pr)
TARGET_PREFIX := StatusPR
else
TARGET_PREFIX := Status
endif

# Default package type for Android builds
PACKAGE_TYPE ?= apk

# mobile app extension - always apk for Android (AAB built alongside when requested)
ifeq ($(OS),ios)
EXTENSION := app
else
EXTENSION := apk
endif

TARGET_NAME := $(TARGET_PREFIX).$(EXTENSION)
TARGET := $(BIN_PATH)/$(TARGET_NAME)

# src files & obj files
STATUS_DESKTOP_NIM_FILES := $(shell find $(STATUS_DESKTOP)/src -type f \( -iname '*.nim' -o -iname '*.nims' \))
STATUS_DESKTOP_UI_FILES := $(shell find $(STATUS_DESKTOP)/ui -type f \( -iname 'qmldir' -o -iname '*.qml' -o -iname '*.qrc' \) -not -iname 'resources.qrc' -not -path '$(STATUS_DESKTOP)/ui/StatusQ/*')
# Include CMakeLists.txt (mobilewebview pin) and prune build/ (generated sources).
STATUS_Q_FILES := $(shell find $(STATUSQ) \( -path '$(STATUSQ)/build' \) -prune -o -type f \( -iname '*.cpp' -o -iname '*.h' -o -iname '*.mm' -o -iname 'CMakeLists.txt' \) -print)
STATUS_Q_UI_FILES := $(shell find $(STATUSQ) -type f \( -iname '*.qml' -o -iname '*.qrc' \))
# No STATUS_GO_FILES here: status-desktop does not track status-go sources
# (#18377 / ADR 0003) — $(STATUS_GO_LIB) delegates freshness to status-go's
# own PHONY sub-make via FORCE.
OPENSSL_FILES := $(shell find $(OPENSSL) -type f \( -iname '*.c' -o -iname '*.h' \))
QRCODEGEN_FILES := $(shell find $(QRCODEGEN) -type f \( -iname '*.c' -o -iname '*.h' \))
# Developed keycard checkouts are file-tracked so edits rebuild the lib; in
# default mode both vars are empty (pinned _deps sources, lib-missing gating).
STATUS_KEYCARD_QT_FILES := $(shell find $(STATUS_KEYCARD_QT_SOURCE_DIR) $(KEYCARD_QT) -type f \( -iname '*.cpp' -o -iname '*.h' \) 2>/dev/null || echo "")
WRAPPER_APP_FILES := $(shell find $(WRAPPER_APP) -type f)
STATUS_GO_STUB_GEN := $(STATUS_GO_OUT)/build/bin/statusgo_stub_exports.cpp
STATUS_GO_SERVICE_GEN := $(STATUS_GO_OUT)/build/bin/statusgo_service_dispatch.cpp

# script files
STATUS_Q_SCRIPT := $(SCRIPTS_PATH)/buildStatusQ.sh
OPENSSL_SCRIPT := $(SCRIPTS_PATH)/buildOpenSSL.sh
QRCODEGEN_SCRIPT := $(SCRIPTS_PATH)/buildQRCodeGen.sh
STATUS_KEYCARD_QT_SCRIPT := $(SCRIPTS_PATH)/buildStatusKeycardQt.sh
NIM_STATUS_CLIENT_SCRIPT := $(SCRIPTS_PATH)/buildNimStatusClient.sh
APP_SCRIPT := $(SCRIPTS_PATH)/buildApp.sh
RUN_SCRIPT := $(SCRIPTS_PATH)/$(OS)/run.sh

# lib files
STATUS_GO_LIB := $(LIB_PATH)/libstatus$(LIB_EXT)
STATUS_Q_LIB := $(LIB_PATH)/libStatusQ$(LIB_SUFFIX)$(LIB_EXT)
OPENSSL_LIB := $(LIB_PATH)/libssl_3$(LIB_EXT)
QRCODEGEN_LIB := $(LIB_PATH)/libqrcodegen.a
STATUS_KEYCARD_QT_LIB := $(LIB_PATH)/libstatus-keycard-qt$(LIB_EXT)
NIM_STATUS_CLIENT_LIB := $(LIB_PATH)/libnim_status_client$(LIB_EXT)
STATUS_DESKTOP_RCC := $(STATUS_DESKTOP)/ui/resources.qrc
STATUS_GO_STUB_LIB := $(LIB_PATH)/libstatus_stub$(LIB_EXT)
STATUS_GO_SERVICE_LIB := $(LIB_PATH)/libstatus_service$(LIB_EXT)
ifeq ($(OS), ios)
LIB_ZXING := $(LIB_PATH)/libZXing$(LIB_SUFFIX)$(LIB_EXT)
endif
