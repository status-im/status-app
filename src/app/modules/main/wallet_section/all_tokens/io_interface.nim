import app_service/service/token/items/types as token_items
import app_service/service/currency/dto as currency_dto
import app/modules/shared_models/currency_amount

export token_items, currency_dto

type
  TokenListsModelDataSource* = tuple[
    getAllTokenLists: proc(): var seq[TokenListItem],
  ]

type
  TokensModelDataSource* = tuple[
    getTokens: proc(): var seq[TokenItem],
  ]

type
  TokenGroupsModelDataSource* = tuple[
    getAllTokenGroups: proc(): var seq[TokenGroupItem],
    getTokenDetails: proc(tokenKey: string): TokenDetailsItem,
    getTokenPreferences: proc(groupKey: string): TokenPreferencesItem,
    getCommunityTokenDescription: proc(chainId: int, address: string): string,
    getTokensDetailsLoading: proc(): bool,
    getTokensMarketValuesLoading: proc(): bool,
  ]

type
  TokenMarketValuesDataSource* = tuple[
    getMarketValuesForToken: proc(tokenKey: string): TokenMarketValuesItem,
    getPriceForToken: proc(tokenKey: string): float64,
    getCurrentCurrencyFormat: proc(): CurrencyFormatDto,
    getTokensMarketValuesLoading: proc(): bool,
  ]

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getHistoricalDataForToken*(self: AccessInterface, tokenKey: string, currency: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method tokenHistoricalDataResolved*(self: AccessInterface, tokenDetails: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getTokenListsModelDataSource*(self: AccessInterface): TokenListsModelDataSource {.base.} =
  raise newException(ValueError, "No implementation available")

method getTokensModelDataSource*(self: AccessInterface): TokensModelDataSource {.base.} =
  raise newException(ValueError, "No implementation available")

method getTokenGroupsModelDataSource*(self: AccessInterface): TokenGroupsModelDataSource {.base.} =
  raise newException(ValueError, "No implementation available")

method getTokenGroupsForChainModelDataSource*(self: AccessInterface): TokenGroupsModelDataSource {.base.} =
  raise newException(ValueError, "No implementation available")

method getTokenMarketValuesDataSource*(self: AccessInterface): TokenMarketValuesDataSource {.base.} =
  raise newException(ValueError, "No implementation available")

method updateTokenPreferences*(self: AccessInterface, tokenPreferencesJson: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getTokenPreferencesJson*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
# Delegate for the view must be declared here due to use of QtObject and multi
# inheritance, which is not well supported in Nim.
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method buildGroupsForChain*(self: AccessInterface, chainId: int): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getTokenByKeyOrGroupKeyFromAllTokens*(self: AccessInterface, key: string): TokenItem {.base.} =
  raise newException(ValueError, "No implementation available")

method filterChanged*(self: AccessInterface, addresses: seq[string]) {.base.} =
  raise newException(ValueError, "No implementation available")

method getTokenGroupByCommunity*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleTokenGroupByCommunity*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getShowCommunityAssetWhenSendingTokens*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleShowCommunityAssetWhenSendingTokens*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getDisplayAssetsBelowBalance*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleDisplayAssetsBelowBalance*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getDisplayAssetsBelowBalanceThreshold*(self: AccessInterface): CurrencyAmount {.base.} =
  raise newException(ValueError, "No implementation available")

method setDisplayAssetsBelowBalanceThreshold*(self: AccessInterface, threshold: int64): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getLastTokensUpdate*(self: AccessInterface): int64 {.base.} =
  raise newException(ValueError, "No implementation available")

method getAutoRefreshTokensLists*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleAutoRefreshTokensLists*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method displayAssetsBelowBalanceChanged*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method displayAssetsBelowBalanceThresholdChanged*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method showCommunityAssetWhenSendingTokensChanged*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method tokenAvailableForBridgingViaHop*(self: AccessInterface, tokenChainId: int, tokenAddress: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getMandatoryTokenGroupKeys*(self: AccessInterface): seq[string] {.base.} =
  raise newException(ValueError, "No implementation available")

method getListOfTokenKeysAvailableForSwapViaParaswap*(self: AccessInterface, chainId: int): seq[string] {.base.} =
  raise newException(ValueError, "No implementation available")