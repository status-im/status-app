import nimqml, tables, sets, algorithm, sequtils, strutils

import app/modules/shared_models/model_utils
import app/modules/shared/model_sync
import app/modules/shared_models/assets_aggregator
import ./token_selector_item
import ./token_selector_builder
import ./token_selector_balances_model
import ./token_selector_tokens_model
export token_selector_item, token_selector_builder, token_selector_balances_model,
  token_selector_tokens_model

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
    Decimals
    CryptoPrice
    CurrentBalance
    CurrencyBalance
    SectionName
    Balances
    Tokens

  TokenSelectorSource* = object
    ## Closures the producer wires to the all_tokens lazy models, so the terminal
    ## model can (re)read the popular/search rows and drive their lazy loading
    ## without middleware coupling. All optional: send owns no popular list, buy
    ## has no search source. `searching` selects which lazy list to act on.
    getPopular*: proc(): seq[PopularGroup] {.closure.}          ## loaded popular rows (AllTokens mode)
    getSearch*: proc(): seq[PopularGroup] {.closure.}           ## loaded search rows
    doSearch*: proc(keyword: string) {.closure.}               ## trigger a backend search
    fetchMore*: proc(searching: bool) {.closure.}              ## grow the active lazy list
    hasMore*: proc(searching: bool): bool {.closure.}
    isLoadingMore*: proc(searching: bool): bool {.closure.}

QtObject:
  type
    TokenSelectorModel* = ref object of QAbstractListModel
      items: seq[TokenSelectorItem]
      # One nested balances model per group KEY, preserved across refreshes so
      # QML keeps its bound submodel alive; chip changes travel through it.
      balancesByKey: Table[string, TokenSelectorBalancesModel]
      # One nested tokens model per group KEY (static per-chain token identity),
      # read by the buy modal's provider filter; preserved for the same reason.
      tokensByKey: Table[string, TokenSelectorTokensModel]
      # Section titles are translated + chain-interpolated in QML and pushed down,
      # keeping i18n out of the middleware.
      ownedSectionName: string
      popularSectionName: string
      # Producer-driven inputs the model re-derives its rows from on any change.
      mode: TokenSelectorMode
      ownedGroups: seq[AggTokenGroup]
      networks: seq[NetworkInfo]
      params: TokenSelectorParams
      source: TokenSelectorSource
      searchKeyword: string

  proc delete(self: TokenSelectorModel)
  proc setup(self: TokenSelectorModel)
  proc newTokenSelectorModel*(mode = TokenSelectorMode.Owned): TokenSelectorModel =
    new(result, delete)
    result.setup
    result.mode = mode
    result.balancesByKey = initTable[string, TokenSelectorBalancesModel]()
    result.tokensByKey = initTable[string, TokenSelectorTokensModel]()

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
      ModelRole.Decimals.int: "decimals",
      ModelRole.CryptoPrice.int: "cryptoPrice",
      ModelRole.CurrentBalance.int: "currentBalance",
      ModelRole.CurrencyBalance.int: "currencyBalance",
      ModelRole.SectionName.int: "sectionName",
      ModelRole.Balances.int: "balances",
      ModelRole.Tokens.int: "tokens",
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
    of ModelRole.Decimals: return newQVariant(item.decimals)
    of ModelRole.CryptoPrice: return newQVariant(item.marketPrice)
    of ModelRole.CurrentBalance: return newQVariant(item.currentBalance)
    of ModelRole.CurrencyBalance: return newQVariant(item.currencyBalance)
    of ModelRole.SectionName: return newQVariant(self.sectionNameFor(item))
    of ModelRole.Balances:
      if self.balancesByKey.hasKey(item.key):
        return newQVariant(self.balancesByKey[item.key])
    of ModelRole.Tokens:
      if self.tokensByKey.hasKey(item.key):
        return newQVariant(self.tokensByKey[item.key])

  proc compareItems(a, b: TokenSelectorItem): int =
    # Owned first (hasBalance desc, matching the sectionName-descending sort:
    # "Your assets on X" > "Popular assets"), then currencyBalance descending.
    # Ties return 0 so Nim's stable sort preserves source order.
    if a.hasBalance != b.hasBalance:
      return (if a.hasBalance: -1 else: 1)
    return cmp(b.currencyBalance, a.currencyBalance)

  proc syncKey(it: TokenSelectorItem): string = it.key
  proc syncRoles(o, n: TokenSelectorItem): seq[int] =
    result = @[]
    if o.name != n.name: result.add(ModelRole.Name.int)
    if o.symbol != n.symbol: result.add(ModelRole.Symbol.int)
    if o.logoUri != n.logoUri: result.add(ModelRole.LogoUri.int)
    if o.marketPrice != n.marketPrice: result.add(ModelRole.CryptoPrice.int)
    if o.currentBalance != n.currentBalance: result.add(ModelRole.CurrentBalance.int)
    if o.currencyBalance != n.currencyBalance: result.add(ModelRole.CurrencyBalance.int)
    if o.hasBalance != n.hasBalance: result.add(ModelRole.SectionName.int)
    # Balances (chips) travel through the nested model's own signals, so no
    # parent-level dataChanged for the Balances role here.

  proc setSourceItems*(self: TokenSelectorModel, items: seq[TokenSelectorItem]) =
    var display = items
    display.sort(compareItems)
    # Keep every submodel this refresh drops alive on the stack until AFTER
    # modelSync has emitted its remove signals. balancesByKey/tokensByKey are a
    # dropped child's SOLE ORC owner and reconcileByKey frees it the moment it
    # drops the key — before the row removal is announced. QML delegates still
    # hold the raw pointer handed out by data() (a nimqml QVariant of a QObject
    # does not keep the Nim ref alive), so freeing first is a use-after-free
    # during the delegate's own teardown. These locals outlive the whole proc.
    let survivingKeys = display.mapIt(it.key).toHashSet
    var retainedBalances {.used.}: seq[TokenSelectorBalancesModel] = @[]
    var retainedTokens {.used.}: seq[TokenSelectorTokensModel] = @[]
    for key, bm in self.balancesByKey:
      if key notin survivingKeys:
        retainedBalances.add(bm)
    for key, tm in self.tokensByKey:
      if key notin survivingKeys:
        retainedTokens.add(tm)
    # Reconcile the per-key nested balances + tokens models BEFORE modelSync
    # announces inserts, so data(Balances)/data(Tokens) is populated for a newly
    # inserted row within this same call. Each update closure recurses into the
    # surviving child model.
    reconcileByKey(self.balancesByKey, display,
      create = proc(item: TokenSelectorItem): TokenSelectorBalancesModel =
        newTokenSelectorBalancesModel(item.chips),
      update = proc(bm: TokenSelectorBalancesModel, item: TokenSelectorItem) =
        bm.updateChips(item.chips))
    reconcileByKey(self.tokensByKey, display,
      create = proc(item: TokenSelectorItem): TokenSelectorTokensModel =
        newTokenSelectorTokensModel(item.tokens),
      update = proc(tm: TokenSelectorTokensModel, item: TokenSelectorItem) =
        if tm.tokenRefs() != item.tokens:
          tm.setItems(item.tokens))
    self.modelSync(self.items, display)

  proc setSectionNames*(self: TokenSelectorModel, owned: string, popular: string) {.slot.} =
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

  # --- producer-driven recompute + dynamic params + lazy passthrough ----------
  #
  # The model holds the owned aggregation source (pushed by the producer), its
  # per-modal params, and closures onto the all_tokens lazy popular/search lists.
  # Any change (a param setter, a fresh owned push, a fetchMore, a search) re-runs
  # buildDisplayItems and diffs the result into the display via setSourceItems —
  # so the granular emissions above still hold end to end.

  proc hasMoreItemsChanged(self: TokenSelectorModel) {.signal.}
  proc isLoadingMoreChanged(self: TokenSelectorModel) {.signal.}

  proc recompute(self: TokenSelectorModel) =
    let searching = self.searchKeyword.len > 0
    var popularGroups: seq[PopularGroup] = @[]
    var searchGroups: seq[PopularGroup] = @[]
    if searching:
      if self.source.getSearch != nil:
        searchGroups = self.source.getSearch()
    elif self.mode == TokenSelectorMode.AllTokens and self.source.getPopular != nil:
      popularGroups = self.source.getPopular()
    self.setSourceItems(buildDisplayItems(
      self.ownedGroups, self.networks, self.params, self.mode, searching,
      popularGroups, searchGroups))

  proc setOwnedSource*(self: TokenSelectorModel, groups: seq[AggTokenGroup],
      networks: seq[NetworkInfo]) =
    ## Producer push of the shared owned aggregation source (+ network join data).
    self.ownedGroups = groups
    self.networks = networks
    self.recompute()
    self.hasMoreItemsChanged()

  proc refresh*(self: TokenSelectorModel) =
    ## Producer nudge when only the popular/search lazy list changed (e.g. groups
    ## for a chain finished loading) — owned source unchanged. Re-runs an active
    ## search so results appear once the backing groups-for-chain finish loading.
    if self.searchKeyword.len > 0 and self.source.doSearch != nil:
      self.source.doSearch(self.searchKeyword)
    self.recompute()
    self.hasMoreItemsChanged()

  # The params are exposed as read+write QtProperties so the QML sites can drive
  # them declaratively (Binding onto the picker model); the write setters guard
  # and recompute. No notify is needed — the binding is one-way QML -> model.
  proc setAccountAddress*(self: TokenSelectorModel, address: string) {.slot.} =
    if address == self.params.accountAddress: return
    self.params.accountAddress = address
    self.recompute()
  proc getAccountAddress(self: TokenSelectorModel): string {.slot.} =
    self.params.accountAddress
  QtProperty[string] accountAddress:
    read = getAccountAddress
    write = setAccountAddress

  proc setEnabledChainId*(self: TokenSelectorModel, chainId: int) {.slot.} =
    ## -1 means "no chain filter". The pickers only ever scope to a single chain
    ## (or none), matching the retired adaptor's single-element enabledChainIds.
    let chains = if chainId == -1: @[] else: @[chainId]
    if chains == self.params.enabledChainIds: return
    self.params.enabledChainIds = chains
    self.recompute()
  proc getEnabledChainId(self: TokenSelectorModel): int {.slot.} =
    if self.params.enabledChainIds.len == 0: -1 else: self.params.enabledChainIds[0]
  QtProperty[int] enabledChainId:
    read = getEnabledChainId
    write = setEnabledChainId

  proc setShowZeroBalanceForDefaultTokens*(self: TokenSelectorModel, value: bool) {.slot.} =
    if value == self.params.showZeroBalanceForDefaultTokens: return
    self.params.showZeroBalanceForDefaultTokens = value
    self.recompute()
  proc getShowZeroBalanceForDefaultTokens(self: TokenSelectorModel): bool {.slot.} =
    self.params.showZeroBalanceForDefaultTokens
  QtProperty[bool] showZeroBalanceForDefaultTokens:
    read = getShowZeroBalanceForDefaultTokens
    write = setShowZeroBalanceForDefaultTokens

  proc setShowCommunityAssets*(self: TokenSelectorModel, value: bool) {.slot.} =
    if value == self.params.showCommunityAssets: return
    self.params.showCommunityAssets = value
    self.recompute()
  proc getShowCommunityAssets(self: TokenSelectorModel): bool {.slot.} =
    self.params.showCommunityAssets
  QtProperty[bool] showCommunityAssets:
    read = getShowCommunityAssets
    write = setShowCommunityAssets

  proc search*(self: TokenSelectorModel, keyword: string) {.slot.} =
    let kw = keyword.strip()
    if self.source.doSearch != nil:
      self.source.doSearch(kw)
    self.searchKeyword = kw
    self.recompute()
    self.hasMoreItemsChanged()
    self.isLoadingMoreChanged()

  proc getSearchString(self: TokenSelectorModel): string {.slot.} =
    return self.searchKeyword
  QtProperty[string] searchString:
    read = getSearchString

  proc fetchMore*(self: TokenSelectorModel) {.slot.} =
    let searching = self.searchKeyword.len > 0
    if self.source.fetchMore != nil:
      self.source.fetchMore(searching)  # grows the underlying lazy list in place
    self.recompute()
    self.hasMoreItemsChanged()
    self.isLoadingMoreChanged()

  proc getHasMoreItems*(self: TokenSelectorModel): bool {.slot.} =
    if self.source.hasMore == nil: return false
    return self.source.hasMore(self.searchKeyword.len > 0)
  QtProperty[bool] hasMoreItems:
    read = getHasMoreItems
    notify = hasMoreItemsChanged

  proc getIsLoadingMore*(self: TokenSelectorModel): bool {.slot.} =
    if self.source.isLoadingMore == nil: return false
    return self.source.isLoadingMore(self.searchKeyword.len > 0)
  QtProperty[bool] isLoadingMore:
    read = getIsLoadingMore
    notify = isLoadingMoreChanged

  proc setSource*(self: TokenSelectorModel, source: TokenSelectorSource) =
    ## Producer wiring of the lazy popular/search closures at creation time.
    self.source = source

  proc delete(self: TokenSelectorModel) =
    # The per-key nested models are constructed with `new(_, delete)`, so ORC runs
    # their finalizers when balancesByKey/tokensByKey are collected — deleting them
    # explicitly here would double-free the underlying QObject. Match the repo
    # convention (keypair_model, collectibles_model): only tear down self.
    self.QAbstractListModel.delete

  proc setup(self: TokenSelectorModel) =
    self.QAbstractListModel.setup

  when defined(testing) or defined(QT_MODEL_SPY):
    proc keysInOrder*(self: TokenSelectorModel): seq[string] =
      self.items.mapIt(it.key)
    proc sectionNameAtForTest*(self: TokenSelectorModel, i: int): string =
      self.sectionNameFor(self.items[i])
    proc decimalsAtForTest*(self: TokenSelectorModel, i: int): int =
      self.items[i].decimals
    proc cryptoPriceAtForTest*(self: TokenSelectorModel, i: int): float =
      self.items[i].marketPrice
    proc balancesModelForKey*(self: TokenSelectorModel, key: string): TokenSelectorBalancesModel =
      if self.balancesByKey.hasKey(key): return self.balancesByKey[key]
      return nil
    proc tokensModelForKey*(self: TokenSelectorModel, key: string): TokenSelectorTokensModel =
      if self.tokensByKey.hasKey(key): return self.tokensByKey[key]
      return nil
