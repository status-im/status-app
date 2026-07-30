import sets

import io_interface
import app_service/service/token/service as token_service
import app_service/service/token/items/token_group
import app_service/service/token/items/market_values
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/wallet_account/dto/asset_group_item
import app_service/service/network/service as network_service
import app_service/service/settings/service as settings_service

# The below-balance threshold is stored as a raw integer scaled by 9 decimals
# (mirrors TokensStore.getDisplayAssetsBelowBalanceThresholdDisplayAmount in QML).
const THRESHOLD_DISPLAY_DECIMALS_DIVISOR = 1_000_000_000.0

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    tokenService: token_service.Service
    walletAccountService: wallet_account_service.Service
    networkService: network_service.Service
    settingsService: settings_service.Service

proc newController*(
  delegate: io_interface.AccessInterface,
  tokenService: token_service.Service,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  settingsService: settings_service.Service,
): Controller =
  result = Controller()
  result.delegate = delegate
  result.tokenService = tokenService
  result.walletAccountService = walletAccountService
  result.networkService = networkService
  result.settingsService = settingsService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  discard

proc getTokenGroups*(self: Controller): var seq[TokenGroupItem] =
  return self.tokenService.getGroupsOfInterest()

proc getGroupedAssetsList*(self: Controller): var seq[AssetGroupItem] =
  return self.walletAccountService.getGroupedAssetsList()

proc getPriceForToken*(self: Controller, tokenKey: string): float64 =
  return self.tokenService.getPriceForToken(tokenKey)

proc getMarketValuesForToken*(self: Controller, tokenKey: string): TokenMarketValuesItem =
  return self.tokenService.getMarketValuesForToken(tokenKey)

proc getTokensDetailsLoading*(self: Controller): bool =
  return self.tokenService.getTokensDetailsLoading()

proc getTokenVisible*(self: Controller, key: string): bool =
  return self.tokenService.getTokenPreferences(key).visible

proc getTokenPosition*(self: Controller, key: string): int =
  return self.tokenService.getTokenPreferences(key).position

proc getNativeSymbolsForChains*(self: Controller, chainIds: seq[int]): seq[string] =
  ## Native token symbols of the enabled chains — these tokens can never be hidden.
  let chainSet = chainIds.toHashSet
  for network in self.networkService.getCurrentNetworks():
    if network.chainId in chainSet:
      result.add(network.nativeCurrencySymbol)

proc getMarketValueThreshold*(self: Controller): float =
  if not self.settingsService.displayAssetsBelowBalance():
    return 0.0
  return float(self.settingsService.displayAssetsBelowBalanceThreshold()) / THRESHOLD_DISPLAY_DECIMALS_DIVISOR
