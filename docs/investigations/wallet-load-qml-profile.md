# Wallet section warm load — qmlprofiler attribution

Companion to `wallet-load-benchmarks.md`. Where that doc measures the load staircase and
gates it, this one names the QML-engine work inside the window.

## How this was captured

Isolated worktree at `de8dcfab68` (`/Users/alexjbanca/Repos/wt-wallet-profile`), so the
run could not collide with concurrent work in the bench worktree.

```
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo <build-dir>      # see trap 1 below
Storybook WalletLoader stall-report -qmljsdebugger=port:49153,block
qmlprofiler -attach 127.0.0.1 -p 49153 --record on -o wallet-warm.qtd
```

Two build traps, both silent:

1. **`make storybook-build` defaults to `Release`, which does not define `QT_QML_DEBUG`.**
   `-qmljsdebugger` is then accepted and does nothing. `storybook/CMakeLists.txt` enables it
   for `Debug` or `RelWithDebInfo`. `RelWithDebInfo` is the right choice — `Debug` inflates
   every number and distorts the ranking.
2. **`storybook-configure` is an order-only prerequisite**, so it only runs when the build
   directory is absent. A `COMMON_CMAKE_BUILD_TYPE=` override on an existing build dir is
   silently ignored; force `cmake -DCMAKE_BUILD_TYPE=... <build-dir>` and check
   `CMakeCache.txt`. Same class of trap as the stale `CTestTestfile` noted in the other doc.

The storybook page argument drops the `Page` suffix: `WalletLoader`, not `WalletLoaderPage`.
Write the trace as `.qtd` (XML, parseable) rather than `.qzt` (binary).

## Window and caveats

The warm window is anchored on the probe's own last `firstRowWatcher` tick and runs back
181ms to `probe.begin()`. On-screen warm staircase for this run: `t_skeleton` 8.24ms,
`t_ready` 146.40ms, `t_first_asset_row` 180.05ms; 18 asset rows, 8376 objects.

- **Absolute times here are inflated** — RelWithDebInfo plus an attached profiler. The
  Release bench's warm figure is 119-159ms to the first row. Use these numbers for
  *ranking*, not as budget measurements.
- On-screen realises 18 rows against the offscreen bench's 26.
- qmlprofiler only sees QML-engine ranges. Of the 181ms window it accounts for ~107ms
  (Javascript 47.7, Creating 45.1, Binding 13.9); the remainder is C++, layout and
  scenegraph work it cannot see — including part of the synchronous list refill.
- **The probe perturbs its own measurement**: `firstRowWatcher` polls
  `countByObjectNamePrefix`, which walks the object tree, and costs 7.89ms of self time
  across 13 ticks in this window. Worth making cheaper before anyone reads on-screen
  staircase numbers closely.

## Top offenders in the warm window

| self ms | count | what | where |
|---|---|---|---|
| 6.17 | 106 | `Image` creation | `StatusImage.qml:26` |
| 5.73 | 125 | `resolveVisibility` | `StatusScrollBar.qml:30` |
| 4.76 | 183 | `ColorImage` creation | `StatusIcon.qml:5` |
| 3.96 | 496 | `Text` creation | `StatusBaseText.qml:28` |
| 2.19 | 50 | `thumbActive` binding | `StatusScrollBar.qml:47` |
| 1.11 | 115 | `ToolTip` creation | Universal style |

By file, the heaviest are `StatusBaseButton` (8.66ms, from `iconOnly` / `active` /
`iconSize` bindings evaluated ~20x each), `StatusScrollBar` (8.61ms, almost all JS),
`StatusIcon` (6.86), `StatusImage` (6.82), `StatusListItem` (6.71), `StatusBaseText` (4.72).

Two observations worth acting on:

- **Scrollbar visibility costs ~7.9ms of pure JS** in a section load. `resolveVisibility`
  runs 125 times and `thumbActive` 50 times for a handful of scrollbars.
- **496 `Text`, 183 `ColorImage`, 106 `Image` and 115 `ToolTip` objects** for a section
  showing 8 accounts and 18 asset rows. This is the same story the per-row cost tells from
  the other direction — the leaf components are numerous and each carries bindings.

## The eager detail views cost ~17ms of the warm window

Creation time attributable to the two eagerly-built detail views:

| ms | component |
|---|---|
| 10.59 | `AssetsDetailsHeader.qml` — of which a single `Repeater` at line 112 is **9.44ms** |
| 4.05 | `AssetsDetailView.qml` (incl. two `SortFilterProxyModel` at line 93, 2.90ms) |
| 1.38 | `InformationTileAssetDetails.qml` |
| 1.09 | `CollectibleDetailView` |
| **~17.1** | **total** |

This **prices `issues/0002`**, which the stall attribution left open. Deferring the detail
views does not move `max_stall_ms` — that was measured and is settled — but it does remove
~17ms of creation from a ~181ms window, roughly 10%, on top of the 13% object-graph
reduction already recorded. On the x10 convention that is ~170ms of device time for a fix
with no interaction risk.

The `Repeater` at `AssetsDetailsHeader.qml:112` is the single largest wallet-specific
creation in the whole warm window, and it is built for a view the user has not opened.

## What this does not say

It does not identify the 32-35ms synchronous refill block — that is C++ `QQuickItemView`
work, largely outside qmlprofiler's ranges, and it is already attributed by the stack
sampler in the other document. These two attributions are complementary: the sampler says
*where the GUI thread is stuck*, this says *what the engine is building*.

## Calibration: profiler milliseconds are not Release milliseconds

Measured after the fact, and it corrects how the numbers above should be read.

This capture attributed ~17.1ms of a ~181ms warm window to the two eagerly-built detail
views. `issues/0002` then deferred exactly those views and A/B'd the result on the Release
bench — ten runs per arm, arm order alternated between rounds. **The warm timings did not
move; the arms fully overlap.** What moved was the object graph: `objects_total` cold
4602 → 3344 (-27%), `objects_settled` 9569 → 8297 (-13%), with cold timings improving
modestly and consistently in sign.

The capture runs `RelWithDebInfo` with a profiler attached, which instruments every
`Creating` range. Creation-heavy work is therefore systematically over-weighted relative to
what a Release build actually pays.

So the ms figures in this document are sound for what they were used for — **ranking**, and
identifying *what* the engine is building — and unsound as a budget anyone can expect to
recover. Judge a fix on counts, evaluation counts, and a Release bench A/B with the arms
alternated and the spread reported. If the arms overlap, the honest answer is that they
overlap.

This does not weaken the findings themselves. Re-evaluating one expression twenty times per
load, or building 115 tooltips nobody has hovered, is a defect at any price. It does mean
the price is unknown until measured on the bench.
