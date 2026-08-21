# Extract the StatusQ leaf-cost work onto its own branch

One of three extractions splitting `feat/storybook-wallet-loader` (the "fat branch",
tip 767a811f0f) into mergeable PRs. **This is an extraction, not an implementation** —
the production code already exists and is device-verified. The job is to lift it out
cleanly, leaving the storybook wallet harness behind.

Two agents, in sequence: an **executor**, then an **adversarial reviewer**. Briefs below.

## Branch

`perf/statusq-leaf-cost`, based on `tests/red-stack-21975` (@120bbbf6ed).
Check the name is free before creating — it was a side-branch name on the fat branch.

Independent of the other two extractions: zero file overlap, any merge order.

## Commits, in this order (order is load-bearing)

    0d645404cd  perf(StatusQ): build control tooltips on the first hover
    7109ea7912  perf(StatusQ): let StatusScrollBar resolve its own policy
    8ad3cfcccd  perf(StatusQ): build the button ripple on the press that needs it
    82a653cb2e  perf(StatusQ): build the remaining ripples on the press that needs them
    b2dabd8162  perf(StatusQ): build the StatusListItem tag rows only when there are tags

`0d645404cd` and `8ad3cfcccd` both edit `StatusBaseButton.qml`; `82a653cb2e` and
`b2dabd8162` both edit `StatusListItem.qml`. Reordering will conflict or silently
produce a different result.

Scope note for reviewers: these are StatusQ-wide changes. They touch every button,
list item, combo box, menu item and scrollbar in the app — not just the wallet.

## Strip on the way through

1. **Every `storybook/benches/**` hunk.** `tests/red-stack-21975` has no
   `storybook/benches/` directory at all, so these hunks would create files that
   should not exist. Four of these five commits carry one.
2. **The `storybook/pages/WalletLoaderPage.qml` hunk in `82a653cb2e`** (3 lines).
   That page is part of the harness and is not being merged.

No dropped commit touches any file these five edit, so nothing else should conflict.

## Filter the commit messages and the code

The fat branch was written in a context these branches will not have. Anything
referencing something that will not exist on this branch must go — in commit messages
**and** in code comments:

- `issues/NNNN` references
- `docs/investigations/...` and `docs/adr/0008-...` references
- anything naming the bench, its baselines, `WalletLoaderPage`, or the wallet mock backend

**Keep every measurement.** The numbers are the justification; without them
"build the StatusListItem tag rows only when there are tags" reads as unmotivated
churn across a shared component. Add one provenance line per commit to the effect of:
measured on the offscreen storybook wallet bench, which is not part of this PR, see
branch `feat/storybook-wallet-loader`. That states plainly the reviewer cannot rerun it.

## Executor brief

Create the branch, cherry-pick the five in order, strip as above, rewrite the messages,
verify, stop. Do not push. Do not open a PR — 0033 does that once all three branches exist.

## Reviewer brief (adversarial, fresh context)

Do not take the executor's summary at face value; read the diffs. Check that:

- the code is **correct** and does what its commit message claims
- each change is **needed** — a deferral that saves nothing is churn on a shared component
- nothing is **over-built**: no abstraction, indirection or option that the problem did not ask for
- there are **no comments explaining what the code already says**; comments earn their
  place only by recording a non-obvious constraint
- it follows `guidelines/QML_ARCHITECTURE_GUIDE.md` and reads like the surrounding StatusQ code
- **no reference survives** to the bench, the baselines, `issues/NNNN`, the investigation
  docs, or the mock backend — in messages or comments
- the five commits are in the required order and each builds on its own

Report findings ranked by severity. An empty report is a valid outcome.

## Acceptance criteria

- [ ] Branch exists on `tests/red-stack-21975` with exactly these five commits, in order
- [ ] `git diff --name-only tests/red-stack-21975 <branch> -- storybook/` lists only
      `tst_StatusButton.qml`, `tst_StatusDeferredToolTip.qml`, `tst_StatusListItem.qml`,
      `tst_StatusRippleFeedback.qml`, `tst_StatusScrollBar.qml` — nothing under
      `storybook/benches/`, `storybook/mocks/`, no `WalletLoaderPage.qml`
- [ ] Storybook QmlTests green differentially against a `tests/red-stack-21975` baseline
      (known pre-existing failures: the ChatTextArea / ChatTextView pair)
- [ ] `make qml-lint` clean
- [ ] No surviving reference to the harness, the docs, or `issues/NNNN`
- [ ] Adversarial review completed and its findings resolved or explicitly declined

## Blocked by

- 0029 (the provenance lines must resolve to a pushed branch)
