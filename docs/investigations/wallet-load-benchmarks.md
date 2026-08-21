# Wallet load benchmarks

Working doc for benchmarking and improving the load time of the wallet section, its
popups and the asset detail page. Vocabulary in `CONTEXT.md` ("Surface load
benchmarking"); measurement contract in `docs/adr/0008-offscreen-storybook-benches-as-wallet-load-gate.md`.

## Metrics

| | What | Role |
|---|---|---|
| **A** load staircase — `t_skeleton`, `t_ready`, `t_content` | wall-clock from surface request | **headline** (`t_content`), recorded |
| **B** stall probe | 1ms timer; counts of gaps > 4ms and > 8ms, plus max gap | `> 8ms` count **hard-gated**; `> 4ms` count and max recorded |
| **C** instantiation counts | QObjects / delegates created in the window | **hard-gated** |

Stop lines:

| Surface | Start | `t_content` |
|---|---|---|
| Wallet section | `WalletLoader.active = true` | `WalletLoader` Ready **and** `walletAccountsListViewLoader` Ready **and** `mainViewLoader` Ready |
| Send / receive / swap popup | handler call (`openSend()`, `launchSwap()`, …) | `opened` **and** primary interactive control present |
| Asset detail | navigation into stack index 2 | detail view Ready (only meaningful once deferred — see below) |

## Budgets

Host budgets are device targets ÷ 10. Numbers are always recorded in **host units**.

| | Device target | Host budget |
|---|---|---|
| section `t_skeleton` | 16ms | 1.6ms |
| section `t_content` | 1s | 100ms |
| popup `t_content` | 400ms | 40ms |
| asset detail `t_content` | 400ms | 40ms |
| longest GUI-thread stall | 32ms | see the restatement below |

The stall budget is the architecture-forcing one: a host ceiling below the cost of
instantiating any non-trivial QML subtree in one go, so the goal is not faster work but
**preemptible** work — chunked through incubation.

### The stall budget, restated (`issues/0016`)

The 3.2ms figure was a device target divided by ten, and it was never reachable: it is
smaller than one incubation bite, and a bite is the smallest unit the GUI thread can be
interrupted between. Worse, a bite is a *lower* bound on the block it produces —
`incubateFor(n)` runs to the end of whatever object it is midway through creating, so the
block is `bite + overshoot` and the overshoot dominates. Measured across both benched
surfaces: halving the bite from 4ms to 2ms left every incubated block in the 4 – 7ms band.

So one number cannot be a stall budget. **Three separate things are budgeted, and a
surface controls only two of them:**

| | what the surface controls | host budget | why that number |
|---|---|---|---|
| longest **incubated** block | that no subtree is uninterruptible — no `Component`-into-`StackView`, no `AsynchronousIfNested` refill without a shell | **8ms** | 2ms bite + the largest uninterruptible sub-creation; measured 4 – 7ms on both surfaces once every subtree is preemptible |
| longest block **outside** incubation — the post-`t_ready` layout + first refill | the per-row delegate cost × realised rows | **section 18ms, detail 12ms** | this pass runs after every deferral has completed; incubation cannot chop it and the controller's budget does not apply. A shell delegate (`issues/0007`) is the only lever |
| GUI-thread **work** in the window (the blocks summed) | objects and bindings built | **section 40ms, detail 15ms** | wall clock ≈ one gentle interval + 2 × work + the post-ready pass, at the 50% gentle duty cycle |

`stalls_over_8ms` stays the gated counter and now means exactly one thing: **blocks the
controller failed to chop, plus the post-ready pass.** On the section a clean warm run
reads **1** — that one is the post-`t_content` pass, which is structurally above 8ms until
the accounts list gets a shell delegate (`issues/0017`).

`t_content` and `t_first_asset_row` stay recorded against the wall-clock budgets above,
and **both benched surfaces now meet them**: section `t_first_asset_row` 55 – 79ms against
100, asset detail `t_content` 22 – 37ms warm / 34 – 37ms cold against 40. Neither got there
by building less — see the cadence section.

### Amendment: the 3.2ms host stall target is unreachable by construction

Superseded by "The stall budget, restated" above (`issues/0016`), which replaces the
single number with three. Kept because the reasoning below is still why 3.2ms was wrong,
and because the display-dependence argument is what killed the 4ms gate threshold.

The incubation controller chunked work into bites of `gentleIntervalMs / 4`, where the
interval followed the primary screen's frame period. That was **~4ms on a 60Hz screen —
which is what the offscreen bench process reports — and ~2ms at 120Hz.** A bite is
the smallest unit of incubated work the GUI thread can be interrupted between, so
**no amount of surface-level work can produce a stall shorter than the controller's
bite.** A perfectly preemptible surface on a 60Hz display still showed 4–6ms blocks.
The bite is now a constant 2ms and no longer follows the screen (`issues/0016`), and the
measured floor did not move with it — the overshoot past the budget, not the budget, is
what sets a block.

Two consequences:

- **3.2ms is a controller-level target, not a surface-level one.** It belongs to
  PR #21921 (the controller's budget), not to any wallet surface. A surface has met
  its obligation when every remaining block *is* one bite.
- **The gate threshold cannot be 4ms.** It sat exactly on the bite, so every metered
  bite scored as a stall and making work preemptible *raised* the count — the metric
  was anti-correlated with the thing it was gating, and it moved with the display's
  refresh rate. A threshold that changes when you plug in a monitor is not a
  threshold. The gate is now `stalls_over_8ms`, which counts **blocks the controller
  failed to chop**; `stalls_over_4ms` stays recorded, ungated, so re-gating on it
  costs no history once the controller's budget moves. See "The stall count went up
  when work became preemptible" below for the measurement that forced this.

## Harness

- **Gate:** storybook `qmlTests`, offscreen, whale profile (`WalletSectionMock` defaults:
  8 accounts / 2000 asset groups / 500 collectibles / 20 saved / 5 communities).
  `tst_WalletSectionPopups.qml` already opens send, swap, receive and buy against a full
  profile; `WalletLoaderPage.qml` covers the section.
- **Calibration / manual verification:** the storybook run on-screen (`WalletLoaderPage`
  already has a `profile-exit` mode for attaching `qmlprofiler`). Required for anything
  frame-coupled.
- **Baselines:** checked-in TSV; a compare step warns past ~20% and a human adjudicates.

## Improvement toolkit, in priority order

For **popups**, skeletons are *not* the first tool. Prior work on this code took ~1s off
send-modal open with none of it from skeletons.

1. **Defer-until-needed latches** on non-visible subtrees — inactive tabs, sticky headers,
   collapsed sections, closed dropdown contents.
2. **Gentle incubation hints** bracketing the open transition (`IncubationHints.pushGentle`/
   `popGentle`). Today only `StatusSectionLayout` does this. Manually verified only.
3. **Precompile** the modal URL when the section becomes ready, as `QmlCompiler.precompile`
   already does for sections.
4. **Skeleton + async loader** only where the primary content is a long list that cannot be
   made cheap. For modals a skeleton risks dialog resize on swap, adds flicker when it lives
   shorter than the open animation, and disturbs initial focus.

For the **section**, skeleton + async loader stays the main mechanism — it is already in
place via `WalletLoader` + `PanelSwapGate`.

## Plan

1. **Pilot — wallet section, end to end.** Bench, record baseline, apply fixes, confirm the
   bench moves. Validates the harness before it is replicated.
2. **Defer the detail views.** `AssetsDetailView` (572 lines) and the collectible detail view
   are eager children of `RightTabView`'s `StackLayout`, so they are built on every section
   load and hidden. Put both behind async `Loader`s keyed on `stack.currentIndex`; this is a
   section-load fix, and it is what *creates* an asset-detail navigation surface worth
   benching. Grep for the same pattern in other `StackLayout` / `SwipeView` children.
   Measured (`issues/0006`): worth -1272 objects and ~25ms of cold time-to-ready, but it
   does **not** move the stall block - see "Deferring the detail views does not move the
   warm block".
3. **Instrument the remaining surfaces** in one pass, record baselines.
4. **Fix in measured-cost order**, not in list order.

## Landing

The machinery under measurement is not on master — `WalletAccountsSkeleton`,
`incubationhints.h` and the skeleton-bearing `WalletLoader` live in the 10-PR perf stack
(#21890 → #21975), with `feat/storybook-wallet-loader` unpushed on top. Work stacks on
`feat/storybook-wallet-loader`, under a separability rule:

- harness commits touch only `storybook/` and test files, so they cherry-pick onto master
  once the stack lands;
- each optimisation is its own revertible commit with before/after in the message;
- baselines live in-repo as data, so a rebase that shifts numbers shows up as a diff.

No CI gate until the stack merges; until then the gate is a local `make` target.

## Baselines

Wallet section, whale profile (8 accounts / 2000 asset groups / 500 collectibles),
offscreen storybook, macOS host. Five consecutive runs of `make run-storybook-bench`,
each recording two rows. Raw rows in
`storybook/benches/baselines/wallet-section-load.tsv`.

**Warm is the headline.** Each run loads the section, tears it down and loads it
again in the same process; the second load is the warm one. See "Warm is the
headline, cold is the canary" below for why.

Current baseline: the **merged tree with the `issues/0016` incubation cadence**,
sixteen runs per phase, machine at load average 3.9 - 4.5. The two history
columns are the trees it replaces - the merged tree before the cadence change
(`issues/0018`, sixteen runs) and post-`issues/0007`.

| | warm (headline) | cold | merged, pre-0016 warm | post-0007 warm | role |
|---|---|---|---|---|---|
| `t_skeleton_ms` | 3.7 - 13.2 | 180.3 - 184.3 | 3.2 - 12.9 | 3.5 - 14.8 | recorded (budget 1.6) |
| `t_ready_ms` | 39.0 - 55.0 | 419.8 - 456.0 | 73.7 - 125.2 | 77.8 - 116.1 | recorded |
| `t_content_ms` | 39.4 - 55.4 | 420.1 - 456.3 | 74.1 - 125.9 | 78.6 - 117.0 | recorded (blind, see below) |
| `t_first_asset_row_ms` | 55.0 - 78.8 | 440.6 - 476.3 | 92.9 - 148.4 | 98.7 - 140.5 | **headline**, recorded (budget 100) |
| `stalls_over_8ms` | 1 - 3 | 3 flat | 1 - 3 | 2 - 4 | **gated** (warm <= 3, cold <= 3) - see the flake note |
| `stalls_over_4ms` | 4 - 9 | 3 - 8 | 9 - 15 | 12 - 16 | recorded, ungated |
| `max_stall_ms` | 10.3 - 16.7 | 342.1 - 348.5 | 8.9 - 14.9 | 17.2 - 32.3 | recorded |
| `objects_total` (at `t_content`) | 2813 / 2942 | 2813 / 2942 | 2813 / 2942 warm, 2813 cold | 4602 / 4731 | gated cold only - see the flake note |
| `objects_settled` | 6022 | 6022 | 6022 | 9166 | gated, exact, both phases |
| `account_delegates` | 8 | 8 | 8 | 8 | gated, exact, both phases |
| `asset_delegates` (at `t_content`) | 0 | 0 | 0 | 0 | gated, exact, both phases |
| `asset_delegates_settled` | 26 | 26 | 26 | 26 | gated, exact, both phases |
| objects per realised assets row | 202 | 202 | 202 | 279 | recorded |

**One gate now flakes on this tree, because the load got faster; it was not touched.**
`objects_total` cold reads 2813 or 2942 (1 of these 16 runs) - the cold layout pass now
races the loaders-Ready stop line exactly as the warm one always has, so the phase
distinction that made this gate cold-only no longer holds. `stalls_over_8ms` warm stayed
inside its ratchet across these sixteen runs at load 3.8 - 4.9, but reached 4 on 1 of 16
at load ~4.5 and 2 of 16 at load ~6 in earlier sets; both are read in full under "The
gentle cadence" below. The fix for either is a decision about the gate, not about the
controller, and is deliberately left open.

Noise floor: every settled count is bit-identical across every phase run, in both
phases - the section builds the same objects warm or cold, and that invariance is
itself gated. `objects_total` used to be exactly reproducible cold and not warm
(the layout pass races the loaders-Ready stop line); since `issues/0016` the cold
load is fast enough to race too.

Warm headline against budget: ~55-79ms host to the first assets row = ~0.6-0.8s
device by the x10 convention, against a 1s device target - **inside budget for the
first time.** It did not get there by building less: the object graph is identical
to the pre-`issues/0016` tree, run for run. What changed is that incubation now
runs at a 50% duty cycle instead of 24%, so the same work occupies half the wall
clock. See "The gentle cadence" below.

The gated stall counter changed from `stalls_over_4ms` to `stalls_over_8ms` in
this slice; the 4ms count is not comparable across that line, because it counts
the controller's bite cadence. See the budgets amendment and "The stall count went
up when work became preemptible".

Ratchets are the observed **maximum** over sixteen runs per phase, not the
median: a ratchet that flakes is worse than no ratchet.

### Warm is the headline, cold is the canary

The cold number is dominated by one-time process warm-up that the app has already
paid before a user ever reaches the wallet - it has started, built AppMain and at
least one other section. Steering by cold would send optimisation work after a
cost nobody experiences: the same section, loaded a second time in the same
process, builds the **identical object graph** (9569 when this was written, 6022
on the merged tree) in a quarter of the time.

So the bench records both and the warm row is the headline. Cold stays recorded as
a canary: **cold moving while warm holds still means someone added first-use
cost**, which does not hurt the wallet but does hurt app start-up - where this
bench is going next.

Caveat in the other direction, so nobody reads warm as "what the user waits":
the warm load also has the *wallet-specific* types and stores warm, which a real
first wallet open does not. A real first open sits between the two numbers. Warm
is the right regression signal because it is the load-invariant one, not because
it is a prediction of user-visible latency.

### Time-to-content as specified is not a valid stop line for this surface

The plan assumed three distinct rungs, `t_content` arriving well after `t_ready`
because `walletAccountsListViewLoader` and `mainViewLoader` incubate after
`WalletLoader` reaches Ready. Measured, they do not.

**Both nested loaders are already `Loader.Ready` at the instant `WalletLoader`
reports Ready** — they complete inside the outer incubation. A watcher attached at
that moment never sees a single status change, so `t_content` lands 0.7ms after
`t_ready`, and that 0.7ms is the cost of walking the tree to find the loaders.

Nothing is on screen at that point. At `t_content` the assets list is 0x0 with no
realised rows: `AssetsView` has not been through a layout pass yet. Its first row
appears **~55ms later**, and the object count goes **4602 -> 9569** — more than
half of everything the section builds happens after it declares its loaders Ready.

Demonstrated cost of trusting it: raising the assets list's `cacheBuffer` to 3000
builds 13,607 extra objects and 82 extra rows, and is completely invisible to the
specified metrics — `objects_total` 4602, `asset_delegates` 0, `account_delegates`
8, all unchanged, all passing. Only the settled count catches it (23176 vs 9569).

**The settle point — first realised assets row, then a stable object count — is the
real stop line for this surface.** The bench runs its window on to it, records
`t_first_asset_row_ms`, and gates `objects_settled` and `asset_delegates_settled`.
`t_content_ms` is still recorded exactly as specified, for continuity.

Related section finding for the deferral slice: `RightTabView`'s per-tab skeleton is
gated on `mainViewLoader.status !== Loader.Ready`, so the grey tiles are dismissed
~55ms host (~0.55s device) before any assets row exists. The user sees an empty
panel, not a skeleton, for that window.

### Generalisation risk — read this before instrumenting another surface

"All nested async loaders Ready" is blind here, so **the equivalent stop line for
the popups is suspect too.** Whoever picks up `issues/0003` must verify that their
stop line observes content the surface actually realised — a rendered row, a
populated field — and not merely `opened` plus a loader status. Check it per
surface; do not carry a stop line across from another one. The cheap check is the
one used here: regress something that only affects the post-ready phase (a larger
`cacheBuffer`, an extra eager child) and confirm the bench notices.

### Attribution of the stall block

Cold, `max_stall_ms` ~350 out of a ~580ms load is one non-preemptible block, and it
is **overwhelmingly one-time process warm-up, not per-load work**. The warm phase
builds the identical 9569-object graph with the block down to 32-35ms and the first
assets row at 119-159ms. This is the measurement the headline decision rests on.

It is **not** the `WalletLayout` document compilation: compiling `walletUrl`
synchronously before the measured window costs ~40ms and moves no staircase number
(`t_skeleton` 196-199, `t_ready` 510-513, block 364). Within the cold block,
0-180ms is the loader's synchronous chrome build and 180-345ms is the first
incubation burst before the event loop is re-entered. What exactly the one-time
cost is - leaf-type loading across StatusQ, first construction of the store and
adaptor singletons, V4 warm-up - is **not yet attributed** and needs a profiler
run.

What this means for which number to steer by is settled under "Warm is the headline,
cold is the canary" above.

### The warm block is the assets list filling itself in one polish pass

`issues/0006`. The warm 32-35ms block is **not incubation of the section tree**. It
sits *after* the whole staircase: it starts 3-6ms after `t_content` and ends exactly
at `t_first_asset_row`.

```
warm phase - stamp timeline (host ms)          warm phase - GUI-thread blocks > 4ms
     10.00  t_skeleton                            0.00 ->   10.32    10.32
    118.99  t_ready                              44.25 ->   68.80    24.55
    120.06  t_content                           112.01 ->  123.15    11.15
   (163.05  first assets row)                   123.15 ->  157.81    34.66   <- the block
                                                157.81 ->  163.79     5.97
```

**What is in it.** A GUI-thread stack sampler (0.5ms cadence, `WalletLoadBenchProbe`
suspends the GUI thread and walks its frame pointers; enable with
`WALLET_BENCH_SAMPLE=1`) took 55 samples inside the block. Every one of them is in
the same call chain:

| samples | frame |
|---|---|
| 54 / 55 | `QSGSoftwareRenderLoop::renderWindow` - one update-request delivery |
| 47 / 55 | `QQuickWindowPrivate::polishItems` |
| 43 / 55 | `QQuickItemViewPrivate::layout` → `refill` → `addVisibleItems` → `createItem` → `QQmlDelegateModelPrivate::object` → `QQmlIncubatorPrivate::incubate` |
| 32 / 55 | ... of which `QQmlObjectCreator::finalize` - binding evaluation and completion |
| 12 / 55 | ... of which `QQmlObjectCreator::create` - object structure |
| 10 / 55 | `QQuickTextPrivate::updateSize` → `setupTextLayout` → `QTextEngine::shapeText` → HarfBuzz |

So the block is **one polish pass in which `AssetsView`'s `ListView` refills and
builds every visible delegate synchronously**. It is synchronous by construction:
`QQuickItemView` creates delegates with `AsynchronousIfNested`, and by this point
`mainViewLoader` has already reported Ready, so there is no enclosing incubation to
nest in and the mode degrades to synchronous. Roughly three quarters of the cost is
binding evaluation and completion rather than object construction, and ~18% of the
whole block is text shaping inside the rows.

**Sizing it.** The block is linear in the number of realised rows and has no fixed
part. Shrinking the bench viewport from 1440x900 to 1440x400 halves the rows and
halves the block:

| viewport | `asset_delegates_settled` | block | `objects_settled` |
|---|---|---|---|
| 1440x900 | 26 | 34.7 / 35.3ms | 9569 |
| 1440x400 | 12 | 13.1ms | 6554 |

That is **~1.55ms and ~200 QObjects of GUI-thread work per realised assets row**
(the marginal object cost across the two viewports; walking one delegate's own
subtree counts 326). The assets rows are the majority of everything the section
builds: `objects_total` at `t_content` is 4602 and `objects_settled` is 9569.

**Where it runs and what triggers it.** On the GUI thread, inside the window's
polish phase, triggered by the first layout pass that gives `AssetsView` a non-zero
size - which cannot happen until `mainViewLoader` is Ready and the panel has been
promoted. It is therefore structurally *after* every mechanism the section currently
uses to stay responsive: the skeleton is already dismissed, the async `Loader` has
already reported Ready, and not one sample inside the block sits under the
incubation controller's `incubateFor` - the metered path has drained and gone idle
by the time this work starts.

### Deferring the detail views does not move the warm block

Stated plainly, because it was an assumption driving the priority of `issues/0002`:
**no.**

> Stale as of `issues/0011`: true while the warm block was the assets refill, wrong
> afterwards. Once the refill was chopped, the surviving max block became the pre-`t_ready`
> creation the detail views are part of, and they are worth ~5-7ms of it. See "The residual
> warm block is `StackView.initialItem`" below.

Measured by temporarily putting `AssetsDetailView` and `CollectibleDetailView`
behind `Loader`s keyed on `stack.currentIndex` (temporary instrumentation under
`ui/`, reverted after measurement - nothing under `ui/` is changed by this issue):

| | baseline (n=9) | detail views deferred (n=9) |
|---|---|---|
| warm `max_stall_ms` | 31.4 - 39.7, median 34.3 | 29.5 - 43.7, median 36.3 |
| warm `t_ready_ms` | 116.6 - 125.2 | 76.5 - 143.4 |
| cold `t_ready_ms` | 499.8 - 521.1 | 471.5 - 503.3 |
| `objects_total` (cold) | 4602 | 3344 |
| `objects_settled` | 9569 | 8297 |

The block does not shrink; the two arms overlap fully and the deferred arm's median
is the higher of the two. The sampler run in the deferred arm shows the same composition - 44 of 56
samples still in the `ListView` refill - because the detail views were never in
that call chain to begin with: they are built during incubation, before `t_ready`,
and the block runs after it.

`issues/0002` is still worth doing, but it should be re-priced: it is a
**graph-size and time-to-ready fix** (-1272 objects, -13%; ~25ms off cold
`t_ready`), not a stall fix. It cannot move the metric that gates this surface.

### Offscreen vs on-screen: the block reproduces, the incubation shape does not

`WalletLoaderPage` gained a `stall-report` positional-argument mode that runs the
same probe through two on-screen loads and prints the same timeline. On-screen, at
18 realised rows (smaller viewport than the bench):

| | on-screen cold | on-screen warm | offscreen warm (bench) |
|---|---|---|---|
| `t_ready` | 579.6 | 202.3 | 119.0 |
| first assets row | 621.8 | 232.0 | 163.1 |
| the block | 580.2 → 621.9 = **41.6ms** | 202.8 → 232.1 = **29.3ms** | 123.2 → 157.8 = **34.7ms** |
| rows | 18 | 18 | 26 |
| per row | 2.3ms | 1.6ms | 1.35ms |

**The block reproduces on-screen, in the same place and with the same shape.** It is
not an artefact of the offscreen harness.

What *does* diverge is everything before it:

- **Incubation is chopped differently.** On-screen the incubation phase is a long
  train of ~8.3ms blocks - one per 120Hz frame, each being one incubation bite plus
  a render - plus one 38.9ms outlier. Offscreen, under `QSGSoftwareRenderLoop`, the
  same work arrives as fewer and larger blocks. Attribution of anything *inside*
  incubation must therefore be done on-screen; attribution of the post-ready block
  can be done either way.
- **The absolute staircase is ~1.7x slower on-screen**, so on-screen numbers are not
  comparable to the checked-in baselines and must never be recorded into the TSV.
- **On-screen there is a long tail** of 4-6ms per-frame blocks for hundreds of ms
  after the assets row appears (image decode and friends) that the offscreen bench
  does not see at all.

Harness caveat found while building the on-screen mode, worth knowing for any later
on-screen bench: **the section must be absent for at least one frame between
teardown and rebuild.** Toggling `harness.active` false→true within one tick
produces a tree that reaches `Loader.Ready` and is then never polished - 4225
objects, zero assets rows, forever. The bench's offscreen teardown already waits
200ms; the page waits 200ms for the same reason.

### What the next fix should attack (superseded by `issues/0007` - kept as the reasoning)

The assets **delegate**, not the section tree.

The stall budget cannot be met by deferring anything at section level, because the
block happens after every section-level deferral has already completed. Two
independent levers, in order:

1. **Make the first fill preemptible.** A `ListView` refill is a single
   uninterruptible call inside `polishItems`; the app cannot chunk it from outside.
   The one lever that works is to make the delegate itself cheap - a small shell
   with the rich content behind a nested async `Loader` - so the synchronous refill
   builds 26 shells and the expensive part incubates in metered bites. This is the
   only shape that can get under the 3.2ms host ceiling.
2. **Make the row cheaper.** ~200 QObjects and ~1.55ms per row is a lot for a token
   row, and three quarters of it is binding evaluation, not construction. ~18% is
   text shaping, so the count of `Text` items per row and their sizing bindings are
   worth a look on their own.

Both are measured directly by `asset_delegates_settled` x per-row cost, so the bench
already gates the shape of the fix.

Note for the ratchet: `stalls_over_4ms` cannot reach its budget while any list fills
synchronously, and `max_stall_ms` on this surface is *by definition* the assets
refill. A change that lowers `max_stall_ms` without lowering the per-row cost or the
row count is measuring something else.


### Both levers landed: the refill block is 34.7 -> ~12ms, and only ~1ms of it is delegates

`issues/0007`. `AssetsView`'s regular delegate is now a `TokenDelegateShell` - an
`Item` carrying the row's geometry and five placeholder tiles, with the
`TokenDelegate` behind a nested `asynchronous` `Loader`. `TokenDelegate` also lost
its two unconditional warning buttons (each a `StatusFlatRoundButton` plus a
`StatusToolTip`), which are now latched on the error text.

| | pre-0007 | post-0007 (n=16) |
|---|---|---|
| warm `max_stall_ms` | 31.7 - 42.6 | 17.2 - 32.3 |
| the post-`t_content` block | 34.7 / 35.3 | 12.2 - 15.7 |
| warm `t_first_asset_row_ms` | 119 - 167 | 98.7 - 140.5 |
| `objects_settled` | 9569 | 9166 |
| objects per realised row | 326 | 279 |
| warm / cold `stalls_over_8ms` | (not measured) | 2-4 / 3-6 |
| warm / cold `stalls_over_4ms` | 7-10 / 10 | 12-16 / 15-19 |

`max_stall_ms` no longer describes the assets list at all. Its worst warm block is
now an incubation **overshoot** in the section tree at t≈21-41ms - a 4ms bite budget
cannot interrupt a deeply nested synchronous sub-creation - which was always there,
just smaller than the 34.7ms assets block that used to dominate.

`objects_settled` moves by two opposing amounts: the shells **add** 8 objects per
row (shell `Item`, `Loader`, placeholder `Item`, five tiles - +208), and the two
latched-off warning buttons **remove** more than that.

**The remaining ~12-16ms block is not the assets delegates.** Replacing the delegate
with a bare `Item { width; height }` - one object per row, no Loader, no
placeholder - leaves the same block: 11.1 - 11.7ms over three runs. The shells cost
~1ms of it and the placeholder tiles are inside the run-to-run noise (11.7-12.8
without them, 11.7-13.6 with). The sampler in that window (n=17-18) shows the first
real layout and render of the promoted panel: `polishItems` over the *accounts*
list's own refill, `QQuickLinearLayout::insertLayoutItems`, anchor updates,
HarfBuzz shaping and the software scenegraph building text and image nodes - plus,
honestly, two samples inside the bench's own `countObjects` walk. Anyone chasing
the next 12ms should start there, not at the assets rows.

**Per-row cost after the change**, for pricing the popups' picker lists: **279
QObjects per realised token row**, and **~1.2 - 1.5ms of incubated GUI-thread work
per row** (six to eight bites summing 31 - 39ms for 26 rows, read off the bite
train). The shell that the synchronous refill pays for is 8 objects and ~0.04ms
per row.

Read that against the 1.55ms per row this cost before: the fix did **not** make the
row much cheaper - the row trim is worth ~14% of its objects and the rest of the
work is unchanged. What changed is that it is now interruptible. A picker list
priced from this number should assume the same: ~1.3ms of row work that can be
metered, not removed.

### The stall count went up when work became preemptible — and that was the gate's fault

The uncomfortable half of `issues/0007`, and it turned out to be a defect in the
metric rather than in the fix.

The incubation controller's gentle bite is `gentleIntervalMs / 4`. The bench process
reports a 60Hz screen, so that is **17ms interval, 4ms budget** — printed per run
next to the block list. The old gate's threshold was also 4ms. Every metered
incubation bite therefore landed at 4.0 - 6.4ms and scored as a stall:

```
warm phase - GUI-thread blocks over 4ms; gentle incubation bite 4ms every 17ms
     80.77 ->    92.51    11.74   <- the refill, now shells only
     92.51 ->    98.15     5.64   \
    107.21 ->   111.40     4.19    |
    122.82 ->   128.08     5.26    |  the incubated fill: one bite per tick,
    140.35 ->   145.63     5.28    |  each floored by the controller's budget
    157.43 ->   162.76     5.33    |
    175.16 ->   179.36     4.20    |
    191.56 ->   195.84     4.29   /
```

Chopping one 35ms block into eight 4ms bites is +7 on a metric that counts blocks.
So the count rose — warm 7-10 -> 12-16, cold 10 -> 15-19 — while every number the
budget actually cares about improved. The gate was anti-correlated with the outcome
it existed to force, and display-dependent on top of that.

**Resolution: the gated counter is now `stalls_over_8ms`.** 8ms is above every
observed bite (largest gap anywhere in the incubated phase: **6.42ms** over sixteen
runs) and far below anything a user reads as smooth, so it counts exactly the right
thing — **blocks the controller failed to chop**. `stalls_over_4ms` stays in the TSV
as a recorded, ungated column, so re-gating on it costs no history once PR #21921
moves the controller's budget. Measured: warm 2-4, cold 3-6; ratchets set at those
maxima. The reasoning that makes 4ms wrong in general is in the budgets amendment.

What the surviving `stalls_over_8ms` blocks are, on a warm load: the loader's
synchronous chrome build at t=0 (~10-15ms), one or two incubation **overshoots**
inside the section tree at t≈21-41ms (15-32ms — a 4ms budget cannot interrupt a
deeply nested synchronous sub-creation), and the post-`t_content` layout pass
(12-16ms). **That last one, not the assets rows, is the next target**; see below.

Cutting the row from 326 to 279 objects bought back roughly two bites. It is kept
on its own merits, not the metric's: latching a rarely-visible subtree off is item 1
of this doc's own improvement toolkit, the two buttons were built on every row and
merely hidden, and the change removes objects from both the graph and the incubated
fill regardless of how stalls are counted.

The related claim from `issues/0006` that needs qualifying: the block was described
as "linear in the number of realised rows and with no fixed part". Across viewport
sizes that held, but it hid a **per-delegate** fixed cost - ~0.27ms of
`QQmlDelegateModel` / incubator / attached-object machinery that a one-`Item`
delegate pays in full. That is why 26 shells of 8 objects still cost ~7ms of refill
where 26 rows of 326 objects cost 40ms.

### Row height is the shell's, and it does not move

`StatusListItem.implicitHeight` is `Math.max(64, titleArea.height + 16)`, and a
token row's title area is under 48px, so every row resolves to exactly the 64px
floor. `TokenDelegateShell.placeholderHeight` is that 64, and
`tst_TokenDelegateShell` gates the two staying equal - if a future change makes a
token row taller, the test fails rather than the scrollbar jumping.

On-screen proof, `WalletLoaderPage` under
`STORYBOOK_INCUBATION_MS=1 STORYBOOK_INCUBATION_GENTLE_MS=0 STORYBOOK_INCUBATION_GAP_MS=200`
(1ms bites 200ms apart, which stretches the ~150ms fill to seconds so it can be
photographed): the rows still filling show the placeholder tiles, the rows already
filled show real content, and the realised rows sit at **identical y** in the
mid-fill and settled screenshots. The placeholder mirrors
`WalletAssetListSkeleton`, which is what the per-tab skeleton showed a moment
earlier, so the two loading states read as one handoff rather than two.


### The residual warm block is `StackView.initialItem`, and it is synchronous by construction

`issues/0011`, measured at `5e3cf80b7f` in `wt-wallet-loader-storybook`.

After `issues/0007` the warm `max_stall_ms` is no longer the assets refill. It is one
block at t≈20-38ms, **16.5 - 17.8ms** over four consecutive runs, and it is
**`QQuickStackView` building its `initialItem`**.

```
warm phase - GUI-thread blocks over 4ms (4 consecutive runs, t_ready 77-91)
     20.4 ->  38.2   17.8   <- the block: StackView.initialItem
     79.9 ->  92.7   12.8       the post-t_content polish/refill pass
     20.2 ->  36.7   16.6
     72.3 ->  80.6    8.3
     80.6 ->  92.8   12.2
```

**Sampler evidence.** `WALLET_BENCH_SAMPLE=1`, 35 samples inside the block, 32 of them in
one chain:

| samples | frame |
|---|---|
| 32 / 35 | `QQmlIncubationController::incubateFor` — the metered pump |
| 32 / 35 | `QQmlObjectCreator::finalize` of the enclosing incubation |
| 32 / 35 | `QQuickStackView::componentComplete` → `pushElements` → `pushElement` |
| 32 / 35 | `QQuickStackElement::load` → `QQmlComponent::create(QQmlIncubator&)` |
| 13 / 35 | ... of which `QQmlObjectCreator::create` / `populateInstance` / `setupBindings` |

The stacks are 40+ frames of nested `createInstance` → `setupBindings` under that one
`QQmlComponent::create`, with no return to the event loop.

**Why the controller cannot chop it.** `WalletLayout.centerPanel` is a `StackView` with
`initialItem: walletContainer`, a `Component` wrapping `RightTabView`. When a `StackView`
is handed a *Component*, `QQuickStackElement::load` incubates it through the stack's own
incubator, which runs to completion inline — the enclosing incubation's
`QQmlInstantiationInterrupt` does not reach it. So the whole centre panel is created in one
call, from inside `componentComplete`, while the controller believes it is spending a 4ms
bite.

**Inside or outside incubation: inside.** It sits in the parent creator's `finalize`, under
`incubateFor`. It is not a polish-phase block like the assets refill was, and not
post-`t_ready` work. It is incubation that the controller has no way to interrupt — the same
class of defect as `QQuickItemView`'s `AsynchronousIfNested` refill, one layer up.

**Confirmed on-screen**, as required for anything inside incubation. `WalletLoaderPage
WalletLoader stall-report` with the sampler: one **33.8ms** block at t=36-70 amid the
on-screen train of ~8ms per-frame blocks, 40 of its 87 samples in the same
`QQuickStackView` / `StackElement` chain. On-screen absolutes are ~1.7x the offscreen ones
(and this run carried the sampler plus a loaded machine), so the size is consistent, not
new. The on-screen run also shows the loader's synchronous chrome build as one **27.0ms**
block at t=0 — offscreen that rung is `t_skeleton` ≈ 4ms.

**Sizing what is in it.** Replacing `CollectibleDetailView` and `AssetsDetailView` with
bare `Item`s (temporary instrumentation, reverted) takes the block from 16.5-17.8 to
**9.3 - 12.2ms** over four runs plus one sampled run at 10.8ms, with the composition
unchanged (11-12 of 17 samples still in the same chain).

| | block at t≈20-38 |
|---|---|
| baseline | 16.5 - 17.8ms |
| two detail views stubbed | 9.3 - 12.2ms |

So the two eagerly-built detail views are worth **~5 - 7ms** of it, and the rest — the
account header, the tab bar row, the per-tab skeleton, the `StackLayout` and the tab-0
column — is **~10 - 11ms** that stays synchronous even after `issues/0002` lands.

#### This contradicts "deferring the detail views does not move the warm block"

That finding (above, from `issues/0006`) was true when it was measured and is now stale.
It was measured while `max_stall_ms` *was* the 34.7ms assets refill, which the detail views
are genuinely not part of — they are built before `t_ready` and the refill runs after it.
Now that the refill is chopped, the surviving max block is exactly the pre-`t_ready`
creation the detail views sit in. `issues/0002` should be re-priced a second time: it is
worth ~5-7ms of the gated stall metric, not zero.

#### The fix exists, is proven, and is deliberately deferred

`QQuickStackElement` has a second path: given an **Item instance** rather than a Component
it adopts the item and incubates nothing (`fromObject`, with `originalParent` restored on
removal). Moving `RightTabView` out of the `Component` and into a
`readonly property Item` of `WalletLayout` — beside `leftPanel` and `centerPanel`, which
are already written that way — makes it part of the section's own asynchronous incubation.

Measured: **the block disappears completely.** The whole warm load becomes a clean bite
train, which is what the budget asks for:

```
arm F, warm - GUI-thread blocks over 4ms
      0.00 ->    4.02    4.02      88.87 ->   92.89    4.02
     22.02 ->   26.05    4.04     105.46 ->  110.97    5.51
     38.59 ->   42.62    4.03     122.10 ->  127.66    5.55
     55.25 ->   59.39    4.14     138.92 ->  148.58    9.66
     72.02 ->   76.13    4.11     149.35 ->  163.02   13.67   <- the post-content pass
```

And it costs more than it saves. Release A/B, arms alternated, three rounds each, same
machine and same load:

| warm | baseline | initialItem as an Item instance |
|---|---|---|
| `max_stall_ms` | 19.6 / 24.0 / 21.5 | 12.5 / 13.9 / 14.9 |
| `stalls_over_8ms` | 2 / 3 / 2 | 1 / 2 / 1 |
| `t_first_asset_row_ms` (headline) | 117.9 / 136.9 / 149.0 | 166.0 / 169.0 / 203.5 |
| cold `t_first_asset_row_ms` | 546 - 648 | 636 - 660 |

The arms do not overlap on either metric. (These rounds ran at load average ~32 with
sibling worktrees building, which inflates both arms; the alternation is what makes the
comparison readable, not the absolutes. The same block measured 16.5-17.8 in the
unalternated runs earlier the same session.)

> Re-priced by `issues/0016`: the duty cycle changed, the tax fell from +48ms to +13ms,
> and the fix is *still* unlanded - for a new reason. See "`issues/0011` re-priced" below.

**Why preemptibility costs 4x here.** The gentle bite is 4ms every 17ms — a **24% duty
cycle**. Work that is metered instead of run in one burst therefore takes roughly four
times as long in wall clock: 17ms of creation becomes ~70ms of staircase, which is the
+48ms the headline shows. That is not a property of this surface; it is the controller's
budget, and it is the same amendment that makes 3.2ms unreachable. **The last un-chopped
block on this surface cannot be removed without a headline regression until the
controller's duty cycle changes (PR #21921) or the gentle hint is popped once the section's
skeleton is up.**

So `issues/0011` lands no production change. What it leaves behind: the attribution, the
mechanism, and a fix that is one edit away the moment the controller's budget makes it
free. The block also shrinks without any restructuring as the leaf-cost work lands —
`issues/0002` takes ~5-7ms out of it directly, and `issues/0008` / `0009` / `0010` cut the
per-leaf cost of everything inside it.

#### The other warm blocks over 8ms, sized

For whoever picks up the next one:

| block | warm size | what the sampler says |
|---|---|---|
| t≈20-38, `StackView.initialItem` | 16.5 - 17.8ms | above |
| straddling `t_ready`/`t_content` | 8.3 - 10.3ms | 15/16 samples under `incubateFor`; **5/16 in the bench's own `collectSubtree`** — `takeInstantiationCounts()` walks 4602 objects at the `t_content` stamp, so ~3ms of this block is the probe, not the section |
| post-`t_content` | 12.1 - 13.4ms | 22/22 `QSGSoftwareRenderLoop::renderWindow`, 16/22 `polishItems`, 14/22 `QQuickItemView` refill → `createItem`; no probe frames. The **accounts** list refills synchronously here for the same `AsynchronousIfNested` reason the assets list used to — an accounts-row shell is the obvious next `issues/0007`-shaped fix |

The `stalls_over_8ms` ratchet is unchanged at warm 4 / cold 6: no fix landed, and the
observed warm count over this issue's runs was 2-3.

Functional suite at `5e3cf80b7f` with a clean tree: **1829 passed, 2 failed, 5 skipped**,
the two documented `ChatTextArea` / `ChatTextView` failures. Same as the post-`issues/0007`
measurement.


### Functional-suite baseline

`make run-storybook-tests` on this stack: **1825 passed, 2 failed, 5 skipped (1832
total)**, failing `ChatTextArea::test_emoji_enlargingCanBeDisabled` and
`ChatTextView::test_clickingAnotherViewDeselectsPrevious`. Re-measured after
`issues/0007`: **1829 passed, 2 failed, 5 skipped** - the same two failures, and the
four extra passes are `tst_TokenDelegateShell` (two test functions plus init and
cleanup). Nothing was dropped. Measured before and after
the bench landed, on the same machine at comparable load - identical both sides, so
adding the bench and its `-E "PagesValidator|WalletSectionLoadBench"` exclusion drops
nothing from the suite. `ctest -N` there: 2 tests registered before, 3 after, 1 run
either way.

Two known flakes, neither related to the bench: `CommunityChatLoaderSection::
test_adminDragReordersUpward` fails under machine load (reproduced at base under load
average 63, passes in isolation 3/3), and the three `StatusChatInput`
mention-suggestion tests reported as failing elsewhere pass on this machine.

Gotcha when re-measuring: `make storybook-build` did **not** re-run CMake after the
storybook `CMakeLists.txt` changed, leaving a stale `CTestTestfile.cmake` that still
registered a test whose source was gone. Force `cmake <build-dir>` and check
`ctest -N` before trusting a before/after comparison.

### What the pilot found about the harness

- **`TestCase.tryVerify` cannot be used through a measurement window.** Its polling
  loop sleeps 10ms between passes, which starves the stall probe: an idle window
  measured through `tryVerify` reports 27 stalls over 4ms and a 12.6ms max gap where
  the truth is 0 and 1.29ms. The bench waits on a plain `QEventLoop` instead
  (`WalletLoadBenchProbe.waitForStamp`). Any later bench must do the same.
- **A QML `Timer` cannot be the stall probe** - it is animation-driven, so its floor
  is the frame period. The probe is a `QBasicTimer` with `Qt::PreciseTimer`.
- **The stall gate is a ratchet, not slack**, and its threshold has to sit above the
  incubation controller's bite or it counts metered work as stalls - which is what
  the 4ms version did until `issues/0007`. The gate is `stalls_over_8ms`, ratcheted
  at the observed maximum (warm 4, cold 6 over sixteen runs). Lower it whenever a
  fix lowers the count; never raise it without saying, as here, what about the
  metric was wrong.
- **`t_skeleton` cold is ~190ms against a ~1.6ms budget, but warm it is 3.6-9.1ms.**
  The loader-owned chrome and both skeletons are built synchronously and pay
  first-use cost in a cold test binary. The cold rung is an upper bound, not a
  reading of what the app does.
- **The post-Ready layout phase is measurable and low-noise offscreen**, contrary to
  the worry that anything frame-coupled would be invisible: the settled counts are
  bit-identical run to run and `t_first_asset_row_ms` spreads ~4ms.
- **The stall probe records every block, not just the worst.** `probe.stalls()`
  returns each gap over the threshold as start/end, and `probe.stampTimeline()`
  returns the staircase in order; printed together they place a block inside the
  window, which is what turned `max_stall_ms` from a number into an attribution.
- **The probe can sample the GUI thread's own stack.** With `WALLET_BENCH_SAMPLE=1`
  a watchdog thread suspends the GUI thread every 0.5ms and walks its frame
  pointers, dumping symbolised stacks to `probe.sampleDumpPath`. Off by default -
  suspending the GUI thread ~2000x/s perturbs the numbers the bench records, though
  measurably little here (34.7 vs 35.3 on the same block). It is the only tool that
  sees inside a non-preemptible block, since every in-process timer is blocked with
  everything else.
- **The whole cold/warm split was only visible because the bench loads twice.** A
  single-load bench on any surface will attribute one-time process warm-up to the
  surface under test. Later benches should load twice for the same reason.
### The asset detail's load time is mostly not work — it is the incubation cadence

`issues/0012`. Baseline for everything below: `260a6820b5`, Release, whale profile,
offscreen storybook, macOS host.

**The second-open anomaly is not a defect.** `issues/0012` opened on the observation
that the second open of the asset detail was consistently slower than the first
(71-126 vs 57-67 host ms over the five runs recorded at `260a6820b5`). It does not
reproduce as an ordering: with the bench temporarily extended to **eight consecutive
opens in one process**, `t_content` reads

```
open  0     1     2     3     4     5     6     7
     65.9  54.9  57.1  56.9  56.0  72.2  72.5  56.5     (run A)
     65.2  56.8  56.0  56.0  73.3  56.2  56.2  56.1     (run B)
```

No monotonic growth, and `objects_settled` is 918/919 on every one of the sixteen
opens - nothing accumulates across the unload/reload cycle and the teardown leaves
nothing behind. What the numbers do show is **two discrete values, ~56 and ~73, one
gentle incubation interval apart.**

**Why.** The window is quantised by the incubation controller. Its gentle bite is
`gentleIntervalMs / 4` = 4ms and its gentle interval is 17ms on the 60Hz the bench
process reports, so `t_ready` is `phase offset + bites x 17ms`. A warm open's block
list is the whole story:

```
warm open - GUI-thread blocks over 4ms          t_ready 56.28
     18.50 ->   23.78    5.28   \
     35.96 ->   40.77    4.81    |  three gentle bites, ~14ms of work
     52.01 ->   56.29    4.28   /
     56.71 ->   65.71    9.00      post-Ready layout + render (outside incubation)
```

**~14ms of GUI-thread work inside a 56ms window.** The other ~42ms is the controller
waiting for its next tick. Nothing in the view is blocking; the surface is already
fully preemptible.

The two phases differ for two structural reasons, neither of them accumulation:

- **The warm open starts from an idle controller.** After the close and the bench's
  200ms drain, `incubatingObjectCount()` is 0, so the controller has fallen back to
  its 128ms idle cadence. The next request takes the fast path
  (`incubatingObjectCountChanged` -> `restart(m_gentleIntervalMs)`), which schedules
  the first bite **a full gentle interval later**. Every warm timeline has zero
  blocks between t=0 and ~17-19ms.
- **The cold open pays a synchronous first-use block at t=0** (document compilation
  and type loading, 4.7-7.6ms) that is not metered by the bite budget at all, and its
  bite train is already running when the request lands, so its first bite comes at
  ~10ms rather than ~18ms.

So which phase reads faster depends on how the view's total work divides into 4ms
bites and where the request lands in the tick. Base warm work sits almost exactly on
the three-bite boundary (3 x 4.25 = 12.75ms against ~13-14ms of work), which makes
the warm number **bistable between 56 and 73ms** and sensitive to machine load. The
five-run baseline at `260a6820b5` was recorded on a loaded machine and caught the
73ms mode five times out of five; at low load the same binary reads 56 seven times
out of eight. **The anomaly was the metric's bistability, not the code's.**

**The count fix.** Everything the view builds is visible at the bench viewport
(1006x769: `infoFlow` at y=442, `detailsFlow` at y=533 h=170), so "defer what is not
visible" has almost no scope here. What it does have is three subtrees that are built
on **every** open and shown on almost none:

| | objects | condition |
|---|---|---|
| chain-tag warning button (`StatusFlatRoundButton` + `StatusToolTip`) x4 | 148 | `errorTooltipText` non-empty |
| header `communityTag` | ~61 | community asset |
| "Minted by" tile | ~88 | community asset |

All three are now latched (`Loader` / conditional `rightComponent`) rather than built
and hidden. `objects_settled` **1146 -> 918, -228, -20%**; the header alone goes
536 -> 378. `information_tiles` moves 3 -> 2 because the always-hidden "Minted by"
tile is no longer instantiated for a plain asset. `chain_tags` stays 4.

**The A/B**, Release, arms alternated, `260a6820b5` vs the change:

| `t_content` | base | latched |
|---|---|---|
| cold, n=10 | 57.3 - 68.4, median 65.8 | 48.1 - 50.6, median 48.5 |
| warm, n=9-10 | 55.6 - 92.9, median ~72 | 53.9 - 89.3, median 55.8 |

**Cold: the arms do not overlap, -17ms, exactly one bite removed.** **Warm: the arms
overlap** - both visit the 56 and the 73 mode; the change shifts which mode is
typical but does not remove a mode. Stated plainly because that is what the data
says.

**The surface does not reach the 40ms host budget, and here is the floor.** With the
cadence above, the reachable values of a warm `t_content` are ~21 (one bite), ~38
(two), ~55 (three). Forty milliseconds is therefore a **two-bite budget**, and two
bites is ~8.5ms of work. The view builds 918 objects in ~11ms; it would have to lose
another ~280 objects to fit. So:

- **~17ms of every warm open is the controller's idle->first-bite latency**, before
  any work happens at all. Measured directly: patching the fast path to
  `restart(0)` (temporary, reverted) and re-running the same build gives warm
  `t_content` **38.8 / 40.0 / 40.2** in three of five runs against 54.2 / 58.9 in the
  other two - i.e. **that one line puts the surface inside its budget without
  touching the view**, and it leaves the cold phase untouched (48.6-49.6, unchanged),
  exactly as the mechanism predicts, because a cold open's controller is not idle.
  This belongs to the controller's PR (#21921), not to a wallet surface, and is left
  unlanded here.
- **The x10 host->device convention does not hold on this surface.** More than half
  of the host number is pacing that is 17ms on any machine. A device is ~10x slower
  at the *work*, not at the *tick*, and after 300ms of burst the controller leaves
  the gentle phase entirely.

**No synchronous list fill here**, contrary to the suspicion that opened the issue.
The header's chain-tag `Repeater` and the two `SortFilterProxyModel`s are created
inside the detail `Loader`'s incubation, so `QQuickItemView`/`QQmlDelegateModel`'s
`AsynchronousIfNested` does nest and the work is chopped: every block before
`t_ready` is 4.0-5.7ms, i.e. one bite plus overshoot. **The only block above one bite
is the post-`t_ready` layout and render pass of the promoted view, 6.4-11.7ms, and it
is outside incubation** - the same class as the section's post-`t_content` block, and
the same place the next 12ms of the section load lives.

**Where the remaining 918 objects are**, for whoever takes this next:

| | objects | share |
|---|---|---|
| `AssetsDetailsHeader` | 378 | of which 4 chain tags x 72 = 288 |
| `StatusChartPanel` | 190 | |
| `detailsFlow` (description + contract tile) | 210 | |
| `infoFlow` (six information tiles) | 99 | |
| — the six `InformationTag`s, counted across the above | 442 | 48% |

**`InformationTag` is 72 objects for what renders as a small pill, and 45 of those
are its `StatusSmartIdenticon`** — for one 16px network icon. Measured breakdown of
one identicon:

```
StatusSmartIdenticon        45
  QQuickItem (rounded-image content, incl. its StatusRoundedImage
              and the error-fallback letter-identicon Loader)   17
  StatusRoundedImage x2                                         12   (content + bridgeBadge)
  QQmlComponent x6                                               6   (the three source
                                                                     components, backgrounds)
  StatusBadge                                                    5
  StatusAssetSettings                                            2
  QQuickLoader x3                                                5
```

**Correction to an earlier reading of this.** The two unconditional
`visible: false` children of `StatusSmartIdenticon` — `StatusBadge` and the
`bridgeBadge` `StatusRoundedImage` — were first estimated at ~31 objects each
identicon by subtraction. Measured directly they are **11** (5 + 6), so latching them
is worth ~66 objects across this surface, not ~186. That is not close to the ~280 the
two-bite budget needs, and `badge` / `bridgeBadge` are public aliases consumed by ~30
call sites as grouped-property assignments (`badge.visible: x`), which a `Loader`
latch breaks. **Not worth the call-site tax at 66 objects** — recorded so nobody
re-derives the wrong number.

The lever that is the right size is the other 34 objects of the identicon: an
`InformationTag` that only ever shows a static image does not need the badge, the
bridge badge, the three source `Component`s or the nested error-fallback `Loader`.
Six of them is ~210 objects, which would put the surface at ~708 against the ~640 a
two-bite budget wants — i.e. back on a bite boundary, bistable again. `InformationTag`
has 19 call sites across 15 files and exposes `asset` as an alias into the identicon,
so this is a StatusQ-leaf-cost-shaped job, not an asset-detail one.

One smaller item, unmeasured: a chain tag whose `balancesAggregator.value` is 0 is
still built and then hidden by `visible:` (on-screen, three of the four created tags
are shown), which a model-side filter would remove.

**On-screen verification** (`WalletLoaderPage`, whale profile, screenshots via
`grabToImage` because the AX bridge exposes no window for Storybook on this host -
`ax tree` returns a menu bar and no `AXWindow`, and `ax screenshot` fails): opening a
token detail, switching to a second token with the detail open, navigating back to
the assets list, and reopening all render correctly, with the chart present in every
detail state and the chain tags re-deriving per token. `AssetsDetailViewPage` with
and without `communityId` confirms both latched branches: the plain asset shows the
Website tile and no community tag, the community asset shows the community tag in the
header and the "Minted by" tile and no Website tile.

**Harness caveat for anyone re-measuring this surface:** these numbers move by a full
17ms tick under machine load, and this repository is worked on by several agents at
once. Check `uptime` before recording; the checked-in TSV rows were taken at load
averages between 4 and 17 and contain both modes deliberately.

**Functional suite** on this stack, measured before and after on the same machine:
**1832 passed, 2 failed, 5 skipped** both sides, failing
`ChatTextArea::test_emoji_enlargingCanBeDisabled` and
`ChatTextView::test_clickingAnotherViewDeselectsPrevious` - the two documented
failures. `PagesValidator` passes. (The 1825-passed figure quoted when this issue was
handed over is stale by the seven test functions `2053b6b3de` and `260a6820b5` added.)

### The merged tree: what the four slices are worth together

`issues/0018`. Until this point no measurement described the product: four branches
forked from `de8dcfab68`, each re-recording the same baseline from a tree that lacked
the others' work. They are now one branch, and every number above is re-recorded on it.

Merge order, least to most entangled: `perf/statusq-leaf-cost` into
`feat/storybook-wallet-loader`, then `perf/defer-wallet-detail-views`. **No
production-code conflicts in either merge.** Both merges conflicted in exactly two
files, both of them measurement: `wallet-section-load.tsv` (resolved as the
schema-normalised union of the histories, then re-recorded by running the bench, never
by picking a side) and `tst_WalletSectionLoadBench.qml` (only the expected-count
constants; every column and gate the three branches added was kept - the
`stalls_over_8ms` column and gate from 0007, the `walletMainViewLoader` objectName
filter from 0002, which the centre panel needs now that it holds more than one async
`Loader`).

**The counts do not compose additively, and the shortfall is the point.**

| | base `de8dcfab68` | 0007 | leaf-cost | 0002 + 0012 | sum of the three | **merged, measured** |
|---|---|---|---|---|---|---|
| `objects_settled` | 9569 | 9166 (-403) | 7365 (-2204) | 8297 (-1272) | 5690 (-3879) | **6022 (-3547)** |
| `objects_total` (cold) | 4602 | 4602 (0) | 3999 (-603) | 3344 (-1258) | 2741 (-1861) | **2813 (-1789)** |
| objects per assets row | 326 | 279 | (not recorded alone) | (not recorded alone) | — | **202** |

So the merged saving is **332 objects short** of the sum of the individual claims -
about 9% of the total reduction was claimed twice. Two overlaps account for it:

- **`issues/0008` / `0009` / `0010` / `0013` / `0014` cut the per-leaf cost of
  everything in the section, including everything inside the two detail views -
  and then `issues/0002` deletes those views from the load entirely.** Every
  scrollbar, tooltip, ripple and tag row the leaf work removed from
  `AssetsDetailView`, `CollectibleDetailView` and `AssetsDetailsHeader` was counted
  by the leaf-cost branch and removed again by the deferral branch. This is the bulk
  of the 332.
- **`issues/0007` latched off the token row's two warning buttons - each a
  `StatusFlatRoundButton` plus a `StatusToolTip` - and `issues/0009` defers exactly
  those tooltips.** The same objects, claimed on two branches.

The per-row number is the cleanest reading of the leaf work in isolation: a realised
token row was 326 objects, 279 after 0007's latch, and **202 on the merged tree**.
The remaining 77 per row are the scrollbar policy, the deferred tooltips and ripples
and the tag row inside `StatusListItem`; across 26 realised rows that is ~2000 of the
settled count.

The same overlap shows on the asset detail, in the other direction and much smaller:
`objects_settled` **918 -> 916**. `issues/0012` had already latched the chain tags'
warning buttons off, and those carried the tooltips `issues/0009` defers, so the leaf
work has almost nothing left to remove on a surface `0012` already trimmed.

**Stalls.** The warm `max_stall_ms` is 8.9 - 14.9 (was 17.2 - 32.3), and
`stalls_over_8ms` is warm 1-3 / cold 3 flat (was 2-4 / 3-6). The largest pre-`t_ready`
block - `StackView.initialItem`, attributed under `issues/0011` at 16.5 - 17.8ms - now
reads **4.9 - 10.3ms**, which is what `issues/0011` predicted: 0002 takes ~5-7ms of it
directly and the leaf work cuts the per-leaf cost of the rest. The block is still
there and still un-choppable; it is simply small enough now that on some runs the t=0
chrome build or the post-`t_content` polish pass is the larger one.

**Ratchets, from the observed maxima over sixteen runs per phase:** section
`stalls_over_8ms` warm 4 -> **3**, cold 6 -> **3**; asset detail `stalls_over_4ms`
12 -> **11** (warm 2-7, cold 7-11 over fourteen runs per phase). Down only, as the rule requires.

**One caveat for whoever tightens next.** The margin between the gate and the
controller's bite train has shrunk: the largest gap *below* the 8ms threshold is now
**7.96ms**, against 6.42ms when the threshold was chosen. The threshold still sits
above every metered bite, but a loaded machine could now push one block across it and
read as a fourth stall. If the warm ratchet starts flaking at 3, that is the reason -
do not raise it without saying which block crossed.

**Functional suite on the merged tree:** `make run-storybook-tests` gives **1869
passed, 2 failed, 5 skipped**, the two documented `ChatTextArea` / `ChatTextView`
failures and nothing else. `PagesValidator` passes separately. The 1869 is the union
of the three branches' test additions (1829 post-0007, 1832 on the detail-view branch,
plus the leaf-cost branch's `tst_StatusDeferredToolTip`, `tst_StatusListItem`,
`tst_StatusScrollBar` and the extended ripple/button tests). **`tst_TokenDelegateShell`
passes unchanged** - `StatusListItem`'s 64px implicit-height floor survived 0014's
restructure, so the shell's `placeholderHeight` is still right and no fix was needed.
Note the trap the working doc already warns about did fire: this merge changes
`storybook/CMakeLists.txt`, and `make storybook-build` did not re-run CMake, so
`cmake <build-dir>` and `ctest -N` were needed before the asset-detail bench was
registered at all.

#### On-screen pass on the merged tree

First real on-screen pass in this workstream (earlier agents had no unlocked screen).
Storybook on-screen, whale profile, driven through the macOS AX bridge; the
`AXWindow` that `issues/0012` could not find is available now.

What was verified: the section loads with the accounts skeleton and a spinner in the
right panel, hands off to real content, the accounts list and the assets list fill,
a token detail opens on a row click and the back arrow returns to the list, the
Collectibles tab switches, a `StatusDeferredToolTip` appears on first hover of a
`StatusButton` (correct bubble, arrow and placement), a button press renders its
ripple/press state, and `SharedAddressesAccountSelector` renders its `StatusListItem`
tag rows with the new `tagsSpacing` API while rows without tags build no tag row at
all.

**The interaction that most needed checking, checked visually.** Under
`STORYBOOK_INCUBATION_MS=1 STORYBOOK_INCUBATION_GENTLE_MS=0 STORYBOOK_INCUBATION_GAP_MS=200`
the fill stretches to tens of seconds and can be photographed mid-way: two rows show
`TokenDelegateShell`'s placeholder tiles while the rows below them are already real,
and **the realised rows sit at identical y in the mid-fill and settled frames.** The
placeholder height still equals the row height after 0014 restructured
`StatusListItem` - the thing `tst_TokenDelegateShell` gates, confirmed on pixels.

Two things seen on screen that no test catches, neither of them caused by this merge:

- **`WalletLoaderPage`'s Collectibles tab shows "Displaying collectibles on
  [nothing] is not currently supported by Status." - an empty `%1`,** and an empty list, even at
  500 mocked collectibles. The empty substitution is
  `CollectiblesNotSupportedTag`'s network name, which the page's mock does not
  populate; no branch in this merge touches that file or the collectibles mock. It
  does mean the section's collectible detail cannot be reached by clicking a row on
  this page - the page's `walletLoaderOpenCollectibleDetailButton` exists for exactly
  that reason, and it sits in a third row of the controls pane that is clipped below
  the pane's 160px preferred height, so it is not reachable on screen either.
- **A long left press on an assets row opens the `AssetContextMenu`.** That is by
  design and pre-existing: `StatusMouseArea.onPressAndHold` synthesises a right click
  (`SystemUtils.synthetizeRightClick`, for touch screens). Recorded because it looks
  exactly like a regression when a synthetic click is held too long, and it cost time
  here; a short click navigates to the asset detail as it should.

#### Harness notes from this pass

- The AX bridge's `hover` warps the cursor back immediately, which cancels the hover
  before a tooltip's delay elapses. Use `mousemove` (no cursor restore) to test hover
  states, and `mousedown` + `mouseup --force` for a click, since the guard that
  refuses to inject while a human is active also sees the tool's own `mousedown`.
- Machine load during this measurement: another agent's `QmlTests` process was alive
  in a sibling worktree (idle, ~0.3% CPU) and the load average sat at 3-8. The runs
  were not alternated arms, so this affects absolutes, not the comparison to the
  checked-in history - which was itself recorded at load averages between 4 and 17.

### The gentle cadence: the duty cycle was the load time, and the bite was never the floor

`issues/0016`, measured on the merged tree at `2d758421c6`. Every A/B below is Release,
offscreen, whale profile, arms alternated between rounds, one process per run.

The controller ran a gentle bite of `gentleIntervalMs / 4` where the interval followed the
screen's frame period — **4ms every 16ms, a 24% duty cycle.** Three things were charged to
that constant: `issues/0011`'s preemptibility fix cost 4x, `issues/0012` found a surface
with 14ms of work reading 56ms, and the 3.2ms stall budget was unreachable.

#### Lever 1 — the controller's budget. Bite and interval are independent knobs.

The 2x2, wallet section, 6 rounds per arm, load ~4.8. Medians of `t_first_asset_row_ms`
and `max_stall_ms`, warm:

| gentle bite / interval | duty | headline | `max_stall` |
|---|---|---|---|
| 4 / 17 (baseline) | 24% | 131.9 | 12.1 |
| 2 / 8 | 25% | 117.1 | 13.3 |
| 4 / 8 | 50% | 78.3 | 13.3 |
| 2 / 4 | 50% | 83.0 | 13.0 |

**The duty cycle is the load time and the bite is not.** Halving the bite at constant duty
(4/17 → 2/8) moves the headline by the quantisation it removes, not by the bite; doubling
the duty halves the headline. And **`max_stall_ms` does not respond to the bite at all** —
because a bite is a *lower* bound on the block it produces. `incubateFor(n)` returns only
after finishing the object it is midway through creating, so a block is `bite + overshoot`,
and across every arm above the incubated blocks sat in the same 4 – 7ms band whether the
budget was 2ms or 4ms. That is the finding that dissolves this issue's premise: the two
metrics are only opposed if the interval is pinned to the frame period.

#### Lever 2 — the idle-cadence wake. Real, and then subsumed.

`restart(0)` in `incubatingObjectCountChanged` instead of `restart(m_gentleIntervalMs)`,
8 rounds alternated, load ~4.5. Warm medians: headline **135.5 → 100.4**, `t_ready`
**115.8 → 83.7**, and the mechanism is visible in the block train — the first incubation
bite starts at 23 – 37ms in the baseline and 4 – 22ms with the fast wake. The paired
difference favoured the fast wake in **8 rounds out of 8**. It is worth about *two*
intervals, not one: a warm section load makes two idle → active transitions, not one.
`t_skeleton` did not move (3.4 – 10.8 either way), so the first bite does not delay the
skeleton's paint.

**It is not worth landing once the interval is 4ms.** Four arms, 8 rounds each, load
3.5 – 6.2, warm medians and the `stalls_over_8ms` distribution:

| arm | headline | `max_stall` | `stalls_over_8ms` median / max |
|---|---|---|---|
| 4/17, wake 17 (baseline) | 122.4 | 10.3 | 2 / 3 |
| 2/4, wake 0 | 59.1 | 11.8 | 2 / **4** |
| 2/4, wake 4 (paced) | **55.2** | 12.2 | **1** / 3 |
| 2/6, wake 6 | 75.3 | 10.7 | 2 / 3 |

A 4ms interval already caps the wake at 4ms, so the zero wake buys nothing on the
headline — and it *costs*, because the idle gap is what separated the loader's synchronous
chrome build at t=0 from the first bite. Remove it and the two merge into one longer block:
`0:19.9` where the paced arm reads `0:6.9 10:5.6`. Same total blocked time, worse worst
case. **Lever 1 subsumes lever 2**; only the cadence was changed.

#### Lever 3 — the gentle hint's lifetime. Inert on desktop, and the wrong lever anyway.

First, a correction to the issue's framing: **`StatusSectionLayout` does not hold a gentle
hint on desktop.** `panelSwitchStarted`/`Ended` bracket the portrait *slide*; in landscape
`onCurrentIndexChanged` emits the pair back-to-back in one call, so `pushGentle` and
`popGentle` net to zero before any tick. The gentle regime during a desktop section load
comes entirely from `gentlePeriodMs = 300` in the controller install. Popping the hint
earlier is a mobile-portrait question, not a desktop one.

Measured on the equivalent knob — shortening the gentle window so the burst reaches the
boosted phase — 4 arms, 4 rounds, load ~5, warm medians:

| gentle window | boost pacing | headline | `max_stall` |
|---|---|---|---|
| 300ms (shipped) | — | 123.7 | 11.8 |
| 50ms | 20ms bite, no gap | 112.1 | 19.1 |
| 0ms | 20ms bite, no gap | 103.6 | **36.8** |
| 0ms | 4ms bite every 8ms | **76.8** | 11.6 |

Leaving the gentle phase early buys ~20ms of headline and costs ~25ms of `max_stall`. That
is a bad trade, and the last row says why it was ever tempting: **the problem was never
gentle-versus-boost, it was the bite size and the duty cycle.** A boosted phase of 20ms
bites is what makes `max_stall` explode; 4ms bites at a 50% duty cycle give the boosted
phase's throughput with the gentle phase's responsiveness. The gentle window is left at
300ms and the hint mechanism is untouched.

#### What landed

`BoostedIncubationController`'s gentle cadence is now **a 2ms bite every 4ms**, constants
rather than divisions of the frame period. Nothing else in the controller changed; the
gentle window, the hint mechanism, the boosted phase and the idle poll are as they were.

Dropping the screen coupling is deliberate. Neither quantity is a property of the refresh
rate: the bite bounds how long a posted event waits behind incubation and the interval
bounds how much of the GUI thread incubation takes, both in absolute time. The old
coupling also made the numbers change when a monitor was plugged in — the same objection
that killed the 4ms gate threshold.

`ui/StatusQ/tests/src/tst_incubationcadence.cpp` pins the three properties the rest of this
document now depends on (bite ≤ 2ms, duty ≥ 50%, interval ≤ 8ms) with the reason for each
in the failure message, so the constants cannot be edited back without a bench run. RED
against the old cadence on the first assertion, green after.

**Wallet section**, 8 rounds alternated at load 3.5 – 6.2, warm:

| | before | after |
|---|---|---|
| `t_first_asset_row_ms` | 110.6 - 152.8, median 122.4 | **51.0 - 74.2, median 55.2** (arms do not overlap) |
| `t_ready_ms` | 92.7 - 130.3, median 104.4 | 34.7 - 53.1, median 37.9 |
| `max_stall_ms` | 9.6 - 16.2, median 10.3 | 10.1 - 14.3, median 12.2 |
| `stalls_over_8ms` | 1 - 3, median 2 | 1 - 3, median **1** |
| cold `t_first_asset_row_ms` | 479.8 - 528.2 | 438.2 - 469.3 |
| cold `max_stall_ms` | 342.5 - 363.4 | 341.7 - 359.4 |

**Asset detail**, 8 rounds alternated at load ~4.5 — the second surface required by the
issue, and the one where the surface is already fully preemptible so the cadence is
*all* there is:

| | before | after |
|---|---|---|
| warm `t_content_ms` | 53.7 - 89.8, median 65.1 | **20.1 - 42.9, median 27.2** (no overlap) |
| cold `t_content_ms` | 48.9 - 66.5, median 50.3 | **29.0 - 35.4, median 34.7** (no overlap) |
| warm `max_stall_ms` | 4.3 - 9.8, median 7.4 | 5.3 - 7.0, median 6.6 |
| cold `max_stall_ms` | 8.4 - 12.9, median 12.3 | 9.2 - 11.3, median 9.8 |

On the asset detail **both metrics improve in both phases** — the time by 45 – 60% and the
worst block by 1 – 2.5ms — and the surface lands inside its 40ms host budget without one
object being removed from it. `objects_settled` is 916 (±1) on every run of both arms:
nothing about the graph changed.

Asset detail baseline re-recorded, fourteen runs per phase at load ~4.5:

| | warm | cold | pre-0016 | role |
|---|---|---|---|---|
| `t_ready_ms` | 22.0 - 34.7 | 31.1 - 35.4 | 53.2 / 48.4 | recorded |
| `t_content_ms` | 22.2 - 36.8 | 34.3 - 36.7 | 53.4 / 49.0 | **headline**, recorded (budget 40) |
| `stalls_over_4ms` | 1 - 4 | 4 - 6 | 2 - 7 / 7 - 11 | **gated** (<= 7, was 11) |
| `max_stall_ms` | 4.5 - 6.4 | 9.1 - 11.7 | 6.8 / 7.9 | recorded |
| `objects_settled` | 916 (±1) | 916 (±1) | 916 | gated |

The `stalls_over_4ms` ratchet drops **11 → 7** (observed maximum over twenty-two runs
per phase). It fell because a 2ms bite mostly produces blocks under the 4ms threshold, so
the counter has gone back to meaning roughly what it says instead of counting the cadence —
which is the condition the budgets amendment set for re-gating on it one day.

**On-screen** (`WalletLoaderPage WalletLoader stall-report`, required for anything inside
incubation), 120Hz, one run per arm: warm `t_ready` 115.6 → 109.8 and the block train keeps
its shape — a contiguous run of ~8ms per-frame blocks, as documented before. What differs
is the count of ~16ms blocks inside the load window, i.e. frames the loop missed: six in
the old-cadence run, two in the new one. Single runs, so this is a shape check, not a
measurement — but it is the opposite of the worry that a 50% duty cycle would starve the
frame loop. The unmeasurable risk that remains is the mobile-portrait slide, which is the
only place a gentle hint is actually held; that belongs to whoever owns PR #21921 on a
device.

#### What PR #21921 needs to know

- The gentle bite and interval are now `kGentleBudgetMs = 2` / `kGentleIntervalMs = 4`,
  constants, and `QScreen` is no longer read. `debugGentleIntervalMs()` /
  `debugGentleBudgetMs()` and the HUD are unchanged.
- `incubatingObjectCountChanged` still wakes with `restart(m_gentleIntervalMs)` — the
  zero-interval wake was measured, is worth ~2 intervals on its own, and is **not** worth
  it at a 4ms interval. The measurement is above if the interval ever grows again.
- The boosted phase is untouched and is still the largest single stall source measured
  here: with `gentlePeriodMs = 0` the shipped 20ms budget produces a 34 – 41ms
  `max_stall`. A boosted phase of ~4ms bites at ~50% duty reached the same cold
  throughput with an 11.6ms `max_stall`. That is a controller-budget decision, not a
  wallet one.
- `ui/StatusQ/tests/src/tst_incubationcontroller.cpp` declares
  `statusq_installBoostedIncubationController` with **two** int parameters where the
  definition takes three; its `boostedPhaseMustNotUseAZeroIntervalTimer` case fails on
  this tree both before and after this change, unchanged. Not touched here — it is
  #21921's file and its own RED test.

#### Two gates flake now, and neither was adjusted

Both are consequences of the load finishing sooner, and both are recorded rather than
papered over.

- **`objects_total` cold** reads 2813 or 2942, 2 of 16 runs. This is the same race the
  warm phase always had — the layout pass beating the loaders-Ready stop line — and the
  cold load is simply no longer slow enough to be immune. The gate is cold-only *because*
  cold used to be deterministic, so that premise is gone. Either gate the documented pair,
  or drop it in favour of `objects_settled`, which stayed bit-identical (6022) on all 16
  runs of both arms.
- **`stalls_over_8ms` warm** reads 1 – 2 on a clean run — better than the baseline's 2 – 3 —
  but 4 when the machine hiccups: 0 of 16 in the recorded set at load 3.8 – 4.9, 1 of 16
  in an earlier set at load ~4.5, 2 of 16 at load ~6. The four blocks
  are always the same ones, and none of them is a bite: the loader's synchronous chrome
  build at t=0, two blocks in the `StackView.initialItem` region, and the post-`t_content`
  polish pass. On a clean run the `initialItem` block now falls *below* the threshold
  (2ms bite + a ~5ms sub-creation ≈ 7ms, where 4ms + 5ms ≈ 9ms crossed it) which is why
  the median improved; a scheduling hiccup inflates all four at once. The baseline arm
  reached its ratchet of 3 under the same hiccups. **The ratchet was not raised.** It
  needs re-deriving on a quiet machine, and the structural fix is the post-`t_content`
  pass — `issues/0017`.

#### `issues/0011` re-priced: cheaper, and now pointless

The `StackView.initialItem` fix was deferred because preemptibility cost 4x. It now costs
1.2x. It is still not worth landing, for a different reason.

Same temporary instrumentation as `issues/0011` (`walletContainer` from a `Component` to a
`readonly property Item`, `replace()` call sites unchanged), 8 rounds alternated under the
new cadence, warm:

| | `Component` (current) | `Item` instance |
|---|---|---|
| `t_first_asset_row_ms` | 50.5 - 79.8, median 59.0 | 55.0 - 87.0, median 71.9 |
| `max_stall_ms` | 8.5 - 14.2, median 11.8 | 8.9 - 13.8, median 10.9 |
| `stalls_over_8ms` | 1 - 3, median 1.5 | 1 - 3, median 1 |
| `objects_settled` | 6022, all 8 runs, both phases | **6022 or 6024** |

The tax fell from +48ms to +13ms on the headline, exactly as the duty-cycle change
predicts. But the benefit fell further: `max_stall_ms` and `stalls_over_8ms` overlap
completely, because the block this fix removes is no longer either surface's worst — the
post-`t_content` polish pass and the t=0 chrome build are. And it makes the
`objects_settled` count non-deterministic in both phases, which is a gated invariant -
the one number this whole workstream has been able to trust run to run.

**Verdict: keep it unlanded.** Revisit if `issues/0017` removes the post-`t_content` pass
and the `initialItem` block becomes the worst block again; the settled-count instability
has to be understood first either way.

### The accounts list fills synchronously too, and a shell delegate is worth it here

`issues/0017`, measured at `0af7115b47` in `wt-wallet-loader-storybook`.

**Re-measured before touching anything.** The post-`t_content` block was documented at
12.1 - 13.4ms; on the merged tree, after `issues/0016` changed the cadence and the merge
cut a token row from 326 to 202 objects, it reads **8.7 - 13.5ms over 24 warm runs at load
averages 3 to 12** (medians 10.6 / 12.1 / 11.1 in three separate eight-run sets). Smaller,
and still the surface's worst warm block: on a warm load `max_stall_ms` **is** this block,
run for run, and it is the whole of `stalls_over_8ms`. So the issue was still worth doing.

#### What is in the block — the issue's premise is right, its arithmetic is not

Two corrections to what the block table said.

**`account_delegates` = 8 is four rows, not eight.** `StatusListItem` names its hover
sensor `root.objectName + "_sensor"`, so a prefix count of `walletAccountListItem` counts
each row twice. Measured directly by type: at `t_content` the accounts list holds
**4 realised rows**, and the other four are built in the post-`t_content` block. (The same
doubling applies to `asset_delegates_settled: 26`, which is 13 realised token rows.)

**The block is both lists, not one.** A fill trace sampled every 1ms through the settle
window, warm:

```
    40.35   accountRows=4  shells=0     <- t_content at 38.50
    40.72 ->  50.20   9.48              <- the block
    52.44   accountRows=8  shells=10
```

One synchronous `QQuickItemView` refill pass builds the remaining four account rows **and**
the assets list's `TokenDelegateShell`s. Sampler over the block, n=16: 11/16 `polishItems`,
10/16 `QQuickListViewPrivate::addVisibleItems` → `refill` → `createItem`, plus text layout
and HarfBuzz shaping — no probe frames.

**Sizing the accounts half.** Replacing the accounts delegate with a bare
`Item { width; height: 64 }` (temporary instrumentation, reverted) takes the block from
9.5-12.9 to **5.5 - 7.2ms** over six runs. So the four account rows are worth **~3.8ms**
of it and the shells plus layout are the remaining ~6.8ms. That is the budget for this fix.

#### What landed

`LeftTabView`'s accounts delegate is now a `WalletAccountDelegateShell` — the same shape as
`TokenDelegateShell`: an `Item` carrying the row's geometry and three placeholder tiles,
with the `StatusListItem` behind a nested `asynchronous` `Loader`. The refill builds shells;
the rows incubate afterwards in the controller's metered bites.

Three things had to move with it:

- **Selection lives on the shell.** `viewState.selectedAddress` is compared there and
  `ListView.view.currentIndex` set from there, so the list still tracks the current row
  while the content is incubating — `highlightRangeMode: ApplyRange` needs a current index
  before any row is realised. The content's `highlighted` reads the shell's `selected`.
- **`objectName: "walletAccountListItem"` stays on the `StatusListItem`,** as
  `AssetView_TokenListItem_` stayed on `TokenDelegate`. `test/e2e` matches it with
  `"type": "StatusListItem"` inside `walletAccountsListView`, and Appium matches its
  `resource-id` and `content-desc`; both still resolve. The shell gets
  `walletAccountRowShell`.
- **The footers align against `firstItem.contentItem`, not `firstItem`.** Two
  `StatusFlatButton.spacing` bindings read
  `firstItem.statusListItemTitleArea.anchors.leftMargin`, which is now one level deeper.
  They fall back to `Theme.padding` until the first row realises, and that is the *same*
  number: the margin is `iconOrImage.active ? Theme.padding : …` and an account row always
  has an identicon. `firstItem.height` — the footer background's height — is now the
  shell's 64 from the moment the list lays out, where before it was `undefined` until the
  first row existed, so that one got slightly better.

#### Row height, and the test that gates it

`StatusListItem.implicitHeight` is `Math.max(64, statusListItemTitleArea.height + 16)`, and
an account row is a title plus a subtitle beside a 40px identicon, so it resolves to the
64px floor — confirmed on the live tree: every realised row measured `h=64`.
`WalletAccountDelegateShell.placeholderHeight` is that 64, and
`tst_WalletAccountDelegateShell` gates the two staying equal and gates the height not
moving when the content arrives — so a future change that makes an account row taller
fails a test rather than moving `contentHeight` and the scroll position mid-fill.

The placeholder mirrors `WalletAccountsSkeleton`'s account row (40px circle, 120×14 and
80×12 bars) so the per-tab skeleton and the shells read as one handoff, and it is placed at
`Theme.padding` from the row's left edge — where the real identicon lands — so the
shell → content handoff does not shift horizontally either.

#### Numbers

Release, offscreen, whale profile, arms alternated between rounds, one process per run.
Two independent eight-round sets, at load average ~6 and ~3.

| warm | before | after |
|---|---|---|
| **post-`t_content` block** | 8.7 - 13.5, medians 11.1 / 12.1 | **4.1 - 7.0, medians 6.2 / 5.2** (no overlap) |
| `max_stall_ms` | 8.7 - 14.3, medians 11.6 / 12.5 | **6.9 - 14.2, medians 8.8 / 7.9** |
| `stalls_over_8ms` | 1 - 4 | **0 - 2** (0 - 3 over 54 runs, below) |
| `t_first_asset_row_ms` (headline) | 45.2 - 83.4, medians 67.7 / 61.1 | 40.3 - 72.8, medians 63.8 / 56.2 |
| cold `t_first_asset_row_ms` | 478.9 - 526.2 | 477.8 - 531.9 (overlap) |
| cold `max_stall_ms` | 361.9 - 385.4 | 366.6 - 400.1 (overlap) |

`max_stall_ms` and the headline overlap as ranges, so the paired view is what carries them.
Over the eight alternated rounds of the first set: **`max_stall_ms` improved in 8 of 8**,
by 2.5 - 5.6ms; the headline improved in 6 of 8 and lost 0.8 and 1.6ms in the other two.

**The headline did not pay for this.** `issues/0011` predicted a tax — metered work takes
~1.2x wall clock under the current duty cycle — and the median moved the *other* way, about
5ms down in both sets. The reason is that the accounts rows were never in the incubated
phase to begin with: they were in the polish pass that runs *after* every deferral has
completed and *before* the assets rows can start incubating. Moving them into incubation
lets the assets fill start sooner. That is a property of a post-ready block, not a general
result — `issues/0011`'s block is inside incubation and would still pay the tax.

**Sampler, after.** Same window on the after arm: **zero** samples in `addVisibleItems` /
`refill` / `createItem`, where the before arm had 10 of 16. What is left is
`renderWindow` / `polishItems`, `QQuickLoader::_q_updateSize` for the shells, and 3 of 10
samples in the bench's own `collectSubtree`.

#### The `stalls_over_8ms` warm ratchet does not come down, and here is why

This issue was named as the structural fix for the flaking gate. It fixed the block; it did
not move the ratchet, and the reason is worth recording because the counter has changed
hands.

**The targeted block left the counter entirely.** Classifying every warm block over 8ms by
where it sits in the load:

| block over 8ms | before (n=32 warm runs) | after (n=38) |
|---|---|---|
| post-`t_content` pass | **30** (0.94 per run) | **0** |
| pre-`t_content`, the `StackView.initialItem` region | 18 (0.56) | 17 (0.45) |
| t=0 synchronous chrome build | 2 (0.06) | 1 (0.03) |

So `stalls_over_8ms` no longer counts this list, or the assets list, at all. Every block it
still counts belongs to `issues/0011`.

**The maximum still does not fall below 3.** Over **54 warm after-arm runs** at load
averages 3 to 13 the count read 0 - 2 on 46 of them and **3** on the rest; the before arm
reached **4**, the documented hiccup value, which is a gate *failure* at the ratchet of 3.
The median moved (1.5 → 0.5 - 1) but the ratchet is the maximum, and by this document's own
rule — a ratchet that flakes is worse than no ratchet — 3 is where it stays. What did
change is that the gate stops failing: the hiccup value is now 3 rather than 4.

Cold is left at 3 as well: it read 2 - 3 on 53 of 54 runs and 8 once, on a run at load
average ~13, which is a machine hiccup and not a reason to raise anything.

**This makes `issues/0011` the worst warm block again**, which is the condition its verdict
named for revisiting it; its `objects_settled` instability still has to be understood
first. Its 0.45-blocks-per-run is the whole of the remaining warm counter, and its ~13ms
block is now `max_stall_ms` on most warm runs — which is why `max_stall_ms` overlaps
between the arms while the post-`t_content` block does not.

#### Counts re-recorded

| gate | before | after | why |
|---|---|---|---|
| `objects_settled` | 6022 | **6134** | +112 = 8 shells × 14 objects (shell `Item`, `Loader`, placeholder `Item`, three tiles, and their attached/context objects) |
| `objects_total` (cold) | 2813 | **2869** | +56 = the four shells realised by `t_content`, at the same 14 objects each |
| `account_delegates` | 8 | 8 | unchanged — still four realised rows at `t_content`; the shells are incubated inside the same window |
| `asset_delegates`, `loading_asset_delegates`, `asset_delegates_settled` | 0, 0, 26 | unchanged | |

**`objects_total` still flakes and was not touched.** It reads the recorded value or that
plus 129, in both phases: **6 of 32 before-arm runs and 9 of 38 after-arm runs** — 19% vs
24%, the same rate within noise. The ±129 is bit-identical on both arms, so it is the same
pre-existing race (`issues/0022`), not something this change introduced; the load simply
finishing sooner makes the layout pass win it a little more often. The gate is re-recorded
exactly and left flaking, per that issue's ownership. `objects_settled` was 6134 on all 38
runs of both phases.

#### `account_delegates` had the same disease, and now has the `_settled` cure

Flagged mid-issue off `issues/0022`'s diagnosis of `objects_total`, and fixed here because
this issue is the one that makes it bite.

`account_delegates` counted realised account rows at the loaders-Ready stop line and was
gated on **both** phases. That is a race, not an invariant: the accounts list needs a layout
pass to refill and nothing in the stop line guarantees one has happened. It read **0 on one
warm run in 36 on unmodified code** — the fastest load in that set, `t_ready` 32.1ms — and
`issues/0017` makes that likelier on both counts, because a shell delegate deliberately
changes what exists at the stop line *and* shortens the load.

So the accounts list gets the pair the assets list already had:

| | before | after |
|---|---|---|
| `account_delegates` | gated at 8, both phases | **recorded only** |
| `account_delegates_settled` | — | **gated at 16**, both phases (new TSV column) |

16 is eight rows; see the doubling note above. Verified over **14 runs / 28 phases**,
including the three fastest warm loads in the set (`t_ready` 32.4, 34.6, 35.1ms): 16 every
time, no failures. It is stable because the settle point is defined by the object count
holding still, not by a stop line that a layout pass can outrun.

`asset_delegates` and `loading_asset_delegates` are **not** at risk and stay gated: they
assert a zero, and a faster load makes a zero safer rather than shakier.

**A TSV column arrived.** `account_delegates_settled` is appended last, and the 196
historical rows are backfilled with `-` — the same treatment `stalls_over_8ms` got when it
was added, and it keeps the file rectangular at 18 fields. Anyone merging another copy of
this baseline needs to know the column exists.

#### On-screen

`WalletLoaderPage` on screen, driven through the AX bridge. The section loads through the
accounts skeleton and hands off to real rows; the row pitch, the footer button text
alignment and the "All accounts" card are pixel-unchanged against the before arm; clicking
an account row highlights it and switches the right panel to that account's header,
address, balance and assets, so selection and the `currentIndex` sync survive the move onto
the shell. Both `AccountOrderSync` and `LeftTabView`'s reordering tests exercise the model
reorder path and pass.

Two harness notes for whoever repeats this:

- **The window must be activated before anything renders.** An occluded or background
  Storybook window defers polish, and with `STORYBOOK_INCUBATION_*` slowing the load the
  section then never appears at all — three minutes of blank left panel that looks exactly
  like a hang. `ax activate` first.
- **A mid-fill photograph of this list could not be captured.** Under
  `STORYBOOK_INCUBATION_MS=1 GENTLE_MS=0 GAP_MS=400` the section takes ~44s to load, but
  `ax screenshot` returns the last composited frame while the window is not repainting, so
  a burst across a reload yields byte-identical settled frames or the skeleton phase, never
  the shell phase. The skeleton phase was captured and is the shape the placeholder
  mirrors; the height invariant itself is covered by `tst_WalletAccountDelegateShell`
  rather than by pixels.
- The on-screen `stall-report`, three alternated runs per arm, **overlaps completely**
  (max block in the load window 14.9 - 27.8 before, 17.7 - 28.5 after; blocks over 8ms
  8 - 9 before, 5 - 9 after). On screen the train is per-frame render work at ~7 - 8ms a
  block and a 5ms offscreen difference does not clear that noise. Shape check only: no
  regression, and no confirmation either.

Functional suite after the change: **1873 passed, 2 failed, 5 skipped** — the documented
`ChatTextArea` / `ChatTextView` pair, and +4 over the 1869 baseline for
`tst_WalletAccountDelegateShell`'s two test functions plus init and cleanup.
`tst_AccountOrderSync` and `tst_LeftTabView` both read the row title through
`itemAtIndex(i).contentItem` now; nothing was dropped or skipped.

### `issues/0011` judged a third time, on today's tree: declined for good

`issues/0011` re-opened, measured at `3cf3202970` in `wt-wallet-loader-storybook`. Both prior
A/Bs predate `issues/0017`, so everything below was re-measured from scratch; none of the
earlier numbers for this fix are used.

Arm **A** is the tree as it stands: `WalletLayout.centerPanel` is a `StackView` with
`initialItem: walletContainer`, a `Component`. Arm **B** is the fix: `walletContainer` becomes
a `readonly property Item` holding the `RightTabView`, declared before `centerPanel`, taking
`QQuickStackElement`'s `fromObject` path. The `replace()` call sites are unchanged — they pass
the same id, now an item. Release, offscreen, whale profile, one process per run, **arms
alternated between rounds and the within-round order alternated too**, three independent sets
of 12 / 16 / 24 rounds at load average 9 – 12. `n = 52` runs per arm per phase.

| warm | A (`Component`) | B (`Item` instance) |
|---|---|---|
| `t_first_asset_row_ms` | 40.9 – 79.7, p25 48.3, **med 54.7**, p75 67.0 | 54.1 – 104.6, p25 69.1, **med 77.9**, p75 91.5 |
| `max_stall_ms` | 6.10 – 15.01, med 8.55 | 4.48 – 14.63, med 7.63 |
| `stalls_over_8ms` | `0`×14 `1`×23 `2`×15, **max 2** | `0`×27 `1`×11 `2`×13 `3`×1, **max 3** |
| `objects_settled` | 6134 on 52 / 52 | **6133 ×3, 6134 ×39, 6135 ×1, 6136 ×9** |
| `objects_total` | 2869 / 2998 | 3281 – 3287, seven values |

| cold | A | B |
|---|---|---|
| `t_first_asset_row_ms` | 423 – 496, med 446 | 439 – 547, med 465 |
| `stalls_over_8ms` | `2`×12 `3`×39 `4`×1 | `3`×35 **`4`×17** |
| `objects_settled` | 6134 on 52 / 52 | 6134 ×39, 6136 ×13 |

**The block really is gone, and the counter is inherited anyway.** Classifying every warm
block over 8ms by where it sits, as `issues/0017` does:

| block over 8ms | A (n=52) | B (n=52) |
|---|---|---|
| pre-`t_ready`, inside incubation | **30** (0.58/run), 8.0 – 14.2 | 18 (0.35/run), 8.6 – 10.2 |
| t=0 synchronous chrome build | 11 (0.21/run) | **18** (0.35/run) |
| straddling `t_ready`/`t_content` | 10 (0.19/run) | 4 (0.08/run) |
| post-`t_content` | 1 (0.02/run) | 0 |
| **total** | 1.00/run | 0.77/run |

Sampler (`WALLET_BENCH_SAMPLE=1`) on arm B confirms both halves:

- The residual pre-`t_ready` block (t≈19.6 – 29.2, 9.5ms) carries **no `QQuickStackView` or
  `StackElement` frames at all** — 13 of 14 samples are `incubateFor` →
  `QQmlIncubatorPrivate::incubate` → `QQmlObjectCreator::createInstance` / `setupBindings`,
  with 8 of 14 also inside a V4 `MemoryManager::runGC` pass. It is ordinary incubation
  overshoot — one deep uninterruptible `createInstance` chain plus a GC — sitting in the
  region the `StackView` block used to occupy.
- The t=0 block is the harness's synchronous `WalletLoader`: 21 / 21 samples in
  `QQuickLoader::setActive` → `_q_sourceLoaded` → `QQmlComponent::create(QQmlIncubator&)`
  running to completion. Arm B does not change what it builds, but it **grows** it — median
  4.5 → 5.7ms — enough to cross 8ms in 18 warm runs instead of 11.

**So `stalls_over_8ms` never reaches 0 – 1.** Its maximum, which is what a ratchet is, goes
**up**: 2 on arm A, 3 on arm B. The median improves (1 → 0) and `max_stall_ms` improves by
0.9ms on completely overlapping ranges. That is the whole benefit.

**Cold regresses onto a gated counter.** Arm B adds a second >8ms block to every cold run's
incubation region (1.00 → **2.00** blocks per run, 9.8 – 20.2ms), so cold `stalls_over_8ms`
reads 4 on 17 of 52 runs against a ratchet of 3 — a 33% gate failure rate, where arm A
failed 1 of 52. Landing would mean raising a ratchet, which this document forbids.

#### The `objects_settled` instability is explained: it is Qt's ListView highlight

The previous re-pricing recorded "6022 or 6024" and could not say what the two objects were.
They are, exactly:

```
QQuickItem [kids=0 w=1006 h=64 vis=true] < QQuickItem < StatusListView#assetViewStatusListView
QQuickListViewAttached
```

`QQuickItemViewPrivate::createHighlight` allocates a **plain `QQuickItem`** as the highlight
when no `highlight` component is set, parents it to `contentItem`, sizes it to the current
item — 1006×64 is one assets row — and its `FxViewItem` pulls the item's
`QQuickListViewAttached` into existence. One item, one attached object, +2.

It appears only once the view has a `currentItem`. Census over 12 arm-A phases: **present 0
times**. Over 16 arm-B phases: present in about half. So this is **not** the settle point
firing early — the settle point is fine, and `objects_settled` on arm A is bit-identical on
52 of 52 runs in both phases. It is a genuine two-mode outcome that the change introduces,
because moving `RightTabView` out of the stack's incubator changes when the assets list is
sized and refilled relative to its model, and therefore whether it has acquired a
`currentItem` by the time everything settles. Arm B also widens `objects_total`'s flake from
two values to seven.

This is a datum for `issues/0024`: on the wallet section a settled count that moves is the
*code* moving, not the stop line.

#### Verdict: declined, and this closes the issue

Three independent reasons, any one of which is sufficient:

1. `stalls_over_8ms` does not reach 0 – 1. Warm maximum 3 against arm A's 2; the warm ratchet
   cannot come down, and cold's would have to go **up**.
2. Cold fails its existing ratchet on a third of runs.
3. `objects_settled`, the one number this workstream has been able to trust run to run, becomes
   four-valued — now with a named cause, so it is a real behavioural change rather than
   measurement noise.

And it is more expensive than when it was last declined, not less: median warm
`t_first_asset_row` 54.7 → 77.9ms, **+23.2ms / 1.42x**, against the +13ms / 1.2x recorded
after `issues/0016`, with 2 of 52 runs crossing the 100ms host budget. `issues/0017` shortened
the load, so the same absolute tax is a larger fraction of it.

The condition its verdict named — "revisit when it becomes the worst warm block again" — has
now been tested and answered. It *is* the worst named block, and removing it still does not
move the gate, because two other blocks of the same size sit immediately behind it: the t=0
synchronous chrome build, and plain incubation overshoot with a V4 GC pass inside it. Those
are the next targets, and neither is a `StackView` problem. **Do not re-open this on stall
numbers alone.** It becomes worth landing only if the controller's duty cycle changes
(PR #21921) so the 1.42x tax disappears, and even then the assets list's `currentItem`
two-mode behaviour has to be pinned down first.

**No gate was touched and no ratchet moved.** Arm A's warm `stalls_over_8ms` read 0 – 2 over
these 52 runs, but `issues/0017` observed 3 over 54 runs of the same code, so 3 stays: a
ratchet that flakes is worse than no ratchet, and re-deriving it on a quiet machine is
`issues/0024`'s. Cold arm A read 4 once in 52, the documented hiccup, so cold stays 3 as well.
The bench's TSV was reverted rather than committed — 434 rows of A/B instrumentation, half of
them from code that does not exist, and the file has no arm column to tell them apart.

### `issues/0015`: the identicon's eager cost is its public API, and it is 21 objects

Measured at `f3469ea38f` with a census harness over the settled wallet section, warm and
cold. Counts only - no time claim is made here, and none could be: the whole quantity in
dispute is 0.34% of `objects_settled`.

| | warm | cold |
|---|---|---|
| `StatusSmartIdenticon` instances | 23 | 23 |
| of those, source component realised | 22 | 22 |
| objects in all identicon subtrees | 888 | 888 |
| `StatusAssetSettings` under identicons | 23 (1 each) | 23 |
| ...whose caller replaced `asset`, so the default is waste | **21** | **21** |
| `badge` + `bridgeBadge` objects, all identicons | 253 | 253 |
| `badge` + `bridgeBadge` per identicon | **11.0** | 11.0 |

**23, not 49.** `wallet-load-qml-profile.md` says a warm load builds 49 identicons. The
settled tree holds 23 in both phases. The profiler counts creations across the whole
capture, including subtrees that are torn down again; the gate-relevant number is 23.

**The badge count confirms the peer's measurement: 11.0 objects per instance, 4.1% of
`objects_settled`.** That is twelve times the default-`asset` waste and it is the real
cost in this component - but `badge` and `bridgeBadge` are public aliases that ten call
sites write into with grouped assignments (`badge.border.color:`, `bridgeBadge.image.source:`),
and an alias into a deferred subtree does not work. Left alone, as `issues/0015` expected.

**The default `asset` cannot be removed locally, and the issue's premise is inverted.** The
default is built on every instance and 21 of 23 throw it away, so the waste is real. But
the premise that "~all" callers supply their own object is a wallet-section fact, not an
app-wide one. Across `ui/` and `storybook/`, 55 instantiation sites split:

- **12** assign the whole object (`asset: root.asset`) - these pay for the wasted default,
  and they are the ones that matter by instance count because `StatusListItem` is one of them;
- **37** write into the default with grouped assignments (`asset.name:`, `asset.isImage:`);
- **6** never touch `asset` at all and rely on the default existing.

A QML property default cannot be made conditional on the caller having overridden it - the
default value binding runs during the inner component's own creation, before any outer
binding is applied, which the census confirms directly. So removing it means converting the
37 grouped-assignment sites to whole-object assignment, and that is:

1. **zero-sum for those 37** - the object moves from the component to the caller;
2. **not mechanical** - the default also supplies `width: 40`, `height: 40`,
   `bgWidth: root.width`, `bgHeight: root.height`, `bgRadius: bgWidth / 2`, all bound to the
   *identicon's* geometry. A caller-declared object binds `root` to the caller's file scope,
   so every converted site would have to restate those five and get them right;
3. **spread across HomePage, Communities, Chat, Wallet and Profile**, each needing on-screen
   verification.

Net app-wide win: one `QtObject` per whole-object-assigning identicon - **21 in the wallet
section, 0.34% of `objects_settled`** - for a 37-file public-API migration. Declined. The
same wall `issues/0014` hit with `StatusListItem`'s tag slot and `issues/0015` anticipated
for the badges, reached from the other side: **every eager cost in `StatusSmartIdenticon` is
load-bearing public API.**

The root `Loader` was left synchronous. Nothing measured here gives a reason to revisit the
`issues/0007` hazard, and the component was not touched, so there is no pop-in to measure.

**No code change.** Nothing in the component moved, so `objects_settled` did not move: the
wallet bench reads 6134 on 112 of 112 phases across this issue's runs, and no gate was
re-recorded.

### `issues/0024`: the asset detail's settled count is Qt's lazy `Layout` attached objects

Part 1 - `account_delegates_settled` gated at the settle point, `account_delegates` demoted
to recorded - **was already done by `issues/0017`** (commit `3cf3202970`). Confirmed on this
tree and not duplicated. It was the right call: over 56 wallet runs here, `account_delegates`
read `0` once on a cold load while `account_delegates_settled` read 16 on 112 of 112 phases.

**The `918` is not `issues/0011`'s `createHighlight` pair.** Type histograms over 66 runs
(132 phases), diffed between a 916, a 917 and a 918 run, differ in exactly one type:

```
QQuickLayoutAttached   107  (settled 916)
QQuickLayoutAttached   108  (settled 917)
QQuickLayoutAttached   109  (settled 918)
```

Every other difference between two runs is `_QMLTYPE_<n>` renumbering. There is no
`QQuickItem`/`QQuickListViewAttached` pair, no `currentItem`, no `ListView` involved.

Walking each attached object to its `QObject::parent()` - which is what the probe's
`parentObject()` invokable was added for, since QML does not expose `parent()` for non-Item
types - names the owners precisely. The baseline 107 are stable. The extras are attached
objects owned by **`InformationTag` items themselves**: the per-chain tags in
`AssetsDetailsHeader`, which are `Repeater` delegates inside a `RowLayout`. Qt allocates a
`Layout` attached object lazily, per item, the first time a layout pass needs one, so
whether a given tag has acquired one depends on which layout passes have run. It happens to
invisible tags as well as the one visible tag, so it is not simply a visibility race.

**The settle point is not firing early.** The census holds the count still for 2000ms past
the settle point in every mode - 916 stays 916, 918 stays 918. It is not one drain sample
short of anything; the missing allocation is never going to happen in that process. Forcing
every `QQuickLayout` in the subtree to resolve its implicit size at the settle point changed
nothing (32 phases, `after == settled` every time), which rules out a merely pending layout
pass.

So the conclusion `issues/0011` drew on the wallet section - *a settled count that moves is
the code moving* - **does not generalise to this surface.** Here the movement is Qt's own
lazy bookkeeping, allocated on a schedule the surface does not control and does not converge
on. That is a third category, alongside `objects_total`'s teardown race (`issues/0022`) and
`account_delegates`' layout race (`issues/0017`).

**The fix is the same pattern the workstream already uses: split the metric, gate the part
that is an invariant.**

| metric | role | value |
|---|---|---|
| `objects_settled` | recorded | 916 x103, 917 x28, 918 x1 |
| `layout_attached` | recorded | 107 x103, 108 x28, 109 x1 |
| `objects_built` (= settled - attached) | **gated, tolerance 0** | **809 on 132 of 132 phases** |

`objects_settled` keeps its old meaning and stays visible, so a future regression in the
upper mode is still readable. `objects_built` is what the surface instantiates, and the
tolerance goes from `+/- 1` to `0`. **No gate was loosened** - the gated quantity is
strictly tighter than before, and the spread it used to swallow is now named and recorded.

The `+/- 1` tolerance was indeed hiding a distribution: it was hiding a three-mode one, and
the third mode was what failed.

#### Ratchets re-derived: none can come down, and both cold ratchets flake

Sixty-six asset-detail runs and fifty-six wallet runs on this tree, one process per run.
The machine was not building anything, but it was not idle either - a Status desktop build
was running at ~60% of a core throughout, which inflates stall counts rather than deflating
them, so every maximum below is a conservative upper bound and any ratchet that *could* have
come down would still have been safe to lower.

| bench | phase | metric | observed range | ratchet | verdict |
|---|---|---|---|---|---|
| wallet | warm | `stalls_over_8ms` | 0 - 3 | 3 | holds, cannot come down |
| wallet | cold | `stalls_over_8ms` | 2 - 4 | 3 | **fails 4 / 56 (7%)** |
| asset detail | warm | `stalls_over_4ms` | 0 - 7 | 7 | holds, cannot come down |
| asset detail | cold | `stalls_over_4ms` | 2 - 9 | 7 | **fails 7 / 66 (11%)** |

**A per-phase split of the asset-detail ratchet was tried and reverted.** Over the first
fifty runs warm read 1 - 5, which would have supported a warm ratchet of 5 against cold's 7 -
a real tightening. It read 7 on the fifty-first. A ratchet that flakes is worse than no
ratchet, so the shared value of 7 stands and the attempt is recorded here so nobody spends
the runs again.

**Both cold ratchets sit below their own distributions and neither may be raised.** They were
derived from quiet subsets: the wallet's cold `stalls_over_8ms` read 4 four times here and
the committed baseline carries a 5; the asset detail's cold `stalls_over_4ms` read 8 five
times and 9 twice, and the committed history has 8 - 11 on earlier trees. Classifying the
wallet's cold blocks shows why - after the ~365ms one-time compile block and the ~40ms
incubation block there is a cluster of 4 - 12ms blocks straddling the threshold, and whether
three or four of them cross 8ms is decided by scheduling noise:

```
 pass (3)   0.00->358.93  382.87->387.75  387.76->429.20  453.39->459.10  459.10->468.41(9.3)  468.41->474.66(6.3)
 fail (4)   0.00->371.48  405.52->410.38  410.39->450.55  465.48->474.91(9.4)  484.83->497.03(12.2)
```

**The fix is to remove the marginal block, not to move the line.** Recorded in both benches'
ratchet comments so the next agent does not re-derive this from scratch. Neither ratchet was
touched.

#### Out of scope but worth filing

Three of the asset detail's four chain tags are permanently invisible
(`visible: balancesAggregator.value > 0`) and fully built anyway - the `Repeater` has no
`active`/`Loader` gate. Deferring them would cut real objects from the surface and would
probably take the `layout_attached` spread with it. It changes the `chain_tags` gate, so it
belongs to `issues/0012`, not here.
