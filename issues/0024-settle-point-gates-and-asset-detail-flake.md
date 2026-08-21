# Move the remaining gates to the settle point, and explain the asset-detail flake

Context: `docs/investigations/wallet-load-benchmarks.md`, "`objects_total` is a teardown race"
and "Two gates still to watch". Found while doing `issues/0022`.

## What to build

Two separate problems, filed together because they are the same question — which counts can be
trusted, and when.

### 1. `account_delegates` has the premise loss too

`issues/0022` established that a count taken at the **loaders-Ready** stop line measures a race,
not a construction invariant: `objects_total`'s two modes differ by exactly one
`WalletAccountsSkeleton` subtree that has not been destroyed yet. It was demoted to recorded.

`account_delegates` is the same kind of number and is gated on **both** phases. One warm run in
36 read `0` and failed — the fastest warm load in the set (`t_ready` 32.1ms), where the accounts
list had not had its layout pass when the loaders declared themselves Ready.

The fix matches a pattern already in the bench: add **`account_delegates_settled`**, gated at
the settle point, and demote `account_delegates` to recorded — exactly the
`asset_delegates` / `asset_delegates_settled` pair that already exists.

`asset_delegates` and `loading_asset_delegates` are **not** at risk: they assert a zero, and a
faster load makes a zero safer, not shakier. Do not touch them.

Note `issues/0017` may have done this already — it was told it is the right agent to, since it
is touching the accounts list. **Check before duplicating.**

### 2. The asset-detail bench flakes on two of its own gates

Seen while confirming the wallet bench: 18 paired runs at load ~9 produced
`objects_settled [warm open] = 918` against its `916 ± 1` gate, and
`stalls_over_4ms [cold open] = 8` against its ratchet of 7. The wallet bench passed 18/18 in
the same invocations.

**The `918` is the one that matters.** It is a *settled* count — the class of number this
workstream has trusted throughout, on the grounds that it is taken after everything has
finished and is therefore deterministic. On the wallet section that has held: `objects_settled`
has not moved off 6022 in any recorded run. On the asset detail it did not hold. Find out why
before anyone widens the gate.

**A datum from `issues/0011`, which met the same class of problem on the wallet section and
chased it to ground.** Its arm-B `objects_settled` moved by exactly two objects, and the two
were identified precisely: a plain `QQuickItem` that `QQuickItemViewPrivate::createHighlight`
allocates when no `highlight` component is set — parented to `contentItem`, sized to the
current item — plus the `QQuickListViewAttached` its `FxViewItem` pulls into existence. It
appears only once the view has acquired a `currentItem`.

The conclusion drawn there: **on the wallet section, a settled count that moves is the code
moving, not the stop line firing early.** Arm A was bit-identical on 52 of 52 runs in both
phases. Check whether the asset detail's 918-vs-916 has the same shape — a `ListView` or
`Repeater` that has or has not acquired a `currentItem` by the settle point — before
concluding its settle point is wrong.

Other possibilities worth eliminating: the settle point on that bench is defined differently and may
be firing before the surface is genuinely settled; something on that surface is genuinely
non-deterministic; or the ±1 tolerance was hiding a two-mode distribution all along.

Do **not** simply widen the tolerance. If a settled count is unstable, either the settle point
is wrong or we have learned something important about what "settled" means, and both outcomes
are worth more than a passing gate.

The `stalls_over_4ms` ratchet was set under load and needs re-deriving on a quiet machine
regardless — as does the wallet bench's `stalls_over_8ms`, which read 5 once in 36 at load ~12.
**Never raise a ratchet to make it pass.**

## Acceptance criteria

- [ ] `account_delegates_settled` gated at the settle point, `account_delegates` recorded — or confirmation `issues/0017` already did it
- [ ] The asset-detail `objects_settled` instability explained with evidence, not tolerated
- [ ] Both benches run 16+ times per phase without a gate flaking, on a quiet machine
- [ ] Ratchets re-derived on a quiet machine and moved down where the data allows
- [ ] No gate loosened and no ratchet raised; any tolerance change justified by a stated cause
- [ ] Findings recorded in the working doc

## Blocked by

- `issues/0022` (done). Coordinate with `issues/0017` on part 1.

---

## Verdict: explained and gated; ratchets could not move

Full evidence in `docs/investigations/wallet-load-benchmarks.md`, "`issues/0024`: the asset
detail's settled count is Qt's lazy `Layout` attached objects".

1. **Part 1 was already done by `issues/0017`** (`3cf3202970`). Confirmed, not duplicated.
   `account_delegates` read `0` once in 56 wallet runs; `account_delegates_settled` read 16
   on 112 of 112 phases.
2. **The flake is not `issues/0011`'s `createHighlight` pair.** The entire 916/917/918 spread
   is `QQuickLayoutAttached` (107/108/109), owned by the `InformationTag` chain tags in
   `AssetsDetailsHeader`. Qt allocates a `Layout` attached object lazily per item; the count
   does not converge (stable for 2000ms past the settle point in every mode) and forcing
   every layout to resolve its implicit size changes nothing. The settle point is fine.
3. **Metric split, tolerance tightened, nothing loosened.** `objects_settled` and a new
   `layout_attached` are recorded; `objects_built` (settled minus attached) is gated at
   **809, tolerance 0** - bit-identical on 132 of 132 phases.
4. **No ratchet could come down.** Wallet warm `stalls_over_8ms` 0-3 (ratchet 3), asset warm
   `stalls_over_4ms` 0-7 (ratchet 7). A per-phase split of the asset ratchet was tried
   (warm 5) and reverted when warm read 7 on the 51st run.
5. **Both cold ratchets flake and may not be raised**: wallet cold 4/56 (7%), asset cold
   7/66 (11%). Both were derived from quiet subsets and sit below their own distributions.
   Recorded in the bench comments; the fix is to remove the marginal block.

Acceptance criteria: "16+ runs per phase without a gate flaking" is met for every **count**
gate and missed for the two cold **stall** ratchets, which cannot be fixed by anything this
issue is allowed to do.
