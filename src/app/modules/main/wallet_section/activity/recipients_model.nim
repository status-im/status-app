import app/modules/shared_models/model_utils
import nimqml, tables, strutils, sequtils, chronicles

type
  ModelRole {.pure.} = enum
    AddressRole = UserRole + 1
    HasNameRole

QtObject:
  type
    RecipientsModel* = ref object of QAbstractListModel
      addresses*: seq[string]
      # TODO: store resolved names here along addresses
      hasMore: bool

  proc delete(self: RecipientsModel)
  proc setup(self: RecipientsModel)
  proc newRecipientsModel*(): RecipientsModel =
    new(result, delete)

    result.addresses = @[]
    # TODO: init data storage for the resolved names

    result.setup

  proc countChanged(self: RecipientsModel) {.signal.}

  proc getCount*(self: RecipientsModel): int {.slot.} =
    self.addresses.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: RecipientsModel, index: QModelIndex = nil): int =
    return self.addresses.len

  method roleNames(self: RecipientsModel): Table[int, string] =
    {
      ModelRole.AddressRole.int:"address",
      ModelRole.HasNameRole.int:"hasName"
    }.toTable

  method data(self: RecipientsModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.addresses.len, role, ModelRole)

    let address = self.addresses[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.AddressRole:
      result = newQVariant(address)
    of ModelRole.HasNameRole:
      # TODO: check the resolved names storage
      result = newQVariant(false)

  proc hasMoreChanged*(self: RecipientsModel) {.signal.}

  proc setHasMore(self: RecipientsModel, hasMore: bool) {.slot.} =
    self.hasMore = hasMore
    self.hasMoreChanged()

  proc addAddresses*(self: RecipientsModel, newAddresses: seq[string], offset: int, hasMore: bool) =
    if offset == 0:
      self.beginResetModel()
      self.addresses = newAddresses
      self.endResetModel()
    else:
      let parentModelIndex = newQModelIndex()
      defer: parentModelIndex.delete

      if offset != self.addresses.len:
        error "offset != self.addresses.len"
        return
      self.beginInsertRows(parentModelIndex, self.addresses.len, self.addresses.len + newAddresses.len - 1)
      self.addresses.add(newAddresses)
      self.endInsertRows()

    self.countChanged()
    self.setHasMore(hasMore)

  proc getHasMore*(self: RecipientsModel): bool {.slot.} =
    return self.hasMore

  QtProperty[bool] hasMore:
    read = getHasMore
    notify = hasMoreChanged

  proc delete(self: RecipientsModel) =
    self.QAbstractListModel.delete

  proc setup(self: RecipientsModel) =
    self.QAbstractListModel.setup
