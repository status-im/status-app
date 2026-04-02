-include ./scripts/EnvVariables.mk
-include ./scripts/Common.mk

# FLAG_KEYCARD_ENABLED: Controls NFC/Keycard support
# - iOS: Default 1 (enabled) - Build with NFC support, works with free Apple Developer account
# - Android: Default 1 (enabled) - NFC support doesn't require paid account on Android
# - Set to 1: Build with NFC support (iOS requires paid Apple Developer account)
# - Set to 0: Build without NFC support
# Usage: make build-ios FLAG_KEYCARD_ENABLED=1
FLAG_KEYCARD_ENABLED ?= 1
FLAG_DAPPS_ENABLED ?= 1
FLAG_CONNECTOR_ENABLED ?= 0
FLAG_BROWSER_ENABLED ?= 1
BUILD_VARIANT ?= release

$(info Configuring build system for $(OS) $(ARCH))

# ---- qt-cmake & build configuration ----

QT_CMAKE := $(QT_DIR)/bin/qt-cmake
CMAKE_BUILD_DIR := $(BUILD_PATH)/cmake-build
VERSION := $(shell cd $(STATUS_DESKTOP) && git describe --tags --always | cut -d- -f1 | cut -d. -f1-3 | sed 's/^v//')
BUILD_VERSION := $(if $(CHANGE_ID),$(CHANGE_ID).)$(shell echo $$(($$(date +%s) / 60)))
OUTPUT_NAME := $(if $(filter pr,$(BUILD_VARIANT)),StatusPR,Status)

CMAKE_FLAGS := \
    -DCMAKE_BUILD_TYPE=$(if $(DEBUG),Debug,Release) \
    -DAPP_AOT_COMPILE=ON \
    -DAPP_RESOURCES_MOBILE=ON \
    -DFLAG_KEYCARD_ENABLED=$(if $(filter 1,$(FLAG_KEYCARD_ENABLED)),ON,OFF) \
    -DPROJECT_VERSION=$(VERSION)

NPROC := $(shell sysctl -n hw.logicalcpu 2>/dev/null || nproc)

ifeq ($(OS),android)
    CMAKE_FLAGS += -DANDROID_PLATFORM=android-35
    GRADLE_BIN := $(QT_DIR)/src/3rdparty/gradle/gradlew
else ifeq ($(OS),ios)
    # qt-cmake defaults to Xcode generator for iOS (handles duplicate static lib
    # symbols, code signing, etc. natively). We set sysroot and arch for device/simulator.
    CMAKE_FLAGS += -DCMAKE_OSX_SYSROOT=$(IPHONE_SDK) -DCMAKE_OSX_ARCHITECTURES=$(ARCH)
endif

# Signing: map STATUS_APP_KEYSTORE_* → QT_ANDROID_KEYSTORE_* for androiddeployqt
ifdef STATUS_APP_KEYSTORE_PATH
CMAKE_FLAGS += -DQT_ANDROID_SIGN_APK=ON
export QT_ANDROID_KEYSTORE_PATH := $(STATUS_APP_KEYSTORE_PATH)
export QT_ANDROID_KEYSTORE_ALIAS := $(STATUS_APP_KEY_ALIAS)
export QT_ANDROID_KEYSTORE_STORE_PASS := $(STATUS_APP_KEYSTORE_PASSWORD)
export QT_ANDROID_KEYSTORE_KEY_PASS := $(STATUS_APP_KEY_PASSWORD)
endif

# ---- Non-CMake dependencies ----
# CC/CXX (clangWrap.sh) are only needed by non-cmake targets.
# Export per-target so cmake/xcodebuild don't inherit them.
$(STATUS_GO_LIB): export CC := $(CC)
$(STATUS_GO_LIB): export CXX := $(CXX)
$(OPENSSL_LIB): export CC := $(CC)
$(OPENSSL_LIB): export CXX := $(CXX)
$(NIM_STATUS_CLIENT_LIB): export CC := $(CC)
$(NIM_STATUS_CLIENT_LIB): export CXX := $(CXX)
$(STATUS_GO_STUB_LIB): export CC := $(CC)
$(STATUS_GO_STUB_LIB): export CXX := $(CXX)
$(STATUS_GO_SERVICE_LIB): export CC := $(CC)
$(STATUS_GO_SERVICE_LIB): export CXX := $(CXX)
$(QRCODEGEN_LIB): export CC := $(CC)
$(QRCODEGEN_LIB): export CXX := $(CXX)

$(STATUS_GO_LIB):
	@echo "Building status-go mobile library"
	@mkdir -p $(LIB_PATH)
ifeq ($(OS),android)
	  CC="$(CC)" $(MAKE) -C ../vendor/status-go statusgo-android-library \
		ARCH=$(ARCH) \
		ANDROID_NDK_ROOT="$(ANDROID_NDK_ROOT)" \
		ANDROID_API="$(ANDROID_API)" \
		HOST_OS="$(HOST_OS)" \
		NIM_SDS_SOURCE_DIR="$(NIM_SDS_SOURCE_DIR)" \
		USE_SYSTEM_NIM=$(USE_SYSTEM_NIM) \
		GO_GENERATE_CMD="go generate" \
		SHELL=/bin/sh
else ifeq ($(OS),ios)
	$(MAKE) -C ../vendor/status-go statusgo-ios-library \
		ARCH=$(ARCH) \
		IPHONE_SDK="$(IPHONE_SDK)" \
		IOS_TARGET="$(IOS_TARGET)" \
		USE_SYSTEM_NIM=$(USE_SYSTEM_NIM) \
		SHELL=/bin/sh
endif
	@echo "Copying library to mobile lib directory"
	@cp $(NIM_SDS_SOURCE_DIR)/build/libsds$(LIB_EXT) $(LIB_PATH)/libsds$(LIB_EXT)
	@cp ../vendor/status-go/build/bin/libstatus$(LIB_EXT) $(LIB_PATH)/libstatus$(LIB_EXT)

$(STATUS_GO_STUB_LIB): $(STATUS_GO_LIB)
	@echo "Building status-go stub library (UI process)"
	@mkdir -p $(LIB_PATH)
	@$(MAKE) $(STATUS_GO_STUB_GEN)
	@$(CXX) -shared -fPIC $(CXX_OPT_FLAGS) \
		-o $(STATUS_GO_STUB_LIB) \
		$(STATUS_DESKTOP)/mobile/statusgo_stub/statusgo_stub.cpp \
		$(STATUS_GO_STUB_GEN) \
		-llog -lc++_shared

$(STATUS_GO_SERVICE_LIB): $(STATUS_GO_LIB)
	@echo "Building status-go service JNI library (service process)"
	@mkdir -p $(LIB_PATH)
	@$(MAKE) $(STATUS_GO_STUB_GEN)
	@$(CXX) -shared -fPIC $(CXX_OPT_FLAGS) \
		-o $(STATUS_GO_SERVICE_LIB) \
		$(STATUS_DESKTOP)/mobile/statusgo_service/statusgo_service_jni.cpp \
		$(STATUS_GO_SERVICE_GEN) \
		-L$(LIB_PATH) -lstatus -llog -lc++_shared

$(STATUS_GO_STUB_GEN):
	@$(MAKE) -C $(STATUS_DESKTOP)/vendor/status-go statusgo-stub-bindings

$(OPENSSL_LIB): $(OPENSSL_FILES)
	@echo "Building OpenSSL"
	@LIB_PATH=$(LIB_PATH) LIB_EXT=$(LIB_EXT) OPENSSL=$(OPENSSL) BUILD_DIR=$(BUILD_PATH) $(OPENSSL_SCRIPT) $(HANDLE_OUTPUT)

$(QRCODEGEN_LIB): $(QRCODEGEN_FILES)
	@echo "Building QRCodeGen"
	@QRCODEGEN=$(QRCODEGEN) $(QRCODEGEN_SCRIPT) $(HANDLE_OUTPUT)
	@echo "QRCodeGen built $(QRCODEGEN_LIB)"

ifeq ($(OS),android)
$(NIM_STATUS_CLIENT_LIB): $(STATUS_GO_STUB_LIB) $(STATUS_GO_SERVICE_LIB)
endif

# Track build flags that affect nim compilation. When DEBUG or feature flags
# change, the sentinel file changes and forces a rebuild of nim_status_client.
NIM_BUILD_FLAGS := DEBUG=$(DEBUG) FLAG_DAPPS_ENABLED=$(FLAG_DAPPS_ENABLED) FLAG_KEYCARD_ENABLED=$(FLAG_KEYCARD_ENABLED) FLAG_BROWSER_ENABLED=$(FLAG_BROWSER_ENABLED)
NIM_FLAGS_SENTINEL := $(BUILD_PATH)/.nim_build_flags

# Recreate sentinel if flags changed (compare content, not just existence)
$(shell mkdir -p $(BUILD_PATH))
$(shell echo "$(NIM_BUILD_FLAGS)" | cmp -s - $(NIM_FLAGS_SENTINEL) || echo "$(NIM_BUILD_FLAGS)" > $(NIM_FLAGS_SENTINEL))

# nim_status_client is now static on both platforms — no link-time deps on
# DOtherSide/StatusQ. Only needs OpenSSL for C compilation.
$(NIM_STATUS_CLIENT_LIB): $(NIM_FLAGS_SENTINEL) $(STATUS_DESKTOP_NIM_FILES) $(NIM_STATUS_CLIENT_SCRIPT) $(OPENSSL_LIB)
	@echo "Building Status Desktop Lib"
	@STATUS_DESKTOP=$(STATUS_DESKTOP) \
	LIB_SUFFIX=$(LIB_SUFFIX) \
	LIB_EXT=.a \
	USE_QML_SERVER=$(USE_QML_SERVER) \
	BUNDLE_IDENTIFIER="$(BUNDLE_IDENTIFIER)" \
	DEBUG=$(DEBUG) \
	FLAG_DAPPS_ENABLED=$(FLAG_DAPPS_ENABLED) \
	FLAG_CONNECTOR_ENABLED=$(FLAG_CONNECTOR_ENABLED) \
	FLAG_KEYCARD_ENABLED=$(FLAG_KEYCARD_ENABLED) \
	FLAG_SINGLE_STATUS_INSTANCE_ENABLED=$(FLAG_SINGLE_STATUS_INSTANCE_ENABLED) \
	FLAG_BROWSER_ENABLED=$(FLAG_BROWSER_ENABLED) \
	$(NIM_STATUS_CLIENT_SCRIPT) $(HANDLE_OUTPUT)
	@echo "Status Desktop Lib built $(NIM_STATUS_CLIENT_LIB)"

# ---- cmake configure (shared across all build targets) ----
# qt-cmake sets the correct generator and toolchain for each platform:
#   iOS: -GXcode + qt.toolchain.cmake (sets CMAKE_SYSTEM_NAME=iOS, sysroot, arch, deployment target)
#   Android: qt.toolchain.cmake (chain-loads NDK toolchain, auto-detects ABI)

NON_CMAKE_DEPS := $(STATUS_GO_LIB) $(OPENSSL_LIB) $(QRCODEGEN_LIB) $(NIM_STATUS_CLIENT_LIB)
CMAKE_CACHE := $(CMAKE_BUILD_DIR)/CMakeCache.txt

$(CMAKE_CACHE): $(NON_CMAKE_DEPS) | makedir
	@echo "Configuring cmake ($(OS), variant=$(BUILD_VARIANT))..."
	@BUILD_VARIANT=$(BUILD_VARIANT) VERSION_CODE=$(BUILD_VERSION) \
		$(QT_CMAKE) -S $(WRAPPER_APP) -B $(CMAKE_BUILD_DIR) $(CMAKE_FLAGS)

.PHONY: cmake-reconfigure
cmake-reconfigure:
	@rm -f $(CMAKE_CACHE)
	@$(MAKE) $(CMAKE_CACHE)

# ---- Platform build targets ----

ifeq ($(OS),android)

.PHONY: apk
apk: $(CMAKE_CACHE)
	@cmake --build $(CMAKE_BUILD_DIR) --target apk -j $$(nproc)
	@mkdir -p $(BIN_PATH)
	@cp $$(find $(CMAKE_BUILD_DIR)/android-build -name "*.apk" -path "*/release/*" | head -1) $(BIN_PATH)/$(OUTPUT_NAME).apk
	@echo "✓ $(BIN_PATH)/$(OUTPUT_NAME).apk"

.PHONY: apk-debug
apk-debug: $(CMAKE_CACHE)
	@cmake --build $(CMAKE_BUILD_DIR) --target apk -j $$(nproc)
	@cd $(CMAKE_BUILD_DIR)/android-build && $(GRADLE_BIN) assembleDebug --no-daemon --console=plain
	@mkdir -p $(BIN_PATH)
	@cp $$(find $(CMAKE_BUILD_DIR)/android-build -name "*.apk" -path "*/debug/*" | head -1) $(BIN_PATH)/$(OUTPUT_NAME).apk
	@echo "✓ $(BIN_PATH)/$(OUTPUT_NAME).apk"

.PHONY: aab
aab: $(CMAKE_CACHE)
	@cmake --build $(CMAKE_BUILD_DIR) --target apk -j $$(nproc)
	@cd $(CMAKE_BUILD_DIR)/android-build && $(GRADLE_BIN) bundleRelease --no-daemon --console=plain
	@mkdir -p $(BIN_PATH)
	@cp $$(find $(CMAKE_BUILD_DIR)/android-build -name "*.aab" -path "*/bundle/*" | head -1) $(BIN_PATH)/$(OUTPUT_NAME).aab
	@echo "✓ $(BIN_PATH)/$(OUTPUT_NAME).aab"

.PHONY: apk-aab
apk-aab: $(CMAKE_CACHE)
	@cmake --build $(CMAKE_BUILD_DIR) --target apk -j $$(nproc)
	@cd $(CMAKE_BUILD_DIR)/android-build && $(GRADLE_BIN) bundleRelease --no-daemon --console=plain
	@mkdir -p $(BIN_PATH)
	@cp $$(find $(CMAKE_BUILD_DIR)/android-build -name "*.apk" -path "*/release/*" | head -1) $(BIN_PATH)/$(OUTPUT_NAME).apk
	@cp $$(find $(CMAKE_BUILD_DIR)/android-build -name "*.aab" -path "*/bundle/*" | head -1) $(BIN_PATH)/$(OUTPUT_NAME).aab
	@echo "✓ $(BIN_PATH)/$(OUTPUT_NAME).apk + .aab"

.PHONY: apk-fdroid
apk-fdroid: apk

else ifeq ($(OS),ios)

# Xcode build flags
XCODE_FLAGS := -configuration Release -sdk $(IPHONE_SDK) -jobs $(NPROC) -parallelizeTargets \
    CURRENT_PROJECT_VERSION=$(BUILD_VERSION)
ifeq ($(QMAKE_EXTRA_CONFIG),fastlane)
    XCODE_FLAGS += CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
else
    XCODE_FLAGS += -allowProvisioningUpdates
endif

.PHONY: ios-app
ios-app: $(CMAKE_CACHE)
	@cd $(CMAKE_BUILD_DIR) && xcodebuild $(XCODE_FLAGS) -target StatusMobile build | xcbeautify
	@mkdir -p $(BIN_PATH)
	@rm -rf $(BIN_PATH)/$(OUTPUT_NAME).app
	@cp -R $(CMAKE_BUILD_DIR)/Release-$(IPHONE_SDK)/$(OUTPUT_NAME).app $(BIN_PATH)/$(OUTPUT_NAME).app
	@test -e "$(BIN_PATH)/$(OUTPUT_NAME).app/Info.plist" || { echo "Build failed"; exit 1; }
	@echo "✓ $(BIN_PATH)/$(OUTPUT_NAME).app"
endif

# ---- Utility targets ----

.PHONY: makedir
makedir:
	@mkdir -p $(BIN_PATH) $(LIB_PATH) $(BUILD_PATH)

.PHONY: default
default: makedir all

ifeq ($(OS),android)
.PHONY: all
all: apk-debug

.PHONY: run
run: apk-debug
	@APP=$(BIN_PATH)/$(OUTPUT_NAME).apk USE_QML_SERVER=$(USE_QML_SERVER) $(RUN_SCRIPT)
else ifeq ($(OS),ios)
.PHONY: all
all: ios-app

.PHONY: run
run: ios-app
	@APP=$(BIN_PATH)/$(OUTPUT_NAME).app USE_QML_SERVER=$(USE_QML_SERVER) $(RUN_SCRIPT)
endif

.PHONY: clean
clean: clean-openssl clean-qrcodegen clean-nim-status-client
	@echo "Cleaning"
	@rm -rf $(ROOT_DIR)/bin $(ROOT_DIR)/build $(ROOT_DIR)/lib

.PHONY: clean-openssl
clean-openssl:
	@rm -f $(OPENSSL_LIB)

.PHONY: clean-qrcodegen
clean-qrcodegen:
	@rm -f $(QRCODEGEN_LIB)
	@cd $(QRCODEGEN) && make clean

.PHONY: clean-nim-status-client
clean-nim-status-client:
	@rm -f $(NIM_STATUS_CLIENT_LIB)
	@rm -rf $(STATUS_DESKTOP)/nimcache
