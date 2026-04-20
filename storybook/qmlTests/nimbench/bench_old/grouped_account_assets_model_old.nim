# Verbatim copy of the master version of
# src/app/modules/main/wallet_section/assets/grouped_account_assets_model.nim
# (the OLD reset-based parent model).
#
# Renamed `Model` -> `GroupedAccountAssetsModelOld` and `newModel` ->
# `newGroupedAccountAssetsModelOld` to coexist with the NEW model.

import nimqml, tables

import ./io_interface_old, ./balances_model_old

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1, # groupKey (crossChainId or tokenKey if crossChainId is empty)
    Balances

QtObject:
  type
    GroupedAccountAssetsModelOld* = ref object of QAbstractListModel
      delegate: GroupedAccountAssetsDataSourceOld
      balancesPerChain: seq[BalancesModelOld]

  proc delete(self: GroupedAccountAssetsModelOld)
  proc setup(self: GroupedAccountAssetsModelOld)
  proc newGroupedAccountAssetsModelOld*(delegate: GroupedAccountAssetsDataSourceOld): GroupedAccountAssetsModelOld =
    new(result, delete)
    result.setup
    result.delegate = delegate

  proc countChanged(self: GroupedAccountAssetsModelOld) {.signal.}
  proc getCount*(self: GroupedAccountAssetsModelOld): int {.slot.} =
    return self.delegate.getGroupedAssetsList().len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: GroupedAccountAssetsModelOld, index: QModelIndex = nil): int =
    return self.delegate.getGroupedAssetsList().len

  method roleNames(self: GroupedAccountAssetsModelOld): Table[int, string] =
    {
      ModelRole.Key.int:"key",
      ModelRole.Balances.int:"balances",
    }.toTable

  method data(self: GroupedAccountAssetsModelOld, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if index.row < 0 or index.row >= self.rowCount() or
      index.row >= self.balancesPerChain.len:
      return

    if role < ModelRole.low.int or role > ModelRole.high.int:
      return

    let enumRole = role.ModelRole
    let item = self.delegate.getGroupedAssetsList()[index.row]
    case enumRole:
    of ModelRole.Key:
      result = newQVariant(item.key)
    of ModelRole.Balances:
      result = newQVariant(self.balancesPerChain[index.row])

  proc modelsUpdated*(self: GroupedAccountAssetsModelOld) =
    self.beginResetModel()
    let lengthOfGroupedAssets = self.delegate.getGroupedAssetsList().len
    let balancesPerChainLen = self.balancesPerChain.len
    let diff = abs(lengthOfGroupedAssets - balancesPerChainLen)
    # Old behaviour preserved verbatim: only grow balancesPerChain, never
    # shrink (the comment in the original explains why - it was to avoid a
    # crash on UI when assets disappeared).  We're benchmarking the old code
    # so we keep its quirks.
    if lengthOfGroupedAssets > balancesPerChainLen:
      for i in countup(0, diff-1):
        self.balancesPerChain.add(newBalancesModelOld(self.delegate, balancesPerChainLen+i))
    self.endResetModel()
    self.countChanged()

  proc delete(self: GroupedAccountAssetsModelOld) =
    self.QAbstractListModel.delete

  proc setup(self: GroupedAccountAssetsModelOld) =
    self.QAbstractListModel.setup
    self.balancesPerChain = @[]
