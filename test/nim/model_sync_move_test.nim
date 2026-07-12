## Functional verification of syncModel's reorder handling under the real Qt
## model path. Compile with -d:QT_MODEL_SPY so model_sync records the granular
## signals it emits. Reorders degrade to remove+insert (no beginMoveRows): after
## a reorder the model reads back in the target order via data(), the recorded
## signals are inserts/removes (never a reset), and the concurrent insert+reorder
## / remove+reorder cases walk the reconciled indices.

import unittest, tables, sequtils
import nimqml

import app/modules/shared/model_sync
import app/modules/shared/qt_model_spy

type
  TItem = object
    id: string
    v: int

QtObject:
  type TModel = ref object of QAbstractListModel
    items: seq[TItem]

  proc setup(self: TModel) = self.QAbstractListModel.setup
  proc delete(self: TModel) = self.QAbstractListModel.delete
  proc newTModel(): TModel =
    new(result, delete)
    result.setup

  method rowCount(self: TModel, index: QModelIndex = nil): int =
    self.items.len

  method roleNames(self: TModel): Table[int, string] =
    {0: "id", 1: "v"}.toTable

  method data(self: TModel, index: QModelIndex, role: int): QVariant =
    if not index.isValid: return
    if index.row < 0 or index.row >= self.items.len: return
    case role
    of 0: return newQVariant(self.items[index.row].id)
    of 1: return newQVariant(self.items[index.row].v)
    else: return

  proc sync(self: TModel, newItems: seq[TItem]) =
    setItemsWithSync(
      self, self.items, newItems,
      getId = proc(x: TItem): string = x.id,
      getRoles = proc(a, b: TItem): seq[int] = (if a.v != b.v: @[1] else: @[]))

proc ids(items: seq[TItem]): seq[string] = items.mapIt(it.id)

# Read the order back through data() (what a QML view would see), not the backing seq.
proc orderViaData(m: TModel): seq[string] =
  result = @[]
  for i in 0 ..< m.rowCount():
    let idx = m.createIndex(i, 0, nil)
    result.add(m.data(idx, 0).stringVal)

proc mk(idsSeq: seq[string]): seq[TItem] =
  idsSeq.mapIt(TItem(id: it, v: 0))

suite "model_sync reorder - functional (remove+insert, no moves)":

  setup:
    let spy = newQtModelSpy()
    spy.enable()

  teardown:
    spy.disable()

  test "reversal: model reads back in target order via data(), remove+insert, no move, no reset":
    let m = newTModel()
    m.sync(mk(@["a", "b", "c", "d"]))
    spy.clear()

    m.sync(mk(@["d", "c", "b", "a"]))

    check m.orderViaData() == @["d", "c", "b", "a"]
    check spy.calls.filterIt(it.kind == BeginMoveRows).len == 0
    check spy.countInserts() > 0
    check spy.countRemoves() > 0
    check spy.countResets() == 0

  test "stable set + data change: dataChanged only, no move, no reset":
    let m = newTModel()
    m.sync(@[TItem(id: "a", v: 1), TItem(id: "b", v: 2)])
    spy.clear()

    m.sync(@[TItem(id: "a", v: 9), TItem(id: "b", v: 2)])

    check m.orderViaData() == @["a", "b"]
    check spy.countDataChanged() > 0
    check spy.calls.filterIt(it.kind == BeginMoveRows).len == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    check spy.countResets() == 0

  test "reorder + concurrent insert (walks reconciled indices)":
    let m = newTModel()
    m.sync(mk(@["a", "b", "c"]))
    spy.clear()

    m.sync(mk(@["c", "x", "a", "b"]))  # insert x, reorder survivors

    check m.orderViaData() == @["c", "x", "a", "b"]
    check spy.countResets() == 0
    check spy.calls.filterIt(it.kind == BeginMoveRows).len == 0

  test "reorder + concurrent remove (walks reconciled indices)":
    let m = newTModel()
    m.sync(mk(@["a", "b", "c", "d"]))
    spy.clear()

    m.sync(mk(@["d", "a", "c"]))  # remove b, reorder survivors

    check m.orderViaData() == @["d", "a", "c"]
    check spy.countResets() == 0
    check spy.calls.filterIt(it.kind == BeginMoveRows).len == 0
