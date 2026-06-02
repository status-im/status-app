import app/modules/shared_models/model_utils
import nimqml, tables

type Item* = object
  ensUsername*: string
  isPending*: bool
  chainId*: int

type
  ModelRole {.pure.} = enum
    EnsUsername = UserRole + 1
    IsPending
    ChainId

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[Item]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup

  proc countChanged(self: Model) {.signal.}
  proc getCount(self: Model): int {.slot.} =
    self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.EnsUsername.int:"ensUsername",
      ModelRole.IsPending.int:"isPending",
      ModelRole.ChainId.int:"chainId"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.EnsUsername:
      result = newQVariant(item.ensUsername)
    of ModelRole.IsPending:
      result = newQVariant(item.isPending)
    of ModelRole.ChainId:
      result = newQVariant(item.chainId)

  proc findIndex(self: Model, chainId: int, ensUsername: string): int =
    for i in 0 ..< self.items.len:
      let item = self.items[i]
      if (item.chainId == chainId and 
          item.ensUsername == ensUsername):
        return i
    return -1

  proc containsEnsUsername*(self: Model, chainId: int, ensUsername: string): bool =
    return self.findIndex(chainId, ensUsername) != -1

  proc addItem*(self: Model, item: Item) =
    if(self.containsEnsUsername(item.chainId, item.ensUsername)):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()

  proc removeItemByEnsUsername*(self: Model, chainId: int, ensUsername: string) =
    let index = self.findIndex(chainId, ensUsername)
    if(index == -1):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.endRemoveRows()
    self.countChanged()

  proc updatePendingStatus*(self: Model, chainId: int, ensUsername: string, pendingStatus: bool) =
    let ind = self.findIndex(chainId, ensUsername)
    if(ind == -1):
      return

    self.items[ind].isPending = pendingStatus

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.IsPending.int])

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
