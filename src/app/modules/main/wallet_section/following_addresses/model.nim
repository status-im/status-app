import nimqml, tables, strutils, std/strformat, chronicles

import item

export item

logScope:
  topics = "following-addresses-model"

type
  ModelRole {.pure.} = enum
    Address = UserRole + 1,
    EnsName,
    Tags,
    Name,
    Avatar

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[Item]

  proc setup(self: Model)
  proc delete(self: Model)

  proc newModel*(): Model =
    new(result, delete)
    result.setup

  proc `$`*(self: Model): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  proc countChanged(self: Model) {.signal.}

  proc getCount*(self: Model): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Address.int:"address",
      ModelRole.EnsName.int:"ensName",
      ModelRole.Tags.int:"tags",
      ModelRole.Name.int:"name",
      ModelRole.Avatar.int:"avatar",
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Address:
      result = newQVariant(item.getAddress())
    of ModelRole.EnsName:
      result = newQVariant(item.getEnsName())
    of ModelRole.Tags:
      result = newQVariant(item.getTags().join(","))
    of ModelRole.Name:
      result = newQVariant(item.getName())
    of ModelRole.Avatar:
      result = newQVariant(item.getAvatar())

  proc setItems*(self: Model, items: seq[Item]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc getItemByAddress*(self: Model, address: string): Item =
    if address.len == 0:
      return
    for item in self.items:
      if cmpIgnoreCase(item.getAddress(), address) == 0:
        return item

  proc setup(self: Model) =
    self.QAbstractListModel.setup

  proc delete(self: Model) =
    self.QAbstractListModel.delete
