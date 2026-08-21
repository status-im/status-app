# The `objects_total` cold gate lost its premise

Context: `docs/investigations/wallet-load-benchmarks.md`, "Two gates flake now, and neither was
adjusted". Small, but it should be decided rather than left flaking.

## What to build

`objects_total` is the instantiation count taken at the loaders-Ready stop line. It was gated
on the **cold phase only**, because on a warm load the layout pass races that stop line and the
count is not reproducible — cold was slow enough to be immune.

After `issues/0016` halved the wall clock, cold is no longer slow enough either: it reads 2813
or 2942, 2 runs in 16. The gate's premise is gone.

Decide, and record why:

- gate the documented pair of values, or
- drop `objects_total` from the gates in favour of `objects_settled`, which stayed
  **bit-identical at 6022 across all 16 runs of both arms** and is the count the workstream
  actually reasons about.

The second is the obvious answer unless `objects_total` is measuring something `objects_settled`
does not. Establish that before deleting it — it is the only column that describes the graph at
the moment the loaders report Ready, which is a real thing to know even if it is a poor gate.
Keep it as a recorded column either way.

## Acceptance criteria

- [ ] `objects_total` is either gated deterministically or demoted to recorded-only, with the reason in the commit message
- [ ] If demoted, it stays in the TSV as a recorded column
- [ ] The bench runs at least 16 times per phase without the gate flaking
- [ ] Storybook functional suite unchanged against its recorded baseline

## Blocked by

- `issues/0016` (done)
