import nimqml, tables, std/strformat, strutils
import keypair_account_item
import ./currency_amount

import ../../../app_service/common/utils

export keypair_account_item

type
  ModelRole {.pure.} = enum
    Account = UserRole + 1

QtObject:
  type
    KeyPairAccountModel* = ref object of QAbstractListModel
      items: seq[KeyPairAccountItem]

  proc delete(self: KeyPairAccountModel)
  proc setup(self: KeyPairAccountModel)
  proc newKeyPairAccountModel*(): KeyPairAccountModel =
    new(result, delete)
    result.setup

  proc countChanged(self: KeyPairAccountModel) {.signal.}
  proc getCount*(self: KeyPairAccountModel): int {.slot.} =
    self.items.len
  QtProperty[int]count:
    read = getCount
    notify = countChanged

  proc `$`*(self: KeyPairAccountModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""KeyPairAccountModel:
      [{i}]:({$self.items[i]})
      """

  method rowCount(self: KeyPairAccountModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: KeyPairAccountModel): Table[int, string] =
    {
      ModelRole.Account.int: "account"
    }.toTable

  method data(self: KeyPairAccountModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return
    if (index.row < 0 or index.row >= self.items.len):
      return
    let item = self.items[index.row]
    let enumRole = role.ModelRole
    case enumRole:
    of ModelRole.Account:
      result = newQVariant(item)

  proc getItems*(self: KeyPairAccountModel): seq[KeyPairAccountItem] =
    return self.items

  proc setItems*(self: KeyPairAccountModel, items: seq[KeyPairAccountItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc addItem*(self: KeyPairAccountModel, item: KeyPairAccountItem) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()

  proc containsAccountAddress*(self: KeyPairAccountModel, address: string): bool =
    for it in self.items:
      if cmpIgnoreCase(it.getAddress(), address) == 0:
        return true
    return false

  proc containsAccountPath*(self: KeyPairAccountModel, path: string): bool =
    for it in self.items:
      if it.getPath() == path:
        return true
    return false

  proc containsPathOutOfTheDefaultStatusDerivationTree*(self: KeyPairAccountModel): bool =
    for it in self.items:
      if utils.isPathOutOfTheDefaultStatusDerivationTree(it.getPath()):
        return true
    return false

  proc getItemAtIndex*(self: KeyPairAccountModel, index: int): KeyPairAccountItem =
    if index < 0 or index >= self.items.len:
      return newKeyPairAccountItem()
    return self.items[index]

  proc getItemByAddress*(self: KeyPairAccountModel, address: string): KeyPairAccountItem =
    for it in self.items:
      if cmpIgnoreCase(it.getAddress(), address) == 0:
        return it
    return nil

  proc removeItemAtIndex*(self: KeyPairAccountModel, index: int) =
    if (index < 0 or index >= self.items.len):
      return
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.endRemoveRows()
    self.countChanged()

  proc removeItemByAddress*(self: KeyPairAccountModel, address: string) =
    for i in 0 ..< self.items.len:
      if cmpIgnoreCase(self.items[i].getAddress(), address) == 0:
        self.removeItemAtIndex(i)
        return

  proc updateDetailsForAddressIfTheyAreSet*(self: KeyPairAccountModel, address, name, colorId, emoji: string) =
    for i in 0 ..< self.items.len:
      if cmpIgnoreCase(self.items[i].getAddress(), address) == 0:
        if name.len > 0:
          self.items[i].setName(name)
        if colorId.len > 0:
          self.items[i].setColorId(colorId)
        if emoji.len > 0:
          self.items[i].setEmoji(emoji)
        return

  proc updateOperabilityForAllAddresses*(self: KeyPairAccountModel, operability: string) =
    for i in 0 ..< self.items.len:
      self.items[i].setOperability(operability)

  proc setBalanceForAddress*(self: KeyPairAccountModel, address: string, balance: CurrencyAmount) =
    for i in 0 ..< self.items.len:
      if cmpIgnoreCase(self.items[i].getAddress(), address) == 0:
        self.items[i].setBalance(balance)

  proc updateAccountHiddenInTotalBalance*(self: KeyPairAccountModel, address: string, hideFromTotalBalance: bool) =
    for i in 0 ..< self.items.len:
      if cmpIgnoreCase(self.items[i].getAddress(), address) == 0:
        self.items[i].setHideFromTotalBalance(hideFromTotalBalance)

  proc delete(self: KeyPairAccountModel) =
    self.QAbstractListModel.delete

  proc setup(self: KeyPairAccountModel) =
    self.QAbstractListModel.setup

