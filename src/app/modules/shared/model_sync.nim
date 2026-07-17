# Model Synchronization Utilities
#
# Efficient utilities for synchronizing Qt models with new data without a
# full model reset. Calculates a minimal diff and applies granular updates
# (insertRows / removeRows / dataChanged).
#
# ----------------------------------------------------------------------------
# Public API — this is all a consumer needs
# ----------------------------------------------------------------------------
#
#   modelSync(model, container, newItems)          -- granular sync, one-liner
#   reconcileByKey(table, items, create, update)   -- keyed nested child models
#
# `modelSync` collapses the whole sync into a single call. Declare two overloads
# next to your item type; `modelSync` picks them up at instantiation via `mixin`,
# the same way `hash` / `==` / `$` are resolved:
#
#   proc syncKey(it: MyItem): string = it.key        # row identity (required)
#   proc syncRoles(o, n: MyItem): seq[int] = ...      # changed role ints (optional)
#
# then, wherever the model receives fresh data:
#
#   self.modelSync(self.items, newItems)
#
# `self.items` is the model's own `seq[MyItem]` backing field; `modelSync` mutates
# it in lockstep with the begin*/end* signals it emits, so `rowCount()` / `data()`
# always read consistent state. `newItems` is consumed (sink) — the caller must
# not reuse it after the call; its rows are copied into `container` as the diff
# inserts them. The model's `countChanged()` fires automatically when the type
# declares one. Omitting
# `syncRoles` syncs the row SET only (insert/remove, no dataChanged).
#
# Nested / keyed child models (a per-row sub-model or QObject):
#
#   reconcileByKey(self.childrenByKey, newItems,
#     create = proc(it: MyItem): ChildModel = newChildModel(it),
#     update = proc(c: ChildModel, it: MyItem) = c.update(it))
#   self.modelSync(self.items, newItems)
#
# Run `reconcileByKey` BEFORE `modelSync` so a freshly inserted row's `data()`
# already sees its child. It keeps the `C` for a surviving key and drops removed
# keys — this replaces the older per-row onInsert/onUpdate/onRemove callbacks.
#
# ----------------------------------------------------------------------------
# Operation order and index semantics
# ----------------------------------------------------------------------------
#
# The apply pass walks operations in this order:
#   1. removes  (descending index order, so earlier removes don't shift the
#                indices of later ones)
#   2. updates  (with indices adjusted for the removes that just happened)
#   3. inserts  (in ascending newIdx order)
#
# Reorder handling: items whose id exists in both lists but at non-stable
# positions (per LIS) are emitted as remove+insert pairs. There is no Qt
# moveRows emission.
#
# Whole-list fast paths: first load (empty -> N) and full clear (N -> empty) use
# beginResetModel/endResetModel instead of walking the diff. (An append onto a
# non-empty model runs the normal diff — there is no dedicated append fast path.)
#
# ----------------------------------------------------------------------------
# Internals (exported for unit tests, NOT part of the consumer surface)
# ----------------------------------------------------------------------------
#
# `setItemsWithSync` (the explicit-closure form `modelSync` delegates to),
# `syncModel` (pure diff -> SyncResult), `applySync` / `applySyncWithBulkOps`
# (the apply passes) and `groupConsecutiveRanges` are lower-level building blocks.
# They carry the granular test coverage; new consumers should reach for
# `modelSync` / `reconcileByKey` above, never these directly.

import nimqml, tables, algorithm, sequtils, sets

# Spy support for testing (only active when QT_MODEL_SPY is defined)
when defined(QT_MODEL_SPY):
  import qt_model_spy

type
  ItemIdentifier*[T] = proc(item: T): string {.closure.}
  RoleDetector*[T] = proc(oldItem, newItem: T): seq[int] {.closure.}
  UpdateItemCallback*[T] = proc(existing: T, updated: T) {.closure.}

  # Discriminated side-effect callbacks. Each fires at the moment the
  # corresponding sync operation completes against the model's `items` seq.
  OnInsertCallback*[T] = proc(idx: int, item: T) {.closure.}
  OnUpdateCallback*[T] = proc(idx: int, oldItem, newItem: T) {.closure.}
  OnRemoveCallback* = proc(idx: int) {.closure.}

  UpdateOp*[T] = object
    index*: int
    item*: T
    roles*: seq[int]

  InsertOp*[T] = object
    index*: int
    item*: T

  RemoveOp* = object
    index*: int

  SyncResult*[T] = object
    toInsert*: seq[InsertOp[T]]
    toRemove*: seq[RemoveOp]
    toUpdate*: seq[UpdateOp[T]]
    hasChanges*: bool

proc longestIncreasingSubseqIndices(values: openArray[int]): HashSet[int] =
  ## Returns the SET of indices into `values` that participate in the longest
  ## strictly-increasing subsequence. Standard O(n log n) patience sort with
  ## parent pointers.
  result = initHashSet[int]()
  if values.len == 0:
    return

  var tails: seq[int] = @[]   # tails[i] = index into values for the smallest tail of an LIS of length i+1
  var prev = newSeq[int](values.len)
  for i in 0..<values.len:
    prev[i] = -1

  for i, x in values:
    var lo = 0
    var hi = tails.len
    while lo < hi:
      let mid = (lo + hi) div 2
      if values[tails[mid]] < x: lo = mid + 1
      else: hi = mid
    if lo > 0:
      prev[i] = tails[lo - 1]
    if lo == tails.len:
      tails.add(i)
    else:
      tails[lo] = i

  if tails.len == 0:
    return
  var k = tails[tails.high]
  while k != -1:
    result.incl(k)
    k = prev[k]

proc syncModel*[T](
  oldItems: openArray[T],
  newItems: openArray[T],
  getId: ItemIdentifier[T],
  getRoles: RoleDetector[T] = nil
): SyncResult[T] =
  ## Computes the minimal set of operations needed to transform `oldItems`
  ## into `newItems`.
  ##
  ## Reorderings are detected via LIS over the items present in both lists:
  ## items participating in the LIS keep their position (emitted as updates
  ## only); items outside the LIS are emitted as remove+insert pairs. This
  ## handles pure inserts, pure removes, and arbitrary mixed orderings without
  ## false positives.
  ##
  ## Complexity: O((n + m) log m) where n = oldItems.len, m = items present in
  ## both lists. In the steady state (no reorders) the LIS covers everything
  ## and it degrades to O(n).

  result.hasChanges = false

  if oldItems.len == 0 and newItems.len == 0:
    return

  if oldItems.len == 0:
    for i, item in newItems:
      result.toInsert.add(InsertOp[T](index: i, item: item))
    result.hasChanges = true
    return

  if newItems.len == 0:
    for i in countdown(oldItems.high, 0):
      result.toRemove.add(RemoveOp(index: i))
    result.hasChanges = true
    return

  # O(1) id lookup for old items.
  var oldMap = initTable[string, int]()
  for i, item in oldItems:
    oldMap[getId(item)] = i

  # Build the "common" sequence: pairs (oldIdx, newIdx) for ids present in both
  # lists, walked in newItems order. It is sorted ascending by newIdx by
  # construction; LIS over the oldIdx values finds which pairs can stay put.
  type Common = tuple[oldIdx: int, newIdx: int]
  var common: seq[Common] = @[]
  for newIdx, newItem in newItems:
    let id = getId(newItem)
    if oldMap.hasKey(id):
      common.add((oldMap[id], newIdx))

  let stable = longestIncreasingSubseqIndices(common.mapIt(it.oldIdx))

  var keepOld = newSeq[bool](oldItems.len)

  # Phase 1: walk new items, emit updates for stable rows and inserts for the rest.
  var commonPtr = 0
  for newIdx, newItem in newItems:
    let id = getId(newItem)
    if oldMap.hasKey(id):
      while commonPtr < common.len and common[commonPtr].newIdx < newIdx:
        inc commonPtr
      let isStable = commonPtr < common.len and
                     common[commonPtr].newIdx == newIdx and
                     commonPtr in stable
      if isStable:
        let oldIdx = common[commonPtr].oldIdx
        keepOld[oldIdx] = true
        if getRoles != nil:
          let changedRoles = getRoles(oldItems[oldIdx], newItem)
          if changedRoles.len > 0:
            result.toUpdate.add(UpdateOp[T](
              index: oldIdx,
              item: newItem,
              roles: changedRoles
            ))
            result.hasChanges = true
      else:
        # Reorder: insert now, the corresponding old position is removed in
        # Phase 2 because keepOld stays false.
        result.toInsert.add(InsertOp[T](index: newIdx, item: newItem))
        result.hasChanges = true
    else:
      result.toInsert.add(InsertOp[T](index: newIdx, item: newItem))
      result.hasChanges = true

  # Phase 2: removes - everything in old that wasn't kept by the LIS.
  # Descending order so successive removals don't invalidate earlier indices.
  for i in countdown(oldItems.high, 0):
    if not keepOld[i]:
      result.toRemove.add(RemoveOp(index: i))
      result.hasChanges = true

proc groupConsecutiveRanges*(indices: seq[int]): seq[tuple[first: int, last: int]] =
  ## Groups consecutive integers into ranges for bulk operations.
  ## Example: [0,1,2,5,6,9] -> [(0,2), (5,6), (9,9)]
  if indices.len == 0:
    return @[]

  var sorted = indices
  sorted.sort()

  var currentFirst = sorted[0]
  var currentLast = sorted[0]

  for i in 1..sorted.high:
    if sorted[i] == currentLast + 1:
      currentLast = sorted[i]
    else:
      result.add((currentFirst, currentLast))
      currentFirst = sorted[i]
      currentLast = sorted[i]

  result.add((currentFirst, currentLast))

proc adjustForRemoves(updates: seq[UpdateOp], removes: seq[RemoveOp]): seq[tuple[adjustedIdx: int, originalIdx: int]] =
  ## For each update, compute its index after the (descending) removes have
  ## been applied. O(R + U): sort updates by index ascending, walk a single
  ## pointer through the ascending remove indices, accumulate the offset.
  ## Precondition: `removes` is in descending order (as syncModel emits).
  result = newSeq[tuple[adjustedIdx: int, originalIdx: int]](updates.len)
  if updates.len == 0:
    return

  var removeIdxAsc = newSeq[int](removes.len)
  for i, r in removes:
    removeIdxAsc[i] = r.index
  removeIdxAsc.sort()

  type Slot = tuple[origIdx: int, slot: int]
  var sortedSlots = newSeq[Slot](updates.len)
  for i, u in updates:
    sortedSlots[i] = (u.index, i)
  sortedSlots.sort(proc(a, b: Slot): int = cmp(a.origIdx, b.origIdx))

  var removePtr = 0
  var offset = 0
  for entry in sortedSlots:
    while removePtr < removeIdxAsc.len and removeIdxAsc[removePtr] < entry.origIdx:
      inc offset
      inc removePtr
    result[entry.slot] = (entry.origIdx - offset, entry.origIdx)

proc applySync*[T](
  model: QAbstractListModel,
  items: var seq[T],
  syncResult: SyncResult[T],
  updateItem: UpdateItemCallback[T] = nil,
  onInsert: OnInsertCallback[T] = nil,
  onUpdate: OnUpdateCallback[T] = nil,
  onRemove: OnRemoveCallback = nil,
) =
  ## Applies a SyncResult to a Qt model with proper notifications.
  ## Order of operations: removes (descending) -> updates -> inserts.
  ## Side-effect callbacks fire AFTER the corresponding `items` mutation and
  ## AFTER the matching Qt signal pair, so they observe the post-op state.

  if not syncResult.hasChanges:
    return

  let parentIndex = newQModelIndex()
  defer: parentIndex.delete

  # Step 1: removes (already in descending order from syncModel).
  for removeOp in syncResult.toRemove:
    let removedIdx = removeOp.index
    when defined(QT_MODEL_SPY):
      recordBeginRemoveRows(removedIdx, removedIdx)
    model.beginRemoveRows(parentIndex, removedIdx, removedIdx)
    items.delete(removedIdx)
    model.endRemoveRows()
    when defined(QT_MODEL_SPY):
      recordEndRemoveRows()
    if not onRemove.isNil:
      onRemove(removedIdx)

  # Step 2: updates. Adjust indices for the removes that already happened.
  let adjusted = adjustForRemoves(syncResult.toUpdate, syncResult.toRemove)
  for i, info in adjusted:
    let adjustedIdx = info.adjustedIdx
    if adjustedIdx < 0 or adjustedIdx >= items.len:
      continue
    let updateOp = syncResult.toUpdate[i]
    let oldItem = items[adjustedIdx]

    if updateItem != nil:
      # Pattern 5: call setters on existing item (QObject-exposing models).
      updateItem(items[adjustedIdx], updateOp.item)
    else:
      items[adjustedIdx] = updateOp.item
      when defined(QT_MODEL_SPY):
        recordDataChanged(adjustedIdx, adjustedIdx, updateOp.roles)
      let modelIndex = model.createIndex(adjustedIdx, 0, nil)
      model.dataChanged(modelIndex, modelIndex, updateOp.roles)
      modelIndex.delete  # release immediately - defer would leak per iteration

    if not onUpdate.isNil:
      onUpdate(adjustedIdx, oldItem, items[adjustedIdx])

  # Step 3: inserts (in ascending newIdx order from syncModel).
  for insertOp in syncResult.toInsert:
    var insertIdx = insertOp.index
    if insertIdx < 0:
      insertIdx = 0
    elif insertIdx > items.len:
      insertIdx = items.len

    when defined(QT_MODEL_SPY):
      recordBeginInsertRows(insertIdx, insertIdx)
    model.beginInsertRows(parentIndex, insertIdx, insertIdx)
    items.insert(insertOp.item, insertIdx)
    model.endInsertRows()
    when defined(QT_MODEL_SPY):
      recordEndInsertRows()

    if not onInsert.isNil:
      onInsert(insertIdx, items[insertIdx])

proc applySyncWithBulkOps*[T](
  model: QAbstractListModel,
  items: var seq[T],
  syncResult: SyncResult[T],
  updateItem: UpdateItemCallback[T] = nil,
  onInsert: OnInsertCallback[T] = nil,
  onUpdate: OnUpdateCallback[T] = nil,
  onRemove: OnRemoveCallback = nil,
) =
  ## Optimized applySync that groups consecutive operations into bulk Qt
  ## notifications where possible.

  if not syncResult.hasChanges:
    return

  let parentIndex = newQModelIndex()
  defer: parentIndex.delete

  # Step 1: bulk removes. Remove indices come descending; group them ascending
  # then iterate the groups in reverse so each group's removal does not
  # invalidate earlier-indexed groups.
  if syncResult.toRemove.len > 0:
    let indices = syncResult.toRemove.mapIt(it.index)
    let ranges = groupConsecutiveRanges(indices)

    for i in countdown(ranges.high, 0):
      let (first, last) = ranges[i]
      when defined(QT_MODEL_SPY):
        recordBeginRemoveRows(first, last)
      model.beginRemoveRows(parentIndex, first, last)
      for j in countdown(last, first):
        items.delete(j)
      model.endRemoveRows()
      when defined(QT_MODEL_SPY):
        recordEndRemoveRows()
      if not onRemove.isNil:
        for j in countdown(last, first):
          onRemove(j)

  # Step 2: bulk updates. Group consecutive updates with identical role sets
  # into a single ranged dataChanged.
  if syncResult.toUpdate.len > 0:
    let adjusted = adjustForRemoves(syncResult.toUpdate, syncResult.toRemove)

    type AdjustedUpdate = tuple[adjustedIdx: int, item: T, roles: seq[int]]
    var adjustedUpdates: seq[AdjustedUpdate] = @[]
    for i, info in adjusted:
      if info.adjustedIdx >= 0 and info.adjustedIdx < items.len:
        let u = syncResult.toUpdate[i]
        adjustedUpdates.add((info.adjustedIdx, u.item, u.roles))

    adjustedUpdates.sort(proc(a, b: AdjustedUpdate): int = cmp(a.adjustedIdx, b.adjustedIdx))

    if updateItem != nil:
      for u in adjustedUpdates:
        let oldItem = items[u.adjustedIdx]
        updateItem(items[u.adjustedIdx], u.item)
        if not onUpdate.isNil:
          onUpdate(u.adjustedIdx, oldItem, items[u.adjustedIdx])
    else:
      var i = 0
      while i < adjustedUpdates.len:
        let startIdx = adjustedUpdates[i].adjustedIdx
        let roles = adjustedUpdates[i].roles
        var endIdx = startIdx

        var oldItems: seq[T] = @[items[startIdx]]
        items[startIdx] = adjustedUpdates[i].item

        var j = i + 1
        while j < adjustedUpdates.len:
          if adjustedUpdates[j].adjustedIdx == endIdx + 1 and
             adjustedUpdates[j].roles == roles:
            endIdx = adjustedUpdates[j].adjustedIdx
            oldItems.add(items[endIdx])
            items[endIdx] = adjustedUpdates[j].item
            j.inc
          else:
            break

        when defined(QT_MODEL_SPY):
          recordDataChanged(startIdx, endIdx, roles)
        let startModelIdx = model.createIndex(startIdx, 0, nil)
        let endModelIdx = model.createIndex(endIdx, 0, nil)
        model.dataChanged(startModelIdx, endModelIdx, roles)
        startModelIdx.delete()
        endModelIdx.delete()

        if not onUpdate.isNil:
          for k in 0 .. (endIdx - startIdx):
            onUpdate(startIdx + k, oldItems[k], items[startIdx + k])

        i = j

  # Step 3: bulk inserts. Sort by index, group consecutive runs into a single
  # beginInsertRows/endInsertRows call.
  if syncResult.toInsert.len > 0:
    var sortedInserts = syncResult.toInsert
    sortedInserts.sort(proc(a, b: InsertOp[T]): int = cmp(a.index, b.index))

    var i = 0
    while i < sortedInserts.len:
      let startIdx = sortedInserts[i].index
      var endIdx = startIdx
      var insertItems: seq[T] = @[sortedInserts[i].item]

      var j = i + 1
      while j < sortedInserts.len and sortedInserts[j].index == endIdx + 1:
        endIdx = sortedInserts[j].index
        insertItems.add(sortedInserts[j].item)
        j.inc

      var actualStartIdx = startIdx
      if actualStartIdx < 0: actualStartIdx = 0
      elif actualStartIdx > items.len: actualStartIdx = items.len

      when defined(QT_MODEL_SPY):
        recordBeginInsertRows(actualStartIdx, actualStartIdx + insertItems.len - 1)
      model.beginInsertRows(parentIndex, actualStartIdx, actualStartIdx + insertItems.len - 1)
      for k, item in insertItems:
        items.insert(item, actualStartIdx + k)
      model.endInsertRows()
      when defined(QT_MODEL_SPY):
        recordEndInsertRows()

      if not onInsert.isNil:
        for k in 0..<insertItems.len:
          onInsert(actualStartIdx + k, items[actualStartIdx + k])

      i = j

proc setItemsWithSync*[T](
  model: QAbstractListModel,
  items: var seq[T],
  newItems: openArray[T],
  getId: ItemIdentifier[T],
  getRoles: RoleDetector[T] = nil,
  updateItem: UpdateItemCallback[T] = nil,
  countChanged: proc() {.closure.} = nil,
  useBulkOps: bool = false,
  onInsert: OnInsertCallback[T] = nil,
  onUpdate: OnUpdateCallback[T] = nil,
  onRemove: OnRemoveCallback = nil,
) =
  ## Lower-level, explicit-closure form of the sync (a drop-in replacement for
  ## the begin/endResetModel pattern). Prefer `modelSync` — see the file header;
  ## this is the proc `modelSync` delegates to, kept exported for the unit tests
  ## and for the rare model that needs a closure `modelSync` doesn't expose:
  ##   - `updateItem`: for QObject-exposing rows, call setters on the existing
  ##     item instead of emitting dataChanged.
  ##   - `getRoles`: emit ranged dataChanged for the changed roles.
  ##   - `onInsert` / `onUpdate` / `onRemove`: keep a sibling `seq[NestedModel]`
  ##     in sync with `items` (the v3 API uses `reconcileByKey` for this instead).

  # Debug/test contract: input keys must be unique (repo `key` convention). A
  # duplicate would make the diff's id->index map last-wins and emit a spurious
  # insert/remove for the shadowed row. Runs in debug app builds and in the
  # spy-instrumented test/bench builds (which are -d:release); compiled out of
  # shipping release builds.
  when defined(QT_MODEL_SPY) or not defined(release):
    if getId != nil:
      var seenKeys = initHashSet[string]()
      for it in newItems:
        let k = getId(it)
        doAssert not seenKeys.containsOrIncl(k),
          "setItemsWithSync: duplicate key in newItems: " & k

  # Fast path: first load (empty -> N). The diff pipeline deep-copies every T
  # several times as it walks; bulk-load via beginResetModel instead.
  if items.len == 0 and newItems.len > 0:
    let parentIndex = newQModelIndex()
    defer: parentIndex.delete
    when defined(QT_MODEL_SPY):
      recordBeginResetModel()
    model.beginResetModel()
    items = @newItems
    model.endResetModel()
    when defined(QT_MODEL_SPY):
      recordEndResetModel()
    if not onInsert.isNil:
      for i in 0 ..< items.len:
        onInsert(i, items[i])
    if countChanged != nil:
      countChanged()
    return

  # Fast path: full clear (N -> empty).
  if items.len > 0 and newItems.len == 0:
    let parentIndex = newQModelIndex()
    defer: parentIndex.delete
    when defined(QT_MODEL_SPY):
      recordBeginResetModel()
    model.beginResetModel()
    let oldLen = items.len
    items.setLen(0)
    model.endResetModel()
    when defined(QT_MODEL_SPY):
      recordEndResetModel()
    if not onRemove.isNil:
      for i in countdown(oldLen - 1, 0):
        onRemove(i)
    if countChanged != nil:
      countChanged()
    return

  let syncResult = syncModel(items, newItems, getId, getRoles)

  if syncResult.hasChanges:
    if useBulkOps:
      model.applySyncWithBulkOps(items, syncResult, updateItem, onInsert, onUpdate, onRemove)
    else:
      model.applySync(items, syncResult, updateItem, onInsert, onUpdate, onRemove)

    if countChanged != nil and (syncResult.toInsert.len > 0 or syncResult.toRemove.len > 0):
      countChanged()

# `modelSync` is the primary consumer API — see the file header for the
# `syncKey` / `syncRoles` protocol and usage. It collapses the four-closure
# `setItemsWithSync` call into a one-liner and always uses the bulk-ops path
# (grouped inserts/removes, ranged dataChanged) plus QT_MODEL_SPY instrumentation.

proc modelSync*[M: QAbstractListModel, T](
    model: M, container: var seq[T], newItems: sink seq[T]) =
  ## Unified granular sync. `container` becomes the new state in lockstep with the
  ## begin/end signals `modelSync` emits; `newItems` is consumed (sink) — the caller
  ## must not reuse it after the call; rows are copied into `container` as needed.
  ## Requires `syncKey(T): string` in scope; `syncRoles(T, T): seq[int]` optional
  ## (omit for identity-only rows). Emits `model.countChanged()` if it exists.
  mixin syncKey, syncRoles, countChanged
  # DX guard: surface the missing-overload requirement at the CALLER's instantiation
  # instead of failing deep inside the getId closure with a bare "undeclared
  # identifier: 'syncKey'". Fires per-instantiation on the offending T.
  when not compiles(syncKey(newItems[0])):
    {.error: "modelSync requires `proc syncKey(it: T): string` declared before this call " &
      "(and optional `proc syncRoles(o, n: T): seq[int]`) near the item type T — see the " &
      "model_sync.nim v3 header.".}
  let getId = proc(it: T): string = syncKey(it)
  var getRoles: RoleDetector[T] = nil
  when compiles(syncRoles(newItems[0], newItems[0])):
    getRoles = proc(o, n: T): seq[int] = syncRoles(o, n)
  var cc: proc() {.closure.} = nil
  when compiles(model.countChanged()):
    cc = proc() = model.countChanged()
  setItemsWithSync(
    model.QAbstractListModel, container, newItems,
    getId = getId,
    getRoles = getRoles,
    countChanged = cc,
    useBulkOps = true)

proc reconcileByKey*[T, C](
    table: var Table[string, C],
    items: openArray[T],
    create: proc(it: T): C {.closure.},
    update: proc(existing: C, it: T) {.closure.} = nil) =
  ## Rebuilds `table` to exactly the keys of `items` (via `syncKey`), preserving
  ## the existing `C` for a surviving key (calling `update` if given) and building
  ## a fresh one otherwise. Dropped keys fall away with the old table. Run this
  ## BEFORE `modelSync` so a newly inserted row's `data()` already sees its child.
  mixin syncKey
  var updated = initTable[string, C]()
  for it in items:
    let k = syncKey(it)
    if table.hasKey(k):
      let existing = table[k]
      if update != nil:
        update(existing, it)
      updated[k] = existing
    else:
      updated[k] = create(it)
  table = updated

# Export main types and procs
export ItemIdentifier, RoleDetector
export OnInsertCallback, OnUpdateCallback, OnRemoveCallback
export UpdateOp, InsertOp, RemoveOp, SyncResult
export syncModel, applySync, applySyncWithBulkOps, setItemsWithSync
export groupConsecutiveRanges
export modelSync, reconcileByKey
