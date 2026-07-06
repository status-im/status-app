# Agent brief — issue 0007: sds pin flip to PR #85

Read `docs/superpowers/plans/agent-briefs/SHARED.md` first, then your issue:
`docs/superpowers/issues/0007-sds-pin-flip-pr85.md`.

## Your role

Implementer of issue 0007. **You HOLD the in-tree build lock** — you are the
only agent allowed to run builds in this repo tree until you announce
completion (commit mentioning 0007 + `cmux notify`). Work briskly: agent 0008
is waiting on you before it can build.

## Key facts you'd otherwise have to rediscover

- The pin: `https://github.com/alexjba/nim-sds.git#5c89d61f897b44b75f2f28978f9928960181cf95`
  (PR logos-messaging/nim-sds#85 head = the local 6-patch queue as one
  commit). Local `vendor/nim-sds` is at exactly 5c89d61 — useful for diffing
  expectations, but the default flow must stop needing it.
- `vendor/status-go/statusgo.nimble` currently has the interim
  `requires "file:///…/vendor/nim-sds"`. The app manifest
  (`nim_status_client.nimble`) keeps ITS interim
  `requires "file:///…/vendor/status-go"` — that one is issue 0010's job, NOT
  yours. file:// chains remain legal, and a URL#hash requires INSIDE a
  file://-required package is fine (the walls only forbid the reverse).
- Expect the lock-divergence pattern and the pkgcache staleness wall
  (AGENTS.md): wipe `~/.nimble/pkgcache/*nim?sds*`-style stale clones if the
  pin's commit isn't discovered; hand-fix divergent lock entries per the
  documented pattern; ALWAYS re-verify from a wiped store
  (`~/.cache/status-desktop-nimbledeps`).
- statusgo.nims' sds engine already handles store copies (`.sds-build/`
  scratch); resolved-path-outside-store = build in place. You should need NO
  engine changes — if you think you do, that's a grill-rule stop.
- `nimble setup` is driven by the desktop Makefile stamp
  (`nimble.paths` keyed on lock + manifests). Setup from a clean store takes
  ~4 min (no SAT solve with a good lock); a full solve (~10 min) means the
  lock isn't being honored — investigate, don't wait it out.

## Acceptance = the issue's five checkboxes. Notes:

- "vendor/nim-sds moved aside" test: `mv vendor/nim-sds /tmp/… && build …
  && mv` back at the end (it stays useful for develop mode later).
- iOS spot-check needs only the libsds cross task, not a full app build:
  `cd vendor/status-go && nim libsdsIos statusgo.nims` with the usual env
  (see issue 0004's verification record for exact invocations), then
  `nm -gU` on the archive → exactly 9 `_Sds*` globals.
- Desktop launch check: `make run-macos` (needs NIMSDS_LIBDIR on
  DYLD_LIBRARY_PATH — already wired; just verify the app comes up and shuts
  down cleanly).

When done, follow the SHARED completion protocol (verification record, PRD
row, progress.txt, commit, notify). Your completion commit message MUST
contain `0007` — agent 0008 polls git log for it.
