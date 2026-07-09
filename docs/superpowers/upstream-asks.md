# Upstream asks — consolidated after iteration 2 (2026-07-07)

Everything the nimble migration is carrying as local patches, fork pins, or
documented workarounds, and where it should eventually land. Sources: PRD
2026-07-06, ADR 0004, vendor/status-go/AGENTS.md walls, issue verification
records 0007–0012.

## nimble (issues to file at nim-lang/nimble)

1. **Dependency bin builds are unconditional** — `nimble setup` builds every
   dependency's `bin` in buildtemp with no opt-out; a `before build` hook
   returning false fails the whole setup. Forced statusgo.nimble to go
   source-only (0010). Ask: a way for consumers (or the dependency) to skip
   dependency bin builds.
2. **Develop links cannot satisfy `URL#hash` requires** — develop checkouts
   carry no specialVersions metadata, so `nimble develop --add` is silently
   ignored for pinned URL deps; lock+sync doesn't help. This is why ADR
   0004's overlay exists. Ask: bind develop links for URL requires (e.g. by
   comparing checkout HEAD to the pinned rev).
3. **Install hooks are target-blind** — `--os/--cpu` never reach hook
   nimscript, and the package store is target-unaware (two targets of one
   version collide). Blocks flag-forwarded cross-compiling installs (0006).
4. **Per-invocation graph revalidation tax** — `nimble <task>` re-pays
   ~46–48 s on a warm store for a URL#hash-pinned manifest (network refresh);
   `--offline` hard-errors instead of trusting the store. This is why the
   driver is `nim <task> status.nims` instead of nimble tasks.
5. **INI-manifest version extraction** — packages with legacy `[Package]`
   manifests (pragmagic uuids/isaac) yield an EMPTY version during
   dependency validation on fresh clones → hard solve failures; also
   corrupts `nimble lock` output (vcsRevision "" for isaac). Forced the
   alexjba/uuids fork pin (0007).
6. **`nimble lock` omits URL#hash-required packages** entirely (and their
   transitive picks), so locks can't freeze the real graph (0010 finding:
   regen is net negative).
7. **Setup-time dependency builds inherit enclosing configs** — Nim's
   parent-dir config walk poisons buildtemp builds; `--skipParentCfg` is
   CLI-only and nimble rejects it. Ask: pass it to dependency builds by
   default.
8. **pkgcache staleness** — `(url, range)`-keyed clones under
   `~/.nimble/pkgcache` are never refreshed; new upstream commits/tags stay
   invisible until hand-deleted.
9. (Earlier findings, still open) stale-lock drift vs `--legacy`; `nimble
   lock` records the consumer repo's HEAD as vcsRevision for URL deps.
10. **`nimble deps` cannot display graphs with bare-URL requires** — it
    resolves requirements by name through the package registry, so an
    unregistered URL dependency (libp2p's `vacp2p/nim-jwt.git#hash`) yields
    "Cannot build the dependency graph … Missing package <url>" even though
    setup resolves, installs, and pathifies it fine (2026-07-07).

## nim-sds (logos-messaging/nim-sds)

- **PR #85** (embeddable + reproducible libsds) is the whole local patch
  queue. When it merges: flip the statusgo.nimble pin from
  `alexjba/nim-sds#5c89d61` to the upstream merge SHA. Nothing else changes
  (0007 made the pin the only coupling).

## status-go (status-im/status-go)

- Branch `nimble-phase1-pin` (currently pinned at `d9281bce9`) needs to
  become a PR to `develop`: nimble package manifest (source-only) +
  statusgo.nims tasks, absorbed status_go wrapper, status_backend cgo
  export, cbindings determinism (sorted emit, `-buildid=`, ZERO_AR_DATE
  repack). After merge: bump the app pin; eventually pin release tags.

## uuids / isaac (pragmagic)

- isaac#4 MERGED (2026-07-09): pragmagic/isaac master `ca0a1e25` carries the
  modern manifest. uuids PR #15 (head `1a8111cc`, amended to pin that isaac
  rev) still open; the app pins the PR head from the pragmagic URL — bump to
  the merge commit when #15 lands. Both pins stay revision-shaped until
  upstream tags releases with modern manifests (nimble ask #5).

## seaqt (seaqt/nim-seaqt, seaqt/nimqml-seaqt)

- Current pins: `smo-6.4@2d95808` (durable via tag
  `qt-6.4-seaqt-gen-5bc1bc58…`) and nimqml `c5e5831`. Asks: durable tags as
  standard practice (qt-6.4 branch is force-pushed), and a decision path for
  the `qt-6.11` generation (matches the actual Qt kit; app-wide API-churn
  risk — needs its own compile/QA pass).

## prl-to-pc (status-im/prl-to-pc)

- Local branch `fix/lockfile-nimblepath` (at `f649ba6`) + annotated tag
  `v0.2.0` need pushing (the 0014 pin `#v0.2.0` resolves from the remote
  only after that; a merge to `main` is nice-to-have — the tag is what the
  pin needs). Contents: efcd65a nimble.paths dep resolution, abb3604 v0.2.0
  bump, f56ac40 source-only/full-tree manifest + store-copy-safe mk,
  84b29f8 message fix, f649ba6 README rewrite. The backup checkout at
  `.phase2-vendor-backup/prl-to-pc` is the only holder of these refs.

## CMake vendors

- No upstream asks — status-keycard-qt `a6cbdd05` and keycard-qt `df00b931`
  are consumed as-is via FetchContent.
