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
- **2026-09-15, no-scratch-copy (issue 0020) — RESOLVED on the fork branch,
  still an upstream ask.** Every build task hardcoded `build/` and
  `build/nimcache` relative to the working directory, located `./library` the
  same way, and required `sds.nims` to be symlinked into the tree first — so
  no consumer could build the nimble store copy, and status-desktop copied the
  whole package instead. `nimble-v0.3.3` head `425287ae` fixes it: `SDS_OUT_DIR`
  (default `build`, upstream behaviour unchanged) is the ONLY directory any
  task writes to, `--nimcache` is explicit on every compile, sources come from
  `thisDir()`, and `sds.nims` is committed + declared in `installFiles`. Ask:
  take this alongside the packaging commit — it is additive, changes no
  default, and touches no ABI. The macOS/iOS/Android legs got the same
  mechanical treatment and are unverified.

## status-go (status-im/status-go)

- Branch `nimble-phase1-pin-2` (currently pinned at `a8a15198a`; the
  2026-09-15 rebase of `nimble-phase1-pin` onto develop `9f09f902`, wrapper
  refreshed from status-desktop master, nim-sds pin `nimble-v0.3.3`, plus the
  no-scratch-copy work below) needs to become
  a PR to `develop`: nimble package manifest (source-only) +
  statusgo.nims tasks, absorbed status_go wrapper, status_backend cgo
  export, cbindings determinism (sorted emit, `-buildid=`, ZERO_AR_DATE
  repack). After merge: bump the app pin; eventually pin release tags.

- **`status-go-deps` → a statusgo.nims task** (issue 0018, adjudication A2,
  2026-07-12). **CLOSED by issue 0020, differently than planned**: the
  consumer does not need `protoc-gen-go` at all any more. status-go commits
  the generated Go sources its library build needs, and `GENERATE_PREREQ=`
  skips `make generate`, so all three copies of the `go install` line are
  simply deleted rather than moved into a task. (CI images still install
  protoc; only regenerating needs it.)

- **No-scratch-copy (issue 0020), the big one, on `nimble-phase1-pin-2`
  head `a8a15198a`.** A consumer that resolves status-go through nimble gets a
  READ-ONLY store copy shared between every consumer of the pin, and until now
  a build wrote into it, so status-desktop `cp -R`'d the whole tree first.
  Three changes make the store copy directly buildable; all three are things
  upstream would have to accept:
  1. **Committing the generated Go sources** (`*.pb.go`, `bindata.go`,
     `migrations.go`, the endpoint + messenger handler tables, and the ONE
     mock a non-test file imports —
     `pkg/services/connector/chainutils/mock`, reached from
     `pkg/services/connector/commands/test_helpers.go`). ~1.8 MB of tracked
     generated Go. The alternative upstream may prefer: keep them untracked
     and ship them in a release artifact / require the generator toolchain on
     every consumer machine. A cheaper half-measure for the mock: move that
     import into a `_test.go` file and the mock can stay untracked.
  2. **Replacing `go:generate` + `go:embed` with `-ldflags -X`** in
     `pkg/version` and `pkg/sentry`. This also fixes a real bug: `git
     describe` in the `go:generate` walked UP out of the build directory and
     stamped whatever repository enclosed it (status-desktop's version ended
     up in status-go's `pkg/version/VERSION`).
  3. **`STATUS_GO_BUILD_DIR` / `GENERATE_PREREQ`** so the library targets can
     write outside the module and skip the generate prerequisite. Note for
     reviewers: `go build -overlay` does NOT let the cbindings entry point
     keep an in-module package path — cgo `chdir()`s into the package
     directory, which then does not exist. The entry point is passed as a file
     argument instead.

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
