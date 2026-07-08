---
id: 0014
title: prl-to-pc into the nimble graph — version pin (#v0.2.0), submodule removed
date: 2026-07-08
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`.
Follows the 0012 conversion pattern (last remaining tool-ish vendor).

## Goal

Consume prl-to-pc (qt-pkgconfig.mk + committed Qt .pc trees + the
pkg-config wrapper/generator sources) as a nimble-graph dependency pinned
**by version tag** — `https://github.com/status-im/prl-to-pc.git#v0.2.0` —
instead of the `vendor/prl-to-pc` git submodule. First tag-pinned (not
SHA-pinned) dependency in the graph; user explicitly wants version-shaped
imports here.

## Decisions (grilled 2026-07-08, user-approved — do not relitigate)

- **Pin form: `#v0.2.0` tag ref.** The tag exists locally in
  `vendor/prl-to-pc` (annotated, at `abb3604` on local branch
  `fix/lockfile-nimblepath`, manifest version 0.2.0) but is NOT pushed.
  nimble resolves URL requires from the remote, so: implement + verify via
  the ADR-0004 overlay against the local checkout, land the manifest pin as
  `#v0.2.0`, and record loudly (completion notify + verification record)
  that the app branch resolves only after the user pushes branch+tag to
  status-im/prl-to-pc. Do NOT push anything yourself.
- **Source-only dependency manifest** (the statusgo precedent, wall #1):
  drop `bin = @["prl_to_pc"]` from prl_to_pc.nimble — nimble setup builds
  dependency bins unconditionally and the tools are built by
  qt-pkgconfig.mk anyway. Keep the tasks (declarative-parser warning is
  harmless, cf. metrics).
- **Pin the transitive deps**: `requires "regex"` (unpinned name-form) must
  become the same pinned URLs the app graph already carries —
  `https://github.com/nitely/nim-regex.git#2c41f0b2fee9fe78cf22f029bc854a77ac2e9768`
  (+ unicodedb `#8938e71cdb3332b8a16eb27a6984c8565ea4643e` if needed as a
  direct require) — name-form requires in dep manifests are wall-#6
  nondeterminism.
- Submodule removal follows the staged 0010/0012 playbook (backup at
  `.phase2-vendor-backup/prl-to-pc` with functional git dir; the local
  branch + tag live ONLY there and in the store overlay afterwards — do not
  lose them).
- Vendor-table row (nimble flavor): `prl-to-pc`, developBranch `main`,
  manifest `prl_to_pc.nimble`. Develop mode = overlay (ADR 0004), like
  seaqt/nimqml.

## Design constraints (answered up front so you don't have to grill)

- **In-package writes**: qt-pkgconfig.mk builds tools into
  `$(QT_PC_SELF_DIR)/.pcwrap` and `qt-pkgconfig-generate` writes .pc trees
  into `$(QT_PC_SELF_DIR)/<ver>/<kit>` — fine for a checkout, NOT for a
  read-only store copy. Make `QT_PC_BUILD_DIR` consumer-overridable (app
  sets a repo-local dir, e.g. `<repo>/.prl-to-pc-build/.pcwrap`), and make
  the generate path refuse/redirect when SELF_DIR is a store copy (missing
  kits in default mode should say "develop prl-to-pc and run
  qt-pkgconfig-generate, then commit upstream" rather than scribbling on
  the store). mk changes are prl-to-pc commits on the same local branch.
- **Consumer plumbing**: the Makefile includes
  `vendor/prl-to-pc/qt-pkgconfig.mk` and config.nims hardcodes
  `repo / "vendor/prl-to-pc"` (pcWrapperDir/pcFileDir/PATH export, lines
  ~283-298). Both must resolve the package root overlay-aware — add a
  shared `prlToPcRoot()` to status_env.nims (statusgoBuildRoot precedent):
  developed checkout if nimble.overlay says so, else the store entry from
  nimble.paths. make can shell out to a tiny `nim` eval or parse
  nimble.paths the way other recipes do.
- The efcd65a consumer-nimble.paths fallback for regex stays (standalone
  clones); the store-copy scenario gets the same explicit --path treatment.
- Store hoist wobble (srcDir "src") doesn't matter here: nothing nim-imports
  prl_to_pc modules; the mk/.pc trees are package-root files.

## Acceptance criteria

- [ ] `nim_status_client.nimble` requires
  `https://github.com/status-im/prl-to-pc.git#v0.2.0`; no
  `vendor/prl-to-pc` submodule (gitmodules section gone, backup dir
  functional).
- [ ] Default-mode desktop build with NO vendor/prl-to-pc checkout: overlay
  pointed at the backup/local repo (documented interim until push), full
  `nim app status.nims` + `nimble build` pass; `make qt-pkgconfig` no-op
  when the committed .pc tree is present; tools build into the repo-local
  build dir, store copy untouched (verify mtimes/checksums).
- [ ] `nim develop status.nims prl-to-pc` → edit qt-pkgconfig.mk → next
  build consumes the edit → `undevelop` restores.
- [ ] `nim vendors status.nims` lists prl-to-pc (7 vendors).
- [ ] Post-push flip documented: once branch+tag are on status-im, a wiped
  pkgcache + store re-solve resolves `#v0.2.0` (record the command; run it
  only if the push happens during your session).
- [ ] Mobile spot-check unaffected (the mk is included by mobile legs too —
  one `--os:ios` compile-config sanity pass).

## Blockers — grill before implementing

- If nimble 0.22.3 rejects or mis-resolves a `#v0.2.0` TAG ref on a URL
  require (only SHA/branch verified so far in this repo), grill with the
  evidence before falling back to a SHA pin — the version-shaped pin is the
  point of this issue.
- Any second in-package write the mk audit finds beyond .pcwrap/generate.

## Blocked by

User push of prl-to-pc branch+tag (for the FINAL resolvable state only;
all implementation and overlay-based verification proceeds now). Holds the
in-tree build lock.
