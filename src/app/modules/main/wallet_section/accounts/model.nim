import nimqml, tables, strutils, std/strformat, std/sequtils, chronicles

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
    KeycardAccount,
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
      ModelRole.KeycardAccount.int: "keycardAccount",
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
      var account = items[i]
      let index = self.findAccountIndex(account)
      if index >= 0:
        let qIndex = self.createIndex(i, 0, nil)
        defer: qIndex.delete

        self.items[index] = account
        self.dataChanged(qIndex, qIndex)
        continue
      self.insertItem(account, i)
      
    self.countChanged()

    for item in items:
      self.itemChanged(item.address())

  proc updateItems*(self: Model, items: seq[Item]) =
    for account in items:
      let i = self.findAccountIndex(account)
      if i >= 0:
        self.items[i] = account
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index)
      else:
        self.insertItem(account, self.getCount())
        self.countChanged()

    for item in items:
      self.itemChanged(item.address())

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

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
    of ModelRole.KeycardAccount:
      result = newQVariant(item.keycardAccount())
    of ModelRole.AssetsLoading:
      result = newQVariant(item.assetsLoading())
    of ModelRole.IsWallet:
      result = newQVariant(item.isWallet())
    of ModelRole.HideFromTotalBalance:
      result = newQVariant(item.hideFromTotalBalance())
    of ModelRole.CanSend:
      result = newQVariant(item.canSend())

  proc updateBalance*(self: Model, address: string, balance: CurrencyAmount, assetsLoading: bool) =
    let i = self.findAccountIndex(address)
    if i < 0:
      error "Trying to update invalid account"
      return
    self.items[i].setBalance(balance)
    self.items[i].setAssetsLoading(assetsLoading)
    let index = self.createIndex(i, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.CurrencyBalance.int, ModelRole.AssetsLoading.int])

  proc updateAccountHiddenFromTotalBalance*(self: Model, address: string, hideFromTotalBalance: bool) =
    let i = self.findAccountIndex(address)
    if i < 0:
      return
    self.items[i].setHideFromTotalBalance(hideFromTotalBalance)
    let index = self.createIndex(i, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.HideFromTotalBalance.int])

  proc updateAccountsPositions*(self: Model, values: Table[string, int]) =
    for address, position in values:
      let i = self.findAccountIndex(address)
      if i < 0:
        continue
      self.items[i].setPosition(position)
    let firstIndex = self.createIndex(0, 0, nil)
    let lastIndex = self.createIndex(self.rowCount() - 1, 0, nil)
    defer: 
      firstIndex.delete
      lastIndex.delete
    self.dataChanged(firstIndex, lastIndex, @[ModelRole.Position.int])

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

