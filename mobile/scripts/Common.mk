SHELL:=/bin/bash
STATUS_DESKTOP := $(shell git rev-parse --show-toplevel)
OS?=android

# verbosity level
V := 0
ifeq ($(V), 0)
  HANDLE_OUTPUT := >/dev/null 2>&1
endif

# compile macros
ifeq ($(USE_QML_SERVER),)
  export APP_VARIANT := $(OS)
else
  export APP_VARIANT := $(OS)/qmlserver-$(USE_QML_SERVER)
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
STATUS_GO?=$(STATUS_DESKTOP)/vendor/status-go
DOTHERSIDE?=$(STATUS_DESKTOP)/vendor/DOtherSide
OPENSSL?=$(ROOT_DIR)/vendors/openssl
QRCODEGEN?=$(STATUS_DESKTOP)/vendor/QR-Code-generator/c
STATUS_KEYCARD_QT?=$(STATUS_DESKTOP)/vendor/status-keycard-qt
NIM_SDS_SOURCE_DIR ?= $(STATUS_DESKTOP)/vendor/nim-sds

# src files & obj files
STATUS_DESKTOP_NIM_FILES := $(shell find $(STATUS_DESKTOP)/src -type f \( -iname '*.nim' -o -iname '*.nims' \))
STATUS_GO_FILES := $(shell find $(STATUS_GO) -type f \( -iname '*.go' \))
OPENSSL_FILES := $(shell find $(OPENSSL) -type f \( -iname '*.c' -o -iname '*.h' \))
QRCODEGEN_FILES := $(shell find $(QRCODEGEN) -type f \( -iname '*.c' -o -iname '*.h' \))
STATUS_GO_STUB_GEN := $(STATUS_DESKTOP)/vendor/status-go/build/bin/statusgo_stub_exports.cpp
STATUS_GO_SERVICE_GEN := $(STATUS_DESKTOP)/vendor/status-go/build/bin/statusgo_service_dispatch.cpp

# script files (non-CMake dependency builds only)
OPENSSL_SCRIPT := $(SCRIPTS_PATH)/buildOpenSSL.sh
QRCODEGEN_SCRIPT := $(SCRIPTS_PATH)/buildQRCodeGen.sh
NIM_STATUS_CLIENT_SCRIPT := $(SCRIPTS_PATH)/buildNimStatusClient.sh
RUN_SCRIPT := $(SCRIPTS_PATH)/$(OS)/run.sh

# lib files (only non-CMake deps — CMake-built deps are linked by the unified project)
STATUS_GO_LIB := $(LIB_PATH)/libstatus$(LIB_EXT)
OPENSSL_LIB := $(LIB_PATH)/libssl_3$(LIB_EXT)
QRCODEGEN_LIB := $(LIB_PATH)/libqrcodegen.a
NIM_STATUS_CLIENT_LIB := $(LIB_PATH)/libnim_status_client.a
STATUS_GO_STUB_LIB := $(LIB_PATH)/libstatus_stub$(LIB_EXT)
STATUS_GO_SERVICE_LIB := $(LIB_PATH)/libstatus_service$(LIB_EXT)
