# Make the assets list's first fill preemptible

Context: `docs/investigations/wallet-load-benchmarks.md` — sections "The warm block is the
assets list filling itself in one polish pass" and "What the next fix should attack".

## What to build

The wallet section's worst budget miss is a single 32-35ms non-preemptible GUI-thread block
on a warm load, against a 3.2ms host budget. It is `AssetsView`'s `ListView` building every
visible delegate synchronously inside one window-polish pass: `QQuickItemView` uses
`AsynchronousIfNested` for visible items, and by the time the list is first laid out
`mainViewLoader` is already Ready, so there is no enclosing incubation and delegate creation
degrades to synchronous. Cost is ~1.55ms and ~200 QObjects per realised row, linear in row
count with no fixed part; roughly three quarters of it is binding evaluation and completion,
~18% text shaping.

Nothing at section level can reach this: the block happens after every section-level deferral
has already completed. The one lever is the delegate itself — a cheap shell carrying the row's
geometry, with the expensive content behind a nested async `Loader`, so the synchronous refill
builds only shells and the rich part incubates in metered bites afterwards.

Unlike the benchmark work, this changes production QML. It is not a harness commit and does not
carry the storybook-only separability rule.

Two levers, and the issue wants both considered even if only the first is implemented:

1. **Shell + nested async content**, as above.
2. **Make the row cheaper** — ~200 QObjects for a token row is a lot. The `Text` item count per
   row and their sizing bindings are worth attacking on their own, and this lever helps whether
   or not the first one lands.

## Known hazards

- **The incubation controller's tick budget is 20ms**, well above the 3.2ms host stall target.
  Moving work out of the synchronous refill and into incubation may therefore trade one 35ms
  block for a train of bites that are individually still over budget. Measure what the
  incubated phase actually costs; if the floor turns out to be the controller's tick rather
  than the delegate, say so — that is a finding about the controller (PR #21921's territory),
  not a failure of this fix, and it must be reported rather than worked around.
- **A shell must know its own height** without its content, or the list's `contentHeight`,
  scrollbar and scroll position will jump as content fills in. If row height is content-derived
  today, that is the hard part of this issue.
- **Visual pop-in** is the obvious regression risk. The shell has to be good enough that filling
  in reads as loading rather than as breakage.
- Interaction with delegate recycling (`reuseItems`), sorting, and the existing per-tab skeletons
  needs checking — this list already sits behind a skeleton, so there are now two loading states
  and they must not fight.

## Acceptance criteria

- [ ] Warm `max_stall_ms` for the wallet section drops substantially from the ~34ms baseline, with before/after from the bench
- [ ] The `stalls_over_4ms` ratchet is lowered to match the new reality, not left at its old headroom
- [ ] Where the remaining stall floor comes from is stated with evidence — delegate, incubation tick, or something else
- [ ] `t_first_asset_row_ms` does not regress; if it does, the trade is quantified and justified
- [ ] The count gates are re-recorded with the new expected values, and the change in `objects_settled` is explained in the commit message
- [ ] Row height is stable across the shell-to-content transition — no visible jump in list geometry or scroll position
- [ ] The result is visually verified on-screen, not only in the offscreen bench
- [ ] The functional suite is unchanged against its recorded baseline
- [ ] Per-row cost after the change is recorded in the working doc, so the popups' picker lists can be priced from it

## Blocked by

- `issues/0006-attribute-the-warm-stall.md` (done)
