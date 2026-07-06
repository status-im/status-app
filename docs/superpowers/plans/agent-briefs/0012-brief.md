# Agent brief — issue 0012, SPIKE PHASE ONLY: seaqt pair nimble-graph feasibility

Read `docs/superpowers/plans/agent-briefs/SHARED.md` first, then your issue:
`docs/superpowers/issues/0012-seaqt-pair-graph-adoption.md`.

## Your role

Run the **feasibility spike only** — the conversion itself is blocked by
issue 0009 and is NOT your job. You NEVER build in the repo tree and you
NEVER edit repo build files; your only repo writes are the spike record
(`docs/superpowers/specs/2026-07-06-seaqt-graph-spike.md`), updates to your
issue file, and their commit. Everything else happens in scratch dirs with a
SEPARATE nimble dir (e.g. `NIMBLE_DIR=~/.cache/seaqt-spike-nimbledeps`) so
you cannot disturb the app store while agent 0007 rebuilds it. Keep scratch
dirs OUTSIDE any repo tree (parent-config poisoning wall — AGENTS.md).

## Spike questions (all four, evidence per answer)

Local checkouts for reference: `vendor/nim-seaqt` (branch qt-6.4,
`seaqt.nimble`, generated Qt 6.4 bindings + Makefile) and
`vendor/nimqml-seaqt` (`nimqml.nimble`). Consumption today is OUTSIDE the
graph: `config.nims` lines ~31–32 hardcode path switches; line ~108 adds a
compatibility include path — read those first, plus how the app build
compiles/links the seaqt C++ shims today (follow the make/StatusQ chain far
enough to know what artifacts seaqt contributes and who compiles them).

1. **Resolution**: in a scratch consumer package, do
   `requires "https://github.com/seaqt/nim-seaqt.git#<qt-6.4 head SHA>"` and
   `requires "https://github.com/seaqt/nimqml-seaqt.git#<pinned SHA>"`
   resolve on nimble 0.22.3? Use the SHAs the submodules currently point at.
   Watch the walls: pkgcache staleness, special-version pre-binding, package
   `name` in their manifests (`seaqt`, `nimqml`) vs repo names.
2. **Store-copy usability**: does a consumer program that imports nimqml (a
   minimal QGuiApplication smoke, or at least a compile of a representative
   module) build against the STORE copies? Key risk: in-package C++ shim
   compilation vs read-only store — establish whether seaqt compiles shims
   via `{.compile.}` into nimcache (fine) or needs to write into its package
   dir (then note the sds `.sds-build/` scratch pattern as the fallback and
   verify a scratch copy works).
3. **The compat include path**: what does `config.nims` line ~108 point at,
   and does an equivalent path exist inside the store copy (i.e. is it
   expressible as a path relative to the resolved package root)?
4. **Qt flag discovery**: seaqt links Qt via pkg-config/qt-pkgconfig
   machinery (see `vendor/prl-to-pc`, `qt-pkgconfig` mentions in the repo,
   and seaqt's own Makefile/config). Does that discovery work when the
   package lives in the store instead of `vendor/`? (QMAKE env available:
   `~/Qt/6.11.0/macos/bin/qmake`.)

## Output

- Spike record at `docs/superpowers/specs/2026-07-06-seaqt-graph-spike.md`:
  PASS or FAIL per question, exact commands + evidence, and a one-paragraph
  overall verdict recommending the issue's pass path or fail path.
- Update issue 0012's first acceptance checkbox + link the record.
- Commit (only your files) with `0012` in the message; notify per SHARED.
- Do NOT proceed to the conversion either way — the issue mandates a grill
  session on your findings first. Your final tab message should present the
  verdict grill-style: findings, options, your recommendation.
