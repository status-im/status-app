---
title: One-command app build + per-vendor develop mode
date: 2026-07-06
tracker: local (GH publication deferred by user; all work stays local)
triage-label: ready-for-agent
parent: status-im/status-desktop#19907
predecessor: 2026-07-03-statusgo-nimble-package-prd.md (closed over issues 0001–0005)
---

## Progress

| Issue | Slice | Status |
|-------|-------|--------|
| 0007 sds pin flip to PR #85 | statusgo.nimble `URL#hash` pin (alexjba/nim-sds#5c89d61), ffi pin dropped, local vendor/nim-sds out of the default flow; + uuids/isaac fork pins (INI-manifest wall, grilled) | done (2026-07-06) |
| 0008 app driver (`status.nims`) | `app` task (host + `--os/--cpu`), setup self-bootstrap, `run`, no-op timing acceptance; develop/undevelop/vendors stubs → 0009 | done (2026-07-06) |
| 0009 develop-mode core | overlay + `develop`/`undevelop`/`vendors` tasks for statusgo + sds, divergence guard, escape hatch | open (blocked by 0008) |
| 0010 status-go full-pin | branch pushed, app manifest → `URL#hash`, submodule removed, store-scratch Go build, stamp-skip vs FORCE arms | open (blocked by 0009) |
| 0011 keycard pair | FetchContent pins + `FETCHCONTENT_SOURCE_DIR` develop redirect | open (blocked by 0009) |
| 0012 seaqt pair | feasibility spike, then graph adoption (spike-gated fallback: stay submodules, UX-wrapped) | spike DONE — PASS, pass path recommended (specs/2026-07-06-seaqt-graph-spike.md); conversion pending grill + 0009 |

## Problem Statement

The previous iteration made status-go a first-class nimble package and gave the
app one dependency graph — but the developer experience is still make-shaped
and vendor-shaped. Building from a clean clone means knowing the right make
targets and env vars; the repo permanently carries vendor checkouts
(submodules) whether or not you are working on them; hacking on a vendor
requires knowing per-vendor conventions (submodule vs sibling clone vs
manifest edits), and the interim `file://` requires — the only local-substitution
mechanism stock nimble 0.22.3 supports for `URL#hash` deps — dirties committed
manifests and chains virally through the requires graph. Meanwhile every build
FORCE-delegates into vendor sub-makes even when nothing can possibly have
changed, so no-op rebuilds cost minutes.

## Solution

Two modes with one front door:

- **One-command build.** `nim app status.nims` (host) / `nim app status.nims
  --os:ios --cpu:arm64` (mobile) is the single canonical entry point: it
  self-bootstraps dependency resolution (`nimble setup` into the out-of-tree
  store, stamp-gated), applies the develop-mode overlay if any, and delegates
  to the existing make recipes. Default mode has **no vendor checkouts at
  all**: every vendor is a pinned dependency (nimble `URL#hash` requires for
  Nim-graph vendors, CMake FetchContent `GIT_TAG` for CMake vendors) built
  from read-only pinned copies.
- **Develop mode, per vendor.** `nim develop status.nims <vendor>` materializes
  the vendor as a real git checkout under `vendor/<name>` (origin = pin URL,
  at the pinned revision) and switches the build to it; every Nim/C++/Go
  change is picked up on the next build via the ADR-0003 FORCE + cmp
  discipline. `undevelop` returns to the pin. Nim-graph vendors switch via a
  nimble.paths overlay (ADR 0004); CMake vendors via
  `FETCHCONTENT_SOURCE_DIR_<NAME>`.
- **Mode-selected rebuild gating.** Pinned vendor ⇒ stamp-skip (pin + target +
  flags unchanged and artifact present → vendor sub-build not invoked at
  all); developed vendor ⇒ FORCE delegation + compare-before-copy. No-op
  default-mode builds drop from minutes to seconds.

## User Stories

1. As a new contributor, I want one command from a clean clone to a runnable
   dev build, so that I don't have to learn make targets and env conventions
   first. (Kit env vars — QMAKE, NDK, team — remain documented prerequisites.)
2. As a mobile developer, I want the same command with `--os/--cpu` flags to
   produce the iOS/Android build, so that desktop and mobile share one UX.
3. As an app developer not touching vendors, I want default-mode builds to
   skip every vendor compilation step when pins are unchanged, so that no-op
   rebuilds take seconds.
4. As an app developer, I want a repo with no vendor checkouts in default
   mode, so that submodule init/sync ceremony disappears.
5. As a vendor developer, I want one command to bring a vendor into an
   editable state, so that I can start hacking on status-go (or sds, keycard,
   seaqt) without learning that vendor's consumption mechanics.
6. As a vendor developer, I want every Nim, C++ and Go change in a developed
   vendor picked up by the next app build automatically, so that I never
   hand-dirty artifacts or guess what to clean.
7. As a vendor developer, I want the materialized checkout to be a normal git
   clone of the vendor's repo, so that committing, pushing and PR-ing use my
   normal git workflow.
8. As a vendor developer, I want `undevelop` to refuse to discard uncommitted
   or unpushed work unless forced, so that exiting develop mode can never
   lose changes.
9. As a vendor developer editing a vendor's own `requires`, I want the build
   to fail loudly with escape-hatch instructions when the checkout's manifest
   diverges from the pinned one, so that resolution drift is impossible to
   hit silently.
10. As a CI engineer, I want the existing make targets to keep working
    unchanged, so that CI migrates on its own schedule.
11. As a maintainer, I want all new build logic written in nimscript and none
    added to make (make frozen, shrinking to leaf recipes), so that the build
    system converges on one language without a big-bang rewrite.
12. As a developer on any platform, I want default mode to build vendors from
    read-only pinned copies, so that local state can never contaminate a
    default build.

## Implementation Decisions

Settled in the 2026-07-06 grilling session (each empirical claim verified in
this repo or recorded in vendor/status-go/AGENTS.md):

- **Task, not install.** The front door is a build task producing the dev
  build in-repo, not a nimble `install` action: `nimble install --os/--cpu`
  is structurally dead for hook-driven builds on stock nimble (hooks never
  see target flags; the store is target-blind), and a GUI app's
  resources/bundle don't fit the bin-on-PATH install contract. A desktop-only
  true `nimble install` may layer on later.
- **Dev build scope.** The task drives to today's `make nim_status_client`
  equivalent (+ `run` companion); packaging/distributables stay make/CI-only.
- **One task, target flags.** `--os/--cpu` selects the target (host default);
  kit selection stays environment-driven with fail-fast validation.
  Multi-ABI Android remains an env override (`--cpu` carries one value).
- **`.nims` driver, not nimble tasks.** Measured on this manifest: `nimble
  <task>` re-pays ~46–48 s of graph revalidation per warm invocation
  (`--offline` hard-errors, `--legacy` is worse at ~1:26); a root-manifest
  task does NOT hang (the declarative-parser wall applies to dependency
  manifests, evaluated per candidate — not the root, evaluated once). The
  driver is nimscript invoked via `nim <task> status.nims` (~1 s). If a
  future nimble drops the tax, promotion to `nimble app` is mechanical.
- **Full-pin vendor end-state.** All six vendors (statusgo, sds, seaqt,
  nimqml, status-keycard-qt, keycard-qt) become pinned dependencies; default
  mode has no vendor checkouts. status-go's local branch gets pushed by the
  user to make its pin reachable. Pin bumps rebuild from store/FetchContent
  copies; artifact-dir contracts move behind the driver.
- **Two vendor flavors, one UX.** Nimble-graph vendors: `URL#hash` requires +
  nimble.paths overlay (ADR 0004). CMake vendors: FetchContent `GIT_TAG` +
  `FETCHCONTENT_SOURCE_DIR_<NAME>` redirect (proven by MobileUI). Nested
  CMake vendors (keycard-qt inside status-keycard-qt) need no parent cascade.
- **Overlay, not file:// flips, not patched nimble** (ADR 0004): develop
  links cannot satisfy `URL#hash` requires on stock 0.22.3; file:// flips
  cascade through parent manifests (which are read-only store copies in the
  end-state), trip the sibling-pin drop wall, and dirty tracked files; a
  patched nimble puts a fork in every developer's toolchain. The overlay's
  known limit — resolution reads the pinned manifest, not the checkout's — is
  guarded by a loud manifest-divergence check and the documented file://
  escape hatch.
- **Mode-selected gating.** Pinned ⇒ stamp-skip, stamp = (resolved store
  path, target triple, flag set) and nothing else; developed ⇒ ADR-0003
  FORCE + compare-before-copy. ADR 0003 is not violated — its FORCE
  semantics become the develop-mode arm (recorded in ADR 0004).
- **Make frozen (strangler ratchet).** The driver delegates to existing make
  recipes; make targets keep working for CI; no new logic lands in make —
  new logic is nimscript, and vendor conversions delete make rules. Full
  make removal is explicitly out of scope (its incremental engine and `-j`
  currently deliver the efficiency requirement); revisit alongside the
  Windows push where the payoff lives.
- **sds pin = PR #85 head** (`alexjba/nim-sds#5c89d61`, the whole 6-patch
  queue): flips the interim `file://` sds requires back to `URL#hash`, which
  also dissolves the file://-chain wall that blocked develop-linking
  statusgo. The pin moves to the upstream merge SHA when logos-messaging
  merges. The explicit ffi pin drops (5c89d61 pins ffi itself).
- **Process.** Every blocker discovered during implementation gets its own
  /grill-with-docs session before an agent proceeds. All work stays local —
  no GH issues/PRs from this effort (the user pushes branches when a pin
  needs reachability).

## Testing Decisions

Same seam philosophy as the predecessor PRD — external behavior at the
boundaries a developer actually touches:

1. **The front door.** Clean clone (+ documented kit env) → `nim app
   status.nims` → runnable dev build; same with `--os:ios/--os:android` →
   signed app / APK. No-op re-run wall time is an explicit acceptance number
   per issue (target: seconds, not minutes, in default mode).
2. **The develop loop, per vendor.** `develop <vendor>` → edit a Nim, C++ and
   Go file (as applicable) → next `app` build picks each up (FORCE + cmp
   observed) → commit on a branch in the checkout → `undevelop` (refuses
   while dirty; `--force` documented) → default build again from the pin,
   byte-identical artifacts.
3. **The guard rails.** Manifest divergence in a developed vendor fails the
   build loudly with escape-hatch instructions; `undevelop` on unpushed work
   refuses; a pinned no-op build invokes no vendor sub-build (verified by
   absence of sub-make invocation, not just unchanged artifacts).

## Out of Scope

- True `nimble install` of the app (bin-on-PATH / machine install) — possible
  later desktop-only layer.
- Dropping make — frozen and shrinking, not removed; revisit with Windows.
- Publishing to the nimble registry; any GH issue/PR automation.
- Prebuilt vendor binaries; nimble upstream fixes (46 s task tax, develop
  binding, hook target-blindness) — file upstream separately.
- Windows validation (unchanged from predecessor PRD).
- Vendors beyond the six named; NBS deletion (Phase 3) stays its own track.

## Further Notes

- Glossary: CONTEXT.md (app entry point, vendor, default/develop mode).
- Mechanism decision record: docs/adr/0004-develop-mode-via-paths-overlay.md.
- All nimble 0.22.3 walls referenced here are verified and documented in
  vendor/status-go/AGENTS.md ("nimble 0.22.3 resolution walls").
