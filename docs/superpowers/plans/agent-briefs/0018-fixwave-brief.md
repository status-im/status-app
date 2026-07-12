# Fix-wave brief — issue 0018 review round (2026-07-12)

Two-axis review of `16a96b3f64..bbf5e65ca5` + three user adjudications. You
are a fresh implementer applying this one wave. Ground rules:
`docs/superpowers/plans/agent-briefs/SHARED-i3.md` (note its environment
block is post-0018: `export QMAKE=~/Qt/6.11.0/macos/bin/qmake`, bootstrap =
`nimble setup && source ./env.sh`, USE_SYSTEM_NIM is dead). You HOLD the
build lock. Keep `docs/superpowers/issues/0018-nbs-deleted.md`'s
Verification record truthful as you change code.

## User adjudications (2026-07-12 — final, implement as stated)

A1. **Driver-side compiler guard IS added** (amends the PRD's "no version
    guard" decision — record the adjudication in the issue + PRD). Shape:
    in the DRIVER (status.nims / status_artifacts.nims — NEVER config.nims;
    nimsuggest evaluates that with its own compiler and would false-positive),
    before the client compile, compare the compiler that will run
    (realpath of `nimExe()` resolution) against the pkgs2 nim entry the
    resolution names (nimble.paths / the store path), and fail fast with a
    message that names `source ./env.sh`. Must not fire under `nimble build`
    (hook PATH is injected = always the pin — cheap to confirm) and must not
    add a per-build subprocess beyond what a key-file check costs.
A2. **status-go-deps inline is ACCEPTED.** Add the status-go-side nimscript
    move to `docs/superpowers/upstream-asks.md` (a push-bearing human task;
    note it collapses the three `go install …protoc-gen-go` copies:
    Makefile, status_artifacts.nims, fdroid/build-app.sh).
A3. **env.sh is the blessed bootstrap.** Amend the issue's "What to build"
    bullet (and the PRD's NBS-deletion block if it names the bare eval) to
    `nimble setup && source ./env.sh`, citing the shellenv PATH-order wall
    (already in the walls doc).

## Critical — env.sh is the bootstrap SPOF; all three confirmed by reviewers

C1. `env.sh:43`: the `grep -m1` pin scrape returns rc=1 on no match and the
    command substitution propagates it — under the callers' `set -e`
    (`fdroid/build-app.sh` has `set -eou pipefail`; ContainerBuilds uses
    `bash -c 'set -e && …'`) sourcing DIES SILENTLY and the WARNING branch
    is unreachable. Append `|| true` inside the substitution.
C2. `env.sh:52`: `if [[ $# -gt 0 ]]; then exec "$@"; fi` — a SOURCED file
    inherits the caller's positional params (verified by probe), so any
    caller sourced from a script with args execs its own argv and never
    returns. Gate the exec arm on executed-not-sourced:
    `[[ "${BASH_SOURCE[0]}" == "$0" ]]` (keep the zsh fallback working —
    when sourced under zsh BASH_SOURCE is unset; test both shells).
C3. `env.sh` hoist asserts nothing about the version: it takes the FIRST
    `pkgs2/nim-*/bin` in shellenv's PATH; with two store nims the wrong one
    silently wins — the exact class the file exists to prevent. After
    hoisting, assert the hoisted `nim -v` (or the path's embedded version)
    against the manifest's `requires "nim == X"` (parse the .nimble — do
    not hardcode 2.2.4) and fail loudly on mismatch. This is the bootstrap
    end of the same contract A1 guards at build time.

Verify C1–C3 with probes for BOTH bash and zsh, sourced and executed, with
and without args, under `set -e`: the fdroid/ContainerBuilds call shapes
must survive, an argful caller must not be hijacked, and a two-nim PATH
(simulate with a fake pkgs2-shaped dir prepended) must fail loudly.

## Important

I1. **CI half-bootstrap → explicit 0019 blocker, not a fix here.** The five
    `ci/Jenkinsfile.*` got `nimble setup` only; later stages take the
    image's nim (or none); `Jenkinsfile.ios` has no bootstrap at all. Per
    review + orchestrator decision: do NOT edit ci/ further (0019 owns it,
    lands next). Instead: (a) amend 0018's record §"criterion 3" wording so
    the divergence-closed claim is scoped to the local front doors and
    names CI as open; (b) add a "Blocked-by-0018 handoff" note in
    `docs/superpowers/issues/0019-ci-nimble-only.md` listing exactly:
    5× Jenkinsfile need `source ./env.sh` (or nimble-alias) after setup,
    Jenkinsfile.ios needs the bootstrap added, and criterion-3's CI leg.
I2. `make clean`'s hardcoded key-file list (Makefile ~1091) vs the consts
    in status_artifacts.nims — one source of truth: either a tiny driver
    task make clean calls, or a documented `.status-*.key` naming
    convention + glob (note `.libsds.key` breaks the pattern — renaming it
    `.status-libsds.key` makes the glob total; if you rename, update every
    reference and the gating-audit table). Also fix the contradictory
    comment two lines above.
I3. `app --os:ios/--os:android --force` warns-and-ignores while
    `buildArtifacts` rejects `--force` — same file, two contracts. Make the
    mobile arms REJECT it (0017's review stance: accepting silently is a
    lie), message pointing at the mobile follow-on.

## Minor (apply if trivial, else record)

M1. env.sh idempotency (repeat `source` grows PATH) + temp-var leakage
    (`STATUS_SHELLENV`, `STATUS_NIM_BIN`, `REL_PATH`, `ABS_PATH`) — dedupe
    guard + unset.
M2. Record in the issue: commit 96d76723d4's title overstates ("includes no
    external makefile" — prl-to-pc's qt-pkgconfig.mk include remains, and
    remains the invariant checker's known blind spot). No amend (shared
    branch) — a record note only.
M3. Deletion-list names appearing in comments only — disclosed, accepted,
    no action (record as reviewed-and-accepted).

## Completion

Re-run: `scripts/check-no-nim-compiles.sh`; `nim app status.nims` no-op ×3;
`nim tests status.nims utils_test`; the C1–C3 probe matrix; `nimble build`
green (A1 guard must not fire there). Update issue record + PRD row +
progress.txt. Commits `fix(nimble/0018): …`/`docs(nimble/0018): …`, gpgsign
off, no --amend/add -A. Delivery: SendMessage TOOL to "team-lead",
summary "0018 fix wave report" — plain text is not delivered.
