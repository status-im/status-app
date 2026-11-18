# Description

These `Jenkinsfile`s are used to run CI jobs in Jenkins. You can find them here:
https://ci.status.im/job/nim-status-client/

# Builds

## Linux

In order to build the Linux version of the application we use the `ubuntu:20.04` Docker image where we install the Qt 5.15.2 provided by [aqt](https://github.com/miurahr/aqtinstall), linuxdeployqt provided by https://github.com/probonopd/linuxdeployqt and other dependencies (go, cmake, gcc etc.). We're using Ubuntu 20.04 to ensure glibc compatibility with the oldest still-supported LTS release and to comply with linuxdeployqt requirements.

The image is built with [`Dockerfile`](./Dockerfile) using:
```
docker build -t statusteam/nim-status-client-build:latest .
```
And pushed to: https://hub.docker.com/r/statusteam/nim-status-client-build

## MacOS

The MacOS builds are run on MacOS hosts and expect Command Line Toold and XCode to be installed, as well as QT being available under `/usr/local/qt`.

It also expects the presence of the following credentials:

* `macos-keychain-identity` - ID of used signing certificate.
* `macos-keychain-pass` - Password to unlock the keychain.
* `macos-keychain-file` - Keychain file with the MacOS signing certificate.

You can read about how to create such a keychain [here](https://github.com/status-im/infra-docs/blob/master/articles/macos_signing_keychain.md).

## Packaging in two steps

The machine that compiles the app has neither the signing keys nor the API keys and proxy credentials. GitHub Actions compiles; a Jenkins job on our own hosts adds the credentials and signs.

### 1. Build, on GitHub Actions

`.github/workflows/ci.yml` compiles the app without credentials and uploads it unsigned:

| Platform | Artifact | Content |
| --- | --- | --- |
| Linux | `Status-linux-x86_64-bundle` | the AppDir, from `make bundle-linux` |
| macOS | `Status-macos-aarch64-bundle` | `Status.app`, from `make bundle-macos` |
| Windows | `Status-windows-x86_64-bundle` | the folder the installer packs, from `make bundle-windows` |
| Android | `Status-android-arm64-bundle` | the APK, signed with a key that lives for one run |
| iOS | `Status-ios-arm64-unsigned` | the app in the layout of an `.ipa` |

Each file gets an [attestation](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations): a signed statement of which workflow built it and from which ref. A pull request from a fork gets none, so its build cannot be signed.

The workflow then packages what it built with the three API keys stored in GitHub and no real signature, for trying the pull request.

### 2. Sign, on Jenkins

[`Jenkinsfile.finalize`](./Jenkinsfile.finalize) takes the `RUN_ID` of a workflow run and a `PLATFORM`. It:

1. downloads the artifact and verifies its attestation ([`fetch-bundle.sh`](./fetch-bundle.sh)). With `RELEASE`, the app must have been built from `master`, a `release/*` branch or a tag;
2. writes the build config file into the app from the `STATUS_BUILD_*` credentials;
3. signs and packages: `scripts/finalize-{linux,macos,windows}.sh`, `mobile/scripts/android/finalize.sh`, or the fastlane lane for iOS;
4. notarizes (macOS releases), uploads and archives the package.

Nothing is compiled, and the scripts need neither Qt nor the git submodules. `make pkg-linux`, `make pkg-macos` and `make pkg-windows` still run both steps on one machine.

### The build config file

[`scripts/write-build-config.sh`](../scripts/write-build-config.sh) writes `build-config.json` from the `STATUS_BUILD_*` environment variables: `STATUS_BUILD_INFURA_TOKEN=abc` becomes `"INFURA_TOKEN": "abc"`. It goes into the package before signing, so the signature covers it. The app reads it at startup ([`src/build_config.nim`](../src/build_config.nim)); an option takes the first value found in:

1. the command line
2. the `STATUS_RUNTIME_*` environment variable
3. the build config file
4. the value compiled in from the `STATUS_BUILD_*` environment variable

A file that cannot be parsed stops the app at startup. Keys the app does not know are ignored.

## iOS

iOS builds use **fastlane** with **match** for code signing management.

For detailed documentation on iOS signing, fastlane configuration, and certificate management, see [`mobile/fastlane/README.md`](../mobile/fastlane/README.md).

