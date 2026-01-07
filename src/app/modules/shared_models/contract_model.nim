import nimqml, tables, strutils, std/strformat

import ./contract_item

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    ChainId
    Address

QtObject:
  type Model* = ref object of QAbstractListModel
    items: seq[Item]

  proc setup(self: Model)
  proc delete(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup
    result.items = @[]

  proc `$`*(self: Model): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Key.int:"key",
      ModelRole.ChainId.int:"chainId",
      ModelRole.Address.int:"address",
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.rowCount():
      return
    let item = self.items[index.row]
    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Key:
        result = newQVariant(item.key())
      of ModelRole.ChainId:
        result = newQVariant(item.chainId())
      of ModelRole.Address:
        result = newQVariant(item.address())
  
  proc setItems*(self: Model, items: seq[Item]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc setup(self: Model) =
    self.QAbstractListModel.setup

  proc delete(self: Model) =
    self.QAbstractListModel.delete

