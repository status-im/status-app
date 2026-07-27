import nimqml, tables

import app/global/global_singleton
import app/core/eventemitter
import app_service/service/token/service as token_service
import app_service/service/token/items/token_group
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/wallet_account/dto/asset_group_item
import app_service/service/network/service as network_service

import app/modules/shared_models/assets_aggregator
import app/modules/shared_models/token_selector_model

import ../all_tokens/module as all_tokens_module

import ./io_interface, ./view, ./controller

export io_interface

# Picker kinds the createModel factory understands (mirrors the retired
# TokenSelectorViewAdaptor configurations at the three call sites).
const
  KIND_SEND = 0      # owned-only list; search filtered to owned
  KIND_SWAP = 1      # all-tokens (lazy tokenGroupsForChainModel, source chain) + search
  KIND_BUY  = 2      # all-tokens (non-lazy tokenGroupsModel), no search
  KIND_SWAP_TO = 3   # bridge receive: all-tokens on the destination (tokenGroupsForChainToModel) + search

type
  Module* = ref object of io_interface.AccessInterface
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: Controller
    allTokensModule: all_tokens_module.Module
    moduleLoaded: bool
    # Live picker models re-pushed the owned source on token/market/preference
    # change, keyed by the id handed to QML so a destroyed modal can release its
    # model (createModelForKind adds, releaseModel removes).
    models: Table[int, TokenSelectorModel]
    nextModelId: int

proc newModule*(
  events: EventEmitter,
  tokenService: token_service.Service,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  allTokensModule: all_tokens_module.Module,
): Module =
  result = Module()
  result.events = events
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = newController(result, tokenService, walletAccountService, networkService)
  result.allTokensModule = allTokensModule
  result.moduleLoaded = false
  result.models = initTable[int, TokenSelectorModel]()

method delete*(self: Module) =
  self.controller.delete
  self.viewVariant.delete
  self.view.delete

# Replicates AssetsViewAdaptor's price selection: the first token in the group
# with a positive price, falling back to the first token.
proc priceForGroup(self: Module, group: TokenGroupItem): float =
  if group.tokens.len == 0:
    return 0.0
  var tokenKey = group.tokens[0].key
  for token in group.tokens:
    if self.controller.getPriceForToken(token.key) > 0:
      tokenKey = token.key
      break
  return self.controller.getPriceForToken(tokenKey)

proc buildOwnedSource(self: Module): tuple[groups: seq[AggTokenGroup], networks: seq[NetworkInfo]] =
  # Index per-(account, chain) balances by group key.
  var balancesByKey = initTable[string, seq[AggBalance]]()
  for assetGroup in self.controller.getGroupedAssetsList():
    var balances: seq[AggBalance] = @[]
    for b in assetGroup.balancesPerAccount:
      balances.add(AggBalance(account: b.account, chainId: b.chainId, balance: b.balance, loading: b.loading))
    balancesByKey[assetGroup.key] = balances

  var aggGroups: seq[AggTokenGroup] = @[]
  for group in self.controller.getTokenGroups():
    if group.tokens.len == 0:
      continue
    var tokenRefs: seq[tuple[key: string, chainId: int]] = @[]
    for t in group.tokens:
      tokenRefs.add((key: t.key, chainId: t.chainId))
    aggGroups.add(AggTokenGroup(
      key: group.key,
      name: group.name,
      symbol: group.symbol,
      logoUri: group.logoUri,
      decimals: group.decimals,
      communityId: group.tokens[0].communityData.id,
      marketPrice: self.priceForGroup(group),
      balances: balancesByKey.getOrDefault(group.key, @[]),
      tokens: tokenRefs))

  var networks: seq[NetworkInfo] = @[]
  for n in self.controller.getCurrentNetworks():
    networks.add(NetworkInfo(chainId: n.chainId, chainName: n.chainName, iconUrl: n.iconUrl))

  return (aggGroups, networks)

proc pushOwnedSource(self: Module) =
  let (groups, networks) = self.buildOwnedSource()
  for m in self.models.values:
    m.setOwnedSource(groups, networks)

proc refreshModels(self: Module) =
  for m in self.models.values:
    m.refresh()

proc toPopularGroups(self: Module, groups: seq[TokenGroupItem]): seq[PopularGroup] =
  for g in groups:
    let communityId = if g.tokens.len > 0: g.tokens[0].communityData.id else: ""
    var tokenRefs: seq[tuple[key: string, chainId: int]] = @[]
    for t in g.tokens:
      tokenRefs.add((key: t.key, chainId: t.chainId))
    result.add(PopularGroup(key: g.key, name: g.name, symbol: g.symbol,
      logoUri: g.logoUri, communityId: communityId, decimals: g.decimals,
      marketPrice: self.priceForGroup(g), tokens: tokenRefs))

method createModelForKind*(self: Module, kind: int): tuple[id: int, model: TokenSelectorModel] =
  let atm = self.allTokensModule
  let searchModel = atm.getSearchResultModelObj()

  var source: TokenSelectorSource
  # Search source (send + swap + bridge receive): snapshot the lazy search-result
  # model. The search catalog is chain-agnostic, shared across the swap sides.
  if kind == KIND_SEND or kind == KIND_SWAP or kind == KIND_SWAP_TO:
    source.getSearch = proc(): seq[PopularGroup] = self.toPopularGroups(searchModel.getLoadedGroups())
    source.doSearch = proc(keyword: string) = searchModel.search(keyword)

  var mode = TokenSelectorMode.Owned
  case kind:
  of KIND_SWAP, KIND_SWAP_TO:
    mode = TokenSelectorMode.AllTokens
    # Swap pay side + same-chain receive draw the source-chain catalog; the bridge
    # receive side draws the destination-chain catalog. Both drive lazy loading
    # against their own popular model, and search against the shared search model.
    let popularModel = if kind == KIND_SWAP_TO: atm.getTokenGroupsForChainToModelObj()
                       else: atm.getTokenGroupsForChainModelObj()
    source.getPopular = proc(): seq[PopularGroup] = self.toPopularGroups(popularModel.getLoadedGroups())
    source.fetchMore = proc(searching: bool) =
      if searching: searchModel.fetchMore() else: popularModel.fetchMore()
    source.hasMore = proc(searching: bool): bool =
      if searching: searchModel.hasMoreItemsForSource() else: popularModel.hasMoreItemsForSource()
    source.isLoadingMore = proc(searching: bool): bool =
      if searching: searchModel.isLoadingMoreForSource() else: popularModel.isLoadingMoreForSource()
  of KIND_BUY:
    mode = TokenSelectorMode.AllTokens
    let popularModel = atm.getTokenGroupsModelObj()
    source.getPopular = proc(): seq[PopularGroup] = self.toPopularGroups(popularModel.getLoadedGroups())
    # tokenGroupsModel is non-lazy: no fetchMore / hasMore.
  else:
    # KIND_SEND: owned list; search results filtered to owned. Lazy loading on the
    # search source only.
    source.fetchMore = proc(searching: bool) =
      if searching: searchModel.fetchMore()
    source.hasMore = proc(searching: bool): bool =
      if searching: searchModel.hasMoreItemsForSource() else: false
    source.isLoadingMore = proc(searching: bool): bool =
      if searching: searchModel.isLoadingMoreForSource() else: false

  let model = newTokenSelectorModel(mode)
  model.setSource(source)
  let id = self.nextModelId
  self.nextModelId.inc
  self.models[id] = model
  # Seed with the current owned source so the model is populated immediately.
  let (groups, networks) = self.buildOwnedSource()
  model.setOwnedSource(groups, networks)
  return (id, model)

method releaseModel*(self: Module, id: int) =
  self.models.del(id)

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSectionTokenSelector", self.viewVariant)

  self.events.on(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT) do(e: Args):
    self.pushOwnedSource()
  self.events.on(SIGNAL_TOKENS_MARKET_VALUES_UPDATED) do(e: Args):
    self.pushOwnedSource()
  self.events.on(SIGNAL_TOKEN_PREFERENCES_UPDATED) do(e: Args):
    self.pushOwnedSource()
  self.events.on(SIGNAL_GROUPS_FOR_CHAIN_LOADED) do(e: Args):
    self.refreshModels()
  self.events.on(SIGNAL_GROUPS_FOR_CHAIN_TO_LOADED) do(e: Args):
    self.refreshModels()

  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
