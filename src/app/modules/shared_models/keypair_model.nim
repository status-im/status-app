import nimqml, tables, std/strformat, sequtils, sugar
import keypair_item
import keypair_account_item
import ./currency_amount

export keypair_item

type
  ModelRole {.pure.} = enum
    KeyPair = UserRole + 1

QtObject:
  type
    KeyPairModel* = ref object of QAbstractListModel
      items: seq[KeyPairItem]

  proc delete(self: KeyPairModel)
  proc setup(self: KeyPairModel)
  proc newKeyPairModel*(): KeyPairModel =
    new(result, delete)
    result.setup

  proc countChanged(self: KeyPairModel) {.signal.}
  proc getCount*(self: KeyPairModel): int {.slot.} =
    self.items.len
  QtProperty[int]count:
    read = getCount
    notify = countChanged

  proc `$`*(self: KeyPairModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""KeyPairModel:
      [{i}]:({$self.items[i]})
      """

  method rowCount(self: KeyPairModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: KeyPairModel): Table[int, string] =
    {
      ModelRole.KeyPair.int: "keyPair",
    }.toTable

  method data(self: KeyPairModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return
    if (index.row < 0 or index.row >= self.items.len):
      return
    let item = self.items[index.row]
    let enumRole = role.ModelRole
    case enumRole:
    of ModelRole.KeyPair:
      result = newQVariant(item)

  proc setItems*(self: KeyPairModel, items: seq[KeyPairItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc addItem*(self: KeyPairModel, item: KeyPairItem) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()

  proc findItemByKeyUid*(self: KeyPairModel, keyUid: string): KeyPairItem =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeyUid() == keyUid):
        return self.items[i]
    return nil

  proc findKeyPairAndAccountByAddresss*(self: KeyPairModel, address: string): (KeyPairItem, KeyPairAccountItem) =
    for i in 0 ..< self.items.len:
      let account = self.items[i].getAccountByAddress(address)
      if not account.isNil:
        return (self.items[i], account)
    return (nil, nil)

  proc onUpdatedAccount*(self: KeyPairModel, keyUid, address, name, colorId, emoji: string) =
    for item in self.items:
      if keyUid == item.getKeyUid():
        item.getAccountsModel().updateDetailsForAddressIfTheyAreSet(address, name, colorId, emoji)
        break

  proc onUpdatedKeypairOperability*(self: KeyPairModel, keyUid, operability: string) =
    for item in self.items:
      if keyUid == item.getKeyUid():
        item.updateOperabilityForAllAddresses(operability)
        break

  proc onHideFromTotalBalanceUpdated*(self: KeyPairModel, keyUid, address: string, hideFromTotalBalance: bool) =
    for item in self.items:
      if keyUid == item.getKeyUid():
        item.getAccountsModel().updateAccountHiddenInTotalBalance(address, hideFromTotalBalance)
        break

  proc keypairNameExists*(self: KeyPairModel, name: string): bool =
    return self.items.any(x => x.getName() == name)

  proc updateKeypairName*(self: KeyPairModel, keyUid: string, name: string) =
    let item = self.findItemByKeyUid(keyUid)
    if item.isNil:
      return
    item.setName(name)

  proc setOwnershipVerified*(self: KeyPairModel, keyUid: string, ownershipVerified: bool) =
    let item = self.findItemByKeyUid(keyUid)
    if item.isNil:
      return
    item.setOwnershipVerified(ownershipVerified)

  proc setBalanceForAddress*(self: KeyPairModel, address: string, balance: CurrencyAmount) =
    for item in self.items:
      item.setBalanceForAddress(address, balance)

  proc delete(self: KeyPairModel) =
    self.QAbstractListModel.delete

  proc setup(self: KeyPairModel) =
    self.QAbstractListModel.setup

