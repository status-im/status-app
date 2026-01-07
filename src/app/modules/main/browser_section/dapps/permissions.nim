import nimqml, tables, strutils, std/strformat

type
  ModelRole {.pure.} = enum
    Name = UserRole + 1

QtObject:
  type
    PermissionsModel* = ref object of QAbstractListModel
      items: seq[string]

  proc delete(self: PermissionsModel)
  proc setup(self: PermissionsModel)
  proc newPermissionsModel*(): PermissionsModel =
    new(result, delete)
    result.setup

  proc `$`*(self: PermissionsModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i]})
      """

  proc modelChanged(self: PermissionsModel) {.signal.}

  proc getCount(self: PermissionsModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: PermissionsModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: PermissionsModel): Table[int, string] =
    {
      ModelRole.Name.int:"name"
    }.toTable

  method data(self: PermissionsModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return
    result = newQVariant(self.items[index.row])

  proc addItem*(self: PermissionsModel, item: string) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    for i in self.items:
      if i == item:
        return

    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.modelChanged()

  proc clear*(self: PermissionsModel) {.slot.} =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()

  proc delete(self: PermissionsModel) =
    self.QAbstractListModel.delete

  proc setup(self: PermissionsModel) =
    self.QAbstractListModel.setup

