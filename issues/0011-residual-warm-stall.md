# Attribute and remove the residual warm stall

> **CLOSED 2026-08-20 — declined for good, on the third and final measurement.**
> Judged on today's tree (post-`issues/0017`), 52 runs, arms alternated. Three independent
> sufficient reasons: `stalls_over_8ms` does not reach 0-1 (warm max 3 vs arm A's 2, and cold's
> ratchet would have to go **up**); cold fails its existing ratchet on a third of runs; and
> `objects_settled` becomes four-valued, with a named cause — moving `RightTabView` out of the
> stack's incubator changes when the assets list acquires a `currentItem`, and Qt's
> `createHighlight` then allocates a plain `QQuickItem` plus its `QQuickListViewAttached`.
>
> It is also **more** expensive than when last declined, not less: median warm
> `t_first_asset_row` 54.7 -> 77.9ms, **+23.2ms / 1.42x** against the +13ms / 1.2x recorded after
> `issues/0016`, with 2 of 52 runs crossing the 100ms host budget. `issues/0017` shortened the
> load, so the same absolute tax is now a larger fraction of it.
>
> The revisit condition its previous verdict named has been tested and answered: it *is* the
> worst named block, and removing it still does not move the gate, because two blocks of the
> same size sit immediately behind it — the t=0 synchronous chrome build, and plain incubation
> overshoot with a V4 GC pass inside it. Neither is a `StackView` problem.
>
> **Do not re-open this on stall numbers alone.** It becomes worth landing only if PR #21921
> changes the controller's duty cycle so the 1.42x tax disappears — and even then the assets
> list's `currentItem` behaviour needs handling.

> **RE-OPENED 2026-08-20 (superseded by the above).** The attribution below is done and stands: the block is
> `QQuickStackView` incubating its `initialItem` inline through the stack's own incubator,
> uninterruptible by the enclosing incubation. The fix — passing an `Item` instance rather
> than a `Component`, which takes `QQuickStackElement`'s `fromObject` path — is implemented
> and proven twice, and was declined twice: at 4x cost under the old cadence, then at 1.2x
> after `issues/0016`, because it still moved median `t_first_asset_row` 59.0 -> 71.9ms.
>
> Its verdict named the condition for revisiting: that it becomes the worst warm block again.
> **It now is.** After `issues/0017` removed the post-`t_content` pass from the counter
> entirely (30 blocks over 8ms across 32 warm runs -> 0), every remaining warm block over
> 8ms belongs to this one, it is `max_stall_ms` on most warm runs at ~13ms, and it is the
> sole reason the `stalls_over_8ms` warm ratchet cannot come below 3.
>
> **Do not act on this before `issues/0024`.** That issue is investigating why a *settled*
> count went unstable on the asset-detail bench — the class of number this workstream trusts
> to decide questions exactly like this one. Re-deciding a marginal trade on numbers whose
> stability is under investigation is how we would get it wrong a third time.

Context: `docs/investigations/wallet-load-benchmarks.md`,
`docs/investigations/wallet-load-qml-profile.md`.

## What to build

After the assets list's first fill was made preemptible (`issues/0007`), the wallet section's
warm `max_stall_ms` fell from 31.7-42.6 to 17.2-26.3, and the refill block itself from ~34.7
to ~12ms. Something else is still blocking well above one incubation bite.

Attribute it, then remove it if the fix is proportionate. Same discipline as `issues/0006`:
evidence, not a plausible story. The GUI-thread stack sampler built for that investigation is
in `WalletLoadBenchProbe` behind `WALLET_BENCH_SAMPLE=1`.

Known context that should shape the search: the incubation controller's gentle bite is
~4ms at 60Hz and ~2ms at 120Hz, so any block materially above that is work the controller
never got the chance to chop. On this codebase the worst offenders have historically been
outside the incubated tree - adaptors and models built synchronously by handlers or store
singletons, and completion handlers doing heavy work on the GUI thread.

Note the standing constraint before setting any target: the 3.2ms host stall budget is
unreachable while the controller's gentle bite sits at ~4ms. That floor belongs to
PR #21921, not to this surface. Do not chase below it here.

## Acceptance criteria

- [ ] The residual block is attributed to specific work with sampler or profiler evidence
- [ ] If it is several blocks, each is sized separately
- [ ] Whether it is inside or outside incubation is stated explicitly
- [ ] A fix is either implemented with before/after numbers, or deliberately deferred with the reason recorded
- [ ] The `stalls_over_8ms` ratchet is lowered if the fix lowers the count
- [ ] Findings written into the working doc

## Blocked by

- `issues/0007-preemptible-assets-list-fill.md`
