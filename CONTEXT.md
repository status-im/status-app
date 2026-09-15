# Ubiquitous Language — status-desktop nimble migration

## App entry point (one-command build)
The single command a developer runs to get a runnable Status app from a clean
clone. It is a **nimscript task** (front door), not a nimble `install` action:
the runnable dev build is produced **in the repo**, exactly where today's make
flow puts it (packaging/distributables stay make/CI-only). One entry point for
all targets: the task receives `--os/--cpu` flags (host by default); kit
selection (QMAKE, NDK, team) stays environment-driven. The task self-bootstraps
dependency resolution (runs `nimble setup` only when the manifest/lock is
stale). It lives in a companion `.nims` driver invoked via `nim` — NOT as a
`nimble` task, because `nimble <task>` re-pays ~46s of graph revalidation on
every invocation (measured; violates build efficiency). If a future nimble
removes that tax, promoting to `nimble app` is mechanical. A true machine-level
`nimble install` of the app is a possible later layer, desktop-host only.

## Vendor
A dependency of the app that Status develops, as opposed to third-party pins.
Two flavors, one develop-mode UX:
- **Nimble-graph vendors** (`statusgo`, `sds`, `seaqt`, `nimqml`): pinned
  `URL#hash` requires in the nimble graph; develop mode via the nimble.paths
  overlay. Build from read-only store copies (scratch engine where in-place
  writes are needed), so default-mode content can never drift.
- **CMake vendors** (`status-keycard-qt`, `keycard-qt`): pinned by CMake
  FetchContent `GIT_TAG`; develop mode via `FETCHCONTENT_SOURCE_DIR_<NAME>`
  redirect to the materialized checkout. Nested CMake vendors (keycard-qt)
  need no parent cascade.
End-state: **default mode has no Vendor checkouts at all** — no submodule
carries a Vendor. (Third-party C/C++ submodules — SFPM, QR-Code-generator,
fcitx5-qt, mobile openssl — are pins, not Vendors, and may remain submodules;
converting them is a separate decision.)
Vendor names, as used by `develop <vendor>`, are the package/project names
above.

## Default mode vs develop mode
- **Default mode**: vendors are consumed at their pinned revisions from the
  nimble resolution (store copies); builds skip every unnecessary compilation
  step.
- **Develop mode**: per-vendor. One command materializes the vendor as a real
  git checkout under `vendor/<name>` (origin = the pin URL, checked out at the
  pinned revision) and switches the build to it; every change in that vendor
  (Nim, C/C++, Go) is picked up by the next app build. The developer can
  commit/push/PR from the checkout. A second command exits develop mode and
  returns to the pin.

## Pinned compiler
The Nim compiler the app's manifest names by exact version, which nimble
materializes in its own store. It is the only compiler that may compile
anything in this repo: every front door reaches it through nimble, and the
build refuses any other. Contrast **system nim**: a compiler installed on a
machine or a CI image. A system nim is never the compiler that builds the app,
even when its version happens to equal the pin; at most it is how nimble
itself gets onto a machine. (CI images standardized on a system nim while this
migration was in flight; the pin was moved to the same version so the two
agree, but the rule is unchanged: the pinned compiler builds, the system one
does not.)
