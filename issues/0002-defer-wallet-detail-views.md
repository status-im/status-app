# Defer the wallet detail views

Context: `docs/investigations/wallet-load-benchmarks.md`.

## What to build

`AssetsDetailView` and the collectible detail view are plain children of `RightTabView`'s
`StackLayout`, so both are constructed on every wallet-section load and then merely
hidden. That cost sits inside the section's time-to-content whether or not the user ever
opens a token, and it means "asset detail load time" is currently unmeasurable — the view
already exists by the time you navigate to it.

Put both behind async `Loader`s keyed on the stack's current index. Two outcomes: the
section's time-to-content and instantiation counts drop, and asset detail becomes a real
navigation surface with a load staircase of its own — which this slice then benches
against the popup-class budget (400ms device / 40ms host).

Also sweep the section for the same pattern: other `StackLayout` / `SwipeView` children
built eagerly and hidden. Record what turns up in the working doc; fixing them is out of
scope here unless trivial.

Watch for the usual deferral hazards: navigation that arrives before the loader is Ready
needs queue-and-replay (the section loader already does this for `openDesiredView`), and
the reset-on-hide handlers currently on `onVisibleChanged` must keep working when the item
can be absent entirely.

## Now priced

A qmlprofiler capture of a warm load (`docs/investigations/wallet-load-qml-profile.md`)
puts the two eager detail views at **~17.1ms of a ~181ms window**: `AssetsDetailsHeader`
10.59ms — of which a single `Repeater` at line 112 is **9.44ms**, the largest
wallet-specific creation in the entire load — plus `AssetsDetailView` 4.05ms (including two
`SortFilterProxyModel` at line 93, 2.90ms), `InformationTileAssetDetails` 1.38ms and
`CollectibleDetailView` 1.09ms.

Note what this fix does NOT do, already measured in `issues/0006`: it does not move
`max_stall_ms`. It removes creation work and object-graph weight, not a block.

## Acceptance criteria

- [ ] Both detail views are behind async `Loader`s keyed on the stack index
- [ ] Wallet-section instantiation counts drop measurably; the new counts are the gated ones
- [ ] Wallet-section `t_content` improves; before/after recorded in the commit message and the TSV
- [ ] Navigating to a token detail still works, including when the request arrives before the loader is Ready
- [ ] The existing reset-on-hide behaviour still fires when the detail view is unloaded rather than hidden
- [ ] A bench covers navigation into asset detail as its own surface, with its own staircase and gates
- [ ] The asset-detail surface's `t_content` is recorded against the 40ms host budget
- [ ] The eager-`StackLayout` sweep is done and its findings are written into the working doc
- [ ] Baseline TSV updated in the same commit as the fix

## Blocked by

- `issues/0001-wallet-section-load-bench.md`
