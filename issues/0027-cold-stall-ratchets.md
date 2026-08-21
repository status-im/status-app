# Cold stall ratchets flake and cannot be raised — demote them

Context: `docs/investigations/wallet-load-benchmarks.md`, "Ratchets re-derived: none can come
down, and both cold ratchets flake".

## The problem

Re-derived over 56 wallet runs and 66 asset-detail runs on a quiet-ish machine:

| bench | phase | metric | observed | ratchet | verdict |
|---|---|---|---|---|---|
| wallet | warm | `stalls_over_8ms` | 0 - 3 | 3 | holds |
| wallet | cold | `stalls_over_8ms` | 2 - 4 | 3 | **fails 7% of runs** |
| asset detail | warm | `stalls_over_4ms` | 0 - 7 | 7 | holds |
| asset detail | cold | `stalls_over_4ms` | 2 - 9 | 7 | **fails 11% of runs** |

Both cold ratchets sit below their own distributions. The workstream's rule is that a ratchet
never goes up, so they cannot be corrected in place; and a gate failing 7-11% of runs is worse
than no gate, because it trains everyone to rerun.

The cause is understood, not mysterious. After the ~365ms one-time compile block and the ~40ms
incubation block, a cold load has a cluster of 4-12ms blocks straddling the threshold, and
whether three or four of them cross is decided by scheduling noise.

## What to build

Demote **both cold stall counters to recorded, ungated**, keeping the warm ones gated.

The justification is not "they flake" — it is that they were the wrong thing to gate. This
workstream established early that **the cold phase measures one-time process warm-up, which is
a canary and not a gate**: cold is dominated by first-use cost the app has already paid before
a user reaches the surface. `objects_total` was demoted for the analogous reason in
`issues/0022` — it measured a teardown race rather than a construction invariant. A cold stall
count measures the compile-and-first-use profile of a fresh test binary, which is not a
property of the surface under test.

Warm stall counts stay gated. They are the ones that describe what a user experiences, they
hold at their current values, and they are what any future fix should move.

Keep both cold counters in the TSV as recorded columns — cold moving while warm holds still
means someone added first-use cost, which is exactly the canary that has been useful before.

Two things already tried, recorded so they are not repeated:

- **A per-phase split of the asset-detail ratchet.** Over the first fifty runs warm read 1-5,
  supporting a warm ratchet of 5 against cold's 7. It read 7 on the fifty-first. Reverted.
- Re-deriving on a quieter machine. The runs above already ran with only a ~60% -of-a-core
  background load, which inflates counts rather than deflating them, so the observed maxima are
  conservative upper bounds.

**The alternative is to remove the marginal blocks rather than move the line** — that is the
honest structural fix, and it is real work on the cold path nobody experiences. Say so if you
disagree with the demotion, but do not raise a ratchet.

## Acceptance criteria

- [ ] Both cold stall counters demoted to recorded, with the reasoning in the commit message
- [ ] Both remain in the TSV as recorded columns
- [ ] Warm stall gates unchanged and still passing
- [ ] Both benches run 30+ times per phase with no gate flaking
- [ ] The ratchet comments in both benches updated so the next reader does not re-derive this

## Blocked by

None.
