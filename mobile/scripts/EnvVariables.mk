#OS: ios, android
QSPEC:=$(shell $(QMAKE) -query QMAKE_XSPEC)
ifeq ($(QSPEC),macx-ios-clang)
    OS:=ios
else ifeq ($(QSPEC),macx-clang)
    OS:=macx
else ifeq ($(QSPEC),win32-msvc)
    OS:=win32
else ifeq ($(QSPEC),linux-g++)
    OS:=linux
else ifeq ($(QSPEC),android-clang)
    OS:=android
else
    OS:=$(QSPEC)
endif

HOST_OS=$(shell uname -s | tr '[:upper:]' '[:lower:]')
#Architectures: arm64, arm, x86_64. x86_64 is default for simulator
ARCH?=$(shell uname -m)
# Detect Qt version from qmake
QT_MAJOR?=$(shell $(QMAKE) -query QT_VERSION | head -c 1 2>/dev/null)
QT_DIR?=$(shell $(QMAKE) -query QT_INSTALL_PREFIX)
MAKEFILE_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

ifneq ($(QT_MAJOR),6)
    $(error Detected Qt major version $(QT_MAJOR), but version 6 is required.)
endif

ifeq ($(OS), ios)
    # iOS
    #SDKs: iphonesimulator, iphoneos
    IPHONE_SDK?=iphonesimulator
    IOS_TARGET?=16

    ifeq ($(IPHONE_SDK), iphoneos)
        ARCH=arm64
    else
        ARCH=x86_64
    endif
else ifeq ($(OS), android)
    # Android
    ANDROID_API?=28
    ANDROID_SDK_ROOT?=
    ANDROID_NDK_ROOT?=

    ifeq ($(ANDROID_SDK_ROOT),)
        $(error "ANDROID_SDK_ROOT is not set. Please set ANDROID_SDK_ROOT to the path of your Android SDK.")
    endif

    ifeq ($(ANDROID_NDK_ROOT),)
        $(error "ANDROID_NDK_ROOT is not set. Please set ANDROID_NDK_ROOT to the path of your Android NDK.")
    endif
else
    $(error "OS=$(OS). OS not supported by build system. Please update qmake to a supported version.")
endif

# tool macros
CC := $(abspath $(MAKEFILE_DIR)/$(OS)/clangWrap.sh)

$(info Using CC=$(CC))
CXX := $(CC)

ifeq ($(DEBUG),1)
CXX_OPT_FLAGS := -g -O0
else
CXX_OPT_FLAGS := -O3
endif

export COMPILER
export CC
export CXX
export CXX_OPT_FLAGS
export ARCH
export OS
export HOST_OS
export QT_MAJOR
export QT_DIR

ifeq ($(OS), ios)
    export SDK=$(IPHONE_SDK)
    export IOS_TARGET
    export CPATH=$(shell xcrun --sdk ${IPHONE_SDK} --show-sdk-path)/usr/include/
    export SDKROOT=$(shell xcrun --sdk ${IPHONE_SDK} --show-sdk-path)
    export LIBRARY_PATH:=${SDKROOT}/usr/lib:${LIBRARY_PATH}
    export LIB_EXT := .a
else
    export ANDROID_API
    export AR=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_OS}-x86_64/bin/llvm-ar
    export AS=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_OS}-x86_64/bin/llvm-as
    export RANLIB=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_OS}-x86_64/bin/llvm-ranlib
    export PATH:=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_OS}-x86_64/bin:${PATH}

    ifeq ($(ARCH), arm64)
        export ANDROID_ABI=arm64-v8a
    else ifeq ($(ARCH), arm)
        export ANDROID_ABI=armeabi-v7a
    else
        export ANDROID_ABI=x86_64
    endif
    export LIB_EXT := .so
endif


# Verify tools are installed
QMAKE ?= $(shell which qmake)
ifeq ($(QMAKE),)
    $(error qmake not found)
endif
$(info QMAKE: $(QMAKE))

RCC := $(shell $(QMAKE) -query QT_HOST_LIBEXECS)/rcc
ifeq ($(RCC),)
    $(error rcc not found)
endif
$(info RCC: $(RCC))

ifeq ($(OS),android)
    ANDROIDDEPLOYQT := $(shell which androiddeployqt)
    ifeq ($(ANDROIDDEPLOYQT),)
        $(error androiddeployqt not found)
    endif
    $(info ANDROIDDEPLOYQT: $(ANDROIDDEPLOYQT))

    ifeq ($(ANDROID_NDK_ROOT),)
        $(error ANDROID_NDK_ROOT not set)
    endif
    $(info NDK: $(ANDROID_NDK_ROOT))

    ifeq ($(ANDROID_API),)
        $(error ANDROID_API not set)
    endif
    $(info ANDROID_API: $(ANDROID_API))
endif

ifeq ($(OS),ios)
    ifeq ($(IPHONE_SDK),)
        $(error IPHONE_SDK not set)
    endif
    $(info IPHONE_SDK: $(IPHONE_SDK))

    ifeq ($(IOS_TARGET),)
        $(error IOS_TARGET not set)
    endif
    $(info IOS_TARGET: $(IOS_TARGET))
endif
# end of tool verification
