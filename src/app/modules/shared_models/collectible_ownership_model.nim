import nimqml, tables, strutils, std/strformat
import stint

import backend/collectibles_types as backend

type
  ModelRole {.pure.} = enum
    AccountAddress = UserRole + 1,
    Balance
    TxTimestamp

QtObject:
  type
    OwnershipModel* = ref object of QAbstractListModel
      items: seq[backend.AccountBalance]

  proc delete(self: OwnershipModel)
  proc setup(self: OwnershipModel)
  proc newOwnershipModel*(): OwnershipModel =
    new(result, delete)
    result.setup

  proc `$`*(self: OwnershipModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  proc countChanged(self: OwnershipModel) {.signal.}

  proc getCount(self: OwnershipModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: OwnershipModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: OwnershipModel): Table[int, string] =
    {
      ModelRole.AccountAddress.int:"accountAddress",
      ModelRole.Balance.int:"balance",
      ModelRole.TxTimestamp.int:"txTimestamp",
    }.toTable

  method data(self: OwnershipModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.AccountAddress:
      result = newQVariant(item.address)
    of ModelRole.Balance:
      result = newQVariant(item.balance.toString(10))
    of ModelRole.TxTimestamp:
      result = newQVariant(item.txTimestamp)

  proc setItems*(self: OwnershipModel, items: seq[backend.AccountBalance]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()
  
  proc getBalance*(self: OwnershipModel, address: string): UInt256 =
    var balance = stint.u256(0)
    for item in self.items:
      if item.address.toUpper == address.toUpper:
        balance += item.balance
        break
    return balance

  proc delete(self: OwnershipModel) =
    self.QAbstractListModel.delete

  proc setup(self: OwnershipModel) =
    self.QAbstractListModel.setup

