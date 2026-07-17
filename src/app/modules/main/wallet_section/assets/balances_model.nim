import app/modules/shared_models/model_utils
import nimqml, tables, strutils, stint

import app_service/service/wallet_account/dto/asset_group_item
import app/modules/shared/model_sync

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
    # Self-updating snapshot of the per-(token, account) balances of a single token
    # group. Held by key (the parent keeps a BalancesModel per group key), NOT by
    # positional index, so it survives the parent's granular reorders. The parent
    # pushes fresh balances via updateBalances(), which diffs against this snapshot
    # and emits granular dataChanged/insert/remove — this is the only path that
    # delivers balance changes to the view without the parent resetting.
    items: seq[BalanceItem]

  when defined(QT_MODEL_SPY):
    # Test-only destruction hook: lets grouped_account_assets_model_test observe WHEN
    # a dropped BalancesModel is ORC-freed relative to the parent's remove signals,
    # proving the child outlives modelSync's beginRemoveRows (no use-after-free).
    var onBalancesModelDeleted*: proc(self: BalancesModel) = nil

  proc setup(self: BalancesModel)
  proc delete(self: BalancesModel)
  proc newBalancesModel*(balances: seq[BalanceItem] = @[]): BalancesModel =
    new(result, delete)
    result.setup
    result.items = balances

  method rowCount(self: BalancesModel, index: QModelIndex = nil): int =
    return self.items.len

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
      of ModelRole.Loading:
        result = newQVariant(item.loading)

  proc syncKey(it: BalanceItem): string =
    # A balance row is uniquely a (token, account) pair (tokenKey already encodes
    # the chain). Stable across refreshes -> lets the diff recognise survivors.
    it.tokenKey & "|" & it.account

  proc syncRoles(o, n: BalanceItem): seq[int] =
    # Identity fields (account/tokenKey/chainId/tokenAddress/groupKey) are static for
    # a given id; only the fetched value and its loading flag move.
    result = @[]
    if o.balance != n.balance: result.add(ModelRole.Balance.int)
    if o.loading != n.loading: result.add(ModelRole.Loading.int)

  proc updateBalances*(self: BalancesModel, newBalances: seq[BalanceItem]) =
    # Granular in-place update: diff the new balances against the cached snapshot and
    # emit only the minimal insert/remove/dataChanged. No beginResetModel -> the
    # nested filteredBalances SFPM and the FunctionAggregators in AssetsViewAdaptor
    # update in place instead of being rebuilt.
    self.modelSync(self.items, newBalances)

  proc setup(self: BalancesModel) =
    self.QAbstractListModel.setup

  proc delete(self: BalancesModel) =
    when defined(QT_MODEL_SPY):
      if onBalancesModelDeleted != nil:
        onBalancesModelDeleted(self)
    self.QAbstractListModel.delete

  # Test-only accessors (used by grouped_account_assets_model_test).
  proc balanceCountForTest*(self: BalancesModel): int =
    self.items.len
  proc balanceAtForTest*(self: BalancesModel, i: int): string =
    self.items[i].balance.toString(10)
