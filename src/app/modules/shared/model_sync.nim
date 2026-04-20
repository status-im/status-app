# Model Synchronization Utilities
#
# Efficient utilities for synchronizing Qt models with new data without a
# full model reset.  Calculates a minimal diff and applies granular updates
# (insertRows / removeRows / dataChanged).
#
# ----------------------------------------------------------------------------
# Quick start (Pattern 1 - simple model owning its own data)
# ----------------------------------------------------------------------------
#
#   proc setItems*(self: MyModel, newItems: seq[MyItem]) =
#     setItemsWithSync(
#       self,
#       self.items,
#       newItems,
#       getId = proc(it: MyItem): string = it.id,
#       getRoles = proc(o, n: MyItem): seq[int] =
#         var roles: seq[int]
#         if o.name != n.name: roles.add(ModelRole.Name.int)
#         return roles,
#       countChanged = proc() = self.countChanged(),
#     )
#
# `self.items` is a plain `seq[T]` field on the model.  applySync mutates it
# in lockstep with the begin*/end* signals it emits, so `rowCount()` and
# `data()` (which read from `self.items`) always see consistent state.
#
# ----------------------------------------------------------------------------
# Pattern 4 (nested model with side effects on insert/update/remove)
# ----------------------------------------------------------------------------
#
#   setItemsWithSync(
#     self, self.items, snapshot,
#     getId    = ...,
#     getRoles = ...,
#     onInsert = proc(idx: int, item: T) =
#       # Row added at `idx`.  Side-effect: register a nested model.
#       self.children.insert(newChildModel(...), idx),
#     onUpdate = proc(idx: int, oldItem, newItem: T) =
#       # Row at `idx` had role changes.  Side-effect: diff the nested seq.
#       self.children[idx].update(oldItem.subItems, newItem.subItems),
#     onRemove = proc(idx: int) =
#       # Row removed from `idx`.  Side-effect: drop the nested model.
#       self.children.delete(idx),
#   )
#
# All three side-effect callbacks default to `nil` - models that don't need
# them simply omit them.
#
# ----------------------------------------------------------------------------
# Operation order and index semantics
# ----------------------------------------------------------------------------
#
# `applySync` walks operations in this order:
#   1. removes  (descending index order, so earlier removes don't shift the
#                indices of later ones)
#   2. updates  (with indices adjusted for the removes that just happened)
#   3. inserts  (in ascending newIdx order)
#
# Callback indices are the row's position **at the moment the callback
# fires** - i.e. post-removes-pre-inserts for `onUpdate`, and the final
# position for `onInsert`.  Side effects on a sibling array (e.g. a
# `seq[NestedModel]`) should `insert(idx)` and `delete(idx)` to keep the
# 1:1 correspondence with `items`.
#
# Reorder handling: items whose ID exists in both lists but at non-stable
# positions (per LIS) are emitted as remove+insert pairs.  Proper MoveOp
# emission is a follow-up.

import nimqml, tables, algorithm, sequtils, sets

# Spy support for testing (only active when QT_MODEL_SPY is defined)
when defined(QT_MODEL_SPY):
  import qt_model_spy

type
  ItemIdentifier*[T] = proc(item: T): string {.closure.}
  ItemComparator*[T] = proc(a, b: T): bool {.closure.}
  RoleDetector*[T] = proc(oldItem, newItem: T): seq[int] {.closure.}
  UpdateItemCallback*[T] = proc(existing: T, updated: T) {.closure.}

  # Discriminated side-effect callbacks.  Each fires at the moment the
  # corresponding sync operation completes against the model's `items` seq.
  # All three default to `nil`; models with no nested state can omit them.
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

  MoveOp* = object
    fromIndex*: int
    toIndex*: int

  SyncResult*[T] = object
    toInsert*: seq[InsertOp[T]]
    toRemove*: seq[RemoveOp]
    toUpdate*: seq[UpdateOp[T]]
    toMove*: seq[MoveOp]
    hasChanges*: bool

proc longestIncreasingSubseqIndices(values: openArray[int]): HashSet[int] =
  ## Returns the SET of indices into `values` that participate in the
  ## longest strictly-increasing subsequence. Standard O(n log n) patience
  ## sort with parent pointers.
  result = initHashSet[int]()
  if values.len == 0:
    return

  var tails: seq[int] = @[]   # tails[i] = index into values for the smallest tail of LIS of length i+1
  var prev = newSeq[int](values.len)
  for i in 0..<values.len:
    prev[i] = -1

  for i, x in values:
    # Binary search for leftmost position where values[tails[pos]] >= x.
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

  # Reconstruct backwards from the tail of the longest run.
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
  ## Reorderings are detected via LIS (longest increasing subsequence) over
  ## the items present in both lists: items participating in the LIS keep
  ## their position and are emitted as updates only; items outside the LIS
  ## are emitted as remove+insert pairs. This handles pure inserts, pure
  ## removes, and arbitrary mixed orderings correctly without false
  ## positives.  (B4)
  ##
  ## Proper MoveOp emission (avoiding the remove/insert pair for true moves)
  ## is a follow-up - see F5 in the plan.  The MoveOp type exists for that
  ## future work.
  ##
  ## Complexity: O((n + m) log m) where n = oldItems.len, m = items present
  ## in both lists.  In the steady state (no reorders), the LIS covers
  ## everything and we degrade gracefully to O(n).

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

  # O(1) ID lookup for old items.
  var oldMap = initTable[string, int]()
  for i, item in oldItems:
    oldMap[getId(item)] = i

  # Build the "common" sequence: pairs (oldIdx, newIdx) for IDs present in
  # both lists, walked in newItems order. The list is sorted ascending by
  # newIdx by construction; we then run LIS over the oldIdx values to find
  # which pairs can stay put.
  type Common = tuple[oldIdx: int, newIdx: int]
  var common: seq[Common] = @[]
  for newIdx, newItem in newItems:
    let id = getId(newItem)
    if oldMap.hasKey(id):
      common.add((oldMap[id], newIdx))

  let stable = longestIncreasingSubseqIndices(common.mapIt(it.oldIdx))

  # Track which old indices are kept (LIS members) so Phase 2 can emit
  # removes for everything else.
  var keepOld = newSeq[bool](oldItems.len)

  # Phase 1: walk new items, emit updates for stable rows and inserts for
  # the rest.
  var commonPtr = 0
  for newIdx, newItem in newItems:
    let id = getId(newItem)
    if oldMap.hasKey(id):
      # Advance commonPtr to the entry matching this newIdx.
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
        # Reorder: insert now, the corresponding old position will be
        # removed in Phase 2 because keepOld stays false.
        result.toInsert.add(InsertOp[T](index: newIdx, item: newItem))
        result.hasChanges = true
    else:
      # New item.
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

# ---------------------------------------------------------------------------
# Index adjustment helpers
# ---------------------------------------------------------------------------

proc adjustForRemoves(updates: seq[UpdateOp], removes: seq[RemoveOp]): seq[tuple[adjustedIdx: int, originalIdx: int]] =
  ## For each update, compute its index after the (descending) removes have
  ## been applied. O(R + U) instead of the O(R*U) original (H4).
  ##
  ## `removes` is expected to be in descending order (as syncModel emits).
  ## We sort the updates by index ascending, walk a single pointer through
  ## the removes array, and accumulate the offset.
  result = newSeq[tuple[adjustedIdx: int, originalIdx: int]](updates.len)
  if updates.len == 0:
    return

  # Build an ascending-sorted view of remove indices.
  var removeIdxAsc = newSeq[int](removes.len)
  for i, r in removes:
    removeIdxAsc[i] = r.index
  removeIdxAsc.sort()

  # Build a (originalIdx, slot) list sorted ascending by originalIdx so we can
  # walk both in lockstep.
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

# ---------------------------------------------------------------------------
# applySync
# ---------------------------------------------------------------------------

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
  ##
  ## Order of operations: removes (descending) -> updates -> inserts.
  ## QModelIndex objects are released inside each loop iteration (B5).
  ##
  ## Side-effect callbacks fire AFTER the corresponding `items` mutation
  ## and AFTER the matching Qt signal pair, so they observe the post-op
  ## state.

  if not syncResult.hasChanges:
    return

  let parentIndex = newQModelIndex()
  defer: parentIndex.delete

  # Step 1: removes (already in descending order from syncModel).
  # NOTE on spy ordering: recordBegin* fires BEFORE model.begin* (Qt
  # stable, items pre-mutation - safe to call data() from a probe).
  # recordEnd* fires AFTER model.end* (Qt stable, items post-mutation -
  # also safe).  Calling data() BETWEEN model.begin*/end* would crash
  # because DOtherSide's model is in a transitional state.
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
      # Pattern 1-4: replace and emit dataChanged for the changed roles.
      items[adjustedIdx] = updateOp.item

      # Spy fires BEFORE createIndex so the probe's own createIndex/data
      # calls don't collide with live QModelIndex objects we hold for the
      # dataChanged emission below.
      when defined(QT_MODEL_SPY):
        recordDataChanged(adjustedIdx, adjustedIdx, updateOp.roles)
      let modelIndex = model.createIndex(adjustedIdx, 0, nil)
      model.dataChanged(modelIndex, modelIndex, updateOp.roles)
      modelIndex.delete  # Release immediately - defer would leak per iteration (B5)

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

# ---------------------------------------------------------------------------
# applySyncWithBulkOps
# ---------------------------------------------------------------------------

proc applySyncWithBulkOps*[T](
  model: QAbstractListModel,
  items: var seq[T],
  syncResult: SyncResult[T],
  updateItem: UpdateItemCallback[T] = nil,
  onInsert: OnInsertCallback[T] = nil,
  onUpdate: OnUpdateCallback[T] = nil,
  onRemove: OnRemoveCallback = nil,
) =
  ## Optimized version of applySync that groups consecutive operations into
  ## bulk Qt notifications where possible. Significantly faster on large
  ## models with many consecutive inserts/removes/updates.

  if not syncResult.hasChanges:
    return

  let parentIndex = newQModelIndex()
  defer: parentIndex.delete

  # Step 1: bulk removes. The remove indices come from syncModel in
  # descending order; group them ascending then iterate the groups in reverse
  # so each group's removal does not invalidate earlier-indexed groups.
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
        # Fire onRemove for each removed row, descending so caller's
        # mutations stay index-stable.
        for j in countdown(last, first):
          onRemove(j)

  # Step 2: bulk updates. Group consecutive updates with identical role sets
  # so we can emit a single ranged dataChanged.
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
      # Pattern 5: setters handle signal emission.
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

        # Capture old values BEFORE replacing - onUpdate needs them.
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

        # Spy fires BEFORE createIndex (see applySync for the rationale).
        when defined(QT_MODEL_SPY):
          recordDataChanged(startIdx, endIdx, roles)
        let startModelIdx = model.createIndex(startIdx, 0, nil)
        let endModelIdx = model.createIndex(endIdx, 0, nil)
        model.dataChanged(startModelIdx, endModelIdx, roles)
        # Release inside the iteration (B5 - defer would leak per loop).
        startModelIdx.delete()
        endModelIdx.delete()

        if not onUpdate.isNil:
          for k in 0 .. (endIdx - startIdx):
            onUpdate(startIdx + k, oldItems[k], items[startIdx + k])

        i = j

  # Step 3: bulk inserts. Sort by index, then group consecutive runs into a
  # single beginInsertRows/endInsertRows call.
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
        # Fire ascending so caller's mutations on a sibling array (e.g.
        # nested-model seq) keep their index correspondence.
        for k in 0..<insertItems.len:
          onInsert(actualStartIdx + k, items[actualStartIdx + k])

      i = j

# ---------------------------------------------------------------------------
# Convenience facade
# ---------------------------------------------------------------------------

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
  ## Drop-in replacement for the begin/endResetModel pattern. See the file
  ## header for usage.
  ##
  ## Pattern 5 (QObject-exposing models): pass `updateItem` to call setters
  ## on the existing item; no dataChanged is emitted.
  ##
  ## Pattern 1-4 (multiple roles or value types): pass `getRoles` to get
  ## ranged dataChanged emissions.
  ##
  ## Pattern 4 (nested models): pass `onInsert` / `onUpdate` / `onRemove`
  ## to keep a sibling `seq[NestedModel]` in sync with `items`.

  # Fast path: first load (empty -> N).  The diff machinery makes 4 deep
  # copies of every T as it walks (syncModel.toInsert.add, the
  # sortedInserts copy, the loop iterator, items.insert), which dominates
  # for value-type DTOs with nested seqs.  When there's nothing to diff,
  # bulk-load via beginResetModel and skip the pipeline entirely.
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

  # Fast path: full clear (N -> empty).  Symmetric.
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
      # Descending so callers' sibling-array deletes stay index-stable.
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

# Export main types and procs
export ItemIdentifier, ItemComparator, RoleDetector
export OnInsertCallback, OnUpdateCallback, OnRemoveCallback
export UpdateOp, InsertOp, RemoveOp, MoveOp, SyncResult
export syncModel, applySync, applySyncWithBulkOps, setItemsWithSync
export groupConsecutiveRanges
