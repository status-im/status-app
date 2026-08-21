# Defer the asset detail's permanently invisible chain tags

Context: `docs/investigations/wallet-load-benchmarks.md`, "Out of scope but worth filing" at the
end of the `issues/0024` section. Belongs with `issues/0012`, which owns this surface's gates.

## What to build

`AssetsDetailsHeader` builds four per-chain tags through a `Repeater` inside a `RowLayout`.
**Three of the four are permanently invisible** — `visible: balancesAggregator.value > 0` — and
are fully constructed anyway, because the `Repeater` has no `active` or `Loader` gate.

This is the same defect `issues/0012` already fixed twice on this surface (the chain tags'
warning buttons, the "Minted by" tile): built on every open, shown on almost none.

There is a second reason to do it. `issues/0024` traced the asset detail's `objects_settled`
spread (916 / 917 / 918) to `QQuickLayoutAttached` objects that Qt allocates lazily for
`Repeater` delegates inside a `RowLayout` — **owned by the `InformationTag` items themselves**.
Deferring the invisible tags should take that spread with it, which would turn a
`916 ± 1` tolerance back into an exact gate.

Note this changes the `chain_tags` gate, which is currently exact at 4.

## Acceptance criteria

- [ ] Tags whose aggregated balance is zero are not constructed
- [ ] A tag appearing once its balance becomes non-zero still works, including after the view is open
- [ ] `objects_settled` on the asset-detail bench drops, and its run-to-run spread is reported — ideally it becomes exact
- [ ] The `chain_tags` gate is re-recorded with the delta explained
- [ ] If the `± 1` tolerance can become exact, make it exact
- [ ] Header renders identically for an asset with one chain, several chains, and all chains — verified on screen
- [ ] Storybook functional suite unchanged against its recorded baseline

## Blocked by

None - `issues/0012` and `issues/0024` are both done.
