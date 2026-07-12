# Model Synchronization Utilities
# 
# This module provides efficient utilities for synchronizing Qt models with new data
# without requiring full model resets. It calculates minimal diffs and applies
# granular updates (insert, remove, update, move operations).
#
# Usage Example:
#   proc setItems*(self: MyModel, newItems: seq[MyItem]) =
#     self.setItemsWithSync(
#       self.items,
#       newItems,
#       getId = proc(item: MyItem): string = item.id,
#       getRoles = proc(old, new: MyItem): seq[int] = 
#         var roles: seq[int]
#         if old.name != new.name: roles.add(ModelRole.Name.int)
#         return roles,
#       countChanged = proc() = self.countChanged()
#     )

import nimqml, tables, algorithm, sequtils

import ./model_sync_reorder

# Spy support for testing (only active when QT_MODEL_SPY is defined)
when defined(QT_MODEL_SPY):
  import qt_model_spy

type
  ItemIdentifier*[T] = proc(item: T): string {.closure.}
  ItemComparator*[T] = proc(a, b: T): bool {.closure.}
  RoleDetector*[T] = proc(oldItem, newItem: T): seq[int] {.closure.}
  UpdateItemCallback*[T] = proc(existing: T, updated: T) {.closure.}
  AfterItemSyncCallback*[T] = proc(oldItem: T, newItem: var T, idx: int) {.closure.}
  
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

proc syncModel*[T](
  oldItems: seq[T],
  newItems: seq[T],
  getId: ItemIdentifier[T],
  getRoles: RoleDetector[T] = nil,
  detectMoves: bool = false
): SyncResult[T] =
  ## Efficiently computes the minimal set of operations needed to transform
  ## oldItems into newItems.
  ##
  ## Parameters:
  ##   oldItems: Current model items
  ##   newItems: Desired model items
  ##   getId: Function to extract unique identifier from item
  ##   getRoles: Optional function to detect which roles changed between old/new
  ##   detectMoves: Whether to detect and optimize move operations (more expensive)
  ##
  ## Returns:
  ##   SyncResult containing all operations needed to sync the model
  ##
  ## Algorithm Complexity: O(n) where n = max(oldItems.len, newItems.len)
  
  result.hasChanges = false
  
  # Early exit: both empty
  if oldItems.len == 0 and newItems.len == 0:
    return
  
  # Early exit: full replace scenarios
  if oldItems.len == 0:
    # All inserts
    for i, item in newItems:
      result.toInsert.add(InsertOp[T](index: i, item: item))
    result.hasChanges = true
    return
  
  if newItems.len == 0:
    # All removes (in reverse order to maintain indices)
    for i in countdown(oldItems.high, 0):
      result.toRemove.add(RemoveOp(index: i))
    result.hasChanges = true
    return
  
  # Build hash maps for O(1) lookup
  var oldMap = initTable[string, int]()
  for i, item in oldItems:
    oldMap[getId(item)] = i
  
  var newMap = initTable[string, int]()
  for i, item in newItems:
    newMap[getId(item)] = i
  
  # Track which old items were found in new items
  var processedOld = newSeq[bool](oldItems.len)
  
  # Phase 1: Identify items that exist in both (updates) and new items (inserts)
  for newIdx, newItem in newItems:
    let id = getId(newItem)
    
    if oldMap.hasKey(id):
      # Item exists in both - potential update
      let oldIdx = oldMap[id]
      processedOld[oldIdx] = true
      
      # Check if data changed
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
      # Item only in new - insert
      result.toInsert.add(InsertOp[T](
        index: newIdx,
        item: newItem
      ))
      result.hasChanges = true
  
  # Phase 2: Identify items only in old (removes)
  # Process in reverse order so indices remain valid during removal
  for i in countdown(oldItems.high, 0):
    if not processedOld[i]:
      result.toRemove.add(RemoveOp(index: i))
      result.hasChanges = true
  
  # Phase 3: Detect moves (optional, more expensive)
  # TODO: Implement move detection algorithm if needed
  # For now, moves are handled as remove + insert which is less efficient
  # but correct. Can optimize later if profiling shows it's needed.

proc groupConsecutiveRanges*(indices: seq[int]): seq[tuple[first: int, last: int]] =
  ## Groups consecutive integers into ranges for bulk operations
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

proc applySync*[T](
  model: QAbstractListModel,
  items: var seq[T],
  syncResult: SyncResult[T],
  updateItem: UpdateItemCallback[T] = nil,
  afterItemSync: AfterItemSyncCallback[T] = nil
) =
  ## Applies a SyncResult to a Qt model with proper notifications
  ##
  ## This function:
  ## 1. Removes obsolete items (with beginRemoveRows/endRemoveRows)
  ## 2. Inserts new items (with beginInsertRows/endInsertRows)
  ## 3. Updates existing items (Pattern 5: calls setters OR Pattern 1-4: uses dataChanged)
  ## 4. Applies move operations if any (with beginMoveRows/endMoveRows)
  ## 5. Calls afterItemSync callback for each updated item (for nested model sync)
  ##
  ## Pattern 5 (QObject-exposing models):
  ##   If updateItem callback is provided, it calls setters on the existing item.
  ##   The setters emit fine-grained property signals (e.g., nameChanged()).
  ##   No dataChanged call is needed!
  ##
  ## Pattern 1-4 (multiple roles or value types):
  ##   If updateItem is nil, replaces the item and calls dataChanged with roles.
  ##
  ## Note: Operations are applied in an order that maintains index validity
  
  if not syncResult.hasChanges:
    return
  
  let parentIndex = newQModelIndex()
  defer: parentIndex.delete
  
  # Step 1: Remove items (in the order provided - already reversed by syncModel)
  for removeOp in syncResult.toRemove:
    when defined(QT_MODEL_SPY):
      recordBeginRemoveRows(removeOp.index, removeOp.index)
    model.beginRemoveRows(parentIndex, removeOp.index, removeOp.index)
    items.delete(removeOp.index)
    when defined(QT_MODEL_SPY):
      recordEndRemoveRows()
    model.endRemoveRows()
  
  # Step 2: Update existing items
  # Must be done after removes but before inserts to maintain correct indices
  for updateOp in syncResult.toUpdate:
    # Adjust index if it was affected by removals
    var adjustedIdx = updateOp.index
    for removeOp in syncResult.toRemove:
      if removeOp.index < updateOp.index:
        adjustedIdx.dec
    
    if adjustedIdx >= 0 and adjustedIdx < items.len:
      let oldItem = items[adjustedIdx]
      
      if updateItem != nil:
        # Pattern 5: Call setters on existing item (QObject-exposing models)
        # Setters emit fine-grained property signals automatically
        updateItem(items[adjustedIdx], updateOp.item)
        # No dataChanged call needed! Setters handle signal emission
      else:
        # Pattern 1-4: Replace item and call dataChanged
        items[adjustedIdx] = updateOp.item
        
        let modelIndex = model.createIndex(adjustedIdx, 0, nil)
        defer: modelIndex.delete
        when defined(QT_MODEL_SPY):
          recordDataChanged(adjustedIdx, adjustedIdx, updateOp.roles)
        model.dataChanged(modelIndex, modelIndex, updateOp.roles)
      
      # Call nested sync callback if provided
      if not afterItemSync.isNil:
        afterItemSync(oldItem, items[adjustedIdx], adjustedIdx)
  
  # Step 3: Insert new items
  for insertOp in syncResult.toInsert:
    # Clamp index to valid range
    var insertIdx = insertOp.index
    if insertIdx < 0:
      insertIdx = 0
    elif insertIdx > items.len:
      insertIdx = items.len
    
    when defined(QT_MODEL_SPY):
      recordBeginInsertRows(insertIdx, insertIdx)
    model.beginInsertRows(parentIndex, insertIdx, insertIdx)
    items.insert(insertOp.item, insertIdx)
    when defined(QT_MODEL_SPY):
      recordEndInsertRows()
    model.endInsertRows()
    
    # Call nested sync callback for newly inserted items (e.g., create nested models)
    if not afterItemSync.isNil:
      var emptyItem: T  # Default/empty item as oldItem (not used for inserts)
      afterItemSync(emptyItem, items[insertIdx], insertIdx)
  
  # Step 4: Apply moves (if any)
  for moveOp in syncResult.toMove:
    model.beginMoveRows(parentIndex, moveOp.fromIndex, moveOp.fromIndex,
                        parentIndex, moveOp.toIndex)
    let item = items[moveOp.fromIndex]
    items.delete(moveOp.fromIndex)
    items.insert(item, moveOp.toIndex)
    model.endMoveRows()

proc applySyncWithBulkOps*[T](
  model: QAbstractListModel,
  items: var seq[T],
  syncResult: SyncResult[T],
  updateItem: UpdateItemCallback[T] = nil,
  afterItemSync: AfterItemSyncCallback[T] = nil
) =
  ## Optimized version of applySync that groups consecutive operations
  ## into bulk operations where possible.
  ##
  ## Pattern 5 (QObject-exposing models):
  ##   If updateItem callback is provided, calls setters instead of dataChanged.
  ##
  ## Pattern 1-4 (multiple roles):
  ##   If updateItem is nil, uses bulk dataChanged for consecutive updates.
  ##
  ## This can be significantly faster for large models with many consecutive
  ## inserts or removes.
  
  if not syncResult.hasChanges:
    return
  
  let parentIndex = newQModelIndex()
  defer: parentIndex.delete
  
  # Step 1: Bulk remove operations
  if syncResult.toRemove.len > 0:
    let indices = syncResult.toRemove.mapIt(it.index)
    let ranges = groupConsecutiveRanges(indices)
    
    # Process ranges in reverse to maintain indices
    for i in countdown(ranges.high, 0):
      let (first, last) = ranges[i]
      when defined(QT_MODEL_SPY):
        recordBeginRemoveRows(first, last)
      model.beginRemoveRows(parentIndex, first, last)
      for j in countdown(last, first):
        items.delete(j)
      when defined(QT_MODEL_SPY):
        recordEndRemoveRows()
      model.endRemoveRows()
  
  # Step 2: Bulk update existing items
  if syncResult.toUpdate.len > 0:
    # First, adjust all indices for removals and sort by adjusted index
    type AdjustedUpdate = tuple[adjustedIdx: int, item: T, roles: seq[int]]
    var adjustedUpdates: seq[AdjustedUpdate] = @[]
    
    for updateOp in syncResult.toUpdate:
      var adjustedIdx = updateOp.index
      for removeOp in syncResult.toRemove:
        if removeOp.index < updateOp.index:
          adjustedIdx.dec
      
      if adjustedIdx >= 0 and adjustedIdx < items.len:
        adjustedUpdates.add((adjustedIdx, updateOp.item, updateOp.roles))
    
    # Sort by adjusted index
    adjustedUpdates.sort(proc(a, b: AdjustedUpdate): int = cmp(a.adjustedIdx, b.adjustedIdx))
    
    if updateItem != nil:
      # Pattern 5: Call setters on existing items (no dataChanged needed)
      for update in adjustedUpdates:
        let oldItem = items[update.adjustedIdx]
        updateItem(items[update.adjustedIdx], update.item)
        if not afterItemSync.isNil:
          afterItemSync(oldItem, items[update.adjustedIdx], update.adjustedIdx)
    else:
      # Pattern 1-4: Group consecutive updates with same roles for bulk dataChanged
      var i = 0
      while i < adjustedUpdates.len:
        let startIdx = adjustedUpdates[i].adjustedIdx
        let roles = adjustedUpdates[i].roles
        var endIdx = startIdx
        
        # Apply first update
        let oldItem = items[startIdx]
        items[startIdx] = adjustedUpdates[i].item
        if not afterItemSync.isNil:
          afterItemSync(oldItem, items[startIdx], startIdx)
        
        # Look for consecutive updates with same roles
        var j = i + 1
        while j < adjustedUpdates.len:
          if adjustedUpdates[j].adjustedIdx == endIdx + 1 and 
             adjustedUpdates[j].roles == roles:
            # Consecutive with same roles - group it!
            endIdx = adjustedUpdates[j].adjustedIdx
            
            # Apply the update
            let oldItem2 = items[endIdx]
            items[endIdx] = adjustedUpdates[j].item
            if not afterItemSync.isNil:
              afterItemSync(oldItem2, items[endIdx], endIdx)
            
            j.inc
          else:
            break
        
        # Emit single dataChanged for the range
        let startModelIdx = model.createIndex(startIdx, 0, nil)
        let endModelIdx = model.createIndex(endIdx, 0, nil)
        defer:
          startModelIdx.delete()
          endModelIdx.delete()
        
        when defined(QT_MODEL_SPY):
          recordDataChanged(startIdx, endIdx, roles)
        model.dataChanged(startModelIdx, endModelIdx, roles)
        
        i = j
  
  # Step 3: Bulk insert operations
  if syncResult.toInsert.len > 0:
    # Sort inserts by index to maintain order
    var sortedInserts = syncResult.toInsert
    sortedInserts.sort(proc(a, b: InsertOp[T]): int = cmp(a.index, b.index))
    
    # Group consecutive inserts
    var i = 0
    while i < sortedInserts.len:
      let startIdx = sortedInserts[i].index
      var endIdx = startIdx
      var insertItems: seq[T] = @[sortedInserts[i].item]
      
      # Look for consecutive inserts
      var j = i + 1
      while j < sortedInserts.len and sortedInserts[j].index == endIdx + 1:
        endIdx = sortedInserts[j].index
        insertItems.add(sortedInserts[j].item)
        j.inc
      
      # Perform bulk insert
      var actualStartIdx = startIdx
      if actualStartIdx < 0: actualStartIdx = 0
      elif actualStartIdx > items.len: actualStartIdx = items.len
      
      when defined(QT_MODEL_SPY):
        recordBeginInsertRows(actualStartIdx, actualStartIdx + insertItems.len - 1)
      model.beginInsertRows(parentIndex, actualStartIdx, actualStartIdx + insertItems.len - 1)
      for k, item in insertItems:
        items.insert(item, actualStartIdx + k)
      when defined(QT_MODEL_SPY):
        recordEndInsertRows()
      model.endInsertRows()
      
      # Call nested sync callback for each newly inserted item (e.g., create nested models)
      if not afterItemSync.isNil:
        for k in 0..<insertItems.len:
          var emptyItem: T  # Default/empty item as oldItem (not used for inserts)
          afterItemSync(emptyItem, items[actualStartIdx + k], actualStartIdx + k)
      
      i = j

proc reconcileOrder*[T](
  model: QAbstractListModel,
  items: var seq[T],
  newItems: seq[T],
  getId: ItemIdentifier[T]
) =
  ## Reorders `items` in place to match `newItems`' order, emitting granular
  ## begin/endMoveRows. Precondition: `items` and `newItems` hold the same id
  ## set (the caller has already reconciled inserts/removes). This fills the gap
  ## syncModel leaves — its move detection is unimplemented, so a
  ## pure reorder would otherwise silently desync the model from newItems.
  ##
  ## Uses MOVE-UP ONLY (see model_sync_reorder.planReorderMovesUp): every move is
  ## upward, so the Qt destination index equals the target index and Qt's move-down
  ## destination-index quirk cannot occur. The move planning is a pure, separately
  ## unit-tested function; here we only replay its moves against the model.
  let currentIds = items.mapIt(getId(it))
  let targetIds = newItems.mapIt(getId(it))
  let moves = planReorderMovesUp(currentIds, targetIds)
  if moves.len == 0:
    return

  let parentIndex = newQModelIndex()
  defer: parentIndex.delete

  for m in moves:
    when defined(QT_MODEL_SPY):
      recordBeginMoveRows(m.fromIdx, m.fromIdx, m.toIdx)
    model.beginMoveRows(parentIndex, m.fromIdx, m.fromIdx, parentIndex, m.toIdx)
    let moved = items[m.fromIdx]
    items.delete(m.fromIdx)
    items.insert(moved, m.toIdx)
    when defined(QT_MODEL_SPY):
      recordEndMoveRows()
    model.endMoveRows()

proc setItemsWithSync*[T](
  model: QAbstractListModel,
  items: var seq[T],
  newItems: seq[T],
  getId: ItemIdentifier[T],
  getRoles: RoleDetector[T] = nil,
  updateItem: UpdateItemCallback[T] = nil,
  countChanged: proc() {.closure.} = nil,
  useBulkOps: bool = false,
  detectMoves: bool = false,
  afterItemSync: AfterItemSyncCallback[T] = nil
) =
  ## Convenience function that combines syncModel and applySync.
  ## This is a drop-in replacement for the common pattern:
  ##   self.beginResetModel()
  ##   self.items = newItems
  ##   self.endResetModel()
  ##   self.countChanged()
  ##
  ## Parameters:
  ##   model: The QAbstractListModel to update
  ##   items: Reference to the model's internal items seq
  ##   newItems: The new items to sync to
  ##   getId: Function to extract unique ID from item
  ##   getRoles: Optional function to detect which roles changed (Pattern 1-4)
  ##   updateItem: Optional function to call setters on existing item (Pattern 5)
  ##   countChanged: Optional callback when count changes
  ##   useBulkOps: Use bulk operations for better performance (default: false)
  ##   detectMoves: Detect move operations (default: false)
  ##   afterItemSync: Optional callback after each item is synced (for nested models)
  ##
  ## Pattern 5 (QObject-exposing models):
  ##   Use updateItem instead of getRoles for fine-grained property updates.
  ##   Example:
  ##     updateItem = proc(existing: KeyPairItem, updated: KeyPairItem) =
  ##       if existing.getName() != updated.getName():
  ##         existing.setName(updated.getName())  # Emits nameChanged()
  ##
  ## Pattern 1-4 (multiple roles):
  ##   Use getRoles to detect which fields changed.
  ##   Example:
  ##     getRoles = proc(old, new: Token): seq[int] =
  ##       if old.name != new.name: result.add(ModelRole.Name.int)
  
  let syncResult = syncModel(items, newItems, getId, getRoles, detectMoves)

  if syncResult.hasChanges:
    if useBulkOps:
      model.applySyncWithBulkOps(items, syncResult, updateItem, afterItemSync)
    else:
      model.applySync(items, syncResult, updateItem, afterItemSync)

    # Call count changed if count actually changed
    if countChanged != nil and (syncResult.toInsert.len > 0 or syncResult.toRemove.len > 0):
      countChanged()

  # Move detection: syncModel does not reorder survivors, so a
  # reorder (incl. a pure reorder, which yields hasChanges=false) would leave the
  # model out of order. When enabled, reconcile the order with granular moves.
  # Runs after set reconciliation so `items` and `newItems` share the same id set.
  if detectMoves:
    reconcileOrder(model, items, newItems, getId)

# Convenience template for common updateRole pattern
template updateRoleIfChanged*[T](item: T, oldValue, newValue: T, role: untyped, roles: var seq[int]) =
  ## Helper template to add role to list if value changed
  ## Usage in getRoles lambda:
  ##   var roles: seq[int]
  ##   updateRoleIfChanged(item.name, old.name, new.name, ModelRole.Name, roles)
  ##   return roles
  if oldValue != newValue:
    item = newValue
    roles.add(role.int)

# Export main types and procs
export ItemIdentifier, ItemComparator, RoleDetector, AfterItemSyncCallback
export UpdateOp, InsertOp, RemoveOp, MoveOp, SyncResult
export syncModel, applySync, applySyncWithBulkOps, setItemsWithSync
export groupConsecutiveRanges, updateRoleIfChanged

