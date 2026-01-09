-include ./scripts/EnvVariables.mk
-include ./scripts/Common.mk

STATUS_GO_LIB := $(LIB_PATH)/libstatus$(LIB_EXT)

$(info Configuring build system for $(OS) $(ARCH) with QT $(QT_MAJOR))

# default rule
default: makedir all

iosdevice: IPHONE_SDK=iphoneos
iosdevice: default

# dependencies
statusq: clean-statusq $(STATUS_Q_LIB)
dotherside: clean-dotherside $(DOTHERSIDE_LIB)
openssl: clean-openssl $(OPENSSL_LIB)
qrcodegen: clean-qrcodegen $(QRCODEGEN_LIB)
nim-status-client: clean-nim-status-client $(NIM_STATUS_CLIENT_LIB)
status-desktop-rcc: clean-status-desktop-rcc $(STATUS_DESKTOP_RCC)

$(STATUS_GO_LIB):
	@echo "Building status-go mobile library"
	@mkdir -p $(LIB_PATH)
ifeq ($(OS),android)
	  CC="$(CC)" $(MAKE) -C ../vendor/status-go statusgo-android-library \
		ARCH=$(ARCH) \
		ANDROID_NDK_ROOT="$(ANDROID_NDK_ROOT)" \
		ANDROID_API="$(ANDROID_API)" \
		HOST_OS="$(HOST_OS)" \
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

$(STATUS_Q_LIB): $(STATUS_Q_FILES) $(STATUS_Q_SCRIPT) $(STATUS_Q_UI_FILES)
	@echo "Building StatusQ"
	@STATUSQ=$(STATUSQ) QT_MAJOR=$(QT_MAJOR) LIB_SUFFIX=$(LIB_SUFFIX) LIB_EXT=$(LIB_EXT) $(STATUS_Q_SCRIPT) $(HANDLE_OUTPUT)
	@echo "StatusQ built $(STATUS_Q_LIB)"

$(DOTHERSIDE_LIB): $(DOTHERSIDE_FILES) $(DOTHERSIDE_SCRIPT)
	@echo "Building DOtherSide"
	@DOTHERSIDE=$(DOTHERSIDE) QT_MAJOR=$(QT_MAJOR) LIB_SUFFIX=$(LIB_SUFFIX) LIB_EXT=$(LIB_EXT) $(DOTHERSIDE_SCRIPT) $(HANDLE_OUTPUT)
	@echo "DOtherSide built $(DOTHERSIDE_LIB)"

$(OPENSSL_LIB): $(OPENSSL_FILES)
	@echo "Building OpenSSL"
	@LIB_PATH=$(LIB_PATH) LIB_EXT=$(LIB_EXT) OPENSSL=$(OPENSSL) BUILD_DIR=$(BUILD_PATH) $(OPENSSL_SCRIPT) $(HANDLE_OUTPUT)

$(QRCODEGEN_LIB): $(QRCODEGEN_FILES)
	@echo "Building QRCodeGen"
	@QRCODEGEN=$(QRCODEGEN) $(QRCODEGEN_SCRIPT) $(HANDLE_OUTPUT)
	@echo "QRCodeGen built $(QRCODEGEN_LIB)"

$(STATUS_DESKTOP_RCC): $(STATUS_DESKTOP_UI_FILES) compile-translations
	@echo "Building Status Desktop rcc"
	@make -C $(STATUS_DESKTOP) rcc $(HANDLE_OUTPUT)
	@echo "Status Desktop rcc built"

$(NIM_STATUS_CLIENT_LIB): $(STATUS_DESKTOP_NIM_FILES) $(NIM_STATUS_CLIENT_SCRIPT) $(STATUS_DESKTOP_RCC) $(DOTHERSIDE_LIB) $(OPENSSL_LIB) $(STATUS_Q_LIB) $(STATUS_GO_LIB) $(QRCODEGEN_LIB)
	@echo "Building Status Desktop Lib"
	@STATUS_DESKTOP=$(STATUS_DESKTOP) LIB_SUFFIX=$(LIB_SUFFIX) LIB_EXT=$(LIB_EXT) USE_QML_SERVER=$(USE_QML_SERVER) $(NIM_STATUS_CLIENT_SCRIPT) $(HANDLE_OUTPUT)
	@echo "Status Desktop Lib built $(NIM_STATUS_CLIENT_LIB)"

# non-phony targets
$(TARGET): $(APP_SCRIPT) $(STATUS_GO_LIB) $(STATUS_Q_LIB) $(DOTHERSIDE_LIB) $(OPENSSL_LIB) $(QRCODEGEN_LIB) $(NIM_STATUS_CLIENT_LIB) $(STATUS_DESKTOP_RCC) $(WRAPPER_APP_FILES)
	@echo "Building app"
ifeq ($(OS),android)
	@STATUS_DESKTOP=$(STATUS_DESKTOP) GRADLE_TARGETS="$(GRADLE_TARGETS)" BIN_DIR=$(BIN_PATH) BUILD_DIR=$(BUILD_PATH) QT_MAJOR=$(QT_MAJOR) $(APP_SCRIPT) $(HANDLE_OUTPUT)
else
	@STATUS_DESKTOP=$(STATUS_DESKTOP) BIN_DIR=$(BIN_PATH) BUILD_DIR=$(BUILD_PATH) QT_MAJOR=$(QT_MAJOR) $(APP_SCRIPT) $(HANDLE_OUTPUT)
endif
	@echo "Built $(TARGET)"

# phony rules
.PHONY: makedir
makedir:
	@mkdir -p $(BIN_PATH) $(LIB_PATH) $(BUILD_PATH)

.PHONY: compile-translations
compile-translations:
	@echo "Building translations"
	@make -C $(STATUS_DESKTOP) compile-translations $(HANDLE_OUTPUT)

.PHONY: apk
apk:
ifeq ($(OS),android)
	@$(MAKE) GRADLE_TARGETS=assembleRelease $(TARGET)
else
	$(error APK target is only available for Android)
endif

.PHONY: aab
aab:
ifeq ($(OS),android)
	@$(MAKE) GRADLE_TARGETS="assembleRelease bundleRelease" $(TARGET)
else
	$(error AAB target is only available for Android)
endif

.PHONY: apk-aab
apk-aab:
ifeq ($(OS),android)
	@$(MAKE) GRADLE_TARGETS="assembleRelease bundleRelease" $(TARGET)
else
	$(error apk-aab target is only available for Android)
endif

.PHONY: ios-app
ios-app:
ifeq ($(OS),ios)
	@$(MAKE) $(TARGET)
	@echo "✓ iOS app built successfully"
else
	$(error iOS app target is only available for iOS)
endif

.PHONY: all
all: $(TARGET)

.PHONY: clean
clean: clean-statusq clean-dotherside clean-openssl clean-qrcodegen clean-nim-status-client clean-status-desktop-rcc
	@echo "Cleaning"
	@rm -rf $(ROOT_DIR)/bin $(ROOT_DIR)/build $(ROOT_DIR)/lib

.PHONY: run
run: makedir $(TARGET)
	@echo "Running"
	@APP=$(TARGET) QT_MAJOR=$(QT_MAJOR) USE_QML_SERVER=$(USE_QML_SERVER) $(RUN_SCRIPT)

.PHONY: clean-statusq
clean-statusq:
	@rm -f $(STATUS_Q_LIB)
	@rm -rf $(STATUSQ)/build
	@make -C $(STATUS_DESKTOP) statusq-clean

.PHONY: clean-dotherside
clean-dotherside:
	@rm -f $(DOTHERSIDE_LIB)
	@rm -rf $(DOTHERSIDE)/build
	@make -C $(STATUS_DESKTOP) dotherside-clean

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

.PHONY: clean-status-desktop-rcc
clean-status-desktop-rcc:
	@rm -f $(STATUS_DESKTOP_RCC)
	@rm -f $(STATUS_DESKTOP)/resources.rcc
	@rm -f $(STATUS_DESKTOP)/ui/resources.qrc
