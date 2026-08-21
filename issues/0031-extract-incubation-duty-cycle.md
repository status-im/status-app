# Extract the incubation duty-cycle change onto its own branch

One of three extractions splitting `feat/storybook-wallet-loader` (tip 767a811f0f) into
mergeable PRs. **Extraction, not implementation.** Smallest of the three, and the one
with the widest blast radius: it changes how every asynchronous Loader in the app is paced.

Two agents, in sequence: an **executor**, then an **adversarial reviewer**.

## Branch

`perf/incubation-duty-cycle`, based on `tests/red-stack-21975` (@120bbbf6ed).
Independent of the other two extractions.

## Content

    d00dbf20c4  perf(statusq): run gentle incubation at a 50% duty cycle

**Plus one hunk that must be split out of `f905357a45`.** That commit is subject-labelled
`test(storybook): verify the incubation cadence outside the wallet` and looks like pure
harness work, but it also carries a correction to `ui/StatusQ/tests/src/tst_incubationcadence.cpp`:
the test's stated rationale claimed the bite was the stall floor, which the measurements
had already disproved. Drop that commit's bench and `Makefile` hunks; keep the `.cpp` hunk.

Without it this branch ships a test whose comments argue the wrong thing.

Fold the `.cpp` hunk into `d00dbf20c4` or land it as a second commit — either is fine,
as long as the reasoning in the test matches the reasoning in the change.

## Do not touch PR #21921

`perf(statusq): event-loop-driven QML incubation controller` is open, **approved**
(jrainville, friofry) and unmerged. It owns `ui/StatusQ/src/externc.cpp` and introduced
the constant this branch replaces:

    m_gentleBudgetMs = qMax(1, m_gentleIntervalMs / 4);   // externc.cpp:101

`perf/qml-incubation` is an ancestor of `tests/red-stack-21975` and `externc.cpp` is
byte-identical on both, so this applies cleanly today. Folding the change back into
#21921 would invalidate two approvals; that was considered and rejected. Leave it alone.

Consequence to state in the PR description: this branch's diff is hard to read without
#21921's context, and it cannot reach master before #21921 does.

## Filter the commit messages and the code

Remove every reference to something that will not exist on this branch — in commit
messages **and** code comments: `issues/NNNN`, `docs/investigations/...`, the benches,
their baselines, `WalletLoaderPage`, the wallet mock backend.

`d00dbf20c4`'s message is dense with measurements and carries the load-bearing argument
(the duty cycle drives wall clock; the bite does not, because `incubateFor()` returns
only after finishing the object it is midway through). **Keep all of it.** Add a
provenance line: measured on the offscreen storybook benches, not part of this PR, see
branch `feat/storybook-wallet-loader`.

## Executor brief

Create the branch, apply the change plus the split hunk, strip and rewrite as above,
verify, stop. Do not push. Do not open a PR — 0033 does that.

## Reviewer brief (adversarial, fresh context)

Read the diff, not the executor's summary. Check that:

- the constants are **correct** and the C++ test actually pins what it claims to pin
- the change is **needed** and the measurement in the message supports the conclusion drawn
- it is **not over-built** — two constants and a test, nothing more
- there are **no comments restating the code**; the test's comments must record *why*
  the constants are what they are, and must now be consistent with the measurements
- it complies with the repo's C++ standards and reads like the surrounding controller code
- **no reference survives** to the benches, `issues/NNNN`, or the investigation docs
- nothing in `externc.cpp` changes beyond the cadence constants — this branch must not
  quietly revise PR #21921's mechanism

Report findings ranked by severity. Empty is a valid outcome.

## Acceptance criteria

- [ ] Branch exists on `tests/red-stack-21975`; `externc.cpp` differs only in the cadence constants
- [ ] `tst_incubationcadence.cpp` carries the corrected rationale
- [ ] `git diff --name-only tests/red-stack-21975 <branch> -- storybook/` is **empty**
- [ ] `make run-statusq-tests` green, including `tst_incubationcadence`
- [ ] Storybook QmlTests green differentially against a `tests/red-stack-21975` baseline
- [ ] No surviving reference to the harness, the docs, or `issues/NNNN`
- [ ] PR #21921 untouched — no force-push, no amend, no new commits on `perf/qml-incubation`
- [ ] Adversarial review completed and its findings resolved or explicitly declined

## Blocked by

- 0029
