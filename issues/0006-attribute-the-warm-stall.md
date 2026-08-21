# Attribute the warm-load stall block

Context: `docs/investigations/wallet-load-benchmarks.md`,
`docs/adr/0008-offscreen-storybook-benches-as-wallet-load-gate.md`.

## What to build

Nothing shippable. This is an attribution task: find out what the wallet section's
warm-load GUI-thread block actually is, and write the answer down.

The pilot bench (`issues/0001`) established that a warm load of the wallet section
takes 119-159ms host to the first assets row, and that inside that window there is a
single non-preemptible block of 32-35ms. The host stall budget is 3.2ms, so this is the
worst miss in the table by a wide margin — roughly 350ms of frozen UI on a low-end
device by the x10 convention, and unlike the ~350ms cold block it is **not** one-time
warm-up: it is paid on a load where the process has already built this exact section
once.

Nothing is known about what that block contains. It is the single most valuable unknown
in this workstream, because the stall budget is the metric that forces the architecture:
a ~3ms ceiling is below the cost of building any non-trivial QML subtree in one go, so
the fix for a stall is always to make the work preemptible, never to make it faster. We
cannot choose how to chop it up without knowing what it is.

The deliverable is an attribution written into the working doc: what the block is, where
it runs, and — stated plainly — whether the fix already scoped in `issues/0002`
(deferring the two eagerly-built detail views) touches it or not. That last point is
currently an assumption and it is driving the priority of the next slice.

Note the harness caveat: the block is measured offscreen, where incubation is metered by
a wall-clock timer rather than by frames. If attribution requires an on-screen run, use
one and say so — `WalletLoaderPage` has a `profile-exit` argument mode for attaching a
profiler on clean exit. If the block does not reproduce on-screen, that is itself a
finding worth more than a guess.

## Acceptance criteria

- [ ] The warm block is attributed to specific work, with evidence, not with a plausible story
- [ ] The attribution states where the work runs and what triggers it
- [ ] It is stated explicitly whether deferring the detail views would move this block
- [ ] If the block is several things rather than one, the breakdown is given with each part sized
- [ ] Any divergence between the offscreen bench and an on-screen run is reported
- [ ] Findings are written into the working doc, in the established vocabulary
- [ ] A recommendation is given for what the next fix should attack, and why
- [ ] No production code is changed and no optimisation is attempted

## Blocked by

- `issues/0001-wallet-section-load-bench.md` (done)
