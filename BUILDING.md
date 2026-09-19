
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
      - [Install nimble](#install-nimble)
      - [Install protobuf](#install-protobuf)
    - [Linux](#linux)
      - [Ubuntu](#ubuntu)
      - [Fedora](#fedora)
    - [macOS](#macos)
      - [Install Homebrew](#install-homebrew)
      - [Install Required Packages](#install-required-packages-1)
      - [Install nimble](#install-nimble-1)
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
    - [Nim dependencies](#nim-dependencies)
      - [Bumping a dependency](#bumping-a-dependency)
      - [Editing a dependency locally](#editing-a-dependency-locally)
    - [status-go](#status-go)
      - [Bumping the status-go pin](#bumping-the-status-go-pin)
      - [Editing status-go locally](#editing-status-go-locally)
      - [Stale store entries](#stale-store-entries)
      - [Windows](#windows-2)
    - [Build Configuration Options](#build-configuration-options)
  - [Pro tips](#pro-tips)
    - [Working with VS Code](#working-with-vs-code)
    - [Data folder](#data-folder)
  - [🐞 Troubleshooting](#-troubleshooting)
    - [Qt Not Found](#qt-not-found)
    - [Application doesn't build](#application-doesnt-build)
    - [No Nim 2.2.10 found / nimble setup failed](#no-nim-2210-found--nimble-setup-failed)
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

#### Install nimble

The Nim-side prerequisite is **nimble 0.24.1**, not a Nim compiler: `nim_status_client.nimble`
pins the compiler (`requires "nim == 2.2.10"`) and `make update` has nimble download it into
nimble's store. Download `nimble-windows_x64.zip` from
[nimble's releases](https://github.com/nim-lang/nimble/releases/tag/v0.24.1) and unzip it into a
directory on `PATH`; `C:\nimble` is where `scripts/windows_build_setup.ps1` puts it.

Do not install Nim. A Nim already on `PATH` does no harm: one of exactly 2.2.10 is reused as it
is, any other version is ignored. Run `scripts/windows_build_setup.ps1` (or just its `Seed-Nim`
step) before the first `make update`: nimble 0.24.1 cannot materialise the pinned Nim correctly
on Windows by itself (see [Windows](#windows-2) under status-go).

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

Install **nimble 0.24.1**, the whole Nim-side prerequisite. Do *not* install Nim:
`nim_status_client.nimble` pins the compiler and `make update` has nimble download it into its
store (`~/.nimble`). The release is a single binary; any directory on `PATH` works (CI uses
`/opt/nimble`):

```bash
mkdir -p ~/.local/bin && curl -fsSL \
  https://github.com/nim-lang/nimble/releases/download/v0.24.1/nimble-linux_x64.tar.gz \
  | tar xz -C ~/.local/bin
```

A Nim already on `PATH` does no harm: one of exactly 2.2.10 is reused as it is, any other
version is ignored.

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

Install **Go**, **nimble** (not Nim), **nvm** and Node.js as per the
[Ubuntu instructions above](#ubuntu).


### macOS

#### Install Homebrew

Install [Homebrew](https://brew.sh/) if not already installed.

#### Install Required Packages

```bash
brew install cmake pkg-config go qt protobuf
```

#### Install nimble

**nimble 0.24.1** is the whole Nim-side prerequisite; do not `brew install nim`
(`nim_status_client.nimble` pins the compiler and `make update` has nimble download it).
`scripts/macos_build_setup.sh`, the script CI runs, installs it into `~/.local/bin`; by hand:

```bash
# Apple silicon; use nimble-macosx_x64.tar.gz on Intel
mkdir -p ~/.local/bin && curl -fsSL \
  https://github.com/nim-lang/nimble/releases/download/v0.24.1/nimble-macosx_aarch64.tar.gz \
  | tar xz -C ~/.local/bin
```

Make sure `~/.local/bin` is on `PATH`.

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
C:\nimble
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


Fetch everything the build needs at the pinned revisions:

```bash
make update
```

This initialises the remaining git submodules (the C/C++ libraries), runs
`nimble setup` (the Nim packages and the pinned compiler, from `nimble.lock` into nimble's
store) and builds the Qt pkg-config wrapper. The first run on an empty store downloads the
dependency graph and the compiler, about two minutes; later runs take seconds. A C compiler
is needed at this point already: nat_traversal (eth's dependency) builds miniupnpc and
libnatpmp during setup.

> Tip: Nim takes a long compile. Try using the `-j8` flag where 8 is the number of cores you want to allocate

Build and run the app:

```bash
make run
```
🎉

### Nim dependencies

The Nim packages the client imports are not git submodules. `nim_status_client.nimble`
declares each one as `requires "<git url>#<sha>"`, the committed `nimble.lock` freezes the
resolved graph, and `nimble setup` materialises it in nimble's store (`~/.nimble` by default,
shared by every checkout on the machine; `NIMBLE_DIR` overrides it). Setup also writes
`nimble.paths` at the repo root, which `config.nims` includes, so the compiler finds the
packages without any environment. `make update` runs it for you; `make deps` (and so the client build) depends on the
`nimble.paths` stamp, which make regenerates only when the manifest or the lock is newer
than it.

The compiler is pinned in the same manifest (`requires "nim == 2.2.10"`) and comes from the
same store. `scripts/resolve-nim.sh` is the one place that finds it: `STATUS_NIM` if set,
else the store entry `nimble setup` materialised, else a `nim` on `PATH`; whatever it finds
must be the pinned version or it exits with an error. make evaluates it once per invocation
and runs every Nim compile with it (the client, the Nim tests, the mobile legs), and puts its
directory on `PATH` for the sub-builds that run a bare `nim` (status-go's libsds task, the
pkg-config wrapper). Nothing is installed on your machine and your `PATH` is not rewritten.

#### Bumping a dependency

1. Edit the package's `requires` line in `nim_status_client.nimble`: replace the `#<sha>` with
   the new revision.
2. Regenerate the lock with `NIMBLE_DIR=$(mktemp -d) nimble lock` (a full solve against an
   empty store, about two minutes: on a warm store nimble 0.24.1 lets entries it already
   holds into the solve, so the same manifest would lock differently on every machine).
   Run it from a real clone: in a git *worktree* nimble does not recognise the `.git` file
   and exits 1 after writing the lock. The lock it wrote is complete; the exit status is the
   only casualty.
3. `make update` materialises the new revision; the client depends on `nimble.paths`, so
   the next build recompiles it.
4. Review the `nimble.lock` diff. Only the package you bumped should move. Every package
   in the graph is pinned at the root, the transitive ones marked `# transitive` in the
   manifest, so if the bumped package's manifest now needs a newer revision of one of
   those, `nimble lock` fails on an unsatisfiable constraint instead of moving it: bump
   that `# transitive` line too.

One package deliberately floats on what the solver picks (websock), and isaac is pinned by
version rather than by revision; the comments on their lines in `nim_status_client.nimble`
say why. A revision the solver moves off a pin gets the same treatment: a comment on the
line.

#### Editing a dependency locally

To work on one of the pinned packages in place, point the manifest at a checkout instead of a
revision:

1. Clone the package anywhere, e.g. `git clone https://github.com/status-im/nim-chronos
   ~/src/nim-chronos`.
2. In `nim_status_client.nimble`, change its `requires` line to an **absolute** `file://`
   URL: `requires "file:///home/you/src/nim-chronos"`. Absolute, because nimble copies a
   relative path verbatim into `nimble.paths`.
3. `make deps` (the manifest changed, so it re-runs `nimble setup`; the committed lock is
   left alone) and build. `nimble.paths` now points at your checkout, so the client
   recompiles once. Later edits inside the checkout are not tracked by make:
   `make REBUILD_NIM=true run` picks them up.

Never commit the flip: restore the `requires "<url>#<sha>"` line when you are done and
`make deps` again. If you ran `nimble lock` while the flip was in place, revert `nimble.lock`
too (it rewrites that package's entry). `nimble develop` is not an option here: on nimble
0.24.1 a develop link cannot override a requirement pinned to a revision, it is silently
ignored and the store copy wins.

### status-go

status-go is one of those pinned packages: `requires "https://github.com/status-im/status-go.git#<sha>"`
in `nim_status_client.nimble`, resolved and materialised by the same `nimble setup`, frozen in
the same lock. The package ships the `status_go` Nim wrapper the client imports, and its own
manifest (`statusgo.nimble`) pins nim-sds, so nim-sds is in the graph transitively and the
desktop repo never names it. There is no `vendor/status-go` submodule and no `vendor/nim-sds`
checkout.

Both libraries are built from the read-only store copies, **in place**: `make status-go` runs
status-go's `libsds` nimble task (`nim libsds <store copy>/statusgo.nims`, which compiles the
nim-sds store copy the resolution names) and then status-go's own Makefile
(`make -C <store copy> statusgo-shared-library`), with every output redirected to
`.statusgo-build/` at the repo root: `build/bin/libstatus.*`, the generated cbindings entry
point, `.sds-build/build/libsds.*`, `.sds-build/library/libsds.h`, and two key files. Nothing
is written into the store. The key files gate rebuilds: `.source-root` records the tree the
artifacts came from (a change, i.e. a pin bump or a `STATUSGO_SRC` flip, wipes the directory)
and `.build-key` the flag set (a change drops the artifacts). While both hold, a no-op build
never invokes the status-go sub-builds. `make status-go-clean` removes the directory.

`make status-go-version` prints the pin's short SHA: a store copy has no git history to
`git describe`. The version compiled into libstatus itself is the desktop version.

#### Bumping the status-go pin

`scripts/override-status-go-ref.sh <sha|branch|PR number>` resolves the ref, rewrites the
requires line, runs `nimble lock` against an empty store and then `nimble setup` (from a
real clone, see [Bumping a dependency](#bumping-a-dependency)). By hand it is the same three
steps: edit the `#<sha>`, `NIMBLE_DIR=$(mktemp -d) nimble lock`, `make update`. The next
build rebuilds libsds, libstatus and the client. A nim-sds bump is a status-go bump: the pin
lives in status-go's `statusgo.nimble`, so pin the status-go revision that carries the nim-sds
revision you want.

Until the status-go packaging branch lands on develop the pin points at that branch (the
manifest comment names it), and the pull-request check that wants the pin on `develop` is red
by design.

#### Editing status-go locally

- `make STATUSGO_SRC=/path/to/status-go` (or export it) builds libsds and libstatus from that
  checkout instead of the store copy. The switch wipes `.statusgo-build/` (the source root
  changed), so a checkout and the store copy never share outputs, and switching back wipes it
  again. The `status_go` wrapper still comes from the store copy: this is for the Go side.
  `make fix-wallet-migrations` runs `go generate` in the status-go tree and needs a checkout
  this way too.
- The `file://` flip from [Editing a dependency locally](#editing-a-dependency-locally) works
  for status-go as for any package: the wrapper, `statusgo.nims` and the libraries all come from
  the checkout then (`STATUSGO_SRC` follows `nimble.paths`), and its `statusgo.nimble` decides
  the nim-sds revision.

#### Stale store entries

nimble 0.24.1 unions the requirements of same-named entries in its store. If
`~/.nimble/pkgs2` holds several `statusgo-*` entries (after bumping the status-go pin a few
times) that pin different nim-sds revisions, `nimble setup` can bind the wrong `sds-*` copy or
write a stale `nimble.paths`. Symptoms: `nimble.paths` names an `sds-…` entry whose revision
is not the one in `nimble.lock`, or the libsds build stops on a nim-sds copy that "has no
library/sds_tasks.nims". Fix:

```bash
rm -rf ~/.nimble/pkgs2/statusgo-* ~/.nimble/pkgs2/sds-*
make update
```

A fresh store never sees this.

#### Windows

Nothing status-go-specific: the two libraries build the same way as on Linux under Git Bash
(the libsds task, then status-go's Makefile), plus the MSVC import libraries the Makefile
synthesises from the headers.

The compiler is the one Windows-only step. nimble 0.24.1 cannot materialise the pinned Nim
correctly on Windows: its architecture probe fails (nimble #1862, fixed after 0.24.1) and it
silently fetches the 32-bit build, with which every compile stops on "Pointer size mismatch
between Nim and C/C++ backend". `nimble setup`, with or without `-l`, is unusable for that step
until a nimble release carries the fix. So run `scripts/windows_build_setup.ps1` (its `Seed-Nim`
step) before the first `make update`: it seeds the x64 Nim 2.2.10 into nimble's store,
checksum-pinned, and a later `make update` finds it there and never runs the probe.

### Build Configuration Options

The following environment variables can be used to customize the build:

- INCLUDE_DEBUG_SYMBOLS (0,1) - Configure nim to include the debug symbols for desktop platforms.
- KDF_ITERATIONS (number) - Configure the KDF_ITERATIONS to use for the DB encryption
- LOG_LEVEL (string) - Chronicles log level compiled into the client (`-d:chronicles_log_level=`). Unset by default
- MONITORING (true,false) - Enable/disable qml monitoring tools. The monitoring tools provide a suite of qml introspection tools to debug data transformations. Defaults to `false`
- NIMBLE_DIR (path) - nimble's store, where `make update` materialises the Nim packages and the compiler. Defaults to `~/.nimble`, shared between checkouts
- NIMFLAGS (string) - Extra flags for every Nim compile, e.g. `NIMFLAGS="-d:someDefine"`
- PRODUCTION_PARAMETERS (string) - Configure the production arguments for nim compilation. Defaults to `-d:production`
- QMAKE (path to executable) - Point the build system to a different qt installation. Defaults to env configuration
- QML_DEBUG (true,false) - Enable qml debugger and profiler. Defaults to `false`
- QML_DEBUG_PORT (number) - Configure the qml debugger port. Defaults to `49152`
- QT_ARCH (string) - Configure the Qt architecture for macOS cross-compilation. Can be used to compile Intel builds on ARM64 OS. Defaults to `$(shell uname -m)`
- REBUILD_NIM (true,false) - Force a recompile of the client when nothing make tracks changed, i.e. after an edit inside a checkout behind a `file://` requires line (a pin bump or a manifest change is tracked through `nimble.paths`)
- REBUILD_UI (true,false) - Force qrc recompilation
- STATUS_KEYCARD_QT_SOURCE_DIR (path) - Point the build system to a local status-keycard-qt folder. Defaults to `vendor/status-keycard-qt`
- STATUSGO_SRC (path) - Build libsds and libstatus from this status-go checkout instead of the resolved store copy (see [status-go](#status-go)). Defaults to the store copy `nimble.paths` names
- STATUS_NIM (path to executable) - Use this Nim instead of the one resolved from nimble's store. It must be the pinned version; `scripts/resolve-nim.sh` checks
- V (0-3) - Build output verbosity. `0` (default) silences make recipes and Nim hints; the value is also passed to nim as `--verbosity`
- VCINSTALLDIR (path) - Visual Studio compiler installation path. Defaults to `C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\BuildTools\\VC\\`


## Pro tips

### Working with VS Code

To have nim code parsing, the editor needs the pinned compiler on `PATH`: run `./env.sh code .` in
the source root folder. `env.sh` asks `scripts/resolve-nim.sh` for the compiler `make update`
materialised, puts its directory on `PATH` and runs what you gave it; `./env.sh bash` opens a
shell in that environment and `source ./env.sh` sets up the current one. No build needs it.
Module resolution needs nothing else: `config.nims` includes `nimble.paths`, so run
`make update` once first. (`nim check` on the whole client does not get through: the seaqt
bindings shell out at compile time with `gorge`, which `check` does not run. That predates
nimble.)

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

### No Nim 2.2.10 found / nimble setup failed

`resolve-nim: no Nim 2.2.10 found` means the store has not been populated yet: run
`make update`. `resolve-nim: … is not Nim 2.2.10` means what it found (`STATUS_NIM`, or a `nim` on `PATH`
before the store was populated) is another version: unset or fix it, or run `make update`. `ERROR: nimble setup failed` after you edited `nim_status_client.nimble` means the
lock no longer matches the manifest: run `nimble lock` (see
[Bumping a dependency](#bumping-a-dependency)) and retry.

## 📬 Need Further Help?

If you get stuck or something doesn't work:

- Ask in `#feedback-desktop` channel on [Status](https://status.app/cc/G-EAAORobqgnsUPSVCLaSJr855iXTIdQiY1Q0ckBe8dWWEBpUAs9s8DTjWEpvsmpE83Izx1JWQuZrWWKUoxiXCwdtB-wPBzyvv_n9a0F61xTaPZE7BEJDC7Ly_WcmQ4tHRAKnPfXE_JUtEX_3NhnXQN0eh4ue0D77dWvaDpDrSi0U0CaGLZ-pqD_iV0z9RMFE2LKulDZdwL40etJ8lxjyTFoxS0lUhdWKinIOk8qBmJJpCmsqMrSklEU#zQ3shZeEJqTC1xhGUjxuS4rtHSrhJ8vUYp64v6qWkLpvdy9L9)
- Open an [issue on GitHub](https://github.com/status-im/status-app/issues/new/choose)

