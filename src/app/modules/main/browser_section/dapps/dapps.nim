import nimqml, tables, strutils, std/strformat, json
import ./item

type
  ModelRole {.pure.} = enum
    Name = UserRole + 1
    Accounts

QtObject:
  type
    DappsModel* = ref object of QAbstractListModel
      items: seq[Item]

  proc delete(self: DappsModel)
  proc setup(self: DappsModel)
  proc newDappsModel*(): DappsModel =
    new(result, delete)
    result.setup

  proc `$`*(self: DappsModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i]})
      """

  proc modelChanged(self: DappsModel) {.signal.}

  proc countChanged(self: DappsModel) {.signal.}

  proc getCount(self: DappsModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: DappsModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: DappsModel): Table[int, string] =
    {
      ModelRole.Name.int:"name",
      ModelRole.Accounts.int:"accounts"
    }.toTable

  method data(self: DappsModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole
    case enumRole:
    of ModelRole.Name:
      result = newQVariant(item.name)
    of ModelRole.Accounts:
      result = newQVariant(item.accounts)

  proc addItem*(self: DappsModel, item: Item) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    for i in self.items:
      if i == item:
        return

    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.modelChanged()
    self.countChanged()

  proc clear*(self: DappsModel) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()
    self.countChanged()

  proc delete(self: DappsModel) =
    self.items = @[]
    self.QAbstractListModel.delete

  proc setup(self: DappsModel) =
    self.QAbstractListModel.setup

