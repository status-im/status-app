import nimqml, tables, std/strformat, stint
import token_owners_item

type
  ModelRole {.pure.} = enum
    Name = UserRole + 1
    ContactId,
    ImageSource,
    NumberOfMessages,
    WalletAddress,
    Amount,
    RemotelyDestructState

QtObject:
  type TokenOwnersModel* = ref object of QAbstractListModel
    items*: seq[TokenOwnersItem]

  proc setup(self: TokenOwnersModel)
  proc delete(self: TokenOwnersModel)
  proc newTokenOwnersModel*(): TokenOwnersModel =
    new(result, delete)
    result.setup

  proc countChanged(self: TokenOwnersModel) {.signal.}

  proc setItems*(self: TokenOwnersModel, items: seq[TokenOwnersItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc count*(self: TokenOwnersModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = count
    notify = countChanged

  method rowCount(self: TokenOwnersModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: TokenOwnersModel): Table[int, string] =
    {
      ModelRole.Name.int:"name",
      ModelRole.ContactId.int:"contactId",
      ModelRole.ImageSource.int:"imageSource",
      ModelRole.NumberOfMessages.int:"numberOfMessages",
      ModelRole.WalletAddress.int:"walletAddress",
      ModelRole.Amount.int:"amount",
      ModelRole.RemotelyDestructState.int:"remotelyDestructState"
    }.toTable

  proc updateRemoteDestructState*(self: TokenOwnersModel, remoteDestructedAddresses: seq[string]) =
    let indexBegin = self.createIndex(0, 0, nil)
    let indexEnd = self.createIndex(self.items.len - 1, 0, nil)
    defer: indexBegin.delete
    defer: indexEnd.delete
    for i in 0 ..< self.items.len:
      self.items[0].remotelyDestructState = remoteDestructTransactionStatus(remoteDestructedAddresses, self.items[0].ownerDetails.address)
    self.dataChanged(indexBegin, indexEnd, @[ModelRole.RemotelyDestructState.int])

  method data(self: TokenOwnersModel, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.items.len:
      return
    let item = self.items[index.row]
    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Name:
        result = newQVariant(item.name)
      of ModelRole.ContactId:
        result = newQVariant(item.contactId)
      of ModelRole.ImageSource:
        result = newQVariant(item.imageSource)
      of ModelRole.NumberOfMessages:
        result = newQVariant(item.numberOfMessages)
      of ModelRole.WalletAddress:
        result = newQVariant(item.ownerDetails.address)
      of ModelRole.Amount:
        result = newQVariant(item.amount.toString(10))
      of ModelRole.RemotelyDestructState:
        result = newQVariant(item.remotelyDestructState.int)

  proc `$`*(self: TokenOwnersModel): string =
      for i in 0 ..< self.items.len:
        result &= fmt"""TokenOwnersModel:
        [{i}]:({$self.items[i]})
        """

  proc setup(self: TokenOwnersModel) =
    self.QAbstractListModel.setup

  proc delete(self: TokenOwnersModel) =
    self.QAbstractListModel.delete

