import nimqml, chronicles

import ./io_interface, ./view, ./controller, ./token_groups_model
import ../io_interface as delegate_interface

export token_groups_model

import app/global/global_singleton
import app/core/eventemitter
import app/modules/shared_models/currency_amount
import app_service/service/token/service as token_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/currency/service
import app_service/service/settings/service as settings_service
import app_service/service/community_tokens/service as community_tokens_service

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool
    addresses: seq[string]

proc init*(
  self: Module,
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  tokenService: token_service.Service,
  walletAccountService: wallet_account_service.Service,
  settingsService: settings_service.Service,
  communityTokensService: community_tokens_service.Service
) =
  self.delegate = delegate
  self.events = events
  self.view = newView(self)
  self.viewVariant = newQVariant(self.view)
  self.controller = controller.newController(self, events, tokenService, walletAccountService, settingsService, communityTokensService)
  self.moduleLoaded = false
  self.addresses = @[]

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  tokenService: token_service.Service,
  walletAccountService: wallet_account_service.Service,
  settingsService: settings_service.Service,
  communityTokensService: community_tokens_service.Service
): Module =
  result = Module()
  result.init(delegate, events, tokenService, walletAccountService, settingsService, communityTokensService)

when defined(testing) or defined(QT_MODEL_SPY):
  proc getViewForTest*(self: Module): View = self.view

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete
  self.controller.delete

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSectionAllTokens", self.viewVariant)

  # Passing on the events for changes in model to abstract model
  self.events.on(SIGNAL_TOKENS_LIST_UPDATED) do(e: Args):
    self.view.modelsUpdated()
    self.view.emitTokenListUpdatedAtSignal()
  self.events.on(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT) do(e:Args):
    self.view.modelsUpdated()
    self.view.onWalletTokensRebuilt()
  self.events.on(SIGNAL_TOKENS_DETAILS_UPDATED) do(e: Args):
    self.view.tokensDetailsUpdated()
  self.events.on(SIGNAL_TOKENS_MARKET_VALUES_ABOUT_TO_BE_UPDATED) do(e: Args):
    self.view.tokensMarketValuesAboutToUpdate()
  self.events.on(SIGNAL_TOKENS_MARKET_VALUES_UPDATED) do(e: Args):
    self.view.tokensMarketValuesUpdated()
  self.events.on(SIGNAL_TOKEN_PREFERENCES_UPDATED) do(e: Args):
    self.view.tokenPreferencesUpdated()
  self.events.on(SIGNAL_COMMUNITY_TOKENS_DETAILS_LOADED) do(e: Args):
    self.view.tokensDetailsUpdated()
  self.events.on(SIGNAL_CURRENCY_FORMATS_UPDATED) do(e:Args):
    self.view.currencyFormatsUpdated()
  self.events.on(SIGNAL_AUTO_REFRESH_TOKENS_UPDATED) do(e:Args):
    self.view.emitAutoRefreshTokensListsChanged()
  self.events.on(SIGNAL_TOKEN_CATALOGUE_CHANGED) do(e: Args):
    let args = TokenCatalogueChangedArgs(e)
    case args.kind
    of tckTokenLists:
      self.view.onTokenListsChanged()
    of tckAllTokenGroups:
      self.view.onAllChainsGroupsChanged()
    of tckChainTokenGroups:
      self.view.onChainGroupsChanged(args.chainId, args.dropped)
  self.events.on(SIGNAL_TOKEN_CATALOGUE_LOADING_CHANGED) do(e: Args):
    if TokenCatalogueChangedArgs(e).kind != tckAllTokenGroups:
      self.view.onCatalogueLoadingChanged()

  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.allTokensModuleDidLoad()

method getHistoricalDataForToken*(self: Module, tokenKey: string, currency: string) =
  self.controller.getHistoricalDataForToken(tokenKey, currency, WEEKLY_TIME_RANGE)
  self.controller.getHistoricalDataForToken(tokenKey, currency, MONTHLY_TIME_RANGE)
  self.controller.getHistoricalDataForToken(tokenKey, currency, HALF_YEARLY_TIME_RANGE)
  self.controller.getHistoricalDataForToken(tokenKey, currency, YEARLY_TIME_RANGE)
  self.controller.getHistoricalDataForToken(tokenKey, currency, ALL_TIME_RANGE)

method getHistoricalDataForTokenByRange*(self: Module, tokenKey: string, currency: string, range: int) =
  self.controller.getHistoricalDataForToken(tokenKey, currency, range)

method tokenHistoricalDataResolved*(self: Module, tokenDetails: string) =
  self.view.setTokenHistoricalDataReady(tokenDetails)

# Interfaces for getting lists from the service files into the abstract models

method getTokenListsModelDataSource*(self: Module): TokenListsModelDataSource =
  return (
    getAllTokenLists: proc(): var seq[TokenListItem] = self.controller.getAllTokenLists(),
  )

method getTokenGroupsModelDataSource*(self: Module): TokenGroupsModelDataSource =
  return (
    getAllTokenGroups: proc(): var seq[TokenGroupItem] = self.controller.getGroupsOfInterest(),
    getTokenDetails: proc(tokenKey: string): TokenDetailsItem = self.controller.getTokenDetails(tokenKey),
    getTokenPreferences: proc(groupKey: string): TokenPreferencesItem = self.controller.getTokenPreferences(groupKey),
    getCommunityTokenDescription: proc(chainId: int, address: string): string = self.controller.getCommunityTokenDescription(chainId, address),
    getTokensDetailsLoading: proc(): bool = self.controller.getTokensDetailsLoading(),
    getTokensMarketValuesLoading: proc(): bool = self.controller.getTokensMarketValuesLoading(),
  )

method getTokenGroupsForChainModelDataSource*(self: Module, chainId: int): TokenGroupsModelDataSource =
  return (
    getAllTokenGroups: proc(): var seq[TokenGroupItem] = self.controller.getChainTokenGroups(chainId),
    getTokenDetails: proc(tokenKey: string): TokenDetailsItem = self.controller.getTokenDetails(tokenKey),
    getTokenPreferences: proc(groupKey: string): TokenPreferencesItem = self.controller.getTokenPreferences(groupKey),
    getCommunityTokenDescription: proc(chainId: int, address: string): string = self.controller.getCommunityTokenDescription(chainId, address),
    getTokensDetailsLoading: proc(): bool = self.controller.getTokensDetailsLoading(),
    getTokensMarketValuesLoading: proc(): bool = self.controller.getTokensMarketValuesLoading(),
  )

method getTokenGroupsAllChainsModelDataSource*(self: Module): TokenGroupsModelDataSource =
  return (
    getAllTokenGroups: proc(): var seq[TokenGroupItem] = self.controller.getAllChainsTokenGroups(),
    getTokenDetails: proc(tokenKey: string): TokenDetailsItem = self.controller.getTokenDetails(tokenKey),
    getTokenPreferences: proc(groupKey: string): TokenPreferencesItem = self.controller.getTokenPreferences(groupKey),
    getCommunityTokenDescription: proc(chainId: int, address: string): string = self.controller.getCommunityTokenDescription(chainId, address),
    getTokensDetailsLoading: proc(): bool = self.controller.getTokensDetailsLoading(),
    getTokensMarketValuesLoading: proc(): bool = self.controller.getTokensMarketValuesLoading(),
  )

method acquireAllTokenGroups*(self: Module) =
  self.controller.acquireAllTokenGroups()

method releaseAllTokenGroups*(self: Module) =
  self.controller.releaseAllTokenGroups()

method getTokenMarketValuesDataSource*(self: Module): TokenMarketValuesDataSource =
  return (
    getMarketValuesForToken: proc(tokenKey: string): TokenMarketValuesItem = self.controller.getMarketValuesForToken(tokenKey),
    getPriceForToken: proc(tokenKey: string): float64 = self.controller.getPriceForToken(tokenKey),
    getCurrentCurrencyFormat: proc(): CurrencyFormatDto = self.controller.getCurrentCurrencyFormat(),
    getTokensMarketValuesLoading: proc(): bool = self.controller.getTokensMarketValuesLoading(),
  )

method acquireChainTokenGroups*(self: Module, chainId: int) =
  self.controller.acquireChainTokenGroups(chainId)

method releaseChainTokenGroups*(self: Module, chainId: int) =
  self.controller.releaseChainTokenGroups(chainId)

method getChainTokenGroupsLoading*(self: Module, chainId: int): bool =
  return self.controller.getChainTokenGroupsLoading(chainId)

method isChainTokenGroupsActive*(self: Module, chainId: int): bool =
  return self.controller.isChainTokenGroupsActive(chainId)

# Non-QML accessors so the token-selector producer can snapshot the lazy popular
# and search lists and drive their fetchMore/search directly.
proc getTokenGroupsModelObj*(self: Module): TokenGroupsModel =
  self.view.getTokenGroupsModelObj()
proc getChainTokenGroupsModelObj*(self: Module, chainId: int): TokenGroupsModel =
  self.view.getChainTokenGroupsModelObj(chainId)
proc onChainTokenGroupsModelUpdated*(self: Module, listener: proc(chainId: int)) =
  self.view.onChainTokenGroupsModelUpdated(listener)
proc getSearchResultModelObj*(self: Module): TokenGroupsModel =
  self.view.getSearchResultModelObj()
proc getTokenGroupsAllChainsModelObj*(self: Module): TokenGroupsModel =
  self.view.getTokenGroupsAllChainsModelObj()
proc isAllChainsTokenGroupsLoading*(self: Module): bool =
  self.controller.getAllChainsTokenGroupsLoading()
proc acquireAllChainsTokenGroupsForKeys*(self: Module, holder: int, mandatoryGroupKeys: seq[string]) =
  self.view.acquireAllChainsTokenGroupsForKeys(holder, mandatoryGroupKeys)
proc releaseAllChainsTokenGroups*(self: Module, holder: int) =
  self.view.releaseAllChainsTokenGroups(holder)

method getTokenByKeyOrGroupKeyFromAllTokens*(self: Module, key: string): TokenItem =
  return self.controller.getTokenByKeyOrGroupKeyFromAllTokens(key)

method ensurePricesForGroup*(self: Module, key: string) =
  self.controller.ensurePricesForGroup(key)

method filterChanged*(self: Module, addresses: seq[string]) =
  if addresses == self.addresses:
      return
  self.addresses = addresses

method updateTokenPreferences*(self: Module, tokenPreferencesJson: string) {.slot.} =
  self.controller.updateTokenPreferences(tokenPreferencesJson)

method getTokenPreferencesJson*(self: Module): string =
  return self.controller.getTokenPreferencesJson()

method getTokenGroupByCommunity*(self: Module): bool =
  return self.controller.getTokenGroupByCommunity()

method toggleTokenGroupByCommunity*(self: Module): bool =
  return self.controller.toggleTokenGroupByCommunity()

method getShowCommunityAssetWhenSendingTokens*(self: Module): bool =
  return self.controller.getShowCommunityAssetWhenSendingTokens()

method toggleShowCommunityAssetWhenSendingTokens*(self: Module): bool =
  return self.controller.toggleShowCommunityAssetWhenSendingTokens()

method getDisplayAssetsBelowBalance*(self: Module): bool =
  return self.controller.getDisplayAssetsBelowBalance()

method toggleDisplayAssetsBelowBalance*(self: Module): bool =
  return self.controller.toggleDisplayAssetsBelowBalance()

method getDisplayAssetsBelowBalanceThreshold*(self: Module): CurrencyAmount =
  return self.controller.getDisplayAssetsBelowBalanceThreshold()

method setDisplayAssetsBelowBalanceThreshold*(self: Module, threshold: int64): bool =
  return self.controller.setDisplayAssetsBelowBalanceThreshold(threshold)

method getLastTokensUpdate*(self: Module): int64 =
  return self.controller.getLastTokensUpdate()

method getAutoRefreshTokensLists*(self: Module): bool =
  return self.controller.getAutoRefreshTokensLists()

method toggleAutoRefreshTokensLists*(self: Module) =
  if not self.controller.toggleAutoRefreshTokensLists():
    error "Failed to toggle autoRefreshTokensLists"
    return
  self.view.emitAutoRefreshTokensListsChanged()

method displayAssetsBelowBalanceChanged*(self: Module) =
  self.view.displayAssetsBelowBalanceChanged()

method displayAssetsBelowBalanceThresholdChanged*(self: Module) =
  self.view.displayAssetsBelowBalanceThresholdChanged()

method showCommunityAssetWhenSendingTokensChanged*(self: Module) =
  self.view.showCommunityAssetWhenSendingTokensChanged()

method getMandatoryTokenGroupKeys*(self: Module): seq[string] =
  return self.controller.getMandatoryTokenGroupKeys()

method isChainSupportedForSwap*(self: Module, chainId: int): bool =
  return self.controller.isChainSupportedForSwap(chainId)

method acquireTokenLists*(self: Module) =
  self.controller.acquireTokenLists()

method releaseTokenLists*(self: Module) =
  self.controller.releaseTokenLists()

method getTokenListsLoading*(self: Module): bool =
  return self.controller.getTokenListsLoading()
