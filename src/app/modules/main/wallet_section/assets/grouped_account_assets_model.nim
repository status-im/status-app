import app/modules/shared_models/model_utils
import nimqml, tables, sequtils

import ./io_interface, ./balances_model

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1, # groupKey (crossChainId or tokenKey if crossChainId is empty)
    Balances

QtObject:
  type
    Model* = ref object of QAbstractListModel
      delegate: io_interface.GroupedAccountAssetsDataSource
      balancesPerChain: seq[BalancesModel]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(delegate: io_interface.GroupedAccountAssetsDataSource): Model =
    new(result, delete)
    result.setup
    result.delegate = delegate

  proc countChanged(self: Model) {.signal.}
  proc getCount*(self: Model): int {.slot.} =
    return self.delegate.getGroupedAssetsList().len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.delegate.getGroupedAssetsList().len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Key.int:"key",
      ModelRole.Balances.int:"balances",
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)

    if index.row >= self.balancesPerChain.len:
      return

    let enumRole = role.ModelRole
    let item = self.delegate.getGroupedAssetsList()[index.row]
    case enumRole:
    of ModelRole.Key:
      result = newQVariant(item.key)
    of ModelRole.Balances:
      result = newQVariant(self.balancesPerChain[index.row])

  proc modelsUpdated*(self: Model) =
    self.beginResetModel()
    let lengthOfGroupedAssets = self.delegate.getGroupedAssetsList().len
    let balancesPerChainLen = self.balancesPerChain.len
    let diff = abs(lengthOfGroupedAssets - balancesPerChainLen)
    # Please note that in case more tokens are added either due to refresh or adding of new accounts
    # new entries to fetch balances data are created.
    # On the other hand we are not deleting in case the assets disappear either on refresh
    # as there is no balance or accounts were deleted because it causes a crash on UI.
    # Also this will automatically be removed on the next time app is restarted
    if lengthOfGroupedAssets > balancesPerChainLen:
      for i in countup(0, diff-1):
        self.balancesPerChain.add(newBalancesModel(self.delegate, balancesPerChainLen+i))
    self.endResetModel()
    self.countChanged()

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
    self.balancesPerChain = @[]
