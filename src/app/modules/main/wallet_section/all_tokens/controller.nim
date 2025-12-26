import ./io_interface

import app/core/eventemitter
import app_service/service/token/service as token_service
import app_service/service/wallet_account/service as wallet_account_service
import app/modules/shared_models/currency_amount
import app_service/service/currency/dto
import app_service/service/settings/service as settings_service
import app_service/service/community_tokens/service as community_tokens_service

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    tokenService: token_service.Service
    walletAccountService: wallet_account_service.Service
    settingsService: settings_service.Service
    communityTokensService: community_tokens_service.Service
    displayAssetsBelowBalanceThreshold: CurrencyAmount

proc newController*(
  delegate: io_interface.AccessInterface,
  events: EventEmitter,
  tokenService: token_service.Service,
  walletAccountService: wallet_account_service.Service,
  settingsService: settings_service.Service,
  communityTokensService: community_tokens_service.Service
): Controller =
  result = Controller()
  result.events = events
  result.delegate = delegate
  result.tokenService = tokenService
  result.walletAccountService = walletAccountService
  result.settingsService = settingsService
  result.communityTokensService = communityTokensService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_TOKEN_HISTORICAL_DATA_LOADED) do(e:Args):
    let args = TokenHistoricalDataArgs(e)
    self.delegate.tokenHistoricalDataResolved(args.result)

  self.events.on(SIGNAL_COMMUNITY_TOKEN_RECEIVED) do(e: Args):
    let args = CommunityTokenReceivedArgs(e)
    let token = createTokenItem(TokenDto(
        address: args.address,
        name: args.name,
        symbol: args.symbol,
        decimals: args.decimals,
        chainId: args.chainId,
        communityData: CommunityDataItem(id: args.communityId),
        logoUri: args.image,
    ))
    self.tokenService.addNewCommunityToken(token)

  self.events.on(SIGNAL_DISPLAY_ASSET_BELOW_BALANCE_UPDATED) do(e:Args):
    self.delegate.displayAssetsBelowBalanceChanged()

  self.events.on(SIGNAL_DISPLAY_ASSET_BELOW_BALANCE_THRESHOLD_UPDATED) do(e:Args):
    self.delegate.displayAssetsBelowBalanceThresholdChanged()

  self.events.on(SIGNAL_SHOW_COMMUNITY_ASSET_WHEN_SENDING_TOKENS_UPDATED) do(e:Args):
    self.delegate.showCommunityAssetWhenSendingTokensChanged()

proc getHistoricalDataForToken*(self: Controller, tokenKey: string, currency: string, range: int) =
  self.tokenService.getHistoricalDataForToken(tokenKey, currency, range)

proc getAllTokenLists*(self: Controller): var seq[TokenListItem] =
  return self.tokenService.getAllTokenLists()

proc buildGroupsForChain*(self: Controller, chainId: int): bool =
  return self.tokenService.buildGroupsForChain(chainId)

proc getTokenByKeyOrGroupKeyFromAllTokens*(self: Controller, key: string): TokenItem =
  return self.tokenService.getTokenByKeyOrGroupKeyFromAllTokens(key)

proc getGroupsForChain*(self: Controller): var seq[TokenGroupItem] =
  return self.tokenService.getGroupsForChain()

proc getGroupsOfInterest*(self: Controller): var seq[TokenGroupItem] =
  return self.tokenService.getGroupsOfInterest()

proc getTokenDetails*(self: Controller, tokenKey: string): TokenDetailsItem =
  return self.tokenService.getTokenDetails(tokenKey)

proc getLastTokensUpdate*(self: Controller): int64 =
  return self.settingsService.getLastTokensUpdate()

proc getMarketValuesForToken*(self: Controller, tokenKey: string): TokenMarketValuesItem =
  return self.tokenService.getMarketValuesForToken(tokenKey)

proc getPriceForToken*(self: Controller, tokenKey: string): float64 =
  return self.tokenService.getPriceForToken(tokenKey)

proc getCurrentCurrencyFormat*(self: Controller): CurrencyFormatDto =
  return self.walletAccountService.getCurrencyFormat(self.tokenService.getCurrency())

proc getTokensDetailsLoading*(self: Controller): bool =
  self.tokenService.getTokensDetailsLoading()

proc getTokensMarketValuesLoading*(self: Controller): bool =
  self.tokenService.getTokensMarketValuesLoading()

proc getCommunityTokenDescription*(self: Controller, chainId: int, address: string): string =
  self.communityTokensService.getCommunityTokenDescription(chainId, address)

proc updateTokenPreferences*(self: Controller, tokenPreferencesJson: string) =
  self.tokenService.updateTokenPreferences(tokenPreferencesJson)

proc getTokenPreferences*(self: Controller, groupKey: string): TokenPreferencesItem =
  return self.tokenService.getTokenPreferences(groupKey)

proc getTokenPreferencesJson*(self: Controller): string =
  return self.tokenService.getTokenPreferencesJson()

proc getTokenGroupByCommunity*(self: Controller): bool =
  return self.settingsService.tokenGroupByCommunity()

proc toggleTokenGroupByCommunity*(self: Controller): bool =
  return self.settingsService.toggleTokenGroupByCommunity()

proc getShowCommunityAssetWhenSendingTokens*(self: Controller): bool =
  return self.settingsService.showCommunityAssetWhenSendingTokens()

proc toggleShowCommunityAssetWhenSendingTokens*(self: Controller): bool =
  return self.settingsService.toggleShowCommunityAssetWhenSendingTokens()

proc getDisplayAssetsBelowBalance*(self: Controller): bool =
  return self.settingsService.displayAssetsBelowBalance()

proc toggleDisplayAssetsBelowBalance*(self: Controller): bool =
  return self.settingsService.toggleDisplayAssetsBelowBalance()

proc getDisplayAssetsBelowBalanceThreshold*(self: Controller): CurrencyAmount =
  let amount = float64(self.settingsService.displayAssetsBelowBalanceThreshold())
  self.displayAssetsBelowBalanceThreshold = newCurrencyAmount(amount, "", self.tokenService.getCurrency(), 9, true)
  return self.displayAssetsBelowBalanceThreshold

proc setDisplayAssetsBelowBalanceThreshold*(self: Controller, threshold: int64): bool =
  return self.settingsService.setDisplayAssetsBelowBalanceThreshold(threshold)

proc getAutoRefreshTokensLists*(self: Controller): bool =
  return self.settingsService.getAutoRefreshTokens()

proc toggleAutoRefreshTokensLists*(self: Controller): bool =
  return self.settingsService.toggleAutoRefreshTokens()

proc tokenAvailableForBridgingViaHop*(self: Controller, tokenChainId: int, tokenAddress: string): bool =
  return self.tokenService.tokenAvailableForBridgingViaHop(tokenChainId, tokenAddress)

proc getMandatoryTokenGroupKeys*(self: Controller): seq[string] =
  return self.tokenService.getMandatoryTokenGroupKeys()

proc getListOfTokenKeysAvailableForSwapViaParaswap*(self: Controller, chainId: int): seq[string] =
  return self.tokenService.getListOfTokenKeysAvailableForSwapViaParaswap(chainId)