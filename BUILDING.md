
# 🛠️ Status Desktop Build Guide

This guide provides step-by-step instructions to build Status Desktop from source on **Windows**, **Linux**, and **macOS**.

If you're looking for instructions to build Status Mobile instead, go [here](/mobile/README.md).

## 📑 Table of Contents

- [🛠️ Status Desktop Build Guide](#️-status-desktop-build-guide)
  - [📑 Table of Contents](#-table-of-contents)
  - [1️⃣ Prerequisites](#1️⃣-prerequisites)
    - [Windows](#windows)
      - [Install Chocolatey](#install-chocolatey)
      - [Install Required Packages](#install-required-packages)
      - [Install Microsoft Visual C++ Build Tools](#install-microsoft-visual-c-build-tools)
      - [Install Go 1.26](#install-go-126)
      - [Install protobuf](#install-protobuf)
    - [Linux](#linux)
      - [Ubuntu](#ubuntu)
      - [Fedora](#fedora)
    - [macOS](#macos)
      - [Install Homebrew](#install-homebrew)
      - [Install Required Packages](#install-required-packages-1)
      - [Install Node.js](#install-nodejs)
      - [Install Python Dependencies](#install-python-dependencies)
  - [2️⃣ Install Qt](#2️⃣-install-qt)
    - [Windows \& Linux](#windows--linux)
    - [Linux (Alternative)](#linux-alternative)
      - [Ubuntu](#ubuntu-1)
      - [Fedora](#fedora-1)
  - [3️⃣ Configure Environment](#3️⃣-configure-environment)
    - [Windows](#windows-1)
    - [Linux](#linux-1)
  - [4️⃣ Build the App](#4️⃣-build-the-app)
    - [Build Configuration Options](#build-configuration-options)
    - [Nim packages](#nim-packages)
    - [Nim token catalogue](#nim-token-catalogue)
  - [Pro tips](#pro-tips)
    - [Working with VS Code](#working-with-vs-code)
    - [Data folder](#data-folder)
  - [🐞 Troubleshooting](#-troubleshooting)
    - [Qt Not Found](#qt-not-found)
    - [Application doesn't build](#application-doesnt-build)
  - [📬 Need Further Help?](#-need-further-help)

## 1️⃣ Prerequisites

StatusQ fetches a pinned Hunspell revision with CMake FetchContent and builds it
statically for offline chat spell checking. No system Hunspell installation is
needed. The English dictionary and license notices are bundled in Qt resources;
only the initial dependency fetch needs network access.
For iOS, the mobile StatusQ build also stages `libhunspell-1.7.a`, which the
qmake wrapper links explicitly alongside the static StatusQ archive.

On every platform, install [nimble](https://github.com/nim-lang/nimble/releases)
0.26.2 or newer and put it on `PATH` (or pass `NIMBLE=/path/to/nimble` to
`make`). The build takes the Nim compiler and every Nim package from
`nim_status_client.nimble` and `nimble.lock` (see [Nim packages](#nim-packages)),
so no separate Nim install is needed.

### Windows

#### Install Chocolatey

Install [Chocolatey](https://chocolatey.org/install) by running the following command in an **Administrator** PowerShell:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; `
[System.Net.ServicePointManager]::SecurityProtocol = `
[System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

#### Install Required Packages

Run with **Administrator** privileges:

```powershell
choco install make cmake mingw wget
```

#### Install Microsoft Visual C++ Build Tools

You can install them from the [Microsoft website](https://visualstudio.microsoft.com/visual-cpp-build-tools/) or run the `Install-VC-BuildTools` from the setup script `scripts/windows_build_setup.ps1`.

#### Install Go 1.26

Download and install Go 1.26 from the [official website](https://go.dev/dl/).

#### Install protobuf

Install [scoop](https://scoop.sh/) if you don't have it already. Then run:

```
scoop bucket add extras
scoop install --global protobuf@36.0
```

> ⚠️ Note: There is a script `scripts/windows_build_setup.ps1`, which is used to install dependencies on CI machines. Feel free to use it as inspiration for the needed versions.

### Linux

#### Ubuntu

Install required packages:

```bash
sudo apt update
sudo apt install libpcsclite-dev build-essential mesa-common-dev libglu1-mesa-dev libssl-dev cmake jq libxcb-xinerama0 libsecret-1-dev
```

> ⚠️ Note: `status-go` needs protoc 36 or newer, which is newer than `protobuf-compiler` in apt. `scripts/ubuntu_build_setup.sh` installs it from the upstream release.

Install **Go 1.26**:

Download and install from the [official website](https://go.dev/dl/).

Install **nvm** (Node Version Manager):

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
```

Add the following to your `.bashrc` or `.zshrc`:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

Install Node.js (LTS version):

```bash
nvm install --lts
nvm alias default lts/*
npm install -g npm@latest
```

#### Fedora

Install required packages:

```bash
sudo dnf install pcsc-lite-devel openssl-devel protobuf-devel protobuf-compiler libsecret-devel
```

Install **nvm** and Node.js as per the [Ubuntu instructions above](#ubuntu).


### macOS

#### Install Homebrew

Install [Homebrew](https://brew.sh/) if not already installed.

#### Install Required Packages

```bash
brew install cmake pkg-config go qt protobuf 
```

Install additional packages if you are planning to build DMG

```bash
brew install nvm yarn fileicon
```


#### Install Node.js

> [!TIP]
> You can skip this step if not planning to build a DMG

Create NVM's working directory:

```bash
mkdir ~/.nvm
```

Add the following to your shell profile (`~/.zshrc`, `~/.bash_profile`, etc.):

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
```

Install Node.js (LTS version):

```bash
nvm install --lts
nvm alias default lts/*
npm install -g npm@latest
```

Install additional dependencies:

```bash
npm install fileicon
brew install coreutils
```

#### Install Python Dependencies

> [!TIP]
> You can skip this step if not planning to build a DMG

If using Python ≥ 3.12:

```bash
python3 -m pip install setuptools --break-system-packages
```


## 2️⃣ Install Qt

### Windows & Linux

Install **Qt 6.11.0** using the [Qt Online Installer](https://download.qt.io/official_releases/online_installers/).

### Linux (Alternative)

You can use any newer 6.11.x version available in your system's package manager.

#### Ubuntu

```bash
sudo apt install qt6-base-dev qt6-declarative-dev qt6-tools-dev qt6-multimedia-dev qt6-shadertools-dev qt6-svg-dev qt6-webengine-dev
```

#### Fedora

```bash
sudo dnf install qt6-qtbase-devel qt6-qtbase-private-devel qt6-qt5compat-devel qt6-qtsvg-devel qt6-qtdeclarative-devel qt6-qtshadertools-devel qt6-qtwebchannel-devel qt6-qtwebengine-devel qt6-qtwebsockets-devel
```


## 3️⃣ Configure Environment

### Windows

Set environment variables:

```powershell
$env:QTBASE = "C:\Qt\6.11.0"
$env:QTDIR = "C:\Qt\6.11.0\msvc2022_64"
$env:GOPATH = "C:\Program Files\Go\bin"
$env:VCINSTALLDIR = "C:\BuildTools\VC"
```

Add the following paths to your `PATH` environment variable:

```
C:\ProgramData\chocolatey\bin
C:\ProgramData\scoop\shims
С:\Users\{your_username}\go\bin
C:\Program Files\Go\bin
C:\Users\{you_username}\.nimble\bin
C:\Qt\6.11.0\msvc2022_64\bin
C:\BuildTools\VC\Tools\MSVC\14.44.35207\bin
C:\ProgramData\mingw64\mingw64\bin
C:\Program Files\CMake\bin
C:\Qt\Tools\Ninja
C:\Program Files\7-Zip
```

### Linux

If you installed Qt via your system's package manager, additional environment configuration may not be necessary.

Otherwise, set those environment variables:
```shell
export QTDIR="/path/to/Qt/6.11.0/gcc_64"
export PATH="${QTDIR}/bin:${PATH}"
```


## 4️⃣ Build the App

> **📝 Note:** On Windows, all commands should be executed under **Git Bash**.
.

Clone the repository:

```bash
git clone https://github.com/status-im/status-app.git
cd status-desktop
```


Update all submodules and build the dependencies:

```bash
make update
```

> Tip: Nim takes a long compile. Try using the `-j8` flag where 8 is the number of cores you want to allocate

Build and run the app:

```bash
make run
```
🎉

### Build Configuration Options

The following environment variables can be used to customize the build:

- INCLUDE_DEBUG_SYMBOLS (0,1) - Configure nim to include the debug symbols for desktop platforms.
- KDF_ITERATIONS (number) - Configure the KDF_ITERATIONS to use for the DB encryption
- MONITORING (true,false) - Enable/disable qml monitoring tools. The monitoring tools provide a suite of qml introspection tools to debug data transformations. Defaults to `false`
- NIMBLE (path to executable) - The nimble to resolve Nim packages with (0.26.2 or newer). Defaults to `nimble` on `PATH`
- PRODUCTION_PARAMETERS (string) - Configure the production arguments for nim compilation. Defaults to `-d:production`
- QMAKE (path to executable) - Point the build system to a different qt installation. Defaults to env configuration
- QML_DEBUG (true,false) - Enable qml debugger and profiler. Defaults to `false`
- QML_DEBUG_PORT (number) - Configure the qml debugger port. Defaults to `49152`
- QT_ARCH (string) - Configure the Qt architecture for macOS cross-compilation. Can be used to compile Intel builds on ARM64 OS. Defaults to `$(shell uname -m)`
- REBUILD_NIM (true,false) - Force nim recompilation
- REBUILD_UI (true,false) - Force qrc recompilation
- STATUS_KEYCARD_QT_SOURCE_DIR (path) - Point the build system to a local status-keycard-qt folder. Defaults to `vendor/status-keycard-qt`
- VCINSTALLDIR (path) - Visual Studio compiler installation path. Defaults to `C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\BuildTools\\VC\\`


### Nim packages

`nim_status_client.nimble` pins the Nim compiler and every Nim package the app
uses; `nimble.lock` records the exact revisions. `make` runs `nimble setup --localdeps`
whenever either changes: packages go to `nimbledeps/` and `nimble.paths` lists
them for the compiler.
After editing the manifest, regenerate the lock with `nimble lock`.

status-go stays a git submodule (`vendor/status-go`) and is not a nimble
dependency. The app pins the Nim libraries status-go links (nim-sds,
nim-token-lists) with the same lines as `vendor/status-go/status_go.nimble`. A
status-go bump that changes those pins must update the app manifest and lock
too.

The app passes status-go its compiler, its resolution (`NIMBLE_ROOT`) and its
own Nim policy for those libraries (`makefiles/nim-libs.mk`), so they build
from the app's resolution with the app's flags.

### Nim token catalogue

Desktop and mobile builds use the Nim token catalogue as the sole token
backend. With the development environment configured, the usual build and
`make run` commands need no token flags or separate library checkout.

Status-go pins the public Go wrapper and native library to the same revision,
builds the native library from the app's nimble resolution and reuses matching
native and backend artifacts. Mobile archives are separate for each
architecture and for iOS devices and simulators. `make clean` removes them; the
next build prepares them again.

There are no build-time or runtime backend selectors. A rollback requires an
earlier app/backend revision.

On iOS, status-go bundles the token library into its static archive. The app's
final link hides the token ABI and the build checks the installed executable
for leaked token-library exports.

## Pro tips

### Working with VS Code

For Nim code parsing, open the IDE with the pinned Nim on `PATH`: run `nimble shell code .` in the source root folder.

### Data folder

The developer builds (using `make run`) compiled with `make` will generate and use the `Status` data folder at the root of the source tree as the user folder.

The release binaries (CI or `make pkg`) will use a user location to create and load user data.

For testing purposes, you can use a custom data folder by passing the `-d` flag. For example:

```bash
make run ARGS="-d=./dir"
```

## 🐞 Troubleshooting

### Qt Not Found

Make sure your `QTDIR` and `PATH` are correctly set. You can also try:

```bash
export QTDIR=/path/to/Qt/6.11.0/gcc_64
export PATH=$QTDIR/bin:$PATH
```

### Application doesn't build

Get more log output:

```bash
make run V=1
```

## 📬 Need Further Help?

If you get stuck or something doesn't work:

- Ask in `#feedback-desktop` channel on [Status](https://status.app/cc/G-EAAORobqgnsUPSVCLaSJr855iXTIdQiY1Q0ckBe8dWWEBpUAs9s8DTjWEpvsmpE83Izx1JWQuZrWWKUoxiXCwdtB-wPBzyvv_n9a0F61xTaPZE7BEJDC7Ly_WcmQ4tHRAKnPfXE_JUtEX_3NhnXQN0eh4ue0D77dWvaDpDrSi0U0CaGLZ-pqD_iV0z9RMFE2LKulDZdwL40etJ8lxjyTFoxS0lUhdWKinIOk8qBmJJpCmsqMrSklEU#zQ3shZeEJqTC1xhGUjxuS4rtHSrhJ8vUYp64v6qWkLpvdy9L9)
- Open an [issue on GitHub](https://github.com/status-im/status-app/issues/new/choose)
