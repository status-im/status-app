## v3 unified API: `modelSync` one-liner + `reconcileByKey` child reconciliation.
## Compile with -d:QT_MODEL_SPY so the granular signals are recorded and asserted:
## a stable-set value change is a single dataChanged (no reset/insert/remove); a
## nested-submodel change recurses into the child (child emits, parent silent); a
## QObject-per-key row keeps its instance across a diff.

import unittest, tables, sequtils
import nimqml

import app/modules/shared/model_sync
import app/modules/shared/qt_model_spy

# ---------------------------------------------------------------------------
# Leaf value model driven purely by the modelSync one-liner.
# ---------------------------------------------------------------------------
type
  Leaf = object
    id: string
    name: string
    v: int

proc syncKey(it: Leaf): string = it.id
proc syncRoles(o, n: Leaf): seq[int] =
  result = @[]
  if o.name != n.name: result.add(1)
  if o.v != n.v: result.add(2)

QtObject:
  type LeafModel = ref object of QAbstractListModel
    items: seq[Leaf]

  proc setup(self: LeafModel) = self.QAbstractListModel.setup
  proc delete(self: LeafModel) = self.QAbstractListModel.delete
  proc newLeafModel(): LeafModel =
    new(result, delete)
    result.setup

  proc countChanged(self: LeafModel) {.signal.}
  method rowCount(self: LeafModel, index: QModelIndex = nil): int = self.items.len
  method roleNames(self: LeafModel): Table[int, string] =
    {0: "id", 1: "name", 2: "v"}.toTable
  method data(self: LeafModel, index: QModelIndex, role: int): QVariant =
    if not index.isValid or index.row < 0 or index.row >= self.items.len: return
    case role
    of 0: return newQVariant(self.items[index.row].id)
    of 1: return newQVariant(self.items[index.row].name)
    of 2: return newQVariant(self.items[index.row].v)
    else: return

  proc sync(self: LeafModel, newItems: seq[Leaf]) =
    self.modelSync(self.items, newItems)

  proc idsInOrder(self: LeafModel): seq[string] = self.items.mapIt(it.id)

# ---------------------------------------------------------------------------
# Nested-submodel parent: each group carries a child model of subitems. A change
# confined to a subitem must recurse into the child (child signals), leaving the
# parent silent for that role.
# ---------------------------------------------------------------------------
type
  Sub = object
    id: string
    bal: int
  Group = object
    id: string
    title: string
    subs: seq[Sub]

proc syncKey(it: Sub): string = it.id
proc syncRoles(o, n: Sub): seq[int] =
  result = @[]
  if o.bal != n.bal: result.add(1)

proc syncKey(it: Group): string = it.id
proc syncRoles(o, n: Group): seq[int] =
  result = @[]
  if o.title != n.title: result.add(1)
  # subs travel through the child model's own signals — not a parent role.

QtObject:
  type SubModel = ref object of QAbstractListModel
    items: seq[Sub]
  proc setup(self: SubModel) = self.QAbstractListModel.setup
  proc delete(self: SubModel) = self.QAbstractListModel.delete
  proc newSubModel(subs: seq[Sub]): SubModel =
    new(result, delete)
    result.setup
    result.items = subs
  proc countChanged(self: SubModel) {.signal.}
  method rowCount(self: SubModel, index: QModelIndex = nil): int = self.items.len
  method roleNames(self: SubModel): Table[int, string] = {0: "id", 1: "bal"}.toTable
  method data(self: SubModel, index: QModelIndex, role: int): QVariant =
    if not index.isValid or index.row < 0 or index.row >= self.items.len: return
    case role
    of 0: return newQVariant(self.items[index.row].id)
    of 1: return newQVariant(self.items[index.row].bal)
    else: return
  proc setSubs(self: SubModel, subs: seq[Sub]) =
    self.modelSync(self.items, subs)

QtObject:
  type GroupModel = ref object of QAbstractListModel
    items: seq[Group]
    childByKey: Table[string, SubModel]
  proc setup(self: GroupModel) = self.QAbstractListModel.setup
  proc delete(self: GroupModel) = self.QAbstractListModel.delete
  proc newGroupModel(): GroupModel =
    new(result, delete)
    result.setup
    result.childByKey = initTable[string, SubModel]()
  proc countChanged(self: GroupModel) {.signal.}
  method rowCount(self: GroupModel, index: QModelIndex = nil): int = self.items.len
  method roleNames(self: GroupModel): Table[int, string] =
    {0: "id", 1: "title", 2: "subs"}.toTable
  method data(self: GroupModel, index: QModelIndex, role: int): QVariant =
    if not index.isValid or index.row < 0 or index.row >= self.items.len: return
    let g = self.items[index.row]
    case role
    of 0: return newQVariant(g.id)
    of 1: return newQVariant(g.title)
    of 2:
      if self.childByKey.hasKey(g.id): return newQVariant(self.childByKey[g.id])
      return
    else: return

  proc sync(self: GroupModel, newGroups: seq[Group]) =
    reconcileByKey(self.childByKey, newGroups,
      create = proc(g: Group): SubModel = newSubModel(g.subs),
      update = proc(sm: SubModel, g: Group) = sm.setSubs(g.subs))
    self.modelSync(self.items, newGroups)

  proc childForKey(self: GroupModel, key: string): SubModel =
    if self.childByKey.hasKey(key): return self.childByKey[key]
    return nil
  proc idsInOrder(self: GroupModel): seq[string] = self.items.mapIt(it.id)

# ---------------------------------------------------------------------------
# QObject-per-key reconciliation (market-details shape): the instance must be
# preserved across a diff for a surviving key.
# ---------------------------------------------------------------------------
QtObject:
  type Detail = ref object of QObject
    key: string
  proc delete(self: Detail) = self.QObject.delete
  proc setup(self: Detail) = self.QObject.setup
  proc newDetail(key: string): Detail =
    new(result, delete)
    result.setup
    result.key = key

suite "model_sync v3 unified API":
  setup:
    let spy = newQtModelSpy()
    spy.enable()
  teardown:
    spy.disable()

  test "leaf one-liner: first load, then stable-set value change is a single dataChanged":
    let m = newLeafModel()
    m.sync(@[Leaf(id: "a", name: "A", v: 1), Leaf(id: "b", name: "B", v: 2)])
    check m.idsInOrder() == @["a", "b"]
    spy.clear()

    m.sync(@[Leaf(id: "a", name: "A", v: 9), Leaf(id: "b", name: "B", v: 2)])
    check m.idsInOrder() == @["a", "b"]
    check spy.countDataChanged() == 1
    check spy.getDataChanged()[0].roles == @[2]
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    check spy.countResets() == 0

  test "leaf one-liner: insert + remove, no reset":
    let m = newLeafModel()
    m.sync(@[Leaf(id: "a"), Leaf(id: "b"), Leaf(id: "c")])
    spy.clear()

    m.sync(@[Leaf(id: "a"), Leaf(id: "x"), Leaf(id: "c")])  # remove b, insert x
    check m.idsInOrder() == @["a", "x", "c"]
    check spy.countResets() == 0
    check spy.countInserts() > 0
    check spy.countRemoves() > 0

  test "recursion: subitem change recurses into child, parent stays silent":
    let m = newGroupModel()
    m.sync(@[
      Group(id: "g1", title: "G1", subs: @[Sub(id: "s1", bal: 1), Sub(id: "s2", bal: 2)]),
      Group(id: "g2", title: "G2", subs: @[Sub(id: "s3", bal: 3)]),
    ])
    let child1 = m.childForKey("g1")
    check child1 != nil
    spy.clear()

    # Only s1's balance changes; group set + titles unchanged.
    m.sync(@[
      Group(id: "g1", title: "G1", subs: @[Sub(id: "s1", bal: 99), Sub(id: "s2", bal: 2)]),
      Group(id: "g2", title: "G2", subs: @[Sub(id: "s3", bal: 3)]),
    ])

    # Same child instance preserved.
    check m.childForKey("g1") == child1
    # Exactly one dataChanged, on the child (bal role = 1), nothing else.
    check spy.countResets() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    check spy.countDataChanged() == 1
    check spy.getDataChanged()[0].roles == @[1]

  test "recursion: parent title change is a parent dataChanged, child untouched":
    let m = newGroupModel()
    m.sync(@[Group(id: "g1", title: "G1", subs: @[Sub(id: "s1", bal: 1)])])
    spy.clear()

    m.sync(@[Group(id: "g1", title: "RENAMED", subs: @[Sub(id: "s1", bal: 1)])])
    check spy.countDataChanged() == 1
    check spy.getDataChanged()[0].roles == @[1]
    check spy.countResets() == 0

  test "duplicate keys in input trip the debug/test uniqueness guard":
    let m = newLeafModel()
    m.sync(@[Leaf(id: "a", name: "A", v: 1)])
    # Two rows share id "a": the diff's id->index map would be last-wins and emit a
    # spurious op for the shadowed row. The debug/testing guard rejects it up front.
    expect AssertionDefect:
      m.sync(@[Leaf(id: "a", name: "A", v: 1), Leaf(id: "a", name: "B", v: 2)])

  test "reconcileByKey preserves QObject instance across a diff, drops removed keys":
    var table = initTable[string, Detail]()
    reconcileByKey(table, @[Leaf(id: "a"), Leaf(id: "b")],
      create = proc(it: Leaf): Detail = newDetail(it.id))
    let a0 = table["a"]
    check table.len == 2

    # "a" survives, "b" removed, "c" added.
    reconcileByKey(table, @[Leaf(id: "a"), Leaf(id: "c")],
      create = proc(it: Leaf): Detail = newDetail(it.id))
    check table.len == 2
    check table.hasKey("a")
    check table.hasKey("c")
    check not table.hasKey("b")
    check table["a"] == a0   # same instance preserved
