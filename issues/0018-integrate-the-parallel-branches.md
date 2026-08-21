# Integrate the four parallel branches and re-measure

Context: `docs/investigations/wallet-load-benchmarks.md`. This is the issue that has to happen
before any further optimisation, because right now **no measurement describes the product**.

## The situation

Four branches all forked from `de8dcfab68` and none contains the others' work:

| branch | carries | `objects_settled` on that branch |
|---|---|---|
| `feat/storybook-wallet-loader` | 0007 preemptible fill, 0011 attribution (no code) | 9166 |
| `perf/defer-wallet-detail-views` | 0002 detail-view deferral, 0012 asset-detail latches | (section) 8297 |
| `perf/statusq-leaf-cost` | 0008 scrollbar, 0009 tooltips, 0010 + 0013 ripples, 0014 tag rows | 7365 |
| `wt-wallet-profile` also holds | the asset-detail bench and its baseline | — |

Every one of them re-recorded the same `wallet-section-load.tsv` from its own starting point,
so the baselines conflict by construction, and **the counts do not compose additively**: they
overlap. 0014 removed tag scroll views from `StatusListItem`; 0009 removed tooltips from the
same items; 0007 wrapped `TokenDelegate` in a shell. Each was measured against a tree that
lacked the others.

## What to build

Merge them into one branch, in a stated order, then re-record every baseline against the
combined tree. The deliverable is a single trustworthy set of numbers plus a merged history —
not a new optimisation.

Suggested order, least to most entangled: `perf/statusq-leaf-cost` (StatusQ leaves) →
`feat/storybook-wallet-loader` (the delegate shell that sits on those leaves) →
`perf/defer-wallet-detail-views` (wallet views and the second bench). Deviate if the conflicts
say otherwise, and record what you actually did.

## Known interactions to check, not assume

- **0007's shell depends on `StatusListItem`'s 64px height floor**, and **0014 restructured
  `StatusListItem`**. If the floor moved, the shell's placeholder height is wrong and the list
  geometry will jump as rows fill. `tst_TokenDelegateShell` was written to gate exactly this —
  if it fails after the merge, it is doing its job; fix the shell, do not relax the test.
- 0009 (tooltips), 0013 (ripples) and 0014 (tag rows) all removed objects from the same
  `StatusListItem` instances. The per-row object count after merging is not the sum of the
  individual reductions.
- `wallet-section-load.tsv` will conflict in every merge. Resolve by **re-recording on the
  merged tree**, never by picking one side.
- The `stalls_over_8ms` ratchets differ per branch. After merging, set them from the observed
  maximum over at least eight runs per phase, as the workstream's rule requires. Ratchets only
  move down.

## What the merged numbers are for

The plan's budgets are under review (`issues/0016`): a surface with ~14ms of work reads ~56ms
because of the incubation controller's 24% duty cycle, so the current host budgets largely
measure cadence, not work. Do not re-litigate that here. Produce the honest combined numbers;
0016 decides what they should be compared against.

## Acceptance criteria

- [ ] All four branches merged into one, with the order recorded
- [ ] Every baseline TSV re-recorded on the merged tree, never resolved by picking a side
- [ ] Combined `objects_settled`, `objects_total`, per-row object count, `t_first_asset_row_ms`, `max_stall_ms` and `stalls_over_8ms` reported for both phases with spread
- [ ] Stated explicitly how the combined counts compare to the sum of the individual claims, and why they differ
- [ ] `tst_TokenDelegateShell` passes, or the shell is fixed if `StatusListItem`'s height floor moved
- [ ] Ratchets re-set from observed maxima over >= 8 runs per phase
- [ ] Full functional suite green against a baseline measured on the merged tree
- [ ] The working doc's headline numbers updated to the merged ones, with the per-branch numbers kept as history

## Blocked by

Nothing, but it should happen before further optimisation work lands on any of the four.
