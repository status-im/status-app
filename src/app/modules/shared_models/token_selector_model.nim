import nimqml, tables, algorithm, sequtils

import app/modules/shared_models/model_utils
import app/modules/shared/model_sync
import ./token_selector_item
import ./token_selector_balances_model
export token_selector_item, token_selector_balances_model

when defined(QT_MODEL_SPY):
  import app/modules/shared/qt_model_spy

# TokenSelectorModel — terminal model for the send/swap/buy token pickers.
#
# Replaces TokenSelectorViewAdaptor's QML proxy graph (per-group
# ObjectProxyModel + SortFilterProxyModels + FastExpressionRoles + RoleSorters +
# LeftJoins). It owns the owned/popular section split and the sort, exposes the
# per-token balance chips as a nested model, and emits per-row/per-role
# dataChanged (no layoutChanged, no reset) on a stable-set refresh.
#
# Input is a flat, already-aggregated+filtered list of TokenSelectorItem value
# DTOs (built by token_selector_builder). setSourceItems diffs the sorted view
# against the mirror.
#
# It is a TERMINAL model: bound directly to the picker ListView with no proxies
# above it, which is what makes the granular emissions safe.

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    Name
    Symbol
    LogoUri
    CurrentBalance
    CurrencyBalance
    SectionName
    Balances

QtObject:
  type
    TokenSelectorModel* = ref object of QAbstractListModel
      items: seq[TokenSelectorItem]
      # One nested balances model per group KEY, preserved across refreshes so
      # QML keeps its bound submodel alive; chip changes travel through it.
      balancesByKey: Table[string, TokenSelectorBalancesModel]
      # Section titles are translated + chain-interpolated in QML and pushed down,
      # keeping i18n out of the middleware.
      ownedSectionName: string
      popularSectionName: string

  proc delete(self: TokenSelectorModel)
  proc setup(self: TokenSelectorModel)
  proc newTokenSelectorModel*(): TokenSelectorModel =
    new(result, delete)
    result.setup
    result.balancesByKey = initTable[string, TokenSelectorBalancesModel]()

  proc countChanged(self: TokenSelectorModel) {.signal.}
  proc getCount*(self: TokenSelectorModel): int {.slot.} =
    return self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: TokenSelectorModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: TokenSelectorModel): Table[int, string] =
    {
      ModelRole.Key.int: "key",
      ModelRole.Name.int: "name",
      ModelRole.Symbol.int: "symbol",
      ModelRole.LogoUri.int: "logoUri",
      ModelRole.CurrentBalance.int: "currentBalance",
      ModelRole.CurrencyBalance.int: "currencyBalance",
      ModelRole.SectionName.int: "sectionName",
      ModelRole.Balances.int: "balances",
    }.toTable

  proc sectionNameFor(self: TokenSelectorModel, item: TokenSelectorItem): string =
    if item.hasBalance: self.ownedSectionName else: self.popularSectionName

  method data(self: TokenSelectorModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)
    let item = self.items[index.row]
    case role.ModelRole:
    of ModelRole.Key: return newQVariant(item.key)
    of ModelRole.Name: return newQVariant(item.name)
    of ModelRole.Symbol: return newQVariant(item.symbol)
    of ModelRole.LogoUri: return newQVariant(item.logoUri)
    of ModelRole.CurrentBalance: return newQVariant(item.currentBalance)
    of ModelRole.CurrencyBalance: return newQVariant(item.currencyBalance)
    of ModelRole.SectionName: return newQVariant(self.sectionNameFor(item))
    of ModelRole.Balances:
      if self.balancesByKey.hasKey(item.key):
        return newQVariant(self.balancesByKey[item.key])

  proc compareItems(a, b: TokenSelectorItem): int =
    # Owned first (hasBalance desc, matching the sectionName-descending sort:
    # "Your assets on X" > "Popular assets"), then currencyBalance descending.
    # Ties return 0 so Nim's stable sort preserves source order.
    if a.hasBalance != b.hasBalance:
      return (if a.hasBalance: -1 else: 1)
    return cmp(b.currencyBalance, a.currencyBalance)

  proc itemRoles(o, n: TokenSelectorItem): seq[int] =
    result = @[]
    if o.name != n.name: result.add(ModelRole.Name.int)
    if o.symbol != n.symbol: result.add(ModelRole.Symbol.int)
    if o.logoUri != n.logoUri: result.add(ModelRole.LogoUri.int)
    if o.currentBalance != n.currentBalance: result.add(ModelRole.CurrentBalance.int)
    if o.currencyBalance != n.currencyBalance: result.add(ModelRole.CurrencyBalance.int)
    if o.hasBalance != n.hasBalance: result.add(ModelRole.SectionName.int)
    # Balances (chips) travel through the nested model's own signals, so no
    # parent-level dataChanged for the Balances role here.

  proc reconcileBalances(self: TokenSelectorModel, newItems: seq[TokenSelectorItem]) =
    # Rebuild balancesByKey identity-preservingly BEFORE setItemsWithSync
    # announces inserts, so data(Balances) is populated for a newly inserted row
    # within this same call.
    var updated = initTable[string, TokenSelectorBalancesModel]()
    for item in newItems:
      if self.balancesByKey.hasKey(item.key):
        let bm = self.balancesByKey[item.key]
        bm.updateChips(item.chips)
        updated[item.key] = bm
      else:
        updated[item.key] = newTokenSelectorBalancesModel(item.chips)
    self.balancesByKey = updated

  proc setSourceItems*(self: TokenSelectorModel, items: seq[TokenSelectorItem]) =
    var display = items
    display.sort(compareItems)
    self.reconcileBalances(display)
    setItemsWithSync(
      self, self.items, display,
      getId = proc(it: TokenSelectorItem): string = it.key,
      getRoles = proc(o, n: TokenSelectorItem): seq[int] = itemRoles(o, n),
      countChanged = proc() = self.countChanged(),
      useBulkOps = true)

  proc setSectionNames*(self: TokenSelectorModel, owned, popular: string) =
    if owned == self.ownedSectionName and popular == self.popularSectionName:
      return
    self.ownedSectionName = owned
    self.popularSectionName = popular
    if self.items.len > 0:
      when defined(QT_MODEL_SPY):
        recordDataChanged(0, self.items.len - 1, @[ModelRole.SectionName.int])
      let first = self.createIndex(0, 0, nil)
      let last = self.createIndex(self.items.len - 1, 0, nil)
      self.dataChanged(first, last, @[ModelRole.SectionName.int])
      first.delete
      last.delete

  proc delete(self: TokenSelectorModel) =
    for bm in self.balancesByKey.values:
      bm.delete
    self.QAbstractListModel.delete

  proc setup(self: TokenSelectorModel) =
    self.QAbstractListModel.setup

  when defined(testing) or defined(QT_MODEL_SPY):
    proc keysInOrder*(self: TokenSelectorModel): seq[string] =
      self.items.mapIt(it.key)
    proc sectionNameAtForTest*(self: TokenSelectorModel, i: int): string =
      self.sectionNameFor(self.items[i])
    proc balancesModelForKey*(self: TokenSelectorModel, key: string): TokenSelectorBalancesModel =
      if self.balancesByKey.hasKey(key): return self.balancesByKey[key]
      return nil
