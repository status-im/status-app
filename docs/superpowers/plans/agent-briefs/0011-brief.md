# Agent brief — issue 0011: keycard pair (FetchContent pins + develop redirect)

Read `docs/superpowers/plans/agent-briefs/SHARED.md` first, then your issue:
`docs/superpowers/issues/0011-keycard-pair-fetchcontent.md`, plus the 0009
verification record (vendor table + overlay you extend).

## Your role

Implementer of issue 0011, in two phases. **Agent 0010 holds the in-tree
build lock and owns `status.nims` + the Makefiles until its completion
commit (containing `0010`) lands.** Poll `git log --oneline | grep 0010`
between phase-A steps.

## Phase A — survey + preparation (immediately; read-only in the repo)

- Map the current keycard chain end-to-end: root `Makefile` keycard targets
  (`STATUS_KEYCARD_QT_SOURCE_DIR ?= vendor/status-keycard-qt`, build dir,
  `STATUSKEYCARD_QT_LIB`), `vendor/status-keycard-qt/CMakeLists.txt` (how it
  FetchContents `keycard-qt` — URL, GIT_TAG form), who consumes the built
  lib (link flags, config.nims/StatusQ?), and the mobile legs (does
  mobile/ build keycard? OpenSSL handling for iOS/Android is mentioned in
  its CMakeLists — note it).
- Record current pins: submodule SHA for status-keycard-qt (`git ls-tree
  HEAD vendor/status-keycard-qt` in the outer repo) and keycard-qt's
  GIT_TAG inside the CMakeLists. If keycard-qt's GIT_TAG is a branch, the
  fix (pin to the SHA it currently resolves to) is part of this issue.
- Design the conversion against the grilled decisions: FetchContent pin for
  status-keycard-qt itself (the existing `STATUS_KEYCARD_QT_SOURCE_DIR` knob
  is the natural develop-redirect seam — decide whether FetchContent
  replaces the make-level clone or wraps it; READ the make recipe before
  choosing; if the natural seam is genuinely contested after reading, grill
  per SHARED).
- Prepare the cmake-flavor vendor-table rows ({status-keycard-qt,
  keycard-qt}: pin refs, checkout dirs, redirect env
  `FETCHCONTENT_SOURCE_DIR_<NAME>` — verify the exact NAME casing cmake
  derives) and the develop/undevelop behavior per ADR 0007 + CONTEXT.md.
  MobileUI's FETCHCONTENT_SOURCE_DIR redirect in `scripts/buildStatusQ.sh`
  is the proven precedent — read it.
- Write your plan into the issue file (a "Survey findings" section) and
  commit it (docs-only commits are allowed in phase A — only your files).

## Phase B — implement + verify (gate: 0010 completion commit in git log)

- Implement: submodule → FetchContent pin (staged removal, Phase 2 playbook,
  backup ref first), vendor-table rows, develop/undevelop redirect legs,
  no-network-on-second-build verification
  (`FETCHCONTENT_UPDATES_DISCONNECTED` if needed).
- Acceptance = the issue's five checkboxes. The develop-mode C++ edit test:
  touch a source in the checkout → next `nim app status.nims` recompiles
  and relinks the dependent — verify via mtime/cmp on the keycard lib, the
  0004 probe pattern.
- Keycard smoke: app launches, keycard service initializes (no hardware
  test).

Follow the SHARED completion protocol; your completion commit MUST contain
`0011`.
