import app/modules/shared_models/model_utils
import nimqml, tables, strutils, std/strformat, std/sequtils

import ./item
import ../../../shared_models/currency_amount

type
  ModelRole {.pure.} = enum
    Name = UserRole + 1,
    Address,
    MixedcaseAddress,
    Path,
    ColorId,
    WalletType,
    CurrencyBalance,
    Emoji,
    KeyUid,
    CreatedAt,
    Position,
    MigratedToColdWallet,
    AssetsLoading,
    IsWallet,
    HideFromTotalBalance,
    CanSend

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
      ModelRole.Path.int:"path",
      ModelRole.ColorId.int:"colorId",
      ModelRole.WalletType.int:"walletType",
      ModelRole.CurrencyBalance.int:"currencyBalance",
      ModelRole.Emoji.int: "emoji",
      ModelRole.KeyUid.int: "keyUid",
      ModelRole.CreatedAt.int: "createdAt",
      ModelRole.Position.int: "position",
      ModelRole.MigratedToColdWallet.int: "migratedToColdWallet",
      ModelRole.AssetsLoading.int: "assetsLoading",
      ModelRole.IsWallet.int: "isWallet",
      ModelRole.HideFromTotalBalance.int: "hideFromTotalBalance",
      ModelRole.CanSend.int: "canSend"
    }.toTable

  proc removeItemWithIndex(self: Model, index: int) =
    if (index < 0 or index >= self.items.len):
      return
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.endRemoveRows()

  proc insertItem(self: Model, item: Item, index: int) =
    if (index < 0 or index > self.items.len):
      return
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginInsertRows(parentModelIndex, index, index)
    self.items.insert(item, index)
    self.endInsertRows()

  proc findAccountIndex(self: Model, address: string): int =
    for i in 0 ..< self.items.len:
      if(cmpIgnoreCase(self.items[i].address(), address) == 0):
        return i
    return -1

  proc findAccountIndex(self: Model, account: Item): int =
    return self.findAccountIndex(account.address())

  proc setItems*(self: Model, items: seq[Item]) =
    proc updateExistingItem(account: Item): bool =
      var itemFound = false

      proc updateRoles() =
        updateItemRolesAndNotify self.findAccountIndex(account):
          itemFound = true
          updateRoleWithValue(name, account.name())
          updateRoleWithValue(address, account.address())
          updateRoleWithValue(mixedcaseAddress, account.mixedcaseAddress())
          updateRoleWithValue(path, account.path())
          updateRoleWithValue(colorId, account.colorId())
          updateRoleWithValue(walletType, account.walletType())
          updateRoleWithValue(currencyBalance, account.currencyBalance())
          updateRoleWithValue(emoji, account.emoji())
          updateRoleWithValue(keyUid, account.keyUid())
          updateRoleWithValue(createdAt, account.createdAt())
          updateRoleWithValue(position, account.position())
          updateRoleWithValue(migratedToColdWallet, account.migratedToColdWallet())
          updateRoleWithValue(assetsLoading, account.assetsLoading())
          updateRoleWithValue(isWallet, account.isWallet())
          updateRoleWithValue(hideFromTotalBalance, account.hideFromTotalBalance())
          updateRoleWithValue(canSend, account.canSend())

      updateRoles()
      return itemFound

    var indexesToRemove: seq[int]

    #remove
    for i in 0 ..< self.items.len:
      if not items.anyIt(it.address() == self.items[i].address()):
        indexesToRemove.add(i)

    while indexesToRemove.len > 0:
      let index = pop(indexesToRemove)
      self.removeItemWithIndex(index)

    # Update or insert
    for i in 0 ..< items.len:
      let account = items[i]
      if updateExistingItem(account):
        continue
      self.insertItem(account, i)
      
    self.countChanged()

    for item in items:
      self.itemChanged(item.address())

  proc updateItems*(self: Model, items: seq[Item]) =
    proc updateExistingItem(account: Item): bool =
      var itemUpdated = false

      proc updateRoles() =
        updateItemRolesAndNotify self.findAccountIndex(account):
          itemUpdated = true
          updateRoleWithValue(name, account.name())
          updateRoleWithValue(address, account.address())
          updateRoleWithValue(mixedcaseAddress, account.mixedcaseAddress())
          updateRoleWithValue(path, account.path())
          updateRoleWithValue(colorId, account.colorId())
          updateRoleWithValue(walletType, account.walletType())
          updateRoleWithValue(currencyBalance, account.currencyBalance())
          updateRoleWithValue(emoji, account.emoji())
          updateRoleWithValue(keyUid, account.keyUid())
          updateRoleWithValue(createdAt, account.createdAt())
          updateRoleWithValue(position, account.position())
          updateRoleWithValue(migratedToColdWallet, account.migratedToColdWallet())
          updateRoleWithValue(assetsLoading, account.assetsLoading())
          updateRoleWithValue(isWallet, account.isWallet())
          updateRoleWithValue(hideFromTotalBalance, account.hideFromTotalBalance())
          updateRoleWithValue(canSend, account.canSend())

      updateRoles()
      return itemUpdated

    for account in items:
      if not updateExistingItem(account):
        self.insertItem(account, self.getCount())
        self.countChanged()

    for item in items:
      self.itemChanged(item.address())

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Name:
      result = newQVariant(item.name())
    of ModelRole.Address:
      result = newQVariant(item.address())
    of ModelRole.MixedcaseAddress:
      result = newQVariant(item.mixedcaseAddress())
    of ModelRole.Path:
      result = newQVariant(item.path())
    of ModelRole.ColorId:
      result = newQVariant(item.colorId())
    of ModelRole.WalletType:
      result = newQVariant(item.walletType())
    of ModelRole.CurrencyBalance:
      result = newQVariant(item.currencyBalance())
    of ModelRole.Emoji:
      result = newQVariant(item.emoji())
    of ModelRole.KeyUid:
      result = newQVariant(item.keyUid())
    of ModelRole.CreatedAt:
      result = newQVariant(item.createdAt())
    of ModelRole.Position:
      result = newQVariant(item.getPosition())
    of ModelRole.MigratedToColdWallet:
      result = newQVariant(item.migratedToColdWallet())
    of ModelRole.AssetsLoading:
      result = newQVariant(item.assetsLoading())
    of ModelRole.IsWallet:
      result = newQVariant(item.isWallet())
    of ModelRole.HideFromTotalBalance:
      result = newQVariant(item.hideFromTotalBalance())
    of ModelRole.CanSend:
      result = newQVariant(item.canSend())

  proc updateBalance*(self: Model, address: string, balance: CurrencyAmount, assetsLoading: bool) =
    updateItemRolesAndNotify self.findAccountIndex(address):
      updateRoleWithValue(currencyBalance, balance)
      updateRoleWithValue(assetsLoading, assetsLoading)

  proc updateAccountHiddenFromTotalBalance*(self: Model, address: string, hideFromTotalBalance: bool) =
    updateItemRolesAndNotify self.findAccountIndex(address):
      updateRole(hideFromTotalBalance)

  proc updateAccountsPositions*(self: Model, values: Table[string, int]) =
    for address, position in values:
      updateItemRolesAndNotify self.findAccountIndex(address):
        updateRole(position)

  proc deleteAccount*(self: Model, address: string) =
    let i = self.findAccountIndex(address)
    if i < 0:
      return
    self.removeItemWithIndex(i)

  proc getNameByAddress*(self: Model, address: string): string =
    let i = self.findAccountIndex(address)
    if i < 0:
      return ""
    return self.items[i].name()

  proc getEmojiByAddress*(self: Model, address: string): string =
    let i = self.findAccountIndex(address)
    if i < 0:
      return ""
    return self.items[i].emoji()

  proc getColorByAddress*(self: Model, address: string): string =
    let i = self.findAccountIndex(address)
    if i < 0:
      return ""
    return self.items[i].colorId()

  proc isOwnedAccount*(self: Model, address: string): bool =
    let i = self.findAccountIndex(address)
    if i < 0:
      return false
    return self.items[i].walletType != "watch"

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
