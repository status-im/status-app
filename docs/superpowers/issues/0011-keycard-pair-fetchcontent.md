---
id: 0011
title: Keycard pair — FetchContent pins + FETCHCONTENT_SOURCE_DIR develop redirect
date: 2026-07-06
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`

## What to build

Bring the CMake vendor flavor online for `status-keycard-qt` and its nested
FetchContent dependency `keycard-qt`:

- Convert the `vendor/status-keycard-qt` submodule to a CMake FetchContent
  pin (`GIT_TAG` = today's submodule SHA) in the app's CMake orchestration
  (the Makefile keycard target already drives cmake; the existing
  `STATUS_KEYCARD_QT_SOURCE_DIR ?=` knob is the natural seam). Submodule
  removal follows the Phase 2 staged playbook.
- `keycard-qt` is already FetchContent'd by status-keycard-qt — pin audit
  only (ensure a fixed `GIT_TAG`, not a branch).
- Vendor-table entries (0009 driver) for both, flavor = cmake: `develop
  status-keycard-qt` / `develop keycard-qt` clone the repo into
  `vendor/<name>` at the pin and export
  `FETCHCONTENT_SOURCE_DIR_<NAME>` (the proven MobileUI pattern in
  buildStatusQ.sh) for all subsequent builds; `undevelop` drops the redirect.
  Nested develop (keycard-qt) must work WITHOUT developing status-keycard-qt.
- Default-mode gating: FetchContent at a fixed GIT_TAG + cmake's own
  incrementality already skip unnecessary work; verify no per-build network
  fetch (FetchContent caches; `FETCHCONTENT_UPDATES_DISCONNECTED` if needed).

## Acceptance criteria

- [ ] Default mode, no `vendor/status-keycard-qt` checkout: full desktop
  build passes with both keycard libs fetched at their pins; second build
  performs no network access and no keycard recompilation.
- [ ] `develop status-keycard-qt` → edit a C++ source → next `nim app` build
  recompiles and relinks the dependent → `undevelop` returns to the pin.
- [ ] `develop keycard-qt` alone (parent stays pinned) → C++ edit picked up
  through status-keycard-qt's build.
- [ ] Keycard functionality smoke on desktop build (app launches; keycard
  service initializes — no deeper hardware test required).
- [ ] `nim vendors status.nims` reports both, with pin + state.

## Blockers — grill before implementing

- Where the FetchContent declaration for status-keycard-qt lives (StatusQ
  CMake vs a new top-level CMakeLists vs the Makefile's cmake invocation) —
  survey the current keycard make target first; grill if the natural seam is
  contested.

## Blocked by

- 0009 (vendor table + develop UX).
