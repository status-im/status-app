# Asset detail load is 1.4-3x over budget

Context: `docs/investigations/wallet-load-benchmarks.md`,
`docs/investigations/wallet-load-qml-profile.md`, and the bench added by `issues/0002`
(`storybook/benches/tst_AssetDetailLoadBench.qml`, baseline
`storybook/benches/baselines/asset-detail-load.tsv`).

## What to build

Deferring the detail views turned asset detail into a real navigation surface with a real
load time, and the first measurement puts it over budget:

| | measured (host ms) | budget |
|---|---|---|
| `t_content`, first open | 56.9 - 67.3 | 40 |
| `t_content`, second open | 71.3 - 125.5 | 40 |
| `max_stall_ms` | 6.5 - 14.1 | see note |
| `objects_settled` | 1146 | — |

Bring it under the popup-class budget of 400ms device / 40ms host, or establish with
evidence what the floor actually is and why.

**Start with the anomaly, not the total.** The second open is *slower* than the first, and
by a wide and widening margin. That is backwards — a second open has the types, the
component and the engine warm, and should be the cheap one. Something is accumulating across
the unload/reload cycle, or the teardown is leaving work behind for the next open to pay.
Find that before optimising anything else; it is both the largest single number on the table
and the one most likely to be a defect rather than a cost.

After that, the ordinary levers, in the order the workstream has found them to pay:

1. **Defer subtrees that are not visible on open** — the same latch pattern that worked on
   the section and the popups. The chart is already behind a `Loader`; the header's per-chain
   tags, the information tiles and the activity area are the candidates.
2. **Check for a synchronous list fill.** The lesson from `issues/0007` generalises: any
   `ListView` or `Repeater` first laid out after its enclosing `Loader` is already Ready
   builds every visible item synchronously, because `QQuickItemView` uses
   `AsynchronousIfNested` and there is no enclosing incubation left. `max_stall_ms` of
   6.5-14.1ms is above the incubation controller's largest observed bite (6.42ms), so
   something here is not being chopped. The header's chain-tag `Repeater` and the two
   `SortFilterProxyModel` instances are the obvious suspects.
3. **Reduce per-item cost** if the counts justify it.

## Known constraints — read before setting any target

- **The 3.2ms host stall budget is unreachable by construction** while the incubation
  controller's gentle bite is ~4ms. That floor belongs to PR #21921. Do not chase below it.
- **qmlprofiler milliseconds are not Release milliseconds.** The capture over-attributes
  object creation. Use it to find *what* is being built; prove any time claim with a Release
  bench A/B, multiple runs per arm, arm order alternated, spread reported. If the arms
  overlap, say so.
- The bench's timings are recorded, not gated — deliberately, because a gate nobody can pass
  is a disabled gate. If your work brings the surface under budget, that is the moment to
  propose gating it.
- Counts (`objects_settled`, `chain_tags`, `information_tiles`) ARE gated and exact. They
  will fail when you change the graph; re-record and explain the delta. Never loosen a gate
  to make it pass.

## Acceptance criteria

- [ ] The second-open-slower-than-first anomaly is explained with evidence, and fixed if it is a defect
- [ ] `t_content` for both first and second open is reported before/after from a Release bench A/B with the spread
- [ ] Whether the surface reaches the 40ms host budget is stated plainly; if it does not, the floor is named with evidence
- [ ] Any block above one incubation bite is attributed — inside or outside incubation, stated explicitly
- [ ] Count gates re-recorded with deltas explained in the commit message
- [ ] Behaviour unchanged: opening a token detail, switching tokens, navigating back, and the chart still work; verified on-screen
- [ ] Storybook functional suite unchanged against its recorded baseline
- [ ] Findings recorded in the working doc

## Blocked by

- `issues/0002-defer-wallet-detail-views.md` (done)
