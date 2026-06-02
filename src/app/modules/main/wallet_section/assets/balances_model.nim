import app/modules/shared_models/model_utils
import nimqml, tables, strutils, sequtils, stint

import ./io_interface
type
  ModelRole {.pure.} = enum
    Account = UserRole + 1,
    GroupKey,
    TokenKey,
    ChainId,
    TokenAddress,
    Balance,
    Loading

QtObject:
  type BalancesModel* = ref object of QAbstractListModel
    delegate: io_interface.GroupedAccountAssetsDataSource
    index: int

  proc setup(self: BalancesModel)
  proc delete(self: BalancesModel)
  proc newBalancesModel*(delegate: io_interface.GroupedAccountAssetsDataSource, index: int): BalancesModel =
    new(result, delete)
    result.setup
    result.delegate = delegate
    result.index = index

  method rowCount(self: BalancesModel, index: QModelIndex = nil): int =
    if self.index < 0 or self.index >= self.delegate.getGroupedAssetsList().len:
      return 0
    return self.delegate.getGroupedAssetsList()[self.index].balancesPerAccount.len

  proc countChanged(self: BalancesModel) {.signal.}
  proc getCount(self: BalancesModel): int {.slot.} =
    return self.rowCount()
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method roleNames(self: BalancesModel): Table[int, string] =
    {
      ModelRole.Account.int:"account",
      ModelRole.GroupKey.int:"groupKey",
      ModelRole.TokenKey.int:"tokenKey",
      ModelRole.ChainId.int:"chainId",
      ModelRole.TokenAddress.int:"tokenAddress",
      ModelRole.Balance.int:"balance",
      ModelRole.Loading.int:"loading"
    }.toTable

  method data(self: BalancesModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)

    let item = self.delegate.getGroupedAssetsList()[self.index].balancesPerAccount[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Account:
        result = newQVariant(item.account)
      of ModelRole.GroupKey:
        result = newQVariant(item.groupKey)
      of ModelRole.TokenKey:
        result = newQVariant(item.tokenKey)
      of ModelRole.ChainId:
        result = newQVariant(item.chainId)
      of ModelRole.TokenAddress:
        result = newQVariant(item.tokenAddress)
      of ModelRole.Balance:
        result = newQVariant(item.balance.toString(10))
      of ModelRole.Loading:
        result = newQVariant(item.loading)

  proc setup(self: BalancesModel) =
    self.QAbstractListModel.setup

  proc delete(self: BalancesModel) =
    self.QAbstractListModel.delete