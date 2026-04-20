# Verbatim copy of the master version of
# src/app/modules/main/wallet_section/assets/balances_model.nim
# (the OLD nested model: no cache, reads through delegate, no granular
# update path).
#
# Renamed `BalancesModel` -> `BalancesModelOld` and `newBalancesModel` ->
# `newBalancesModelOld` to coexist with the NEW model in the bench lib.

import nimqml, tables, strutils, stint

import ./io_interface_old

type
  ModelRole {.pure.} = enum
    Account = UserRole + 1,
    GroupKey,
    TokenKey,
    ChainId,
    TokenAddress,
    Balance

QtObject:
  type BalancesModelOld* = ref object of QAbstractListModel
    delegate: GroupedAccountAssetsDataSourceOld
    index: int

  proc setup(self: BalancesModelOld)
  proc delete(self: BalancesModelOld)
  proc newBalancesModelOld*(delegate: GroupedAccountAssetsDataSourceOld, index: int): BalancesModelOld =
    new(result, delete)
    result.setup
    result.delegate = delegate
    result.index = index

  method rowCount(self: BalancesModelOld, index: QModelIndex = nil): int =
    if self.index < 0 or self.index >= self.delegate.getGroupedAssetsList().len:
      return 0
    return self.delegate.getGroupedAssetsList()[self.index].balancesPerAccount.len

  proc countChanged(self: BalancesModelOld) {.signal.}
  proc getCount(self: BalancesModelOld): int {.slot.} =
    return self.rowCount()
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method roleNames(self: BalancesModelOld): Table[int, string] =
    {
      ModelRole.Account.int:"account",
      ModelRole.GroupKey.int:"groupKey",
      ModelRole.TokenKey.int:"tokenKey",
      ModelRole.ChainId.int:"chainId",
      ModelRole.TokenAddress.int:"tokenAddress",
      ModelRole.Balance.int:"balance"
    }.toTable

  method data(self: BalancesModelOld, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if self.index < 0 or self.index >= self.delegate.getGroupedAssetsList().len or
      index.row < 0 or index.row >= self.delegate.getGroupedAssetsList()[self.index].balancesPerAccount.len:
      return
    if role < ModelRole.low.int or role > ModelRole.high.int:
      return
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

  proc setup(self: BalancesModelOld) =
    self.QAbstractListModel.setup

  proc delete(self: BalancesModelOld) =
    self.QAbstractListModel.delete
