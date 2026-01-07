import nimqml, tables, strutils, std/strformat

import item
import app_service/common/account_constants

export item

type
  ModelRole {.pure.} = enum
    Name = UserRole + 1,
    Address
    MixedcaseAddress
    Ens
    ColorId
    IsTest

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[Item]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup

  proc `$`*(self: Model): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  proc countChanged(self: Model) {.signal.}
  proc itemChanged(self: Model, address: string) {.signal.}

  proc getCount*(self: Model): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Name.int:"name",
      ModelRole.Address.int:"address",
      ModelRole.MixedcaseAddress.int:"mixedcaseAddress",
      ModelRole.Ens.int:"ens",
      ModelRole.ColorId.int:"colorId",
      ModelRole.IsTest.int:"isTest",
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Name:
      result = newQVariant(item.getName())
    of ModelRole.Address:
      result = newQVariant(item.getAddress())
    of ModelRole.MixedcaseAddress:
      result = newQVariant(item.getMixedcaseAddress())
    of ModelRole.Ens:
      result = newQVariant(item.getEns())
    of ModelRole.ColorId:
      result = newQVariant(item.getColorId())
    of ModelRole.IsTest:
      result = newQVariant(item.getIsTest())

  proc setItems*(self: Model, items: seq[Item]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

    for item in items:
        self.itemChanged(item.getAddress())

  proc getItemByAddress*(self: Model, address: string, isTest: bool): Item =
    if address.len == 0 or address == ZERO_ADDRESS:
      return
    for item in self.items:
      if cmpIgnoreCase(item.getAddress(), address) == 0 and
        (item.getIsTest() == isTest):
          return item

  proc nameExists*(self: Model, name: string, isTest: bool): bool =
    for item in self.items:
      if item.getName() == name and
        (item.getIsTest() == isTest):
          return true
    return false

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

