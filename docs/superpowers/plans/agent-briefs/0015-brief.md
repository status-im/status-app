# Agent brief — issue 0015: prl-to-pc nimble-native

Read `docs/superpowers/plans/agent-briefs/SHARED-i3.md` first, then your
issue: `docs/superpowers/issues/0015-prl-to-pc-nimble-native.md` (the
"What to build" section is user-approved — do not relitigate it). Then read
the 0014 brief + its verification record: that issue put prl-to-pc into the
graph and is your playbook for everything about its store copy.

## Your role

Implementer of issue 0015. **You HOLD the in-tree build lock.** A second agent
is running spikes, but only in scratch dirs and throwaway clones — it will
never build in this tree. Work in
`/Users/alexjbanca/Repos/status-desktop/.claude/worktrees/nimble-migration`.

## The one decision that shapes everything

prl-to-pc's new consumer interface must be **executed, not included**:

> `include`/`import` resolve at **parse** time, but `nimble.paths`'s `--path`
> switches only take effect at script **runtime**. The store path is dynamic
> (`prl_to_pc-0.2.0-<checksum>`). Therefore no `config.nims` and no driver
> script can ever `include` a file out of the store.

Hence `nim e <package root>/qt_pkgconfig.nims <subcommand>`. If you find
yourself writing an `include`, you have taken a wrong turn.

## Context you would otherwise rediscover

- **prl-to-pc's remote is now real.** Tag `v0.2.0` (peeled `f649ba6`) is
  pushed; PR #1 is merged to `main`. `main` is 2 commits past the tag: the
  probe-based System/Generated mode merge, plus `81aa1e8` (space-safe
  consumer-paths extraction). **Branch v0.3.0 off `main`, not off the tag** —
  the probe logic you need is only on `main`.
- **The app pin is `#v0.2.0`** in `nim_status_client.nimble`. The store entry
  is `prl_to_pc-0.2.0-d902f8c93f0f…`. A pkgcache clone lives at
  `~/.nimble/pkgcache/githubcom_statusimprltopcgit_v020`; the key embeds the
  ref, so a future `#v0.3.0` pin mints a **fresh** clone — the pkgcache
  staleness wall does not bite you.
- **Store copies are read-only pinned content.** The tools must be built into
  the repo-local `.prl-to-pc-build/` (that is what `QT_PC_BUILD_DIR` exists
  for). A criterion checks the store entry is byte-identical (per-file md5)
  before and after a full build.
- **`generate` must refuse on a store copy.** The marker is the presence of
  `nimblemeta.json` in the package root. This already exists in the mk; port
  the semantics, keep the actionable message.
- **The two consumer seams today** are `config.nims` (the pkg-config env
  block, which derives `pcKit`/`pcVer`/`pcFileDir` — that derivation is what
  you are deleting) and the root `Makefile`'s `include $(PRL_TO_PC_ROOT)/qt-pkgconfig.mk`
  plus its include-remake-reexec bootstrap. `prlToPcRoot()` lives in
  `status_env.nims` and is shared by driver + config.nims. Keep it.
- **`qt-pkgconfig.mk` stays** in v0.3.0, working, unchanged in behaviour. The
  interim mobile make legs consume it. Do not delete it upstream. Do delete
  the app's `make qt-pkgconfig*` targets and their bootstrap once the driver
  owns tools+env — but the root Makefile keeps *including* the mk for mobile.
- **prl-to-pc already has a test harness**: `tests/test_qt_pkgconfig_mk.nim`,
  wired into its `nimble test`. Your nimscript interface joins that suite.
- **Kits**: 6.11.0 = Generated (broken prefix), 6.11.1 and 6.12.0 = System.
  Both modes are acceptance criteria. On a System-mode kit there is **no
  wrapper at all**, so `config.nims` must not assert one exists — that
  assertion is in the code today and is a bug the moment probe-mode lands.
- **Brew's pkg-config resolves ambient Qt6Core** on this machine
  (`/opt/homebrew/lib/pkgconfig` is baked in), so a naive "is Qt6Core
  findable" probe is never empty. The upstream probe compares
  `pkg-config --variable=libdir Qt6Core` against `qmake -query QT_INSTALL_LIBS`
  for string equality. Do not invent a different probe.
- **Walls that will bite you**: a `nimble.lock` in the compile CWD disables
  nim's default nimblepath (this repo has one) → be explicit with `--path`;
  the parent-checkout `config.nims` walk poisons compiles run inside nested
  worktrees → `--skipParentCfg:on` where relevant; `nim e` inside the store
  dir will pick up prl-to-pc's own `config.nims` (that is fine, it is theirs).

## Authoring order (this IS the acceptance path)

1. `nim develop status.nims prl-to-pc` → materialises `vendor/prl-to-pc`.
   Reset it to track `main` (the develop checkout may come up at the tag).
2. Author `qt_pkgconfig.nims` there (`env` / `tools` / `generate`), plus tests
   in prl-to-pc's own suite covering both probe modes and the store refusal.
3. Convert the app against the live checkout: driver calls `tools`, then `env`
   once, caching the output to a repo-local gitignored artifact keyed on
   (qmake path, resolved package root, kit). `config.nims` reads the cache.
   Delete the kit derivation and the wrapper assertion from `config.nims`.
   `generate` becomes an explicit driver task.
4. Prove BOTH kits: build on 6.11.0 (Generated) and on 6.11.1 or 6.12.0
   (System). The System-mode build is the one that proves the assertion is
   really gone.
5. **STOP HERE and hand back.** The push of prl-to-pc `main` + the annotated
   tag `v0.3.0` is the human's job (SHARED-i3: never push). Your final message
   must state exactly what needs pushing and from where.
6. After the human pushes, you will be resumed to: bump the app pin to
   `#v0.3.0`, `undevelop`, wipe the store entry, re-solve from the remote, and
   re-verify (full build, no-op timing, store byte-identity, develop
   round-trip).

## Pre-identified grill triggers (stop and ask, do not improvise)

- If `nim e` cannot see the consumer's `nimble.paths` well enough to resolve
  `regex`/`unicodedb` for the tool builds, and the fix is not a plain
  `--path:` argument you pass explicitly.
- If the env cache's key cannot be computed without shelling out per compile
  (that would defeat its purpose).
- If the probe on 6.11.1/6.12.0 does NOT select System mode, contradicting the
  recorded finding — that means the probe or the kits changed; report, do not
  patch around it.
- Any second in-package write beyond the tools directory.

## Definition of done for this handoff

Everything in steps 1–4 committed and green, the issue file carrying a
verification record for what you proved so far, and a final message that
tells the human precisely what to push. Do not tick the criteria that depend
on the push (pin bump, remote re-solve) — they belong to your second run.
