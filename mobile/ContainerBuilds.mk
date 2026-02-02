MAKEFILE_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
QT_VERSION?=6.9.2
QT_MAJOR=$(shell echo $(QT_VERSION) | cut -d. -f1)

-include $(MAKEFILE_DIR)/scripts/Common.mk

# Supported architectures
# arm64: arm64-v8a
# arm: armeabi-v7a
# x86_64: x86_64
# x86: x86
ARCH?=arm64

# Use the same pre-built Docker image as CI (see ci/Jenkinsfile.android)
DOCKER_IMAGE := harbor.status.im/status-im/status-desktop-build:1.0.6-qt$(QT_VERSION)-android

# Map architecture to Android ABI
ifeq ($(ARCH), arm64)
    ANDROID_ABI := arm64-v8a
else ifeq ($(ARCH), arm)
    ANDROID_ABI := armeabi-v7a
else
    ANDROID_ABI := x86_64
endif

# Package type (apk or aab)
PACKAGE_TYPE?=apk

$(TARGET): $(STATUS_DESKTOP_NIM_FILES) $(STATUS_DESKTOP_UI_FILES) $(STATUS_Q_FILES) $(STATUS_Q_UI_FILES) $(STATUS_GO_FILES) $(DOTHERSIDE_FILES) $(OPENSSL_FILES) $(QRCODEGEN_FILES) $(WRAPPER_APP_FILES)
	@echo "Building $(TARGET) for architecture $(ARCH) using Docker image $(DOCKER_IMAGE)"
	@mkdir -p $(BIN_PATH)
	@docker run --rm \
		--platform linux/amd64 \
		--entrypoint="" \
		-v $(ROOT_DIR)/..:/home/jenkins/workspace/status-desktop \
		-w /home/jenkins/workspace/status-desktop/mobile \
		-e ARCH=$(ARCH) \
		-e ANDROID_ABI=$(ANDROID_ABI) \
		-e QT_VERSION=$(QT_VERSION) \
		-e PACKAGE_TYPE=$(PACKAGE_TYPE) \
		-e MAKEFLAGS="-j$$(nproc) V=0" \
		$(DOCKER_IMAGE) \
		bash -c "export QMAKE=\$$(which qmake) && make ARCH=$(ARCH) PACKAGE_TYPE=$(PACKAGE_TYPE)"
	@echo "Build completed: $(TARGET)"
	@touch $(TARGET)

run: $(TARGET)
	@echo "Running $(TARGET)"
	@APP=$(TARGET) QT_MAJOR=$(QT_MAJOR) ADB=$(shell which adb) EMULATOR=$(shell which emulator) AVDMANAGER=$(shell which avdmanager) SDKMANAGER=$(shell which sdkmanager) $(RUN_SCRIPT)

clean:
	@echo "Cleaning container builds"
	@rm -rf $(ROOT_DIR)/bin $(ROOT_DIR)/build $(ROOT_DIR)/lib

default: $(TARGET)