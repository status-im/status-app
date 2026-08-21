# WalletLoaderPage cannot reach the collectibles path

Context: `docs/investigations/wallet-load-benchmarks.md`, "On-screen pass on the merged tree".
Found while verifying `issues/0018`; not caused by any of the perf work.

## What to build

Two small defects in the storybook harness combine to make the wallet section's entire
collectibles path unverifiable on screen:

1. **The Collectibles tab shows an empty substitution** — "Displaying collectibles on
   [nothing] is not currently supported by Status." — and an empty list, even with 500
   mocked collectibles. The empty `%1` is `CollectiblesNotSupportedTag`'s network name,
   which the page's mock never populates. So a collectible row cannot be clicked, and the
   collectible detail view cannot be opened the way a user opens it.
2. **The fallback is unreachable too.** `walletLoaderOpenCollectibleDetailButton` exists on
   `WalletLoaderPage` precisely so the detail can be opened without a row click — but it sits
   in a third row of the controls pane that is clipped below the pane's 160px preferred
   height, so it cannot be pressed on screen either.

Fix both: populate whatever the collectibles mock needs so the tab renders its list, and make
the controls pane's third row reachable.

This matters beyond tidiness. `CollectibleDetailView` was deferred behind a `Loader` in
`issues/0002`, and the deferral of an entire view is exactly the kind of change whose
regressions are invisible to counts and tests — the assets path was verified on screen and
the collectibles path was not, purely because the harness could not reach it.

## Acceptance criteria

- [ ] The Collectibles tab renders its list against the mocked profile, with the network name substituted
- [ ] A collectible row can be clicked and opens the collectible detail view
- [ ] Every control in `WalletLoaderPage`'s controls pane is reachable on screen
- [ ] The deferred `CollectibleDetailView` is verified on screen: it opens, renders, and unloads on the way out
- [ ] Storybook functional suite unchanged against its recorded baseline
- [ ] Only `storybook/` files touched, unless the empty substitution turns out to be a production defect — in which case say so, because then it affects the app and not just the harness

## Blocked by

None - can start immediately.
