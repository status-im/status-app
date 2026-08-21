# Extract the wallet load work onto its own branch

One of three extractions splitting `feat/storybook-wallet-loader` (tip 767a811f0f) into
mergeable PRs. **Extraction, not implementation** — the production code exists and was
verified on a Redmi A5 with a real profile.

Two agents, in sequence: an **executor**, then an **adversarial reviewer**.

## Branch

`perf/wallet-load`, based on `tests/red-stack-21975` (@120bbbf6ed).

Treated as **independent** of the asset-detail tap fix (0028). The conservative plan
chained it, on the assumption 0028 would be fixed in `onAssetClicked` and collide with
`2053b6b3de`. The root-cause work then concluded the fix is upstream — the legacy
`groupedAccountAssetsModel` appears to be unpopulated since the terminal-model rewire,
which puts the fix in Nim or the store, not the handler. If the device probe in 0028
proves otherwise, re-chain this branch on top of the fix.

## Commits, in this order

    1cf5cf026a  perf(wallet): make the assets list's first fill preemptible
    1bf95022e8  perf(wallet): latch the token row's two warning buttons off
    2053b6b3de  perf(wallet): defer the two detail views behind async loaders
    b0cfb4460c  perf(wallet): latch the always-hidden subtrees off the asset detail
    7bfb8cb905  perf(wallet): make the accounts list's first fill preemptible

## Strip on the way through

1. **Every `storybook/benches/**` hunk.** `tests/red-stack-21975` has no
   `storybook/benches/` directory; these hunks would create files that should not exist.
2. **`storybook/qmlTests/tests/tst_WalletDetailViewDeferral.qml`, added by `2053b6b3de`.**
   It is the only test on the whole fat branch that needs the full wallet mocking
   (`WalletSectionMock`, `WalletSectionPopupsMock`), which is not being merged. Drop the
   file entirely; do not attempt to adapt it here. Rescuing it against the pre-existing
   stubs is deferred to a later issue.

Every other test in these commits is mock-free and rides along unchanged:
`tst_TokenDelegateShell`, `tst_WalletAccountDelegateShell`, and edits to the pre-existing
`tst_AssetsView`, `tst_LeftTabView`, `tst_AccountOrderSync`.

No dropped commit touches any file these five edit.

## Known consequence, state it in the PR description

Dropping that test leaves `2053b6b3de` — which moved three behaviours onto the loader
(the token is picked before anything to display it exists; a navigation request can land
mid-incubation; the reset that hung off `visible` must now fire on unload) — without
automated coverage. Compounding it: the asset detail screen **cannot currently be opened
on master** (see 0028), so manual verification cannot reach it either. Say so plainly
rather than letting a reviewer assume it was exercised.

## Filter the commit messages and the code

Remove every reference to something that will not exist on this branch — messages **and**
code comments: `issues/NNNN`, `docs/investigations/...`, the benches and their baselines,
`WalletLoaderPage`, the wallet mock backend.

Watch for this specifically: `1cf5cf026a`'s message explains why the accessible name
stays on `TokenDelegate` rather than the shell, partly by reference to "the bench's
time-to-first-row". The reasoning is sound and worth keeping — the e2e suites observe
that name too — but it has to be restated without the bench.

**Keep every measurement**, plus a provenance line: measured on the offscreen storybook
wallet bench, not part of this PR, see branch `feat/storybook-wallet-loader`.

## Executor brief

Create the branch, cherry-pick the five in order, strip as above, rewrite the messages,
verify, stop. Do not push. Do not open a PR — 0033 does that.

## Reviewer brief (adversarial, fresh context)

Read the diffs, not the executor's summary. Check that:

- the code is **correct** and does what its commit message claims
- each change is **needed** — a delegate shell that does not actually make the first fill
  preemptible is pure added indirection
- it is **not over-built**: the shells should carry geometry and placeholders, nothing more
- there are **no comments restating the code**; comments must earn their place by
  recording a non-obvious constraint (the `implicitHeight` floor and the
  `AsynchronousIfNested` behaviour are legitimate examples)
- it follows `guidelines/QML_ARCHITECTURE_GUIDE.md` — `id: root`, private state in
  `QtObject { id: d }`, no dynamic scoping, declarative over imperative, sorted `qmldir`
- shell and content geometry cannot drift apart silently — if a token or account row can
  grow taller than its placeholder, `contentHeight` and the scroll position move while
  rows fill in
- **no reference survives** to the bench, the baselines, `issues/NNNN`, the investigation
  docs, or the mock backend
- `tst_WalletDetailViewDeferral.qml` is absent and no orphan reference to it remains

Report findings ranked by severity. Empty is a valid outcome.

## Acceptance criteria

- [ ] Branch exists on `tests/red-stack-21975` with exactly these five commits, in order
- [ ] `git diff --name-only tests/red-stack-21975 <branch> -- storybook/` lists only
      `tst_AccountOrderSync.qml`, `tst_AssetsView.qml`, `tst_LeftTabView.qml`,
      `tst_TokenDelegateShell.qml`, `tst_WalletAccountDelegateShell.qml`,
      `pages/AssetsDetailsHeaderPage.qml` — nothing under `storybook/benches/` or
      `storybook/mocks/`, no `WalletLoaderPage.qml`, no `tst_WalletDetailViewDeferral.qml`
- [ ] Storybook QmlTests green differentially against a `tests/red-stack-21975` baseline
      (known pre-existing failures: the ChatTextArea / ChatTextView pair)
- [ ] `make qml-lint` clean
- [ ] No surviving reference to the harness, the docs, or `issues/NNNN`
- [ ] PR description states the missing deferral coverage and that 0028 blocks manual reach
- [ ] Adversarial review completed and its findings resolved or explicitly declined

## Blocked by

- 0029
