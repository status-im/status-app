# Upstream asks — consolidated after iteration 2 (2026-07-07)

Everything the nimble migration is carrying as local patches, fork pins, or
documented workarounds, and where it should eventually land. Sources: PRD
2026-07-06, ADR 0007, vendor/status-go/AGENTS.md walls, issue verification
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

7. **`nimble setup` reuses a PATH nim equal to the pin and materialises no
   store entry** — 0.22.3 and 0.24.1 alike (2026-09-15, Linux): with a nim
   2.2.10 first on PATH, `requires "nim == 2.2.10"` resolves and nimble prints
   "using <that nim> for compilation", but `pkgs2/nim-2.2.10-…` is never
   created and `nimble shellenv` exposes no store nim — so a bootstrapped
   shell (env.sh hoists the store entry; the driver's guard asserts it) has
   nothing to hoist. Nim-free, 0.22.3 downloads the release binary into the
   store in ~1 min; 0.24.1 downloads the LATEST release for itself and
   SIGSEGVs during setup. Ask: always materialise the pinned entry (or an
   explicit `nimble install nim@X` that does), and fix the nim-free 0.24
   bootstrap crash.
8. **Bundled 0.22.2 falls back to a static release list** — the nimble in
   the nim-2.2.10-linux_x64 tarball listed nim candidates only up to 2.2.6
   and failed `nim == 2.2.10` ("Couldnt find a solution … + nim 2.2.10"),
   i.e. its `releases.json` fetch fell back to the compiled-in list (cause not
   isolated; the 0.22.3 release binary fetched and cached the list fine on
   the same machine). Ask: surface the fetch failure loudly instead of
   silently solving against a stale list.

## nim-sds (logos-messaging/nim-sds)

- **PR #85** (embeddable + reproducible libsds) is the whole local patch
  queue. When it merges: flip the statusgo.nimble pin from
  `alexjba/nim-sds#5c89d61` to the upstream merge SHA. Nothing else changes
  (0007 made the pin the only coupling).
- **2026-09-15 rebase:** PR #85 is still open, and status-go develop now
  requires the `release/v0.3` line (`v0.3.3`: the retrieval-hint provider the
  sds-go-bindings pin in go.mod links against; master/release-v0.4 changed the
  FFI ABI). v0.3.3 is NOT consumable as a nimble dependency as-is:
  release/v0.3 keeps the pre-nimble layout — two manifests at the root
  (nimble rejects the package: "Skipping package statusgo due to invalid
  dependency"), the FFI wrapper outside srcDir (a store copy would drop it),
  a vendored build system, taskpools undeclared and libp2p unpinned. The
  statusgo.nimble pin therefore moved to `alexjba/nim-sds#a771a894` = branch
  `nimble-v0.3.3`: v0.3.3 + one commit (reliability.nimble removed,
  installDirs = library+src, taskpools declared, libp2p == 2.0.0, NIMFLAGS
  forwarding, nimbase.h from the running nim, PR #85's localized and
  reproducible static archives). Library ABI untouched. Ask: land that commit
  (or PR #85's equivalent) on `release/v0.3`, tag it, and flip the pin to the
  upstream tag. Byte-reproducibility of the static archive is UNVERIFIED on
  this pin (Linux host).

## status-go (status-im/status-go)

- Branch `nimble-phase1-pin-2` (currently pinned at `6d3368e97`; the
  2026-09-15 rebase of `nimble-phase1-pin` onto develop `9f09f902`, wrapper
  refreshed from status-desktop master, nim-sds pin `nimble-v0.3.3`) needs to become
  a PR to `develop`: nimble package manifest (source-only) +
  statusgo.nims tasks, absorbed status_go wrapper, status_backend cgo
  export, cbindings determinism (sorted emit, `-buildid=`, ZERO_AR_DATE
  repack). After merge: bump the app pin; eventually pin release tags.

- **`status-go-deps` → a statusgo.nims task** (issue 0018, adjudication A2,
  2026-07-12; **push-bearing, human**). Desktop's `make status-go-deps` is
  deleted; its one line — `go install
  google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.1` (the plugin status-go's
  own `go generate` needs) — is now inlined at the desktop call sites, which is
  what the driver's `buildLibstatus()` already did. The tool install belongs to
  status-go, not to its consumer: add it as a task/hook in `statusgo.nims` (the
  same place `libsds`/`statusgo` live), then bump the app pin. That collapses
  **three copies of the same `go install` line** into one:
  1. `Makefile`'s `$(STATUSGO)` recipe (status-desktop),
  2. `status_artifacts.nims`' `buildLibstatus()` (status-desktop),
  3. `fdroid/build-app.sh` (status-desktop).
  Until it lands, a version bump of `protoc-gen-go` must be applied in all
  three — the drift risk this ask exists to remove.

## uuids / isaac (pragmagic)

- isaac#4 MERGED (2026-07-09): pragmagic/isaac master `ca0a1e25` carries the
  modern manifest. uuids PR #15 (head `1a8111cc`, amended to pin that isaac
  rev) still open; the app pins the PR head from the pragmagic URL — bump to
  the merge commit when #15 lands. Both pins stay revision-shaped until
  upstream tags releases with modern manifests (nimble ask #5).

## seaqt (seaqt/nim-seaqt, seaqt/nimqml-seaqt)

- Current pins (2026-09-15 rebase): `qt-6.8@7d40abd7` — master's submodule
  moved to the Qt 6.8 generation while the migration was in flight — and
  nimqml `fa084a8d` (master's submodule). The former `smo-6.4@2d95808` pin was
  durable via tag `qt-6.4-seaqt-gen-5bc1bc58…`; `7d40abd7` has NO tag, and the
  generation branches are force-pushed orphans, so this pin can become
  unreachable (master's submodule carries the identical hazard). Asks: a tag
  for `qt-6.8@7d40abd7`, durable tags as standard practice, and a decision
  path for the `qt-6.11` generation (matches the actual Qt kit; app-wide
  API-churn risk — needs its own compile/QA pass).

## prl-to-pc (status-im/prl-to-pc)

- PUSHED + MERGED (2026-07-09): tag `v0.2.0` (peeled f649ba6) live on the
  remote; PR status-im/prl-to-pc#1 merged the branch to `main`. Post-push
  flip verified: wiped seeded pkgcache/store → re-solve from GitHub
  materialized the identical entry `prl_to_pc-0.2.0-d902f8c9…`. Residual:
  `main` is 2 commits past the tag (probe-based System/Generated mode
  merge + 81aa1e8 space-safe consumer-paths review fix) — bump the app pin
  when upstream tags a v0.2.1, not urgent.
- **2026-09-15 rebase:** the app pin moved from tag `v0.3.0` to main's head
  `03a8a917` (master's submodule revision, 4 commits past the tag). Ask: tag
  it (v0.3.1 or v0.4.0) so the pin goes back to tag form.

## CMake vendors

- No upstream asks — status-keycard-qt `8582bffc` (master's submodule
  revision as of the 2026-09-15 rebase; was `a6cbdd05`) and its nested
  keycard-qt pin are consumed as-is via FetchContent.

## nimside (seaqt/nimside)

- ASK (2026-07-10, from wake-stall issue 0015 spike): to become the idiomatic
  home for Nim view-controllers it needs (1) compatibility with the app's
  vendored nim-seaqt tag (currently 57 compile errors: pkg-config `gorge`
  version probing + `PropertyDef` drift), (2) arbitrary base classes in the
  `qobject` macro (today hardcoded to QObject — no QAbstractListModel
  subclassing), (3) QML type registration (none exists; its compile-time
  metaobject generation is the right primitive for it — cleaner than
  DOtherSide's template-slot pool). Until then: classic-nimqml/nimqml-seaqt
  carry production; a bounded registrar port (~150 lines over
  QQmlPrivate::qmlregister) sits on the seaqt-migration checklist and gets
  deleted in nimside's favor when it matures. Evidence:
  docs/investigations/21395-wake-stall/issues/0015-nim-view-controller-spike.md.
