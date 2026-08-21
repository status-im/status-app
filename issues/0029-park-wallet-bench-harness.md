# Park the wallet bench harness

Prerequisite for 0030, 0031, 0032. **No reviewer agent** — this is one push of an
existing branch.

## What to do

Push `feat/storybook-wallet-loader` (currently local-only, tip 767a811f0f) to origin
un-merged, so that the provenance lines the extraction issues add to commit messages
resolve to something real.

The branch is the only record of how any of the wallet perf work was measured: the
generated wallet mock backend (~1900 lines), `WalletLoaderPage`, and ten benches with
their recorded baselines. None of it is merging. If it only exists in a local worktree
it is gone the first time that directory is cleaned.

Do **not** open a PR for it. It is a dated artefact, not a proposal.

## Also park (uncommitted, on that branch)

`CONTEXT.md`, `docs/adr/0008-*.md`, `docs/investigations/wallet-load-benchmarks.md`,
`docs/investigations/wallet-load-qml-profile.md`, `issues/`. Commit them onto the parked
branch. They do not go into any of the four PRs.

## Acceptance criteria

- [ ] `git ls-remote --heads origin feat/storybook-wallet-loader` returns 767a811f0f or later
- [ ] No PR is open for the branch
- [ ] The docs above are committed on it
