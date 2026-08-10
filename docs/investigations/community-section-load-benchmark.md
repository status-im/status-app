# Community section load — benchmark & top offenders

Date: 2026-08-07. Host: macOS M-series, storybook `CommunityChatLoaderPage`
driven by `CommunitySectionMock`. Low-end estimates use a ×10 slowdown factor
(Redmi A5 class), consistent with past device measurements.

## How to reproduce

```bash
# wall-clock (no profiler): READY = refresh → CommunityChatLoader Ready
storybook/build/Qt6.11.0/bin/Storybook.app/Contents/MacOS/Storybook \
    CommunityChatLoader profile-exit [members=N] [categories=N] [channels=N] \
    [messages=N] [membersPanel=1]

# profiled (note: debugger disables the QML disk cache => cold-compile trace;
# add QML_FORCE_DISK_CACHE=1 for warm-equivalent)
qmlprofiler -o out.qtd .../Storybook CommunityChatLoader profile-exit channels=20
```

Analysis scripts (scratchpad): `community_qtd.py` (inclusive), `community_self.py`
(self-time; separate nesting sweeps for the compile vs GUI domains).

## Wall-clock results (median of 3, warm QML cache)

| Config | READY (macOS) | ×10 low-end est. |
|---|---|---|
| base: 20 channels, 500 msgs/chat, 500 members | ~790 ms | ~8 s |
| 210 channels (10 cat × 20 + 2) | ~1300 ms | ~13 s |
| 2000 msgs/chat | ~770 ms | no effect ✓ (virtualized) |
| 5000 members, panel closed | ~800 ms | no effect ✓ (occasional GC outlier +600 ms) |
| cold first open (QML compile, no cache) | +700 ms | first-open penalty; AOT mitigates partly |

**Channels are the only scaling knob: ~2.7 ms/channel row on macOS → ~27 ms/row
low-end.** A 30-channel community adds ~0.8 s, 100 channels ~2.7 s of GUI-thread
work on device, all inside the section incubation (blocks READY).

## Top offenders (ranked by low-end impact)

1. **Channels list is not virtualized.** `CommunityColumnView` wraps
   `StatusChatListAndCategories` in a `StatusScrollView` and expands the inner
   ListView to `contentHeight` (`StatusChatList.qml:14`), so every channel row
   is instantiated at section load. All per-row costs below multiply by the
   full channel count, not the visible count.
   *Fix direction: virtualize (let the ListView scroll itself / height-capped
   viewport), or build rows incrementally after Ready.*

2. **Per-row fat in `StatusChatListItem` rows** (self-time for 212 rows ≈
   500–600 ms total, dominates offender 1):
   - 3 hidden action buttons per row (`StatusFlatRoundButton`), each evaluating
     4–5 color expressions at creation (~77 ms JS total).
   - An eager `StatusToolTip` per item (~26 ms create + 28 ms JS).
   - `ColorImage`/`StatusIcon` per row (75 ms create + 40 ms JS).
   - A `DropArea` per row (drag-reorder) + `StatusDraggableListItem` wrapper
     (37 ms) even for non-admins.
   *Fix direction: Loader-defer buttons/tooltips until hover, gate DropArea on
   admin/drag state.*

3. **Cold compile of never-shown views (~700 ms wall on desktop first open).**
   Inline `Component{}`/type references pull these into the compile graph of
   every community section load: `ControlNodeOfflineCommunityView` (192 ms) +
   `ControlNodeOfflineCenterPanel` (169 ms), `CreateChannelPopup` (49 ms),
   `PermissionsSettingsPanel` (30 ms), `EditPermissionView` (27 ms),
   `ChatContextMenuView` (25 ms), `RenameGroupPopup` (17 ms),
   `BannedMemberCommunityView`, `StatusEmojiSuggestionPopup`…
   *Fix direction: lazy `Loader.setSource(url)` / async `Qt.createComponent`
   for the join/banned/offline full-page views and popups.*

4. **Right-panel (members) show triggers two ~90 ms layout storms** —
   `StatusSectionLayoutLandscape.qml:251` (`opacity: showRightPanel ? 1 : 0`
   flip relayouts the SplitView) and `ChatView.qml:324` (UserListPanel
   `visible` flip pays the whole panel polish), each evaluated twice during the
   skeleton→real swap. ~180 ms desktop → ~2 s low-end for opening members.
   The 5000-member list itself is fine (virtualized + latched mention adaptor).

5. **`StatusScrollBar.resolveVisibility`** ran 690× (~72 ms) during the list
   fill — reevaluated on every contentHeight change while rows append. Scales
   with channel count.

6. **Skeleton build cost**: `CommunityChannelsSkeleton` rows are nested
   QtQuick.Layouts; measured up to 150 ms create+polish in one run (~7 ms/row).
   Skeletons must be near-free — plain `Column`/`Row` instead of Layouts.

## Non-issues (verified)

- Message history size: no READY effect (`modelActive` gating + virtualization).
- Community members count: no effect until the panel opens; the members list is
  virtualized.
- Token permissions / join-state variants: negligible at load.

## Fixes landed (2026-08-07, same session)

Offenders 1, 2, 5, 6 addressed (3 and 4 remain follow-ups):

1. **Row-type delegate split** (`StatusChatList`): each row builds only its
   own type via a Loader — previously every delegate instantiated BOTH a
   `StatusChatListCategoryItem` and a `StatusChatListItem` (one hidden), so
   212 category items existed for 10 categories.
2. **Admin-only drag machinery**: the `DropArea` + `StatusDraggableListItem`
   wrappers only exist when `draggableItems`; members get the bare row.
3. **Virtualized member channels list**: `StatusChatListAndCategories` gained
   a `virtualized` mode (bounded, self-scrolling list); `CommunityColumnView`
   enables it for non-admins. Admins keep the expanded list inside the
   ScrollView — drag-reorder addresses rows across the whole list — with their
   banners below. 212-row config now builds ~20 delegates instead of 213.
4. **Lazy muted-icon chrome** (`StatusChatListItem`): icon + sensor + unmute
   tooltip only exist on actually-muted rows.
5. **Skeleton diet**: all chat/community skeletons switched from
   QtQuick.Layouts to plain positioners (`MembersListSkeleton` alone showed up
   to 105 ms of Layout polish with the panel closed).

### After (interleaved medians, warm cache, macOS)

| Config | Before | After |
|---|---|---|
| base (20 channels) | ~790 ms | **~525 ms** |
| 30 channels | ~850 ms (est.) | **~585 ms** |
| 210 channels | ~1300 ms | **~550 ms** (flat) |
| members panel on, 5000 members | n/a | ~635 ms |

Per-channel load cost is eliminated (was ~2.7 ms/row → ~27 ms/row low-end).
Estimated low-end base load: ~8 s → **~5.5 s**; large communities no longer
pay a channels penalty at all.

Note: an earlier "residual scaling" measurement was a benchmarking artifact —
sequential same-config batches absorb cache/thermal effects into the first
config measured. Interleave configs round-robin when comparing.

## Device validation (2026-08-08, Redmi-class, warmstart9.qzt + simpleperf)

Community open measured ~3.7 s (loadSection @53.97 s → panel swap @57.7 s in
the QML trace). **Not the backend**: no status-go thread shows meaningful CPU
in simpleperf; the GUI thread is saturated (~4.1 s CPU in the window) and the
render + Mali threads burn ~3.3 s combined. Breakdown:

| Cost | Evidence |
|---|---|
| `setActiveSectionById` — one 477 ms synchronous call at switch start | qzt: `RootStore.qml:111`, 376 ms self — nim section-activation work blocking the GUI thread |
| Message tail build ~0.4–0.8 s | qzt: 386 ms billed under `ChatMessagesView` `cacheBuffer` binding (ListView populating cache synchronously) + `MessageView` Loaders 239 ms total + avatar loaders streaming until ~59.8 s |
| Skeleton + chrome build ~0.3 s wall | markers 54.0→54.9 s — interleaved with incubation slices |
| Shimmer render cost for the whole 4 s | `LoadingSkeletonGroup` OpacityMask sweep (XAnimator @54.06 s) keeps render+GPU threads busy; glDrawElements/glBindFramebuffer dominate QtThread (2.3 s) |
| `StatusScrollBar.resolveVisibility` | 107 ms / 53 calls (offender 5 — still alive on device) |
| `QResource::isValid/fileName` 175 ms | qrc lookups (icons/emoji) on the GUI thread |
| Profiler tax ~0.5 s | `QQmlProfiler::reportData` + QQmlDebugServer thread — unprofiled UX likely ~3.2 s |
| Pre-open retry loop ~1 s (first open only) | log: `AppMain: active community section … not present in repeater (count=22)` ×7 @06:58:08 — switching before the sections repeater has the row |

Device fix candidates, ranked: (1) make the nim section-activation async or
slimmer; (2) cap the initial message tail / defer `cacheBuffer` until after
first paint on mobile; (3) cheaper skeleton shimmer on low-end (no OpacityMask
over the whole panel); (4) debounce `resolveVisibility`; (5) fix the
section-repeater retry loop.

### Fixes landed for the device path (2026-08-08)

1. **First-show model latch** (`ChatContentView`): the messages model attaches
   only once the chat is effectively visible (section swap done), latched.
   Message tail + avatars no longer build inside the incubation window.
2. **Boosted incubation controller** (`statusq_installBoostedIncubationController`,
   installed at app boot with a 20 ms budget per event-loop tick): replaces the
   render-loop-driven default whose budget collapses when frames are slow —
   which is precisely the low-end-device condition.

A/B on the storybook page (`STORYBOOK_INCUBATION_MS=20`), interleaved: on an
idle machine boost takes the 210-channel load 857→441 ms; on a CPU-contended
machine (simulating a slow device) the default controller balloons to
**5.4–8.1 s** while boost stays **flat at 400–490 ms** — a 10–15× difference
and load-independent. The device's 3.7 s skeleton is this starvation.

## Baseline guards

`tst_CommunityChatLoaderSection` (12 tests) now enforces: row-type split
(no hidden twins), no drag machinery for members (kept for admins),
virtualization (<60 delegates for 212 rows), lazy muted tooltips, load cost
bounded at `large < small * 1.5 + 500ms`, and the join-state routing.
Follow-ups: offender 3 (lazy-compile never-shown views), offender 4
(members-panel layout storms), app-wide lazy button tooltips
(`StatusBaseButton`/`StatusFlatRoundButton` `tooltip` is public alias API).
Admin drag-and-drop needs a manual storybook check (no automated DnD test).
