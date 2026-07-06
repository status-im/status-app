# Shared brief — nimble-migration iteration-2 agents (read first)

You are one of several autonomous agents working in parallel on the
nimble-migration iteration-2 plan, each in its own cmux workspace tab. The
human (Alex) tracks you via the cmux sidebar and will discuss with you in
your tab when you ask.

## Required reading, in order (skim nothing)

1. Your issue file (named in your own brief) — it is the contract.
2. `docs/superpowers/prds/2026-07-06-one-command-and-develop-mode-prd.md`
3. `CONTEXT.md` (glossary — use these terms exactly)
4. `docs/adr/0004-develop-mode-via-paths-overlay.md`
5. `vendor/status-go/AGENTS.md` — ALL of it, especially "nimble 0.22.3
   resolution walls". Every wall there was verified empirically; do not
   rediscover them, and do not fight them.
6. `docs/superpowers/progress.txt` — at least the 2026-07-06 entries.

## Ground rules (non-negotiable)

- **Local only.** Work on branch `worktree-nimble-migration` in this worktree
  (`vendor/status-go` commits go on its `nimble-phase1-pin` branch). Commit
  with `--no-gpg-sign`. NEVER push. NEVER create/modify anything on GitHub
  (read-only `gh`/fetch is fine).
- **Paths.** All edits inside THIS worktree
  (`…/status-desktop/.claude/worktrees/nimble-migration`); never touch the
  parent checkout at `~/Repos/status-desktop`.
- **Commits.** Commit your work in reviewable chunks with conventional-ish
  messages mentioning your issue id (e.g. `feat(nimble/0007): …`). Other
  agents share this working tree: `git add` ONLY your own files, never
  `git add -A`; if the index is locked, wait a few seconds and retry.
- **Build lock.** Only ONE agent may run builds inside the repo tree at a
  time (concurrent builds clobber shared build dirs). Your brief says whether
  you hold the in-tree build lock. Scratch-dir work
  (`~/.cache/…`, `/private/tmp/…`) is always allowed. The lock holder
  announces completion via a commit containing its issue id + `cmux notify`.
- **No scope creep.** Your issue's acceptance criteria are the whole job.
  Follow-ups go into the issue file's notes, not into code.

## Decision protocol (the grill rule)

If you need to make a compromise that affects **how the modules are
configured** (nimble manifests / requires shape, config.nims, lock handling,
store/overlay semantics, vendor build contracts) or to implement a
**workaround in nimble module config**:

1. First exhaust: the codebase, `vendor/status-go/AGENTS.md`, the nimble
   docs and source (github.com/nim-lang/nimble — read the actual code), and
   a small empirical experiment in a scratch dir.
2. Only if those cannot answer: STOP that thread of work. In your tab, run a
   grilling-style interaction: state the blocker in one paragraph, list the
   options with trade-offs, give YOUR recommended answer, ask ONE question at
   a time. Send `cmux notify --title "<issue-id>: decision needed" --body
   "<one-line summary>"` so the human sees it, then WAIT for the answer.
3. Never silently work around a wall; never leave an undocumented compromise.

## cmux features (use them)

- `cmux set-status task "<what you're doing now>"` — update as you go.
- `cmux set-progress 0.0-1.0` — coarse is fine; `cmux clear-progress` at end.
- `cmux log --level progress|success|warning|error "<msg>"` — milestones.
- `cmux notify --title "…" --body "…"` — ONLY when done, blocked, or needing
  a decision (it interrupts the human).

## Completion protocol

1. All acceptance criteria verified — add a dated **Verification record**
   section to your issue file (follow the style of issue 0004's record:
   exact commands, exact evidence).
2. Update the PRD Progress table row + append a summary to
   `docs/superpowers/progress.txt`.
3. Commit everything, `cmux set-status task "done"`, `cmux clear-progress`,
   `cmux log --level success …`, `cmux notify --title "<issue-id> done" …`.
4. Report a concise summary in your tab and stay available for discussion.
