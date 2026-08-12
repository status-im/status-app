import nimqml, tables, sequtils

import app/global/global_singleton
import app/core/eventemitter
import app_service/service/token/service as token_service
import app_service/service/token/items/token_group
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/wallet_account/dto/asset_group_item
import app_service/service/network/service as network_service
import app_service/service/settings/service as settings_service

import app/modules/shared_models/assets_aggregator

import ./io_interface, ./view, ./controller

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool
    addresses: seq[string]
    chainIds: seq[int]

proc newModule*(
  events: EventEmitter,
  tokenService: token_service.Service,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  settingsService: settings_service.Service,
): Module =
  result = Module()
  result.events = events
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = newController(result, tokenService, walletAccountService, networkService, settingsService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.controller.delete
  self.viewVariant.delete
  self.view.delete

# Replicates AssetsViewAdaptor's price selection: the first token in the group
# with a positive price, falling back to the first token.
proc priceAndChangeForGroup(self: Module, group: TokenGroupItem): tuple[price: float, change: float] =
  if group.tokens.len == 0:
    return (0.0, 0.0)
  var tokenKey = group.tokens[0].key
  for token in group.tokens:
    if self.controller.getPriceForToken(token.key) > 0:
      tokenKey = token.key
      break
  let price = self.controller.getPriceForToken(tokenKey)
  let change = self.controller.getMarketValuesForToken(tokenKey).changePct24hour
  return (price, change)

proc buildAndPush(self: Module) =
  # Index the per-(account, chain) balances by group key so each token group can
  # pick up its contributing balances in one lookup.
  var balancesByKey = initTable[string, seq[AggBalance]]()
  for assetGroup in self.controller.getGroupedAssetsList():
    var balances: seq[AggBalance] = @[]
    for b in assetGroup.balancesPerAccount:
      balances.add(AggBalance(account: b.account, chainId: b.chainId, balance: b.balance, loading: b.loading))
    balancesByKey[assetGroup.key] = balances

  let detailsLoading = self.controller.getTokensDetailsLoading()

  var aggGroups: seq[AggTokenGroup] = @[]
  var communities = initTable[string, AggCommunity]()
  for group in self.controller.getTokenGroups():
    if group.tokens.len == 0:
      continue
    let community = group.tokens[0].communityData
    let (price, change) = self.priceAndChangeForGroup(group)
    aggGroups.add(AggTokenGroup(
      key: group.key,
      name: group.name,
      symbol: group.symbol,
      logoUri: group.logoUri,
      decimals: group.decimals,
      communityId: community.id,
      soulbound: group.tokens.anyIt(it.soulbound),
      ownerToken: group.tokens.anyIt(it.isOwnerToken),
      marketPrice: price,
      marketChangePct24hour: change,
      marketDetailsLoading: detailsLoading,
      visible: self.controller.getTokenVisible(group.key),
      position: self.controller.getTokenPosition(group.key),
      balances: balancesByKey.getOrDefault(group.key, @[])))
    if community.id.len > 0 and not communities.hasKey(community.id):
      communities[community.id] = AggCommunity(name: community.name, image: community.image)

  let filters = AggFilters(
    accounts: self.addresses,
    chains: self.chainIds,
    marketValueThreshold: self.controller.getMarketValueThreshold(),
    nativeSymbols: self.controller.getNativeSymbolsForChains(self.chainIds))

  self.view.setSourceItems(buildAssetItems(aggGroups, communities, filters))

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSectionAssetsView", self.viewVariant)

  self.events.on(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT) do(e: Args):
    self.buildAndPush()
  self.events.on(SIGNAL_TOKENS_MARKET_VALUES_UPDATED) do(e: Args):
    self.buildAndPush()
  self.events.on(SIGNAL_TOKEN_PREFERENCES_UPDATED) do(e: Args):
    self.buildAndPush()

  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true

method filterChanged*(self: Module, addresses: seq[string], chainIds: seq[int]) =
  self.addresses = addresses
  self.chainIds = chainIds
  self.buildAndPush()
