# Verify the wallet load work on a real low-end device

Context: the whole of `docs/investigations/wallet-load-benchmarks.md`, and
`docs/adr/0008-...md` with both amendments.

## What to build

Every number in this workstream is a macOS host number. The device target was handled by an
**x10 acceptance convention adopted deliberately as a heuristic and never calibrated** — the
original plan had a calibration step, which was cut on purpose to keep moving. That was the
right call at the time. The work is now done, and it has never been measured against the thing
it was for.

Two questions, in order of importance:

### 1. Does the incubation cadence change hold on device?

`issues/0016` changed `BoostedIncubationController`'s gentle cadence from `frameperiod/4` per
frame to a fixed **2ms bite every 4ms**. `issues/0023` verified it does not regress interaction
on desktop — chat section reproduces the wallet result, and the interaction case beats the old
60Hz cadence everywhere. But it named what it could not reach, and the gaps are exactly the
device:

- **Mobile portrait is the only place a gentle hint is genuinely held in the product.** On
  landscape desktop the panel-switch push/pop nets to zero, so the gentle window barely exists
  there. The portrait panel slide is the real case, and it was *simulated* by holding a hint,
  not run on hardware.
- **A real 60Hz display.** The `4/17` arm was reproduced by setting constants, not by plugging
  in a 60Hz monitor. Every run was on a 120Hz panel.
- **Touch/flick input.** The desktop scroll was a `NumberAnimation`, not a `Flickable` under a
  real pointer grab. Input-event latency under a drag is unmeasured.
- **The boosted phase** — untouched throughout, and still the largest single stall source
  anyone has measured on this controller.

A slower CPU changes the arithmetic: a 2ms bite is a budget, but a bite is a *lower* bound on
the block it produces, because `incubateFor()` returns only after finishing the object it is
midway through. On a device where a single object takes longer than 2ms to create, the bite
budget stops bounding anything and the duty cycle is whatever the objects make it.

### 2. What is the real host-to-device ratio?

Measure the wallet section's load staircase on device and against the same profile on host, and
report **per-rung ratios** rather than one scalar. Instantiation, JS evaluation and image decode
do not scale by the same factor, and anything disk-cache bound can be far worse than 10x.

The point is not to produce a prettier number. It is to find out whether the x10 convention
under-or-over-stated the win, and therefore whether the budgets in the plan mean anything.

## What "done" looks like

A statement of whether the shipped behaviour on a real low-end Android matches what the host
benches predicted, with numbers, plus a corrected multiplier if the data supports one.

If the cadence change regresses anything on device — particularly portrait panel slides — that
is the finding, and it is worth more than every host number in this document. Say it plainly.

## Acceptance criteria

- [ ] The reference device is named exactly, model and all, and recorded in the working doc
- [ ] Wallet section staircase measured on device, per rung, against the same profile on host
- [ ] Per-rung host-to-device ratios reported, not a single scalar
- [ ] The cadence change A/B'd on device, including a portrait panel slide with a real gentle hint
- [ ] Touch/flick interaction during incubation observed on device
- [ ] A plain statement of whether the x10 convention held, with a corrected figure if not
- [ ] Findings recorded in the working doc; the plan's budgets restated if the data demands it

## Blocked by

- `issues/0016` and `issues/0023` (both done). Coordinate with PR #21921, which owns the controller
  and whose territory the portrait and boosted-phase cases are.
