# Shared brief — nimble-migration iteration-3 agents (read first)

You are an autonomous implementer working one slice of the iteration-3 plan.
Unlike iteration 2, you are a **subagent of an orchestrator**, not a cmux tab
with a human in it. The human (Alex) is NOT watching you. Everything you want
to tell him must travel through the orchestrator in your **final message**.

## Required reading, in order (skim nothing)

1. Your issue file (named in your own brief) — it is the contract.
2. `docs/superpowers/prds/2026-07-09-nimble-owns-nim-compilation-prd.md` —
   especially "Implementation Decisions". Those were grilled and user-approved;
   **do not relitigate them.**
3. `CONTEXT.md` (glossary — use these terms exactly: Vendor, default mode,
   develop mode, App entry point).
4. `docs/adr/0003-platform-sentinel-ownership.md` and
   `docs/adr/0007-develop-mode-via-paths-overlay.md`.
5. `.phase2-vendor-backup/status-go/AGENTS.md` — ALL of it, especially the
   "nimble 0.22.3 resolution walls". Every wall there was verified
   empirically. Do not rediscover them; do not fight them.
6. `docs/superpowers/progress.txt` — the 2026-07-08 and 2026-07-09 entries.

## Ground rules (non-negotiable)

- **Local only. Never push. Never modify anything on GitHub.** Read-only `gh`
  and `git fetch` are fine. If your issue needs a push (0015 does), you STOP
  and hand back — the human pushes, never you.
- **Paths.** All edits inside THIS worktree
  (`/Users/alexjbanca/Repos/status-desktop/.claude/worktrees/nimble-migration`).
  Never touch the parent checkout at `~/Repos/status-desktop` — it holds
  unrelated user work, and its `config.nims` is a known rpath-leak source.
- **Commits.** `git -c commit.gpgsign=false commit` — interactive gpg cannot
  reach a tty here and a plain `git commit` WILL fail. Conventional messages
  naming your issue id: `feat(nimble/0015): …`. Never `git commit --amend`
  (shared branch). Never `git add -A` — stage only your own files.
- **Build lock.** Only ONE agent may run builds inside the repo tree at a
  time. Your brief states whether you hold it. If you do not, you may only
  work in scratch dirs (`/private/tmp/…`, `~/.cache/…`) and throwaway clones.
- **No scope creep.** Your acceptance criteria are the whole job. Follow-ups
  are recorded as notes in the issue file, never implemented.

## Build environment (this machine)

    export QMAKE=~/Qt/6.11.0/macos/bin/qmake

**`USE_SYSTEM_NIM` is dead** (issue 0018, 2026-07-12): it was a
nimbus-build-system variable, and NBS is gone — submodule, makefiles, vendored
compiler and env-script wrapper. Exporting it now does nothing at all. So is
`make update` / `make deps` / `make status-go-deps`.

**The bootstrap, and the only Nim-side prerequisite, is nimble:**

    nimble setup       # resolves the graph AND materialises the pinned compiler
    source ./env.sh    # puts <store>/pkgs2/nim-2.2.4-<checksum>/bin FIRST on PATH

After that, the `nim` on PATH **is** the compiler `nim_status_client.nimble`
pins. Do this in any shell from which you run `nim <task> status.nims` or a make
leg (`make mobile-build`, `make pkg-macos`). `nimble build` / `nimble run` need
no bootstrap: nimble injects the pinned compiler for its own tasks and hooks.

- **Use `env.sh`, not a bare `eval "$(nimble shellenv)"`** (wall, measured
  2026-07-12): shellenv's PATH lists `$NIMBLE_DIR/bin` *before* the pinned
  `pkgs2/nim-<ver>-<checksum>/bin`, and `~/.nimble/bin/nim` is a symlink that
  choosenim (or `nimble install nim@X`) can repoint at another compiler — which
  would then shadow the pin. `env.sh` re-hoists the pinned bin to the front.
  On this machine the symlink happens to BE the pin, so the hazard is invisible
  until it isn't.
- There is **no NBS nim to avoid prepending** any more; the 2.2.10/2.2.4
  divergence that rule existed for is closed at the root.

- Bare `make` without `QMAKE=` picks Linux paths in status-keycard-qt. Always
  pass it.
- Qt kits present: **6.11.0 = Generated mode** (broken prefix), **6.11.1 and
  6.12.0 = System mode**. iOS kit: `~/Qt/6.11.0/ios/bin/qmake` with
  `IPHONE_SDK=iphoneos QMAKE_DEVELOPMENT_TEAM=8B5X2M6H2Y`.
- The store is the default `~/.nimble`. Do not point `NIMBLE_DIR` elsewhere
  for in-tree work.
- Timings to beat (2026-07-09, this machine): driver no-op ~6.3 s desktop;
  full default rebuild after a store-entry wipe ~1:10; iOS leg ~2:30.

## Decision protocol (the grill rule) — READ THIS TWICE

You will hit questions the codebase cannot answer. When you do:

1. **First exhaust**, in this order: the codebase; the walls doc; the nimble
   source itself (`github.com/nim-lang/nimble` — read the actual code, do not
   guess at its behaviour); a small empirical experiment in a scratch dir with
   a throwaway `NIMBLE_DIR`. Most "unknowns" die here. An empirical answer
   beats an argued one, always.
2. **Only if those cannot answer**, and the question affects how modules are
   configured (manifest/`requires` shape, `config.nims`, lock handling,
   store/overlay semantics, vendor build contracts) or would mean an
   undocumented workaround: **STOP that thread of work.**
3. End your turn with a final message containing, in this exact shape:

   ```
   DECISION NEEDED — <issue id>
   Blocker:      <one paragraph: what you tried, what the evidence says>
   Options:      <2-4 options, each with its trade-off and what it costs>
   Recommend:    <your pick, and why>
   Evidence:     <commands run + their output, or file:line citations>
   Done so far:  <what is committed and green; what is left>
   ```

   The orchestrator will grill the human and send you the answer. Your context
   survives — you will be resumed, not restarted. Do NOT guess, do NOT pick
   the option that is easiest to implement, and do NOT silently work around a
   wall.
4. If you can proceed on other independent threads while blocked, say so and
   keep working on them; stop only the blocked thread.

**A wrong answer that compiles is worse than a stop.** Every wall in the walls
doc cost hours to find. Adding an undocumented one costs the next agent the
same hours.

## Verification standards

Claims require evidence. "It builds" means you ran the build and can paste the
exit status and timing. Copy the style of the verification records in issues
0013 and 0014: exact commands, exact evidence, timings, and an explicit note
for anything you could NOT verify (e.g. "Windows leg: ported, unverified").

Never report an acceptance criterion as met on the strength of reading the
code. If a criterion is unverifiable on this machine, say so plainly and
leave the checkbox unticked.

## Completion protocol

1. Every acceptance criterion verified — append a dated **Verification
   record** to your issue file (style of 0013/0014: exact commands + evidence).
2. Update the PRD Progress table row and append a summary to
   `docs/superpowers/progress.txt`, including any new wall you discovered
   (and add real walls to the walls doc).
3. Commit everything (`-c commit.gpgsign=false`).
4. Final message = a concise report to the orchestrator: what landed, the
   evidence, what you could not verify, what surprised you, and any follow-ups
   you recorded. Assume the orchestrator will independently re-verify your
   acceptance criteria, because it will.
