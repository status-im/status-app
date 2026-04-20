import nimqml, tables, strutils, stint

import app/modules/shared/model_sync
import app_service/service/wallet_account/dto/asset_group_item

# Nested model in the Pattern 4 showcase.
#
# Self-contained Qt list model: owns its own `items: seq[BalanceItem]` mirror
# that is mutated in lockstep with begin*/end* signal emissions (the Qt
# contract).  The parent model feeds it updates via either:
#
#   - `setInitialItems(newBalances)`  - on parent insert.  Bulk-loads the
#     mirror without emitting any signals because the nested model has no
#     attached view yet (it was just constructed).  This is the small-N
#     perf fix: avoids the per-row signal cost on fresh loads.
#
#   - `update(newBalances)`           - on parent update.  Diffs against the
#     current mirror via setItemsWithSync and emits granular dataChanged
#     for the rows whose `balance` actually changed.

type
  ModelRole {.pure.} = enum
    Account = UserRole + 1,
    GroupKey,
    TokenKey,
    ChainId,
    TokenAddress,
    Balance

QtObject:
  type BalancesModel* = ref object of QAbstractListModel
    items: seq[BalanceItem]

  proc setup(self: BalancesModel)
  proc delete(self: BalancesModel)
  proc newBalancesModel*(): BalancesModel =
    new(result, delete)
    result.setup

  method rowCount(self: BalancesModel, index: QModelIndex = nil): int =
    return self.items.len

  proc countChanged(self: BalancesModel) {.signal.}
  proc getCount(self: BalancesModel): int {.slot.} =
    return self.items.len
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
      ModelRole.Balance.int:"balance"
    }.toTable

  method data(self: BalancesModel, index: QModelIndex, role: int): QVariant =
    if not index.isValid:
      return
    if index.row < 0 or index.row >= self.items.len:
      return
    if role < ModelRole.low.int or role > ModelRole.high.int:
      return
    let item = self.items[index.row]
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

  proc setInitialItems*(self: BalancesModel, newBalances: openArray[BalanceItem]) =
    ## Bulk-loads the mirror WITHOUT emitting any signals.  Only safe to call
    ## immediately after `newBalancesModel()` and before the model is exposed
    ## to QML.  Used by the parent model's `onInsert` callback to skip the
    ## per-row signal cost on fresh loads.
    self.items = @newBalances

  proc update*(self: BalancesModel, newBalances: openArray[BalanceItem]) =
    ## Diff the current mirror against `newBalances` and emit granular Qt
    ## notifications for the changed rows.  Used by the parent model's
    ## `onUpdate` callback when a stable parent row's balances changed.
    setItemsWithSync(
      self,
      self.items,
      newBalances,
      getId = proc(item: BalanceItem): string =
        item.account & "-" & $item.chainId & "-" & item.tokenAddress,
      getRoles = proc(oldItem, newItem: BalanceItem): seq[int] =
        var roles: seq[int] = @[]
        if oldItem.balance != newItem.balance:
          roles.add(ModelRole.Balance.int)
        return roles,
      countChanged = proc() = self.countChanged(),
      useBulkOps = true,
    )

  proc setup(self: BalancesModel) =
    self.QAbstractListModel.setup
    self.items = @[]

  proc delete(self: BalancesModel) =
    self.QAbstractListModel.delete

# No test-only accessors needed - everything the test reads goes through
# `rowCount()` and `data()` (the public Qt model API).
