# Offscreen storybook benches as the wallet load-time gate

The wallet section, its send / receive / swap popups and the asset detail page are
gated on load benchmarks that run as offscreen storybook `qmlTests` against a
generated whale profile, not against a real device. The storybook test runner
already installs the same `BoostedIncubationController` the app installs, so async
incubation there is metered by a wall-clock timer rather than by frames: the
resulting timings are a low-noise, near-deterministic proxy for total incubation
work. We chose that repeatability over the truthfulness of a device measurement,
because a gate nobody can reproduce is a gate nobody enforces.

## Considered options

**A real-device gate.** Truthful, but a device cannot be given a whale profile,
device runs are not reproducible in CI, and calibrating a host↔device ratio needs
one account synced to both machines. Rejected as a gate; device runs stay a manual
sanity check.

**A `test/nim` bench** in the style of the existing model-layer benches. Those
drive an offscreen `QQmlApplicationEngine` and already have a stall probe and a TSV
convention, but they cannot reach the wallet *section* — there is no store stack —
and would need `WalletSectionMock` reimplemented in Nim. Left alone; they remain the
right tool for model-layer work.

## Consequences

- **Headline metric is time-to-content** — the top rung of the load staircase, chosen
  because it is the only stop line that cannot be improved by deferring work deeper.
  Time-to-skeleton and time-to-ready are recorded alongside as attribution.
- **Hard-gated:** instantiated object / delegate counts, and the count of GUI-thread
  stalls over the host threshold (1ms probe, 4ms gate). Both are deterministic.
- **Recorded, not gated:** the staircase timings and the max stall, kept as a checked-in
  TSV so an intentional change shows up as a reviewable diff rather than an edited
  magic number. CI therefore cannot catch a pure timing regression that changes no
  object counts.
- **Whale-only workload.** Gating at a single large profile keeps the suite fast and
  surfaces scaling failures, at the cost of hiding regressions that only affect small
  profiles; any fix that buys whale scaling with added indirection needs a manual
  sanity check at small N.
- **×10 is a convention, not a measurement.** Host numbers are recorded in host units;
  device acceptability is judged by multiplying by ten. Nothing is pre-multiplied.
- **Known blind spot:** anything visible only against a real render loop — most
  importantly incubation gentle-hints bracketing real open animations — is invisible
  to the gate and can even read as a regression there. Such work is verified by
  running the storybook on-screen, never gated.

## Amendment — pilot findings (issue 0001)

Two parts of the contract above did not survive first contact with the wallet section.

**A stop line of "all nested async loaders Ready" does not establish time-to-content.**
On the wallet section both nested loaders complete inside the outer incubation, so that
stop line lands 0.7ms after time-to-ready, at an instant when the assets list is 0x0 with
no realised rows. It is blind by an order of magnitude: raising the list's `cacheBuffer`
added 13607 objects and 82 rows while moving none of the specified metrics. Time-to-content
must therefore observe content the surface actually realised — a rendered row, a populated
field — and the benches run on to a settle point (first realised row, then a stable object
count). Each surface must verify its own stop line rather than inherit one.

**The headline is a warm load, not a cold one.** A cold load in a fresh test binary is
dominated by one-time process warm-up the app has already paid before a user reaches the
surface: the identical 9569-object graph builds in roughly a quarter of the time on a second
load in the same process. Each bench run therefore records both phases and the warm row is
the headline; the cold row is kept as a canary, since cold moving while warm holds still means
someone added first-use cost — which does not hurt the surface but does hurt app start-up.

Consequences: gates on the settled counts apply to both phases, and their equality across
phases is itself part of the claim. Counts taken at the loaders-Ready stop line are gated on
the cold phase only — on a warm load the layout pass races that stop line and the count is not
reproducible.

## Amendment 2 — the stall floor was the controller, and it moved (issue 0016)

Amendment 1 recorded that the 3.2ms host stall budget was "unreachable by construction". That
was true of the controller as it then was, and it is no longer the whole story.

The gentle cadence was paced off the screen's frame period — a bite of `frameperiod/4` once
per frame, 4ms every 16ms at 60Hz, **a 24% duty cycle**. Three quarters of every metered load
was the controller waiting for its next tick. That single constant was what made preemptibility
cost ~4x wall clock, what left a surface with 14ms of work reading 56ms, and what put this
project's two headline metrics — time-to-content and max stall — in direct opposition.

Neither quantity is a property of the refresh rate. The bite bounds how long a posted event
waits behind incubation; the interval bounds how much of the GUI thread incubation takes. Both
are absolute times. They are now constants: **a 2ms bite every 4ms, a 50% duty cycle.**

The consequence that matters for this ADR: **the two metrics stopped opposing each other.**
On the asset detail both improve in both phases, with an object graph identical run for run.
Both benched surfaces are inside their wall-clock budgets for the first time.

Two things this did NOT change, and which the next reader should not re-derive:

- **Halving the bite is not what did it.** A bite is a *lower* bound on the block it produces,
  because `incubateFor()` returns only after finishing the object it is midway through
  creating. Incubated blocks stayed in the same 4-7ms band whether the budget was 2ms or 4ms.
  Only the duty cycle moves the wall clock.
- **A stall floor still exists**, set by the largest single object the engine creates without
  returning, not by the bite budget. The 3.2ms target remains out of reach; what changed is
  that reaching for it no longer costs time-to-content.

`ui/StatusQ/tests/src/tst_incubationcadence.cpp` pins bite ≤ 2ms, duty ≥ 50% and interval ≤ 8ms,
each with its reason in the failure message, so the constants cannot be edited back without a
bench run.
