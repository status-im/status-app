
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
      - [Install Nimble](#install-nimble)
      - [Install protobuf](#install-protobuf)
    - [Linux](#linux)
      - [Ubuntu](#ubuntu)
      - [Fedora](#fedora)
    - [macOS](#macos)
      - [Install Homebrew](#install-homebrew)
      - [Install Required Packages](#install-required-packages-1)
      - [Export GITHUB\_USER and GITHUB\_TOKEN environment variables](#export-github_user-and-github_token-environment-variables)
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
    - [Nim toolchain and Nim C libraries (nimble)](#nim-toolchain-and-nim-c-libraries-nimble)
    - [Build Configuration Options](#build-configuration-options)
  - [Pro tips](#pro-tips)
    - [Working with VS Code](#working-with-vs-code)
    - [Data folder](#data-folder)
  - [🐞 Troubleshooting](#-troubleshooting)
    - [Qt Not Found](#qt-not-found)
    - [Application doesn't build](#application-doesnt-build)
  - [📬 Need Further Help?](#-need-further-help)

## 1️⃣ Prerequisites

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

#### Install Nimble

The Nim-side prerequisite is **nimble**, *not* a particular Nim compiler: the
compiler is pinned in `nim_status_client.nimble` and nimble materialises it in
its own store (see [4️⃣ Build the App](#4️⃣-build-the-app)). Nimble ships with
every Nim distribution, so install Nim from the
[official website](https://nim-lang.org/install_windows.html) — or
[choosenim](https://github.com/nim-lang/choosenim) — and then stop caring about
its version: the pin decides what compiles this repo.

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
sudo apt install libpcsclite-dev build-essential mesa-common-dev libglu1-mesa-dev libssl-dev cmake jq libxcb-xinerama0
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
sudo dnf install pcsc-lite-devel openssl-devel protobuf-devel protobuf-compiler
```

Install **nvm** and Node.js as per the [Ubuntu instructions above](#ubuntu).


### macOS

#### Install Homebrew

Install [Homebrew](https://brew.sh/) if not already installed.

#### Install Required Packages

```bash
brew install cmake pkg-config go qt protobuf nim
```

> The `nim` formula is installed **for its nimble**, which is the actual
> prerequisite. Its compiler version is irrelevant: `nim_status_client.nimble`
> pins the compiler this repo builds with, and nimble materialises that one in
> its store (see [4️⃣ Build the App](#4️⃣-build-the-app)).

Install additional packages if you are planning to build DMG

```bash
brew install nvm yarn fileicon
```

#### Export GITHUB_USER and GITHUB_TOKEN environment variables

`status-desktop` uses Homebrew to download precompiled binary packages ("bottles") from GitHub.
Sometimes, Homebrew can hit GitHub's API rate limits, causing builds to fail.
To avoid this, you can generate a [GitHub personal access token](https://github.com/settings/personal-access-tokens) and export it in your environment:


```shell
export GITHUB_TOKEN=github_pat_YOURSUPERSECRETTOKENDONOTSHARE
export GITHUB_USER=yourgithubname
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
sudo apt install qt6-base-dev qt6-declarative-dev qt6-tools-dev qt6-multimedia-dev qt6-svg-dev qt6-webengine-dev
```

#### Fedora

```bash
sudo dnf install qt6-qtbase-devel qt6-qtbase-private-devel qt6-qt5compat-devel qt6-qtsvg-devel qt6-qtdeclarative-devel qt6-qtwebchannel-devel qt6-qtwebengine-devel qt6-qtwebsockets-devel
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
C:\nim-2.2.6\bin
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


Bootstrap the Nim toolchain — **this is the whole prerequisite**:

```bash
nimble setup            # resolves the graph AND materialises the pinned compiler
source ./env.sh         # puts THAT compiler at the front of PATH
```

> `env.sh` wraps `eval "$(nimble shellenv)"` and then hoists the pinned
> compiler's `pkgs2/nim-<version>-<checksum>/bin` to the front of `PATH`. Use it
> rather than bare `shellenv`: shellenv lists `~/.nimble/bin` *first*, and if you
> ever installed another Nim through nimble or choosenim, the `nim` symlink there
> would shadow the pin.

Build and run the app:

```bash
nim run status.nims
```
🎉

> **You do not install Nim.** `nim_status_client.nimble` pins the compiler
> (`requires "nim == 2.2.4"`) and nimble materialises it in its own store, so
> after `source ./env.sh` the `nim` on your PATH *is* the pinned compiler, by
> construction. Two guards keep it that way (issue 0018 review): `env.sh`
> asserts the compiler it hoists against the manifest's `requires "nim == …"`,
> and the driver refuses to compile the client with anything but the pinned
> store entry — naming `source ./env.sh` when it refuses.
> **Nimble is the only machine prerequisite** of the Nim side (plus Qt, Go, cmake
> and the platform packages listed above). The vendored `nimbus-build-system`,
> `make update`, `make deps`, `make status-go-deps` and `USE_SYSTEM_NIM` are all
> **gone** (issue 0018) — no shims: the driver bootstraps the submodules and the
> brew bottles itself, and nimble owns the compiler.
>
> The shell bootstrap is only needed for commands you run *yourself* outside
> nimble (`nim <task> status.nims`, `make mobile-build`). `nimble build` /
> `nimble run` inject the pinned compiler on their own.
>
> Since issue 0017 the driver owns every Nim compile. `nim app status.nims`
> builds; `nim run status.nims` builds if needed and launches;
> `nim app status.nims --force` forces a full client rebuild (the old
> `REBUILD_NIM=true`); `nim tests status.nims` runs the Nim suite.
> `make run` / `make nim_status_client` / `make tests-nim-linux` are gone.

Mobile builds are still make legs (they compile the client for iOS/Android).
They take the compiler from `PATH` too, so run them from a bootstrapped shell:

```bash
source ./env.sh && make mobile-build
```

### Nim toolchain and Nim C libraries (nimble)

The Nim side of this repo — the app's own dependency graph and the Nim C
libraries linked by status-go (nim-sds) — is resolved and built by this
repo's build system via [Nimble](https://github.com/nim-lang/nimble), not by
status-go and not by a vendored compiler.

**Prerequisite:** **Nimble (>= 0.22) on your PATH — and nothing else Nim-side.**
The compiler is not a prerequisite: `nim_status_client.nimble` pins it
(`requires "nim == 2.2.4"`) and `nimble setup` materialises it in nimble's store
(`~/.nimble/pkgs2/nim-<version>-<checksum>/`), building it from source once if
no binary is cached. `source ./env.sh` (a `nimble shellenv` wrapper) then puts
that store compiler at the FRONT of `PATH`, and every Nim compile in this repo —
the client, the Nim test suite, the mobile legs — uses it. nimble also injects it itself for its own tasks and
hooks, so `nimble build` / `nimble run` need no shell bootstrap.

There is no vendored compiler and no `nimbus-build-system` any more (issue
0018), and therefore no `USE_SYSTEM_NIM`: a bootstrapped shell cannot disagree
with the pin.

**App dependencies (`nimble.lock` → `~/.nimble`, nimble's default store):**
`nim_status_client.nimble` lists every Nim library the app needs as a
`requires "<git-url>#<sha>"` entry; `nimble.lock` is the committed, resolved
lock file (exact revision per package). The former `vendor/nim-*` submodules
for these libraries are gone — `nimble setup` materializes them under
nimble's default store (`~/.nimble`, shared safely between checkouts — the
store is content-addressed) and writes `nimble.paths` at the repo root, which
`config.nims` includes (behind `--noNimblePath`) to wire them into the
compile. One store for every front door: `nimble build` / `nimble run`
resolve against the default store, so make uses it too (a dedicated store
would force every nimble command through developer-exported env). Override
with the `NIMBLE_DIR` env var (nimble reads it natively) for CI or clean-room
runs. *Migration note:* the former dedicated store at
`~/.cache/status-desktop-nimbledeps` is retired — delete it whenever you
like (`rm -rf ~/.cache/status-desktop-nimbledeps`).
This runs automatically for the desktop build: the driver re-runs `nimble setup`
whenever `nimble.lock`, one of the graph's manifests
(`nim_status_client.nimble`; plus `vendor/status-go/statusgo.nimble` when a
statusgo develop checkout exists) or the develop overlay changes (content-keyed
in `.status-setup.key`), so a plain `nim run status.nims` /
`nim app status.nims` keeps the resolution in sync without a manual step. The
one-time bootstrap above (`nimble setup` + `source ./env.sh`) exists only to put
the pinned compiler on your PATH in the first place.
Ad-hoc nimble commands (e.g. `nimble lock` after editing a manifest) need no
store flags anymore. Mobile builds pick up the same
`config.nims`/`nimble.paths` resolution
but don't independently trigger the setup, so build desktop (or run
`make nimble-deps`) at least once first if you're going mobile-only or after
editing `nimble.lock` by hand.

**status-go in the same graph:** status-go is itself a nimble package (it
ships the `status_go` Nim wrapper next to the Go sources, and its manifest
owns the nim-sds pin), pinned by `nim_status_client.nimble` as a
`requires "<git-url>#<sha>"` like every other dependency — the app's one
`nimble setup` resolves status-go's Nim dependencies together with the app's
own: one resolution, one store, one lock file. There is no separate
per-status-go dependency solve or cache, and no `vendor/status-go` checkout
in the default flow. Because the store copy is read-only, the build maintains
a writable scratch copy of it at `.statusgo-build/` (refreshed only when the
pin or the build-flag set changes — `nim prepareStatusgo status.nims`, run by
make): libstatus and libsds build there, and while the pin is unchanged and
the artifacts exist, no-op builds skip the status-go sub-make entirely.
status-go's `statusgo.nims` build tasks (libsds) read the resolution from the
`nimble.paths` beside them, which the Makefiles derive by copying the app's
`nimble.paths` (all entries are absolute). The app compiles the wrapper with
`-d:statusGoNoAutoLink` (set in `config.nims`): it links the shared
libstatus/libsds flavors it builds itself instead of the wrapper's static
auto-link layout. To hack on status-go, run `nim develop status.nims
statusgo`: it materializes a real git clone at `vendor/status-go` (origin =
the pin URL, a branch at the pinned revision) and switches the build to it —
every Go/Nim/C edit is picked up by the next build (ADR 0003 FORCE +
compare-before-copy). `nim undevelop status.nims statusgo` returns to the
pin (refusing while the checkout has uncommitted or unpushed work).

**The seaqt pair in the same graph:** the Qt bindings (package `seaqt`, repo
nim-seaqt) and the NimQml layer (package `nimqml`, repo nimqml-seaqt) are
pinned `requires "<git-url>#<sha>"` dependencies too. They are pure-source
packages: the generated C++ shims compile via Nim `{.compile.}` pragmas into
the client's own nimcache, so the read-only store copies are consumed
directly — no sub-build, no scratch copy. The app-owned `seaqt_compat/`
include shim (`config.nims`) and the pkg-config-based Qt flag discovery
(prl-to-pc, below) work unchanged from store paths. To hack on them:
`nim develop status.nims seaqt` / `nim develop status.nims nimqml`.

**prl-to-pc in the same graph:** the Qt pkg-config machinery — the committed
relocatable Qt `.pc` trees per kit, the wrapper/generator sources, and the two
consumer interfaces `qt_pkgconfig.nims` and `qt-pkgconfig.mk` — is a pinned
dependency (`https://github.com/status-im/prl-to-pc.git#v0.3.0`; tag pins
resolve like any `#sha` special version). It is consumed as package-root
*files*, not Nim modules.

prl-to-pc decides which of two pkg-config modes the active Qt kit needs, by
probing it: **System mode** when the kit ships usable `.pc` metadata of its own
(nothing is built, no wrapper exists), **Generated mode** otherwise (Qt's
`.prl`-only kits, and kits whose `.pc` carry a broken build-farm prefix) — then
the committed relocatable tree plus the `pkg-config` wrapper that resolves its
`@@QT_PREFIX@@` placeholder are used. The app never re-implements any of that:

- the driver runs `nim e <root>/qt_pkgconfig.nims tools <buildDir> <paths>` and,
  once per build, `… env`, caching the answer in
  `.prl-to-pc-build/qt-pkgconfig.env` (keyed on the qmake path, the resolved
  package root and the kit);
- `config.nims` replays that cache — a build outside the driver (`make
  nim_status_client` on a fresh tree) fails fast and names the command to run;
- the root `Makefile` still `include`s `qt-pkgconfig.mk`, but only the mobile
  legs and `nim-test-run` consume it. The desktop build has no `qt-pkgconfig`
  make dependency.

The store copy is read-only, so the tools build into the repo-local
`.prl-to-pc-build/.pcwrap/`, and generating a *new* kit's `.pc` tree from a
store copy is refused — add kits from a checkout (`nim develop status.nims
prl-to-pc`, then `nim qtPkgconfigGenerate status.nims`) and commit them
upstream.

**What's still a git submodule:** only things that aren't pure Nim (C/C++):
`DOtherSide`, `SortFilterProxyModel`, `QR-Code-generator`, `fcitx5-qt`,
`mobile/vendors/openssl`. They are *pins*, not Vendors (CONTEXT.md), and the
driver initialises the ones the host build consumes itself — there is no
`make update` and no submodule auto-init in the Makefile.

**Hacking on a dependency locally:** to edit one of the pinned libraries in
place instead of at its pinned SHA, edit `nim_status_client.nimble` and point
that library's `requires` at your checkout with an ABSOLUTE `file://` URL
(`requires "file:///home/you/nim-chronos"`), then re-run `make nimble-deps`.
nimble resolves the checkout with link semantics — edits are picked up by the
next build without reinstalling anything. This is a machine-local manifest
edit; restore the pinned URL before committing. (`nimble develop --add` does
NOT work here: on nimble 0.22.3 develop links cannot satisfy `<url>#<sha>`
requires — they are silently ignored and the store copy wins. See
`vendor/status-go/AGENTS.md`, "nimble 0.22.3 resolution walls".)

- The nim-sds version pin lives in status-go's `statusgo.nimble`
  (a `requires "<git-url>#<sha>"` entry — interim the alexjba fork pin
  carrying the nim-sds patch queue until logos-messaging/nim-sds#85 merges
  and the pin moves to the upstream merge SHA). status-go's sds build tasks
  compile whatever copy the nimble resolution names: the pinned store copy
  is built in a scratch dir at `<statusgo root>/.sds-build` (i.e.
  `.statusgo-build/.sds-build` in the default flow — the store stays
  pristine; no `vendor/nim-sds` checkout exists), a develop-linked local
  checkout is built in place.

These run automatically as part of `nim app status.nims` / mobile builds.
No sibling `../nim-sds` clone is needed or used.

> **📝 Note:** if you have an old local run script that exports `CGO_LDFLAGS`
> with `-L.../nim-sds/build -lsds` (from before this migration), you can drop
> that — status-go now derives its own `-lsds` from `NIM_SDS_LIB_DIR`, and it's
> injected via `override +=` so it survives even if a stray `CGO_LDFLAGS` is
> still being passed on the command line. Passing the old flags is harmless
> but unnecessary.

### Build Configuration Options

The following environment variables can be used to customize the build:

- INCLUDE_DEBUG_SYMBOLS (0,1) - Configure nim to include the debug symbols for desktop platforms.
- KDF_ITERATIONS (number) - Configure the KDF_ITERATIONS to use for the DB encryption
- KEYCARD_QT_SOURCE_DIR (path) - Point the build system to a local keycard-qt folder. Defaults to empty (the pinned revision is fetched by CMake FetchContent); `nim develop status.nims keycard-qt` sets it to `vendor/keycard-qt`.
- MONITORING (true,false) - Enable/disable qml monitoring tools. The monitoring tools provide a suite of qml introspection tools to debug data transformations. Defaults to `false`
- NIM_SDS_SOURCE_DIR (path) - Point status-go's standalone build to a local nim-sds folder (unused by this repo's flow: the app builds libsds from the nimble-resolved copy and passes it via NIM_SDS_LIB_DIR/NIM_SDS_INC_DIR)
- PRODUCTION_PARAMETERS (string) - Configure the production arguments for nim compilation. Defaults to `-d:production`
- QMAKE (path to executable) - Point the build system to a different qt installation. Defaults to env configuration
- QML_DEBUG (true,false) - Enable qml debugger and profiler. Defaults to `false`
- QML_DEBUG_PORT (number) - Configure the qml debugger port. Defaults to `49152`
- QT_ARCH (string) - Configure the Qt architecture for macOS cross-compilation. Can be used to compile Intel builds on ARM64 OS. Defaults to `$(shell uname -m)`
- REBUILD_NIM — **removed** (issue 0017). Use `nim app status.nims --force`.
- USE_SYSTEM_NIM — **removed** (issue 0018): a nimbus-build-system knob, and there is no vendored compiler left to bypass.
- REBUILD_UI (true,false) - Force qrc recompilation
- STATUS_KEYCARD_QT_SOURCE_DIR (path) - Point the build system to a local status-keycard-qt folder. Defaults to empty (the pin in `cmake/status-keycard-qt/CMakeLists.txt` is fetched by CMake FetchContent); `nim develop status.nims status-keycard-qt` sets it to `vendor/status-keycard-qt`
- VCINSTALLDIR (path) - Visual Studio compiler installation path. Defaults to `C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\BuildTools\\VC\\`


## Pro tips

### Working with VS Code

To have nim code parsing, set the environment variables before opening your IDE. E.g. run `./env.sh code .` in the source root folder. `env.sh` is now a thin wrapper over `nimble shellenv` (issue 0018): it puts the *pinned* compiler on PATH and then execs what you gave it. `./env.sh bash` opens a shell in that environment; `source ./env.sh` bootstraps the current one.

### Data folder

The developer builds (using `nim run status.nims`) will generate and use the `Status` data folder at the root of the source tree as the user folder.

The release binaries (CI or `make pkg`) will use a user location to create and load user data.

For testing purposes, you can use a custom data folder by passing the `-d` flag
to the binary the driver built — the `run` task takes no application arguments
(the old `make run ARGS=...`; see issue 0017's follow-ups):

```bash
nim app status.nims
./bin/StatusDev.app/Contents/MacOS/nim_status_client -d=./dir   # macOS
./bin/nim_status_client -d=./dir                                # Linux
```

## 🐞 Troubleshooting

### Qt Not Found

Make sure your `QTDIR` and `PATH` are correctly set. You can also try:

```bash
export QTDIR=/path/to/Qt/6.11.0/gcc_64
export PATH=$QTDIR/bin:$PATH
```

### Application doesn't build

The driver streams the compiler's own output, so a failing build already shows
you the error. `make run V=1` (which used to be the answer here) is gone.

To see the client compile again after a successful build — the driver skips it
when nothing changed — force it:

```bash
nim app status.nims --force
```

To see WHY a step re-ran, delete its key file and re-run. Every key file the
driver keeps at the repo root is named `.status-<artifact>.key`
(`.status-client.key`, `.status-rcc.key`, `.status-setup.key`,
`.status-libsds.key`) — which is also what `make clean` removes, with one glob.

## 📬 Need Further Help?

If you get stuck or something doesn't work:

- Ask in `#feedback-desktop` channel on [Status](https://status.app/cc/G-EAAORobqgnsUPSVCLaSJr855iXTIdQiY1Q0ckBe8dWWEBpUAs9s8DTjWEpvsmpE83Izx1JWQuZrWWKUoxiXCwdtB-wPBzyvv_n9a0F61xTaPZE7BEJDC7Ly_WcmQ4tHRAKnPfXE_JUtEX_3NhnXQN0eh4ue0D77dWvaDpDrSi0U0CaGLZ-pqD_iV0z9RMFE2LKulDZdwL40etJ8lxjyTFoxS0lUhdWKinIOk8qBmJJpCmsqMrSklEU#zQ3shZeEJqTC1xhGUjxuS4rtHSrhJ8vUYp64v6qWkLpvdy9L9)
- Open an [issue on GitHub](https://github.com/status-im/status-app/issues/new/choose)

