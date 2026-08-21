# Verify the incubation cadence change outside the wallet

Context: `docs/investigations/wallet-load-benchmarks.md`, "The gentle cadence";
`docs/adr/0008-...md` amendment 2.

## What to build

`issues/0016` changed `BoostedIncubationController`'s gentle cadence from a bite of
`frameperiod/4` once per frame (**24% duty cycle**) to a fixed **2ms bite every 4ms (50%)**.
It is the highest-blast-radius change in this workstream: the controller paces *every*
asynchronous `Loader` and delegate incubation in the app, and it was benched on two surfaces,
both in the wallet.

Incubation now takes **twice as much GUI thread** as before. On a surface where the user is
waiting for content that is a straight win — proven, both metrics improved. The open question
is what it does where the user is **not** waiting: during scrolling, during an open animation,
during chat load, anywhere something else wants the GUI thread while incubation is running.

That is precisely the case the gentle window exists for, and it is the case the wallet benches
do not cover.

## What to measure

Storybook has the surfaces: `ChatLoaderPage`, `CommunityChatLoaderPage`, and the wallet pages.
There are existing section benches and tests to borrow shape from — `tst_ChatLoaderSection`,
the chat virtualization tests, and the wallet load bench and its probe
(`WalletLoadBenchProbe`, stall probe, staircase stamps, `WALLET_BENCH_SAMPLE=1` sampler).

At minimum, A/B the old cadence against the new one (arms alternated, spread reported) on:

1. **A chat section load** — a second heavy surface, to confirm the wallet result generalises.
2. **Interaction during incubation** — the case the wallet benches structurally cannot show:
   scroll a long list, or run an open animation, *while* a section incubates, and measure
   whether frames are worse than they were at 24%. This is the finding that would matter.

If the honest answer is "no measurable regression anywhere we can reach", say that plainly.
The point is to have looked, with numbers, before an engine-level constant ships.

## Constraints already established

- **Anything inside incubation must be attributed on-screen, not offscreen** — incubation is
  chopped differently under the two regimes, and this issue is entirely about incubation.
  `WalletLoaderPage` has a `stall-report` mode; add an equivalent where you need one.
- **A bite is a lower bound on the block it produces** — `incubateFor()` returns only after
  finishing the object it is midway through. Blocks stayed 4-7ms at either budget. Do not
  expect the bite size to bound anything.
- Watch for bistability near a bite boundary and for machine load; run quiet, report spread,
  and if arms overlap, say they overlap.
- `tst_incubationcadence.cpp` pins bite ≤ 2ms, duty ≥ 50%, interval ≤ 8ms. If your findings
  argue for different constants, change the test's expectations *and* its stated reasons — do
  not leave the test asserting a rationale the numbers no longer support.

## Acceptance criteria

- [ ] A second, non-wallet surface A/B'd old vs new cadence, both phases, spread reported
- [ ] The interaction-during-incubation case measured, with the method described
- [ ] A clear statement of whether the new cadence regresses anything outside the wallet
- [ ] If it does, a proposed constant that holds both cases, with the trade quantified
- [ ] `tst_incubationcadence.cpp` still passes, or is updated with reasons that match the data
- [ ] Storybook functional suite unchanged against its recorded baseline
- [ ] Findings recorded in the working doc

## Blocked by

- `issues/0016` (done)
