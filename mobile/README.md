
# Status Mobile Build System

This repository contains the build system for Status Mobile, supporting both iOS and Android platforms with Qt6 compatibility.
Cross-compilation is currently supported on MacOs and Linux. Windows is not supported. The dev setup runs well on WSL with Windows emulator.

## Table of Contents
- [Quick Start Guide (Container Builds) - Android](#quick-start-guide-container-builds)
- [Developer Setup Guide](DEV_SETUP.md)
- [Build System Documentation](DEV_SETUP.md#build-system-documentation)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Contributing](CONTRIBUTING.md)

## Quick Start Guide (Container Builds)

This section is for users who want to get up and running quickly with minimal technical setup.

### Prerequisites
- Docker
- ADB (Android Debug Bridge)
- Android Emulator

### Quick setup - android

1. **Install dependencies:**

```bash
# macOS
brew install docker --cask
# Start docker
open -a Docker
brew install android-platform-tools android-commandlinetools xcbeautify
```

```bash
# Ubuntu
sudo apt-get update
sudo apt install android-sdk-common

sdkmanager --install \
"build-tools;36.0.0" \
"emulator" \
"platform-tools" \
"platforms;android-36" \
"ndk;27.2.12479018" \
"system-images;android-36;google_apis;arm64-v8a"
```

2. **Verify installation:**
```bash
docker --version
adb --version
emulator --version
avdmanager --version
sdkmanager --version
```

3. **Building the app**
```bash
make -f mobile/ContainerBuilds.mk
```

4. **Running the app**
```bash
# Linux and MacOS
make -f mobile/ContainerBuilds.mk run
```

### What Happens Behind the Scenes
- The build process uses the same pre-built Docker image as the CI pipeline (`harbor.status.im/status-im/status-desktop-build:1.0.3-qt6.11.0-android`)
- All required tools and dependencies (Qt 6.11.0, Android SDK/NDK, Go, Nim) are provided by the container
- The container runs on linux/amd64 platform for consistency, even on ARM macOS machines
- The built APK/AAB is available in the `mobile/bin/android/qt6/` directory
