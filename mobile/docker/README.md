# Status Desktop Mobile Build Docker Image

This directory contains a multi-stage Dockerfile that builds the complete environment for Status Desktop Android development and CI.

## Multi-Stage Build Structure

The Dockerfile uses a multi-stage build approach with the following layers:

1. **appimage-builder**: Base Ubuntu Noble image with AppImage builder tools
2. **qt-dev-base**: Extends appimage-builder with Qt development dependencies and Android SDK/NDK
3. **qt-installation**: Extends qt-dev-base with pre-built Qt binaries
4. **nim-runtime**: Extends qt-installation with Nim, Go, Nix, and OpenSSL for Android
5. **mobile-build**: Final stage with mobile-specific dependencies for Android APK builds

## Build Arguments

- `QTVER`: Qt version (default: 6.9.2)
- `TARGETARCH`: Target architecture (default: amd64)
- `JAVA_VERSION`: Java version (default: 17)
- `ANDROID_API_LEVEL`: Android API level (default: 35)
- `ANDROID_NDK_VERSION`: Android NDK version (default: 27.2.12479018)
- `GOLANG_VERSION`: Go version (default: 1.24.7)
- `NIM_VERSION`: Nim version (default: 2.0.12)
- `NIX_VERSION`: Nix version (default: 2.24.11)

## Building the Image

The image is built via Jenkins using `ci/Jenkinsfile.qt-build`. To build manually:

```bash
# Build the complete mobile-build image
docker build \
  --build-arg QTVER=6.9.2 \
  --build-arg TARGETARCH=amd64 \
  --build-arg JAVA_VERSION=17 \
  --build-arg ANDROID_API_LEVEL=35 \
  --build-arg ANDROID_NDK_VERSION=27.2.12479018 \
  --target mobile-build \
  -t statusteam/nim-status-client-build:1.0.1-qt6.9.2-android .
```

## Qt Source Build

When building Qt from source, the process requires:
1. Building the qt-dev-base stage
2. Running the Qt build script inside the container
3. Copying the qt_export directory with compiled Qt binaries

## Image Contents

The final image includes:
- Qt 6.9.2 for Android and desktop
- Android SDK/NDK
- Nim 2.0.12
- Go 1.24.7
- Nix package manager
- OpenSSL 3.0.15 for Android arm64-v8a
- Protobuf compiler and tools
- All necessary build dependencies

## Usage

The image is primarily used in CI/CD pipelines for building Status Desktop Android APKs. It provides a complete, reproducible build environment with all required tooling pre-installed.