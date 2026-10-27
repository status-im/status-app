import nimqml, tables, sets, sequtils

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

import ./io_interface, ./view, ./controller, ./chain_catalog

export io_interface

# Picker kinds the createModel factory understands (mirrors the retired
# TokenSelectorViewAdaptor configurations at the call sites).
const
  KIND_SEND = 0      # owned-only list (send, swap pay side); search filtered to owned
  KIND_SWAP = 1      # retired, built as KIND_SEND
  KIND_BUY  = 2      # all-tokens (non-lazy tokenGroupsModel), no search
  KIND_SWAP_TO = 3   # swap receive: all-tokens on the destination chain (its shared model) + search

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
    # swap receive models, each a holder of all token groups
    allTokenGroupsHolders: HashSet[int]
    # the destination chain each swap receive model reads
    catalogs: Table[int, ChainCatalog]
    # Retained until the next modal: QML tears the released list's delegates down
    # after releaseModel returns, and a modal releases its whole batch at once.
    pendingRelease: seq[TokenSelectorModel]

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
    if group.tokens.anyIt(it.soulbound or it.isOwnerToken):
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
    if g.tokens.anyIt(it.soulbound or it.isOwnerToken):
      continue
    let communityId = if g.tokens.len > 0: g.tokens[0].communityData.id else: ""
    var tokenRefs: seq[tuple[key: string, chainId: int]] = @[]
    for t in g.tokens:
      tokenRefs.add((key: t.key, chainId: t.chainId))
    result.add(PopularGroup(key: g.key, name: g.name, symbol: g.symbol,
      logoUri: g.logoUri, communityId: communityId, decimals: g.decimals,
      marketPrice: self.priceForGroup(g), tokens: tokenRefs))

method createModelForKind*(self: Module, kind: int): tuple[id: int, model: TokenSelectorModel] =
  # the previous modal is gone by now, so its retained models can go
  self.pendingRelease.setLen(0)

  let atm = self.allTokensModule
  let searchModel = atm.getSearchResultModelObj()

  var source: TokenSelectorSource
  var mode = TokenSelectorMode.Owned
  var catalog: ChainCatalog
  case kind:
  of KIND_SWAP_TO:
    mode = TokenSelectorMode.AllTokens
    # search against the shared, lazily paged search-result model
    source.getSearch = proc(): seq[PopularGroup] = self.toPopularGroups(searchModel.getLoadedGroups())
    source.doSearch = proc(keyword: string) = searchModel.search(keyword)
    # the destination chain's shared model, set by setCatalogChainId
    catalog = newChainCatalog(proc(chainId: int): TokenGroupsModel = atm.getChainTokenGroupsModelObj(chainId))
    catalog.wire(source, searchModel, proc(groups: seq[TokenGroupItem]): seq[PopularGroup] =
      self.toPopularGroups(groups))
    let allChainsModel = atm.getTokenGroupsAllChainsModelObj()
    source.getPopularAllChains = proc(): seq[PopularGroup] = self.toPopularGroups(allChainsModel.getLoadedGroups())
    source.fetchMoreAllChains = proc() = allChainsModel.fetchMore()
    source.hasMoreAllChains = proc(): bool = allChainsModel.hasMoreItemsForSource()
    source.isLoadingMoreAllChains = proc(): bool =
      allChainsModel.isLoadingMoreForSource() or atm.isAllChainsTokenGroupsLoading()
  of KIND_BUY:
    mode = TokenSelectorMode.AllTokens
    let popularModel = atm.getTokenGroupsModelObj()
    source.getPopular = proc(): seq[PopularGroup] = self.toPopularGroups(popularModel.getLoadedGroups())
    # tokenGroupsModel is non-lazy: no fetchMore / hasMore.
  else:
    # KIND_SEND: the owned list, searched in place by the model (searchOwned): the
    # holdings are in memory, so no catalog source and nothing to page. Paging the
    # catalog and keeping the held hits showed "Loading more tokens..." for as
    # long as the catalog had matches, over a list of a few rows.
    discard

  let model = newTokenSelectorModel(mode)
  model.setSource(source)
  let id = self.nextModelId
  self.nextModelId.inc
  self.models[id] = model
  # Seed with the current owned source so the model is populated immediately.
  let (groups, networks) = self.buildOwnedSource()
  model.setOwnedSource(groups, networks)
  if kind == KIND_SWAP_TO:
    self.catalogs[id] = catalog
    self.allTokenGroupsHolders.incl(id)
    atm.acquireAllChainsTokenGroupsForKeys(id, groups.mapIt(it.key))
  return (id, model)

method releaseModel*(self: Module, id: int) =
  if not self.models.hasKey(id):
    return
  let model = self.models[id]
  self.models.del(id)
  self.pendingRelease.add(model)
  self.catalogs.del(id)
  if self.allTokenGroupsHolders.missingOrExcl(id):
    return
  self.allTokensModule.releaseAllChainsTokenGroups(id)

method setCatalogChainId*(self: Module, id: int, chainId: int) =
  self.catalogs.withValue(id, catalog):
    if catalog[].setChain(chainId):
      self.models[id].refresh()

when defined(testing) or defined(QT_MODEL_SPY):
  proc hasCatalogForTest*(self: Module, id: int): bool = self.catalogs.hasKey(id)

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSectionTokenSelector", self.viewVariant)

  self.allTokensModule.onChainTokenGroupsModelUpdated(proc(chainId: int) =
    for id, catalog in self.catalogs:
      if catalog.reads(chainId):
        self.models[id].refresh())

  self.events.on(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT) do(e: Args):
    self.pushOwnedSource()
  self.events.on(SIGNAL_TOKENS_MARKET_VALUES_UPDATED) do(e: Args):
    self.pushOwnedSource()
  self.events.on(SIGNAL_TOKEN_PREFERENCES_UPDATED) do(e: Args):
    self.pushOwnedSource()
  self.events.on(SIGNAL_TOKEN_CATALOGUE_CHANGED) do(e: Args):
    let args = TokenCatalogueChangedArgs(e)
    if args.kind == tckAllTokenGroups:
      self.refreshModels()
  # only the flag: a finished load also comes as changed
  self.events.on(SIGNAL_TOKEN_CATALOGUE_LOADING_CHANGED) do(e: Args):
    if TokenCatalogueChangedArgs(e).kind == tckAllTokenGroups:
      for m in self.models.values:
        m.isLoadingMoreChanged()

  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
