import nimqml, tables, strutils, std/strformat
import ../../../../../app_service/service/wallet_account/service as wallet_account_service

type
  ModelRole {.pure.} = enum
    Name = UserRole + 1
    Address
    ColorId
    Emoji

QtObject:
  type
    AccountsModel* = ref object of QAbstractListModel
      items: seq[WalletAccountDto]

  proc delete(self: AccountsModel)
  proc setup(self: AccountsModel)
  proc newAccountsModel*(): AccountsModel =
    new(result, delete)
    result.setup

  proc `$`*(self: AccountsModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i].name})
      """

  proc modelChanged(self: AccountsModel) {.signal.}
  proc countChanged(self: AccountsModel) {.signal.}

  proc getCount(self: AccountsModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: AccountsModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: AccountsModel): Table[int, string] =
    {
      ModelRole.Name.int:"name",
      ModelRole.Address.int:"address",
      ModelRole.ColorId.int:"colorId",
      ModelRole.Emoji.int:"emoji"
    }.toTable

  method data(self: AccountsModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Name:
      result = newQVariant(item.name)
    of ModelRole.Address:
      result = newQVariant(item.address)
    of ModelRole.ColorId:
      result = newQVariant(item.colorId)
    of ModelRole.Emoji:
      result = newQVariant(item.emoji)

  proc addItem*(self: AccountsModel, item: WalletAccountDto) =
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

  proc clear*(self: AccountsModel) {.slot.} =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()
    self.countChanged()

  proc delete(self: AccountsModel) =
    self.items = @[]
    self.QAbstractListModel.delete

  proc setup(self: AccountsModel) =
    self.QAbstractListModel.setup

