# The incubation duty cycle makes preemptibility cost 4x

Context: `docs/investigations/wallet-load-benchmarks.md`, section "The residual warm block is
`StackView.initialItem`". This is the constraint blocking two other issues; it is filed so it
stops being rediscovered.

## The problem

The boosted incubation controller runs a gentle bite of `gentleIntervalMs / 4` — **4ms of
work every 17ms at 60Hz, a 24% duty cycle.** Work that is metered instead of run in one burst
therefore takes roughly **four times as long in wall clock**.

That is not a detail. It puts two of this workstream's metrics in direct opposition:

- Making a block preemptible is what the stall budget asks for.
- Doing so multiplies that work's contribution to time-to-content by ~4.

Measured, not theorised (`issues/0011`, Release A/B, arms alternated, three rounds each).
Moving `WalletLayout`'s centre panel from a `Component` to an `Item` instance removes the
last un-chopped block on the surface completely — and costs more than it saves:

| warm | baseline | preemptible |
|---|---|---|
| `max_stall_ms` | 19.6 / 24.0 / 21.5 | 12.5 / 13.9 / 14.9 |
| `stalls_over_8ms` | 2 / 3 / 2 | 1 / 2 / 1 |
| `t_first_asset_row_ms` (headline) | 117.9 / 136.9 / 149.0 | **166.0 / 169.0 / 203.5** |

The arms do not overlap on either metric. ~17ms of creation becomes ~70ms of staircase.

The same constant is why the **3.2ms host stall budget is unreachable by construction** — a
bite is the smallest unit the GUI thread can be interrupted between, and it is larger than
the budget.

## A second, independent measurement of the same constraint

`issues/0012` reached the same place from the other end. On the asset detail surface, a warm
open reads ~56ms of `t_content` and contains **~14ms of actual GUI-thread work**:

```
warm open - GUI-thread blocks over 4ms          t_ready 56.28
     18.50 ->   23.78    5.28   \
     35.96 ->   40.77    4.81    |  three gentle bites, ~14ms of work
     52.01 ->   56.29    4.28   /
     56.71 ->   65.71    9.00      post-Ready layout + render
```

**The other ~42ms is the controller waiting for its next tick.** Nothing in that view blocks;
the surface is already fully preemptible. It also found a second cost that belongs here:

- **A warm open starts from an idle controller.** After a close, `incubatingObjectCount()`
  is 0, so the controller has dropped to its 128ms idle cadence. The next request takes the
  fast path (`incubatingObjectCountChanged` → `restart(m_gentleIntervalMs)`), which schedules
  the first bite **a full gentle interval later** — every warm timeline has zero blocks for
  the first ~17-19ms. A user-initiated open therefore pays ~17ms of pure latency before any
  work starts. That is a third lever, and probably the cheapest of the three.
- Because the window is quantised, a surface whose work sits near a bite boundary reads
  **bistable** between two values one interval apart. The asset detail's original
  "second open is slower" anomaly was exactly this, not accumulation — it was the metric's
  bistability, not the code's.

### This makes the plan's host budgets suspect

The 40ms popup-class and 100ms section-class host budgets were set by dividing device targets
by ten. But a surface with 14ms of work reads 56ms, so those budgets are largely measuring
**incubation cadence, not work**, and are unreachable for anything needing more than ~2 bites.
Whatever this issue concludes, the budget table needs restating in terms of something the
surface actually controls.

## What to investigate

Three candidate levers, and they are not exclusive:

1. **The controller's budget itself** — PR #21921's territory. A shorter bite at a higher
   frequency changes both the stall floor and the duty cycle. What the right numbers are, and
   whether they can differ between a gentle window and an idle one, is the question.
2. **The idle-cadence wake latency** — see above; a user-initiated open waits a full gentle interval before its first bite. Whether the first bite after an idle period can be scheduled immediately is a self-contained question.
3. **The gentle hint's lifetime** — currently `StatusSectionLayout` pushes a gentle hint for
   the whole panel-switch animation. Once the skeleton is up and the animation has settled,
   there may be no reason to stay gentle: the user is looking at a placeholder, not at motion
   that a long bite would stutter. Popping the hint earlier would let incubation run at full
   speed for the part of the load nobody is watching. **This is testable in our own code**,
   unlike lever 1.

Whatever the answer, it should be measured on the wallet section bench, which is now
sensitive to exactly this trade — `max_stall_ms` and `t_first_asset_row_ms` move in opposite
directions, so any proposal must report both.

## What this unblocks

- The `StackView.initialItem` fix in `issues/0011` — implemented, proven, deliberately not
  landed. It becomes free the moment the duty cycle changes.
- Any future "make it preemptible" fix on any surface, which today all carry the same 4x tax.
- The 3.2ms stall budget in the plan, which is currently unreachable and known to be.

## Acceptance criteria

- [x] The duty-cycle trade is quantified: 2x2 over bite x duty on the wallet bench. **The
      duty cycle is the wall clock; the bite is not the stall floor** - a bite is a lower
      bound on its block, so halving it left every incubated block in the same 4-7ms band.
- [x] The gentle-hint lifetime question is answered with a measurement - and with a
      correction: on desktop no gentle hint is ever held (`StatusSectionLayout` emits its
      switch pair back-to-back in landscape). Shortening the equivalent window buys ~20ms
      and costs ~25ms of `max_stall`; the boosted phase's 20ms bite is the real cost.
- [x] Measured on the asset detail as well: `t_content` 65.1 -> 27.2 warm, 50.3 -> 34.7
      cold, `max_stall` down in both phases.
- [x] The stall budget is restated as three budgets (incubated block, block outside
      incubation, work), replacing the single unreachable number.
- [x] Findings in `docs/investigations/wallet-load-benchmarks.md`, "The gentle cadence".

Landed: `d00dbf20c4` (controller), `0af7115b47` (baselines, ratchet, harness hook).
Left open: the `objects_total` cold gate, which the faster load made non-deterministic,
and the `issues/0011` fix, which got cheaper (+48ms -> +13ms) but no longer buys anything
on the gated metrics and destabilises `objects_settled`.

## Blocked by

None - but coordinate with PR #21921, which owns the controller.
