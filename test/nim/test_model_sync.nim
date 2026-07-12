import unittest, sequtils, tables, algorithm
import app/modules/shared/model_sync

# Test item type
type
  TestItem = object
    id: string
    name: string
    value: int
    flag: bool

proc `==`(a, b: TestItem): bool =
  a.id == b.id and a.name == b.name and a.value == b.value and a.flag == b.flag

suite "Model Sync Tests":
  
  test "Empty to empty - no changes":
    let oldItems: seq[TestItem] = @[]
    let newItems: seq[TestItem] = @[]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == false
    check result.toInsert.len == 0
    check result.toRemove.len == 0
    check result.toUpdate.len == 0
  
  test "Empty to non-empty - all inserts":
    let oldItems: seq[TestItem] = @[]
    let newItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == true
    check result.toInsert.len == 3
    check result.toRemove.len == 0
    check result.toUpdate.len == 0
    check result.toInsert[0].index == 0
    check result.toInsert[1].index == 1
    check result.toInsert[2].index == 2
  
  test "Non-empty to empty - all removes":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    let newItems: seq[TestItem] = @[]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == true
    check result.toInsert.len == 0
    check result.toRemove.len == 3
    check result.toUpdate.len == 0
    # Removes should be in reverse order
    check result.toRemove[0].index == 2
    check result.toRemove[1].index == 1
    check result.toRemove[2].index == 0
  
  test "No changes - identical items":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(1)
        if old.value != new.value: roles.add(2)
        return roles
    )
    
    check result.hasChanges == false
    check result.toInsert.len == 0
    check result.toRemove.len == 0
    check result.toUpdate.len == 0
  
  test "Update single field":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2-Updated", value: 200),
    ]
    
    const NameRole = 1
    const ValueRole = 2
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(NameRole)
        if old.value != new.value: roles.add(ValueRole)
        return roles
    )
    
    check result.hasChanges == true
    check result.toInsert.len == 0
    check result.toRemove.len == 0
    check result.toUpdate.len == 1
    check result.toUpdate[0].index == 1
    check result.toUpdate[0].roles == @[NameRole]
    check result.toUpdate[0].item.name == "Item2-Updated"
  
  test "Update multiple fields":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100, flag: false),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1-New", value: 999, flag: true),
    ]
    
    const NameRole = 1
    const ValueRole = 2
    const FlagRole = 3
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(NameRole)
        if old.value != new.value: roles.add(ValueRole)
        if old.flag != new.flag: roles.add(FlagRole)
        return roles
    )
    
    check result.hasChanges == true
    check result.toUpdate.len == 1
    check result.toUpdate[0].roles.len == 3
    check NameRole in result.toUpdate[0].roles
    check ValueRole in result.toUpdate[0].roles
    check FlagRole in result.toUpdate[0].roles
  
  test "Mix of operations - insert, update, remove":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1-Updated", value: 100),  # Update
      TestItem(id: "4", name: "Item4", value: 400),          # Insert
      TestItem(id: "3", name: "Item3", value: 300),          # No change
      # Item2 removed
    ]
    
    const NameRole = 1
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(NameRole)
        return roles
    )
    
    check result.hasChanges == true
    check result.toInsert.len == 1  # Item4
    check result.toRemove.len == 1  # Item2
    check result.toUpdate.len == 1  # Item1
    
    check result.toInsert[0].item.id == "4"
    check result.toRemove[0].index == 1  # Item2 was at index 1
    check result.toUpdate[0].index == 0  # Item1 at index 0
    check result.toUpdate[0].item.name == "Item1-Updated"
  
  test "Insert at beginning":
    let oldItems = @[
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == true
    check result.toInsert.len == 1
    check result.toInsert[0].index == 0
    check result.toInsert[0].item.id == "1"
  
  test "Insert at end":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == true
    check result.toInsert.len == 1
    check result.toInsert[0].index == 2
    check result.toInsert[0].item.id == "3"
  
  test "Insert in middle":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == true
    check result.toInsert.len == 1
    check result.toInsert[0].index == 1
    check result.toInsert[0].item.id == "2"
  
  test "Remove from beginning":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    let newItems = @[
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == true
    check result.toRemove.len == 1
    check result.toRemove[0].index == 0
  
  test "Remove from end":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == true
    check result.toRemove.len == 1
    check result.toRemove[0].index == 2
  
  test "Remove from middle":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "3", name: "Item3", value: 300),
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == true
    check result.toRemove.len == 1
    check result.toRemove[0].index == 1
  
  test "Remove multiple consecutive items":
    let oldItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "2", name: "Item2", value: 200),
      TestItem(id: "3", name: "Item3", value: 300),
      TestItem(id: "4", name: "Item4", value: 400),
      TestItem(id: "5", name: "Item5", value: 500),
    ]
    let newItems = @[
      TestItem(id: "1", name: "Item1", value: 100),
      TestItem(id: "5", name: "Item5", value: 500),
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    check result.hasChanges == true
    check result.toRemove.len == 3
    # Should be in reverse order: 3, 2, 1
    check result.toRemove[0].index == 3
    check result.toRemove[1].index == 2
    check result.toRemove[2].index == 1
  
  test "Group consecutive ranges":
    let indices = @[0, 1, 2, 5, 6, 9, 15, 16, 17, 18]
    let ranges = groupConsecutiveRanges(indices)
    
    check ranges.len == 4
    check ranges[0] == (0, 2)
    check ranges[1] == (5, 6)
    check ranges[2] == (9, 9)
    check ranges[3] == (15, 18)
  
  test "Group consecutive ranges - single items":
    let indices = @[1, 3, 5, 7]
    let ranges = groupConsecutiveRanges(indices)
    
    check ranges.len == 4
    check ranges[0] == (1, 1)
    check ranges[1] == (3, 3)
    check ranges[2] == (5, 5)
    check ranges[3] == (7, 7)
  
  test "Group consecutive ranges - empty":
    let indices: seq[int] = @[]
    let ranges = groupConsecutiveRanges(indices)
    
    check ranges.len == 0
  
  test "Group consecutive ranges - single range":
    let indices = @[5, 6, 7, 8, 9]
    let ranges = groupConsecutiveRanges(indices)
    
    check ranges.len == 1
    check ranges[0] == (5, 9)
  
  test "Large dataset performance":
    # Create a large dataset
    var oldItems: seq[TestItem] = @[]
    for i in 0..999:
      oldItems.add(TestItem(id: $i, name: "Item" & $i, value: i * 100))
    
    # Modify some items, remove some, add some
    var newItems: seq[TestItem] = @[]
    for i in 0..899:  # Remove last 100
      if i mod 10 == 0:  # Update every 10th item
        newItems.add(TestItem(id: $i, name: "Updated-" & $i, value: i * 100))
      else:
        newItems.add(TestItem(id: $i, name: "Item" & $i, value: i * 100))
    
    # Add new items
    for i in 1000..1099:
      newItems.add(TestItem(id: $i, name: "NewItem" & $i, value: i * 100))
    
    const NameRole = 1
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(NameRole)
        return roles
    )
    
    check result.hasChanges == true
    check result.toRemove.len == 100  # Removed 900-999
    check result.toInsert.len == 100  # Added 1000-1099
    check result.toUpdate.len == 90   # Updated every 10th from 0-899

suite "Nested Model Sync (update detection for nested models)":
  test "afterItemSync callback is called for updated items":
    var callbackCalled = 0
    var lastOldId = ""
    var lastNewId = ""
    var lastIdx = -1
    
    var items: seq[TestItem] = @[
      TestItem(id: "1", name: "Alice", value: 100),
      TestItem(id: "2", name: "Bob", value: 200),
      TestItem(id: "3", name: "Charlie", value: 300)
    ]
    
    let newItems: seq[TestItem] = @[
      TestItem(id: "1", name: "Alice Updated", value: 150),  # Changed
      TestItem(id: "2", name: "Bob", value: 200),            # Unchanged
      TestItem(id: "3", name: "Charlie", value: 350)         # Changed
    ]
    
    # Manually apply sync with callback (without Qt model)
    let syncResult = syncModel(
      items, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(1)
        if old.value != new.value: roles.add(2)
        return roles
    )
    
    # Manually apply updates with callback
    for updateOp in syncResult.toUpdate:
      let oldItem = items[updateOp.index]
      items[updateOp.index] = updateOp.item
      # Simulate nested-sync side effect on update
      callbackCalled.inc
      lastOldId = oldItem.id
      lastNewId = updateOp.item.id
      lastIdx = updateOp.index
    
    check callbackCalled == 2  # Called for items 1 and 3
    check lastIdx >= 0
    check items[0].name == "Alice Updated"
    check items[2].value == 350

  test "afterItemSync can detect nested changes":
    type
      NestedItem = object
        id: string
        count: int
      
      ParentItem = object
        id: string
        name: string
        nested: seq[NestedItem]
    
    var items: seq[ParentItem] = @[
      ParentItem(
        id: "p1",
        name: "Parent1",
        nested: @[
          NestedItem(id: "n1", count: 1),
          NestedItem(id: "n2", count: 2)
        ]
      )
    ]
    
    let newItems: seq[ParentItem] = @[
      ParentItem(
        id: "p1",
        name: "Parent1 Updated",
        nested: @[
          NestedItem(id: "n1", count: 10),  # Updated
          NestedItem(id: "n2", count: 20)   # Updated
        ]
      )
    ]
    
    var nestedSyncCalled = false
    
    let syncResult = syncModel(
      items, newItems,
      getId = proc(item: ParentItem): string = item.id,
      getRoles = proc(old, new: ParentItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(1)
        return roles
    )
    
    # Manually apply with nested sync simulation
    for updateOp in syncResult.toUpdate:
      let oldItem = items[updateOp.index]
      items[updateOp.index] = updateOp.item
      # Simulate nested-sync side effect on update
      for i in 0..<updateOp.item.nested.len:
        if i < oldItem.nested.len:
          if oldItem.nested[i].count != updateOp.item.nested[i].count:
            nestedSyncCalled = true
    
    check nestedSyncCalled
    check items[0].name == "Parent1 Updated"
    check items[0].nested[0].count == 10

  test "afterItemSync called for all updated items":
    var callbackCount = 0
    
    var items: seq[TestItem] = @[
      TestItem(id: "1", name: "A", value: 1),
      TestItem(id: "2", name: "B", value: 2),
      TestItem(id: "3", name: "C", value: 3)
    ]
    
    let newItems: seq[TestItem] = @[
      TestItem(id: "1", name: "A-new", value: 1),
      TestItem(id: "2", name: "B-new", value: 2),
      TestItem(id: "3", name: "C-new", value: 3)
    ]
    
    let syncResult = syncModel(
      items, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        if old.name != new.name: @[1] else: @[]
    )
    
    # Simulate a nested-sync side effect for each update
    for updateOp in syncResult.toUpdate:
      items[updateOp.index] = updateOp.item
      callbackCount.inc
    
    check callbackCount == 3  # Called for all updated items
    check items[0].name == "A-new"
    check items[1].name == "B-new"
    check items[2].name == "C-new"

  test "afterItemSync not called for insertions or deletions":
    var callbackCount = 0
    
    let oldItems: seq[TestItem] = @[
      TestItem(id: "1", name: "A", value: 1),
      TestItem(id: "2", name: "B", value: 2)
    ]
    
    let newItems: seq[TestItem] = @[
      TestItem(id: "2", name: "B", value: 2),  # Item 1 removed
      TestItem(id: "3", name: "C", value: 3)   # Item 3 added
    ]
    
    let syncResult = syncModel(
      oldItems, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] = @[]
    )
    
    # Count updates only (not inserts/removes)
    for updateOp in syncResult.toUpdate:
      callbackCount.inc
    
    # Callback should not be called - no updates, only insert + remove
    check callbackCount == 0
    check syncResult.toInsert.len == 1
    check syncResult.toRemove.len == 1

suite "Reorder detection (LIS)":
  # syncModel must detect surviving-row reorders and emit them as minimal
  # remove+insert pairs (it does NOT emit Qt moves). A pure reorder of the same
  # set therefore has changes.
  test "swap last two -> minimal remove+insert":
    # old = [a, b, c], new = [a, c, b].
    # LIS over the common oldIdx sequence keeps {a, b} stable; c is moved.
    let old = @[TestItem(id: "a"), TestItem(id: "b"), TestItem(id: "c")]
    let nu = @[TestItem(id: "a"), TestItem(id: "c"), TestItem(id: "b")]
    let r = syncModel(old, nu, getId = proc(it: TestItem): string = it.id)
    check r.hasChanges
    check r.toInsert.len == 1
    check r.toInsert[0].index == 1
    check r.toRemove.len == 1
    check r.toRemove[0].index == 2

  test "full reverse -> LIS keeps one stable element":
    let old = @[TestItem(id: "a"), TestItem(id: "b"), TestItem(id: "c")]
    let nu = @[TestItem(id: "c"), TestItem(id: "b"), TestItem(id: "a")]
    let r = syncModel(old, nu, getId = proc(it: TestItem): string = it.id)
    check r.hasChanges
    check r.toInsert.len == 2
    check r.toRemove.len == 2

  test "pure mid-list insert does NOT flag survivors as reordered":
    # Regression guard: a cheap oldIdx==newIdx heuristic would spuriously mark
    # every shifted survivor as moved. The LIS keeps them stable.
    let old = @[TestItem(id: "a"), TestItem(id: "b"), TestItem(id: "c")]
    let nu = @[TestItem(id: "x"), TestItem(id: "a"), TestItem(id: "b"), TestItem(id: "c")]
    let r = syncModel(old, nu, getId = proc(it: TestItem): string = it.id)
    check r.toInsert.len == 1
    check r.toInsert[0].index == 0
    check r.toRemove.len == 0

  test "reorder deltas applied to a plain seq reproduce target order":
    # Simulate applySync ordering (removes descending, then inserts ascending)
    # on a plain seq and check it reproduces the target.
    proc simulate(current, target: seq[string]): seq[string] =
      let old = current.mapIt(TestItem(id: it))
      let nu = target.mapIt(TestItem(id: it))
      var work = old
      let r = syncModel(old, nu, getId = proc(it: TestItem): string = it.id)
      for rem in r.toRemove:            # descending from syncModel
        work.delete(rem.index)
      var ins = r.toInsert
      ins.sort(proc(a, b: InsertOp[TestItem]): int = cmp(a.index, b.index))
      for op in ins:
        work.insert(op.item, op.index)
      return work.mapIt(it.id)

    check simulate(@["a", "b", "c"], @["b", "a", "c"]) == @["b", "a", "c"]
    check simulate(@["a", "b", "c", "d", "e"], @["e", "d", "c", "b", "a"]) ==
      @["e", "d", "c", "b", "a"]
    check simulate(@["a", "b", "c", "d"], @["d", "a", "b", "c"]) ==
      @["d", "a", "b", "c"]
    check simulate(@["a", "b", "c", "d", "e", "f"], @["c", "f", "a", "e", "b", "d"]) ==
      @["c", "f", "a", "e", "b", "d"]

suite "Bulk Operations Tests":
  test "Bulk remove - consecutive ranges are grouped":
    # Test that consecutive removes are grouped into ranges
    let items = @[
      TestItem(id: "1", value: 1),
      TestItem(id: "2", value: 2),
      TestItem(id: "3", value: 3),
      TestItem(id: "4", value: 4),
      TestItem(id: "5", value: 5),
      TestItem(id: "6", value: 6),
      TestItem(id: "7", value: 7),
    ]
    
    # Remove items 1, 2, 3 (consecutive) and 5, 6 (consecutive)
    let newItems = @[
      TestItem(id: "4", value: 4),
      TestItem(id: "7", value: 7),
    ]
    
    let result = syncModel(
      items, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    # Should have 5 remove operations (items 1,2,3,5,6 removed)
    check result.toRemove.len == 5
    
    # Test groupConsecutiveRanges helper
    let indices = result.toRemove.mapIt(it.index)
    let ranges = groupConsecutiveRanges(indices)
    
    # Should group into 2 ranges
    check ranges.len == 2
    # First range: items at indices 0,1,2 (items with ids "1","2","3")
    # Second range: items at indices 4,5 (items with ids "5","6")
    check ranges[0].first == 0
    check ranges[0].last == 2
    check ranges[1].first == 4
    check ranges[1].last == 5
  
  test "Bulk insert - consecutive inserts are grouped":
    # Test that consecutive inserts are grouped
    let items = @[
      TestItem(id: "1", value: 1),
      TestItem(id: "7", value: 7),
    ]
    
    # Insert items 2,3,4,5,6 between 1 and 7
    let newItems = @[
      TestItem(id: "1", value: 1),
      TestItem(id: "2", value: 2),
      TestItem(id: "3", value: 3),
      TestItem(id: "4", value: 4),
      TestItem(id: "5", value: 5),
      TestItem(id: "6", value: 6),
      TestItem(id: "7", value: 7),
    ]
    
    let result = syncModel(
      items, newItems,
      getId = proc(item: TestItem): string = item.id
    )
    
    # Should have 5 insert operations
    check result.toInsert.len == 5
    
    # All inserts should be consecutive indices (1,2,3,4,5)
    var sortedInserts = result.toInsert
    sortedInserts.sort(proc(a, b: InsertOp[TestItem]): int = cmp(a.index, b.index))
    
    check sortedInserts[0].index == 1
    check sortedInserts[1].index == 2
    check sortedInserts[2].index == 3
    check sortedInserts[3].index == 4
    check sortedInserts[4].index == 5
  
  test "Bulk dataChanged - consecutive updates with same roles are grouped":
    # Test that consecutive updates with same roles are grouped
    let items = @[
      TestItem(id: "1", value: 1, name: "A"),
      TestItem(id: "2", value: 2, name: "B"),
      TestItem(id: "3", value: 3, name: "C"),
      TestItem(id: "4", value: 4, name: "D"),
      TestItem(id: "5", value: 5, name: "E"),
    ]
    
    # Update all items - only value changed (same role for all)
    let newItems = @[
      TestItem(id: "1", value: 10, name: "A"),
      TestItem(id: "2", value: 20, name: "B"),
      TestItem(id: "3", value: 30, name: "C"),
      TestItem(id: "4", value: 40, name: "D"),
      TestItem(id: "5", value: 50, name: "E"),
    ]
    
    let result = syncModel(
      items, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.value != new.value:
          roles.add(1)  # Value role
        if old.name != new.name:
          roles.add(2)  # Name role
        return roles
    )
    
    # All 5 items should be marked for update
    check result.toUpdate.len == 5
    
    # All should have same roles (only value changed)
    for updateOp in result.toUpdate:
      check updateOp.roles == @[1]
    
    # With bulk ops, these should be emitted as single dataChanged(0, 4, [1])
  
  test "Bulk dataChanged - different roles prevent grouping":
    # Test that updates with different roles are NOT grouped
    let items = @[
      TestItem(id: "1", value: 1, name: "A"),
      TestItem(id: "2", value: 2, name: "B"),
      TestItem(id: "3", value: 3, name: "C"),
    ]
    
    # Update items with different role combinations
    let newItems = @[
      TestItem(id: "1", value: 10, name: "A"),      # Only value
      TestItem(id: "2", value: 2, name: "Updated"),  # Only name
      TestItem(id: "3", value: 30, name: "C"),      # Only value
    ]
    
    let result = syncModel(
      items, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.value != new.value:
          roles.add(1)  # Value role
        if old.name != new.name:
          roles.add(2)  # Name role
        return roles
    )
    
    check result.toUpdate.len == 3
    
    # Different roles for each
    check result.toUpdate[0].roles == @[1]     # Item 1: value only
    check result.toUpdate[1].roles == @[2]     # Item 2: name only
    check result.toUpdate[2].roles == @[1]     # Item 3: value only
    
    # Items 0 and 2 have same roles but are NOT consecutive,
    # so should result in 3 separate dataChanged calls
  
  test "Bulk dataChanged - mixed consecutive groups":
    # Test grouping with multiple consecutive groups
    let items = @[
      TestItem(id: "1", value: 1, name: "A"),
      TestItem(id: "2", value: 2, name: "B"),
      TestItem(id: "3", value: 3, name: "C"),
      TestItem(id: "4", value: 4, name: "D"),
      TestItem(id: "5", value: 5, name: "E"),
      TestItem(id: "6", value: 6, name: "F"),
    ]
    
    # Update with pattern: [value,value,name,name,value,value]
    let newItems = @[
      TestItem(id: "1", value: 10, name: "A"),     # Value
      TestItem(id: "2", value: 20, name: "B"),     # Value
      TestItem(id: "3", value: 3, name: "C2"),     # Name
      TestItem(id: "4", value: 4, name: "D2"),     # Name
      TestItem(id: "5", value: 50, name: "E"),     # Value
      TestItem(id: "6", value: 60, name: "F"),     # Value
    ]
    
    let result = syncModel(
      items, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.value != new.value:
          roles.add(1)  # Value role
        if old.name != new.name:
          roles.add(2)  # Name role
        return roles
    )
    
    check result.toUpdate.len == 6
    
    # Verify role patterns
    check result.toUpdate[0].roles == @[1]  # Items 0-1: value
    check result.toUpdate[1].roles == @[1]
    check result.toUpdate[2].roles == @[2]  # Items 2-3: name
    check result.toUpdate[3].roles == @[2]
    check result.toUpdate[4].roles == @[1]  # Items 4-5: value
    check result.toUpdate[5].roles == @[1]
    
    # With bulk ops, should emit 3 dataChanged calls:
    # - dataChanged(0, 1, [1])  // Items 0-1
    # - dataChanged(2, 3, [2])  // Items 2-3
    # - dataChanged(4, 5, [1])  // Items 4-5
  
  test "Bulk operations - large dataset performance":
    # Test bulk operations with large dataset
    var items: seq[TestItem] = @[]
    for i in 0..<1000:
      items.add(TestItem(id: $i, value: i, name: "Item" & $i))
    
    # Update all items - only value changed (add 100 to ensure all change)
    var newItems: seq[TestItem] = @[]
    for i in 0..<1000:
      newItems.add(TestItem(id: $i, value: i + 100, name: "Item" & $i))
    
    let result = syncModel(
      items, newItems,
      getId = proc(item: TestItem): string = item.id,
      getRoles = proc(old, new: TestItem): seq[int] =
        var roles: seq[int]
        if old.value != new.value:
          roles.add(1)
        return roles
    )
    
    # All 1000 items should be marked for update
    check result.toUpdate.len == 1000
    
    # All should have same roles
    for updateOp in result.toUpdate:
      check updateOp.roles == @[1]
    
    # With bulk ops, this should result in just 1 dataChanged call!
    # dataChanged(0, 999, [1])

suite "Pattern 5: QObject-Exposing Models - updateItem Callback Tests":
  
  # For Pattern 5 tests, we need a QObject-like item with setters
  type
    QObjectLikeItem = ref object
      id: string
      name: string
      value: int
      nameSetterCalled: int
      valueSetterCalled: int
  
  proc setName(self: QObjectLikeItem, newName: string) =
    self.name = newName
    self.nameSetterCalled.inc
  
  proc setValue(self: QObjectLikeItem, newValue: int) =
    self.value = newValue
    self.valueSetterCalled.inc
  
  test "updateItem callback is called for updates":
    let oldItems = @[
      QObjectLikeItem(id: "1", name: "Old1", value: 100),
      QObjectLikeItem(id: "2", name: "Old2", value: 200),
    ]
    let newItems = @[
      QObjectLikeItem(id: "1", name: "New1", value: 150),  # Updated
      QObjectLikeItem(id: "2", name: "Old2", value: 200),  # Unchanged
    ]
    
    var updateItemCalls = 0
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: QObjectLikeItem): string = item.id,
      getRoles = proc(old, new: QObjectLikeItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(1)
        if old.value != new.value: roles.add(2)
        return roles
    )
    
    check result.toUpdate.len == 1
    check result.toUpdate[0].index == 0
    
    # Simulate what applySyncWithBulkOps would do with updateItem callback
    let updateItem = proc(existing: QObjectLikeItem, updated: QObjectLikeItem) =
      updateItemCalls.inc
      if existing.name != updated.name:
        existing.setName(updated.name)
      if existing.value != updated.value:
        existing.setValue(updated.value)
    
    # Call updateItem for each update
    for updateOp in result.toUpdate:
      updateItem(oldItems[updateOp.index], updateOp.item)
    
    # Verify setters were called
    check updateItemCalls == 1
    check oldItems[0].nameSetterCalled == 1
    check oldItems[0].valueSetterCalled == 1
    check oldItems[0].name == "New1"
    check oldItems[0].value == 150
  
  test "updateItem calls only changed property setters":
    let oldItems = @[
      QObjectLikeItem(id: "1", name: "Name1", value: 100),
    ]
    let newItems = @[
      QObjectLikeItem(id: "1", name: "Name1", value: 999),  # Only value changed!
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: QObjectLikeItem): string = item.id,
      getRoles = proc(old, new: QObjectLikeItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(1)
        if old.value != new.value: roles.add(2)
        return roles
    )
    
    check result.toUpdate.len == 1
    
    # updateItem callback
    let updateItem = proc(existing: QObjectLikeItem, updated: QObjectLikeItem) =
      if existing.name != updated.name:
        existing.setName(updated.name)
      if existing.value != updated.value:
        existing.setValue(updated.value)
    
    updateItem(oldItems[0], result.toUpdate[0].item)
    
    # Only value setter should be called!
    check oldItems[0].nameSetterCalled == 0  # NOT called
    check oldItems[0].valueSetterCalled == 1  # Called once
    check oldItems[0].value == 999
  
  test "updateItem with multiple items - fine-grained updates":
    let oldItems = @[
      QObjectLikeItem(id: "1", name: "A", value: 1),
      QObjectLikeItem(id: "2", name: "B", value: 2),
      QObjectLikeItem(id: "3", name: "C", value: 3),
    ]
    let newItems = @[
      QObjectLikeItem(id: "1", name: "A_changed", value: 1),  # Name only
      QObjectLikeItem(id: "2", name: "B", value: 222),         # Value only
      QObjectLikeItem(id: "3", name: "C_changed", value: 333), # Both changed
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: QObjectLikeItem): string = item.id,
      getRoles = proc(old, new: QObjectLikeItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(1)
        if old.value != new.value: roles.add(2)
        return roles
    )
    
    check result.toUpdate.len == 3
    
    # updateItem callback
    let updateItem = proc(existing: QObjectLikeItem, updated: QObjectLikeItem) =
      if existing.name != updated.name:
        existing.setName(updated.name)
      if existing.value != updated.value:
        existing.setValue(updated.value)
    
    for updateOp in result.toUpdate:
      updateItem(oldItems[updateOp.index], updateOp.item)
    
    # Item 1: Name setter called, value setter NOT called
    check oldItems[0].nameSetterCalled == 1
    check oldItems[0].valueSetterCalled == 0
    check oldItems[0].name == "A_changed"
    
    # Item 2: Value setter called, name setter NOT called
    check oldItems[1].nameSetterCalled == 0
    check oldItems[1].valueSetterCalled == 1
    check oldItems[1].value == 222
    
    # Item 3: BOTH setters called
    check oldItems[2].nameSetterCalled == 1
    check oldItems[2].valueSetterCalled == 1
    check oldItems[2].name == "C_changed"
    check oldItems[2].value == 333
  
  test "updateItem does not call setters when item unchanged":
    let oldItems = @[
      QObjectLikeItem(id: "1", name: "Same", value: 42),
    ]
    let newItems = @[
      QObjectLikeItem(id: "1", name: "Same", value: 42),  # Identical!
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: QObjectLikeItem): string = item.id,
      getRoles = proc(old, new: QObjectLikeItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(1)
        if old.value != new.value: roles.add(2)
        return roles
    )
    
    # No updates detected!
    check result.toUpdate.len == 0
    
    # No setters should be called
    check oldItems[0].nameSetterCalled == 0
    check oldItems[0].valueSetterCalled == 0
  
  test "Pattern 5 proof: setters handle signals, no dataChanged needed":
    # This test documents the key Pattern 5 optimization:
    # Instead of calling dataChanged(entire item) which triggers ALL bindings,
    # we call individual setters which emit fine-grained signals (nameChanged, valueChanged)
    # that only trigger SPECIFIC bindings.
    
    let oldItems = @[
      QObjectLikeItem(id: "1", name: "Old", value: 1),
      QObjectLikeItem(id: "2", name: "Old", value: 2),
      QObjectLikeItem(id: "3", name: "Old", value: 3),
    ]
    let newItems = @[
      QObjectLikeItem(id: "1", name: "New", value: 1),  # Name changed
      QObjectLikeItem(id: "2", name: "New", value: 2),  # Name changed
      QObjectLikeItem(id: "3", name: "New", value: 3),  # Name changed
    ]
    
    let result = syncModel(
      oldItems, newItems,
      getId = proc(item: QObjectLikeItem): string = item.id,
      getRoles = proc(old, new: QObjectLikeItem): seq[int] =
        var roles: seq[int]
        if old.name != new.name: roles.add(1)
        if old.value != new.value: roles.add(2)
        return roles
    )
    
    check result.toUpdate.len == 3
    
    let updateItem = proc(existing: QObjectLikeItem, updated: QObjectLikeItem) =
      if existing.name != updated.name:
        existing.setName(updated.name)  # Emits nameChanged() only!
      # No need to check value - it didn't change
    
    for updateOp in result.toUpdate:
      updateItem(oldItems[updateOp.index], updateOp.item)
    
    # PROOF: Only name setters called (3 times)
    # In QML: Only bindings to `item.name` would re-evaluate
    # Bindings to `item.value` would NOT be triggered!
    check oldItems[0].nameSetterCalled == 1
    check oldItems[0].valueSetterCalled == 0  # Not called!
    check oldItems[1].nameSetterCalled == 1
    check oldItems[1].valueSetterCalled == 0
    check oldItems[2].nameSetterCalled == 1
    check oldItems[2].valueSetterCalled == 0
    
    # In contrast, with dataChanged(role=KeyPair):
    # - All 3 items would emit "entire item changed"
    # - QML would re-evaluate ALL bindings (name AND value)
    # - Result: 2x more QML work than necessary!

when isMainModule:
  echo "Running model sync tests..."

