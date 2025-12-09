## Developer Setup Guide

This section is for developers who want full control over the build environment.

### iOS Development Setup

#### Prerequisites

- Python 3.x
- Qt 6.9.2
- Xcode
- iPad Pro simulator

#### Setup Steps

1. **Install Qt for iOS (skip if you have it already):**
```bash
pip3 install -U pip
pip3 install aqtinstall

# Install Qt 6.9.2
aqt install-qt mac ios 6.9.2 -O $HOME/qt -m all --autodesktop

# If the above fails on arm64, try:
arch -x86_64 aqt install-qt mac ios 6.9.2 -O $HOME/qt -m all --autodesktop
export PATH=$HOME/qt/6.9.2/ios/bin:$HOME/qt/6.9.2/macos/libexec:$HOME/qt/6.9.2/macos/bin:${PATH}
export QTDIR=$HOME/qt/6.9.2/ios
```

2. **Build and run:**
```bash
make mobile-run
```

Running the app requires a code sign identity. See [Signing](#signing)

#### Keycard

The keycard support is disabled by default in the mobile makefile for IOS. It requires a paid apple developer account to run the app with NFC enabled.

To enable keycard use the `USE_STATUS_KEYCARD_QT=1` flag for the main Makefile and use a paid account by updating the `QMAKE_DEVELOPMENT_TEAM` flag and the bundle if (if the development team isn't Status).

#### Signing

By default the app isn't signed.

To sign the app the `QMAKE_DEVELOPMENT_TEAM` flag needs to be provided. If the development team is not Status development team, then the app bundle id needs to be updated to a unique bundle id.

#### 

### Android Development Setup

#### Prerequisites - can be installed using the Android Studio
- JDK 17
  - Settings > Build, Execution, Deployment > Build Tools > Gradle: Gradle JDK - Download JDK - Select 17 
- Android SDK
  - Settings > Languages & Framework > Android SDK - Select Android 15 - Apply
- Android NDK 27.2.12479018
  - Settings > Languages & Framework > Android SDK > SDK Tools tab - Check Show Package Details - NDK (Side by side) > Select 27.2.12479018 - Apply
- Platform android-35
	- Installed with Android 15
- Android emulator (optional)
  - Installed with Android Studio
- Android command-line tools
  - Settings > Languages & Framework > Android SDK > SDK Tools tab - Select Android SDK Command-line Tools - Apply

#### Setup Steps

1. **Install Qt for Android (skip if you have it already):**


Note: It's best to install the qt architecture matching the system architecture

```bash
# For Qt6 (includes desktop tools)
# arm host
aqt install-qt mac android 6.9.2 android_arm64_v8a -O $HOME/qt -m all --autodesktop
# x64 host
aqt install-qt mac android 6.9.2 android_x86_64 -O $HOME/qt -m all --autodesktop
# optional
aqt install-qt mac android 6.9.2 android_x86 -O $HOME/qt -m all
aqt install-qt mac android 6.9.2 android_armv7 -O $HOME/qt -m all
```
2. **Set environment variables:**
```bash
# Set Java home
export JAVA_HOME=/path/to/jdk

# Set Android SDK and NDK paths
export ANDROID_SDK_ROOT=/path/to/android-sdk
export ANDROID_NDK_ROOT=/path/to/android-ndk/27.2.12479018

# Add Android tools to PATH
export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/tools/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# Add Qt to PATH. Qt6 needs both android bin and host libexec and host bin (in this order!)
export QTDIR='/your/Qt/Preferred/Folder' # CHANGE ME
export QTTARGET='yourQtHostTarget' # CHANGE ME
export PATH="$QTDIR/6.9.2/$QTTARGET/bin:$QTDIR/6.9.2/$QTTARGET/libexec:$QTDIR/6.9.2/$QTTARGET/bin:${PATH}"

```

3. **Validate the environment**
```
qmake --version # prints qmake for android
java --version # 17.0.14
emulator --version # execution works
echo $ANDROID_NDK_ROOT # points to 27.2.12479018
ls -l $ANDROID_SDK_ROOT/platforms/android-35 # android-35 in installed
avdmanager --version
sdkmanager --version
adb --version
```

4. **Build and run:**
```bash
make mobile-run
```

## Build System Documentation

### Environment Variables

The build system uses several environment variables to control the build process:

#### Build Control Variables
- `USE_SYSTEM_NIM=1`: Use system-installed Nim instead of building from source. Make sure `nim` and `nimble` are available

#### Platform Configuration
- `OS`: Target platform (`ios` or `android`)
	- qmake driven
- `ARCH`: Target architecture
	- defaults to host arch for android and `x86_64` for ios simulator
	- iOS: `arm64` (device) or `x86_64` (simulator)
	- Android: `arm64` (arm64-v8a), `arm` (armeabi-v7a), `x86_64`, or `x86`
- `PATH`: Should contain the path to Android or iOS Qt installation `bin` folder

#### Android-specific Variables
- `ANDROID_API`: Android API level (default: 28)
- `ANDROID_NDK_ROOT`: Path to Android NDK
- `ANDROID_SDK_ROOT`: Path to Android SDK
- `JAVA_HOME`: Path to JDK installation

#### iOS-specific Variables
- `IPHONE_SDK`: iOS SDK to use (`iphoneos` or `iphonesimulator`)
- `IOS_TARGET`: Minimum iOS version (16 for Qt6)

### Qt Version Compatibility

#### Qt6
- iOS minimum deployment target: iOS 16
- iOS simulator: iPad Pro
- Android target: Android 35
- Android NDK: 27.2.12479018
- Android API: 28
- JDK: 17

### Directory Structure
- `mobile/bin`: Final build outputs
- `mobile/lib`: Compiled libraries
- `mobile/build`: Intermediate build files
- `mobile/scripts`: Build scripts and utilities

### Key Components
- Status Go
- StatusQ
- DOtherSide
- OpenSSL
- QRCodeGen
- Nim Status Client

### Build Targets
- `make mobile-build`: Build all components
- `make mobile-clean`: Clean all build artifacts
- `make mobile-run`: Build and run the application
