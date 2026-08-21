# Asset detail never opens: the click handler looks up a retired model

Found on device (Redmi A5) on 2026-08-20 while validating the wallet load work. **Not a
regression from that work** — see "Provenance" below.

## Symptom

Tapping any row in the wallet's Assets list does nothing at all. No navigation, no error
dialog, no visual change.

## Root cause

`RightTabView.qml`'s `onAssetClicked` does, in order:

```qml
const tokenGroup = SQUtils.ModelUtils.getByKey(RootStore.walletAssetsStore.groupedAccountAssetsModel, "key", key)
const listAsset = SQUtils.ModelUtils.getByKey(RootStore.walletAssetsStore.assetsModel, "key", key)
d.assetDetailTokenGroup = listAsset ? Object.assign({}, tokenGroup, { ... }) : tokenGroup
RootStore.setCurrentViewedHolding(tokenGroup.key, ...)   // <- throws here
stack.currentIndex = 2                                    // <- never runs
```

`tokenGroup` is **null**, so line 586 throws and the navigation on the next line never
executes:

```
RightTabView.qml:586  TypeError: Cannot read property 'key' of null
```

The reason it is null is a model mismatch introduced by the terminal-assets-model rewire.
`WalletAssetsStore` says so in its own comment:

```qml
// Terminal, already-aggregated assets model built in Nim (replaces the QML
// AssetsViewAdaptor proxy chain). Consumed by AssetsView in RightTabView.
readonly property var assetsModel: walletSectionAssetsView.assetsModel
```

The visible list is fed by that terminal Nim `assetsModel`. The click handler looks the tapped
key up in `groupedAccountAssetsModel` — a `LeftJoinModel` over the legacy
`baseGroupedAccountAssetModel`. The list was rewired; this lookup was not.

## Reproduction

Device, real profile, wallet section. Reproduced 3/3:

- specific account ("Status account"), tapped USDT (EVM) — throws, no navigation
- same account, tapped Status/SNT — throws, no navigation
- **All accounts** mode, tapped vBSWAP — throws, no navigation

So it is neither asset-specific nor mode-specific: every tap fails.

## Provenance — why this is not the deferral work

`issues/0002` deferred `AssetsDetailView` behind an async `Loader` and changed exactly one line
of this handler:

```
-  assetDetailView.tokenGroup = listAsset ? Object.assign({}, tokenGroup, {
+  d.assetDetailTokenGroup   = listAsset ? Object.assign({}, tokenGroup, {
```

`git blame` puts the failing line 586 and the navigation on 587 at pre-existing commits. And
`Object.assign({}, null, {...})` does not throw, so the assignment line is harmless with a null
`tokenGroup` in both the old and new versions. The throw is at the same place either way.

## What to decide

The fix is not obviously "guard the null" — that would make the tap silently do nothing instead
of silently doing nothing. The real question is which model is authoritative:

- Should the handler read the group from the terminal `assetsModel` it already queries, and stop
  consulting `groupedAccountAssetsModel` at all?
- Or do the two models' `key` values need reconciling, because other call sites still join on it?

`RootStore.qml:162` also feeds `groupedAccountAssetsModel` to something as `tokensList`, so it is
not obviously dead — check its other consumers before retiring it from this path.

Whoever owns the terminal-assets-model rewire should make this call.

## Acceptance criteria

- [ ] Tapping any asset opens the asset detail, on a specific account and in All accounts mode
- [ ] The authoritative model for this path is stated, and other `groupedAccountAssetsModel` consumers are checked
- [ ] No `TypeError` in the log on tap
- [ ] A test covers a tap whose key is absent from the secondary model, so the handler can never again throw before navigating
- [ ] Verified on device, not only in storybook — the storybook mocks populate both models, which is why this was invisible there

## Blocked by

None. Independent of the wallet load work.
