---
id: 0014
title: prl-to-pc into the nimble graph — version pin (#v0.2.0), submodule removed
date: 2026-07-08
tracker: local (GH publication deferred by user)
triage-label: ready-for-agent
status: done (2026-07-08; final remote resolvability blocked on the user
  pushing prl-to-pc branch+tag — see the INTERIM section)
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

- [x] `nim_status_client.nimble` requires
  `https://github.com/status-im/prl-to-pc.git#v0.2.0`; no
  `vendor/prl-to-pc` submodule (gitmodules section gone, backup dir
  functional). (Verification record, 2026-07-08.)
- [x] Default-mode desktop build with NO vendor/prl-to-pc checkout: full
  `nim app status.nims` + `nimble build` pass; `make qt-pkgconfig` no-op
  when the committed .pc tree is present; tools build into the repo-local
  build dir, store copy untouched (per-file md5 + mtimes identical).
  *Interim mechanism differs from the sketch:* resolution stays alive via
  the SEEDED PKGCACHE, not the overlay — an unresolvable require fails
  `nimble setup` before any overlay applies, so overlay-only bring-up is
  structurally impossible; the overlay remains the develop-mode arm
  (record leg 0/1 + the INTERIM section).
- [x] `nim develop status.nims prl-to-pc` → edit qt-pkgconfig.mk → next
  build consumes the edit → `undevelop` restores. (Record leg 3; incl. a
  divergence-guard probe against the tag-shaped rev.)
- [x] `nim vendors status.nims` lists prl-to-pc (7 vendors).
- [x] Post-push flip documented (INTERIM section): wiped seeded pkgcache +
  store entry + nimble.paths → `make nimble-deps` re-solves `#v0.2.0` from
  the remote. NOT run — the push did not happen during the session.
- [x] Mobile spot-check unaffected: `--os:ios --cpu:arm64` full leg,
  signed app, codesign strict OK (record leg 5).

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

## What was built (2026-07-08)

- **prl-to-pc commits** (local branch `fix/lockfile-nimblepath`, now at
  `f649ba6` = f56ac40 manifest/mk changes + 84b29f8 refusal-message fix +
  f649ba6 README rewrite; annotated tag `v0.2.0` RE-POINTED from abb3604 to
  f649ba6 — legitimate because neither was ever pushed):
  - `prl_to_pc.nimble`: source-only AND full-tree — `bin` dropped (nimble
    builds dependency bins unconditionally during every consumer setup;
    wall #1) and `srcDir` dropped too. The srcDir drop is a NEW finding
    beyond the grilled decisions: a srcDir-declaring package's store copy
    is hoisted and **stripped to the srcDir contents** (verified on
    nimqml/regex entries + a spike materialization) — qt-pkgconfig.mk and
    the committed .pc trees would simply not exist in the store. Without
    srcDir the full repo tree materializes (statusgo precedent). regex +
    unicodedb pinned by revision (wall #6), same SHAs the app graph pins.
  - `qt-pkgconfig.mk`: `QT_PC_BUILD_DIR` + `QT_PC_CONSUMER_PATHS` are
    consumer-overridable (`?=`); `qt-pkgconfig-generate` refuses to write
    .pc trees into a store copy (detected via the `nimblemeta.json` root
    marker) and points at the develop-and-commit-upstream flow. mk audit
    found no in-package writes beyond the tool build + generate.
- **App manifest**: `requires "https://github.com/status-im/
  prl-to-pc.git#v0.2.0"` — the graph's first version-TAG pin. Verified
  empirically (spike + app solve): an annotated tag ref resolves on nimble
  0.22.3 exactly like a `#sha` special, `specialVersions` records
  `['#v0.2.0', '0.2.0']` (the semantic version rides along), and
  `vcsRevision` is the PEELED commit (f649ba6), not the tag object.
- **Consumers, overlay-aware**: `prlToPcRoot()` in status_env.nims
  (develop checkout per nimble.overlay, else the `pkgs2/prl_to_pc-` entry
  from nimble.paths); config.nims reads the .pc trees from that root and
  the wrapper from the repo-local `.prl-to-pc-build/.pcwrap`; the Makefile
  includes `$(PRL_TO_PC_ROOT)/qt-pkgconfig.mk` (same two-arm derivation)
  and exports the two mk override knobs. Missing-resolution bootstrap:
  GNU make include-remake-reexec on `.prl-to-pc-build/bootstrap.mk`
  (prereq = nimble.paths) — fresh clones self-heal; an entryless
  resolution hits a loud stub error instead of "No rule to make target".
- **Vendor row** `prl-to-pc` (nimble flavor, developBranch `main`, pin
  parsed live from the manifest). No FORCE arms: the mk is re-read every
  make parse and the wrapper/generator have real make prerequisites under
  the resolved root. New `flipRemove` arm on the Vendor object: mode
  flips drop `.prl-to-pc-build/.pcwrap/*` so a stale tool binary can
  never survive a develop/undevelop transition (mtime tracking alone
  can't catch undevelop-after-pushed-edits).
- **Submodule removed** (staged playbook): backup branch
  `backup/nimble-0014-pin`; working dir functional at
  `.phase2-vendor-backup/prl-to-pc` (core.worktree repointed via the
  module gitdir config; `.git` pointer file rewritten absolute). The
  local branch + re-pointed tag live ONLY in that gitdir until pushed.
- BUILDING.md: prl-to-pc paragraph; submodule list shrinks again.
- `nimble.lock` intentionally NOT regenerated (0010/0012 precedent: the
  lock never constrains URL-pinned solves).

### INTERIM until the user pushes branch+tag (read this before wiping caches)

The tag exists only locally, so `nimble setup` can resolve the pin ONLY
through the seeded pkgcache clone (nimble reuses existing pkgcache clones
and never refetches). The brief's overlay-only bring-up sketch cannot
work by itself: an unresolvable require fails `nimble setup` before any
overlay is applied — the seed is what keeps resolution alive, the overlay
stays the develop-mode mechanism it always was. Seeded on this machine:

    git clone https://github.com/status-im/prl-to-pc.git \
      ~/.nimble/pkgcache/githubcom_statusimprltopcgit_v020
    git -C ~/.nimble/pkgcache/githubcom_statusimprltopcgit_v020 \
      fetch <backup-repo> '+refs/tags/v0.2.0:refs/tags/v0.2.0'
    git -C ~/.nimble/pkgcache/githubcom_statusimprltopcgit_v020 checkout v0.2.0

(`<backup-repo>` = `.phase2-vendor-backup/prl-to-pc`.) Deleting that
pkgcache dir before the push breaks the next full re-solve.

**Push checklist for the user** (from `.phase2-vendor-backup/prl-to-pc`):
`git push origin fix/lockfile-nimblepath v0.2.0` (or merge to main first —
the tag is what the pin needs). **Post-push flip** (run to prove remote
resolvability; also the recipe for every other machine):

    rm -rf ~/.nimble/pkgcache/githubcom_statusimprltopcgit_v020 \
           ~/.nimble/pkgs2/prl_to_pc-* nimble.paths
    make nimble-deps        # re-solves #v0.2.0 from status-im/prl-to-pc

Store entry checksum is content-addressed and URL-independent (verified
during the spike: loopback and github materializations of the same commit
produced the identical `prl_to_pc-0.2.0-b47270b3…` entry), so the
post-push entry will be identical to the verified one:
`prl_to_pc-0.2.0-d902f8c93f0fefb23e12e1a0b4800a0b840bb298` (tag target
f649ba6; re-verified after the README rewrite moved the tag — wiped entry,
re-solve from the seeded cache, full `nim app` 1:09.9, no-op 5.9 s).

## Verification record (2026-07-08, macOS arm64 host; Qt 6.11.0 kits; nim 2.2.4 + nimble 0.22.3; store = ~/.nimble)

Env: `PATH=$PWD/vendor/nimbus-build-system/vendor/Nim/bin:$PATH`,
`QMAKE=~/Qt/6.11.0/macos/bin/qmake USE_SYSTEM_NIM=1` (iOS leg:
`QMAKE=~/Qt/6.11.0/ios/bin/qmake IPHONE_SDK=iphoneos
QMAKE_DEVELOPMENT_TEAM=8B5X2M6H2Y`). Pre-push interim: pkgcache seeded
per the INTERIM section above (spike C proved the mechanism from a
throwaway NIMBLE_DIR before the app graph consumed it).

0. **Spikes** (scratch consumers, loopback dumb-HTTP serve of the local
   repo per the AGENTS.md recipe, throwaway stores `~/.nb0014{a,b,c}`):
   (A) `requires "<loopback>#v0.2.0"` on the OLD manifest — the annotated
   tag ref RESOLVES on nimble 0.22.3 (no grill needed on the pre-identified
   blocker): store dir `prl_to_pc-0.2.0-<checksum>`, `specialVersions:
   ['#v0.2.0', '0.2.0']`, `vcsRevision` = the PEELED commit. But the entry
   was srcDir-HOISTED AND STRIPPED (only src/ contents + manifest), and
   setup BUILT the bin (wall #1 live) — both fatal for mk/.pc-tree
   consumption; hence the manifest fix (bin AND srcDir dropped — the
   srcDir strip is a new finding sharpening the issue's "hoist wobble
   doesn't matter" assumption). (B) fixed manifest: FULL tree in the store
   (6.11.0/ trees + qt-pkgconfig.mk + src/), no bin build, regex/unicodedb
   resolved at the pinned SHAs. (C) the real
   `https://github.com/status-im/prl-to-pc.git#v0.2.0` URL resolves from
   the seeded pkgcache clone with the correct github URL + vcsRevision in
   nimblemeta — the pre-push bring-up. Same content checksum as (B).
1. **Default-mode build, NO checkout, wiped entry** (criterion 2): with
   `vendor/prl-to-pc` absent, `rm -rf ~/.nimble/pkgs2/prl_to_pc-*
   nimble.paths .prl-to-pc-build` → `nim app status.nims` = **1:09.95**
   end-to-end (re-solve + entry re-materialization + libsds refresh; the
   solve kept the known-good graph: libp2p 2.0.0 / websock 0.4.0 / lsquic
   0.5.4; regex/unicodedb re-materialized at the same revisions under new
   content checksums — same-version/different-materialization variance,
   root entries valid). Default no-op `nim app` = **6.95 s** (0013
   baseline 5.9–7 s). `nimble build` (hook incl.) = **1:37** warm, rc=0
   (0013: ≈89 s; ≈78 s of it is nimble's dispatch tax). Launch smoke via
   bare `./bin/nim_status_client`: QML up, libstatus/libsds/StatusQ/
   keycard-qt all loaded (lsof), clean SIGTERM. (A 12.5 h orphan client
   from the overnight 0013 session held the single-instance lock and was
   killed first.)
2. **Store copy untouched by builds** (the .pcwrap relocation check): the
   wrapper builds into `.prl-to-pc-build/.pcwrap/pkg-config` (functional:
   resolves `--libs Qt6Core` from the store .pc tree with the prefix
   override) and per-file md5 + mtime/size snapshots of the whole store
   entry are IDENTICAL before/after a full `nim app` build.
   `make qt-pkgconfig` no-op = **2.2 s**; wrapper rebuild = 1.7 s.
   `make qt-pkgconfig-generate` against the store copy REFUSES (exit 1)
   with the develop-and-commit-upstream message (criterion: no store
   scribbling; the missing-kit auto path hits the same refusal).
3. **Develop round-trip** (criterion 3): checkout materialized from the
   backup (`git clone .phase2-vendor-backup/prl-to-pc vendor/prl-to-pc` +
   origin reset to the github URL — pre-push interim; post-push `nim
   develop status.nims prl-to-pc` clones directly) → `develop` reused it
   ("never clobbered") and recorded the overlay → probe line appended to
   the checkout's qt-pkgconfig.mk → next `nim app` (1:05) printed the
   probe (mk consumed from the checkout), `applyOverlay: prl-to-pc →
   vendor/prl-to-pc (1 path entry)`, wrapper re-built from the checkout
   (flipRemove dropped the store-built one). Divergence guard probed with
   the TAG-shaped rev: a manifest edit failed the next build in seconds
   ("DIVERGED manifest", names v0.2.0 + exact revert commands + file://
   escape hatch); revert recovered. `undevelop` exited cleanly (this
   checkout's remote-tracking refs cover all commits since they came from
   the backup clone — the unpushed-work refusal semantics are 0012-proven)
   → next build back to the store entry, probe gone, overlay empty.
4. **`nim vendors status.nims`** (criterion 4): 7 vendors — the 6 from
   0012 + `prl-to-pc [nimble-graph, default]` with pin
   `https://github.com/status-im/prl-to-pc.git#v0.2.0`.
5. **Mobile spot-check** (criterion 6): `nim app status.nims --os:ios
   --cpu:arm64` = **2:29.6**, signed `mobile/bin/ios/qt6/Status.app`,
   `codesign --verify --deep --strict` OK — the mobile make legs consumed
   qt-pkgconfig.mk + the ios kit's committed .pc tree from the store copy.
   Desktop flip-back rebuild (platform sentinel) = 54.5 s; final default
   no-op = **7.33 s**.
6. **Post-push flip** (criterion 5): NOT run — the push did not happen
   during this session; the exact command is in the INTERIM section above.

Timing summary (vs 0013): driver no-op 6.95–7.33 s (0013: 5.9–7 s);
nimble build warm 1:37 (0013 ≈89 s — within the dispatch-tax noise band);
full default rebuild after entry wipe 1:09.95; develop-mode build 1:05;
qt-pkgconfig no-op 2.2 s; iOS leg 2:29.6 (0013: 2:19); desktop flip-back
54.5 s.

### Residuals / notes

- Pre-existing noise, not 0014: `install_name_tool -delete_rpath … no
  LC_RPATH` lines from StatusQ's cmake_install re-running fixups on an
  already-fixed libStatusQ.dylib; the special-versions "Multiple
  dependencies require different special versions" warning wall.
- `develop` on a fresh machine pre-push cannot clone the pin (tag not on
  the remote): materialize from `.phase2-vendor-backup/prl-to-pc` as in
  leg 3. Self-heals post-push.
- The `vendors`/`develop` pin-match display compares the checkout HEAD
  SHA against the literal ref string, so tag pins always print
  "(HEAD <sha>; pin v0.2.0)" — cosmetic.
- The develop checkout at `vendor/prl-to-pc` was LEFT in place
  (undeveloped, gitignored, inert in default mode) as the pre-push
  develop convenience; delete freely.
