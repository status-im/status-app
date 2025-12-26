import nimqml, sequtils, strutils, json, chronicles

import io_interface, token_lists_model, token_groups_model

const
  LAZY_LOADING_BATCH_SIZE = 100
  LAZY_LOADING_INITIAL_COUNT = 100

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      marketHistoryIsLoading: bool

      tokenListsModel: TokenListsModel
      tokenGroupsModel: TokenGroupsModel # refers to tokens of interest for active networks mode
      tokenGroupsForChainModel: TokenGroupsModel # refers to all tokens for a specific chain
      searchResultModel: TokenGroupsModel # refers to tokens that match the search keyword

  ## Forward declaration
  proc modelsUpdated*(self: View)
  proc delete*(self: View)

  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.marketHistoryIsLoading = false
    result.tokenListsModel = newTokenListsModel(delegate.getTokenListsModelDataSource())
    result.tokenGroupsModel = newTokenGroupsModel(
      delegate.getTokenGroupsModelDataSource(),
      delegate.getTokenMarketValuesDataSource())
    result.tokenGroupsForChainModel = newTokenGroupsModel(
      delegate.getTokenGroupsForChainModelDataSource(),
      delegate.getTokenMarketValuesDataSource(),
      modelModes = @[ModelMode.NoMarketDetails, ModelMode.UseLazyLoading],  # We allow empty market details for the tokenGroupsForChainModel, because
                                                                            # it is used for the swap input panel where market details are not needed.
      lazyLoadingBatchSize = LAZY_LOADING_BATCH_SIZE,
      lazyLoadingInitialCount = LAZY_LOADING_INITIAL_COUNT)
    result.searchResultModel = newTokenGroupsModel(
      delegate.getTokenGroupsForChainModelDataSource(),
      delegate.getTokenMarketValuesDataSource(),
      modelModes = @[ModelMode.NoMarketDetails, ModelMode.UseLazyLoading, ModelMode.IsSearchResult],
      lazyLoadingBatchSize = LAZY_LOADING_BATCH_SIZE,
      lazyLoadingInitialCount = LAZY_LOADING_INITIAL_COUNT)

  proc load*(self: View) =
    self.modelsUpdated()
    self.delegate.viewDidLoad()

  proc marketHistoryIsLoadingChanged*(self: View) {.signal.}
  proc getMarketHistoryIsLoading(self: View): QVariant {.slot.} =
    return newQVariant(self.marketHistoryIsLoading)
  proc setMarketHistoryIsLoading(self: View, isLoading: bool) =
    if self.marketHistoryIsLoading == isLoading:
      return
    self.marketHistoryIsLoading = isLoading
    self.marketHistoryIsLoadingChanged()
  QtProperty[QVariant] marketHistoryIsLoading:
    read = getMarketHistoryIsLoading
    notify = marketHistoryIsLoadingChanged

  proc getTokenListUpdatedAt(self: View): QVariant {.slot.} =
    return newQVariant(self.delegate.getLastTokensUpdate())
  proc tokenListUpdatedAtChanged(self: View) {.signal.}
  proc emitTokenListUpdatedAtSignal*(self: View) =
    self.tokenListUpdatedAtChanged()
  QtProperty[QVariant] tokenListUpdatedAt:
    read = getTokenListUpdatedAt
    notify = tokenListUpdatedAtChanged

  proc getHistoricalDataForToken*(self: View, tokenKey: string, currency: string) {.slot.} =
    self.setMarketHistoryIsLoading(true)
    self.delegate.getHistoricalDataForToken(tokenKey, currency)

  proc tokenHistoricalDataReady*(self: View, tokenDetails: string) {.signal.}

  proc setTokenHistoricalDataReady*(self: View, tokenDetails: string) =
    self.setMarketHistoryIsLoading(false)
    self.tokenHistoricalDataReady(tokenDetails)

  proc tokenListsModelChanged*(self: View) {.signal.}
  proc getTokenListsModel(self: View): QVariant {.slot.} =
    return newQVariant(self.tokenListsModel)
  QtProperty[QVariant] tokenListsModel:
    read = getTokenListsModel
    notify = tokenListsModelChanged

  proc tokenGroupsForChainModelChanged*(self: View) {.signal.}
  proc getTokenGroupsForChainModel(self: View): QVariant {.slot.} =
    return newQVariant(self.tokenGroupsForChainModel)
  QtProperty[QVariant] tokenGroupsForChainModel:
    read = getTokenGroupsForChainModel
    notify = tokenGroupsForChainModelChanged

  proc searchResultModelChanged*(self: View) {.signal.}
  proc getSearchResultModel(self: View): QVariant {.slot.} =
    return newQVariant(self.searchResultModel)
  QtProperty[QVariant] searchResultModel:
    read = getSearchResultModel
    notify = searchResultModelChanged

  proc tokenGroupsModelChanged*(self: View) {.signal.}
  proc getTokenGroupsModel(self: View): QVariant {.slot.} =
    return newQVariant(self.tokenGroupsModel)
  QtProperty[QVariant] tokenGroupsModel:
    read = getTokenGroupsModel
    notify = tokenGroupsModelChanged

  proc buildGroupsForChain*(self: View, chainId: int, mandatoryGroupKeysString: string) {.slot.} =
    if not self.delegate.buildGroupsForChain(chainId):
      return
    var mandatoryGroupKeys: seq[string] = @[]
    if mandatoryGroupKeysString.len > 0:
      mandatoryGroupKeys = mandatoryGroupKeysString.split("$$")
    else:
      mandatoryGroupKeys = self.delegate.getMandatoryTokenGroupKeys()

    self.tokenGroupsForChainModel.modelsUpdated(resetModelSize = true, mandatoryGroupKeys)
    self.tokenGroupsForChainModelChanged()

  proc getTokenByKeyOrGroupKeyFromAllTokens*(self: View, key: string): string {.slot.} =
    let token = self.delegate.getTokenByKeyOrGroupKeyFromAllTokens(key)
    if token.isNil:
      return ""
    return $(%* token)

  proc modelsUpdated*(self: View) =
    self.tokenListsModel.modelsUpdated()
    self.tokenGroupsModel.modelsUpdated()

  proc tokensMarketValuesUpdated*(self: View) =
    self.tokenGroupsModel.tokensMarketValuesUpdated()

  proc tokensMarketValuesAboutToUpdate*(self: View) =
    self.tokenGroupsModel.tokensMarketValuesAboutToUpdate()

  proc tokensDetailsUpdated*(self: View) =
    self.tokenGroupsModel.tokensDetailsUpdated()

  proc currencyFormatsUpdated*(self: View) =
    self.tokenGroupsModel.currencyFormatsUpdated()

  proc tokenPreferencesUpdated*(self: View) =
    self.tokenGroupsModel.tokenPreferencesUpdated()

  proc updateTokenPreferences*(self: View, tokenPreferencesJson: string) {.slot.} =
    self.delegate.updateTokenPreferences(tokenPreferencesJson)

  proc getTokenPreferencesJson(self: View): string {.slot.} =
    let preferences = self.delegate.getTokenPreferencesJson()
    return preferences

  QtProperty[string] tokenPreferencesJson:
    read = getTokenPreferencesJson

  proc tokenGroupByCommunityChanged*(self: View) {.signal.}

  proc getTokenGroupByCommunity(self: View): bool {.slot.} =
    return self.delegate.getTokenGroupByCommunity()

  QtProperty[bool] tokenGroupByCommunity:
    read = getTokenGroupByCommunity
    notify = tokenGroupByCommunityChanged

  proc toggleTokenGroupByCommunity*(self: View): bool {.slot.} =
    if not self.delegate.toggleTokenGroupByCommunity():
      error "Failed to toggle tokenGroupByCommunity"
      return
    self.tokenGroupByCommunityChanged()

  proc showCommunityAssetWhenSendingTokensChanged*(self: View) {.signal.}

  proc getShowCommunityAssetWhenSendingTokens(self: View): bool {.slot.} =
    return self.delegate.getShowCommunityAssetWhenSendingTokens()

  QtProperty[bool] showCommunityAssetWhenSendingTokens:
    read = getShowCommunityAssetWhenSendingTokens
    notify = showCommunityAssetWhenSendingTokensChanged

  proc toggleShowCommunityAssetWhenSendingTokens*(self: View) {.slot.} =
    if not self.delegate.toggleShowCommunityAssetWhenSendingTokens():
      error "Failed to toggle showCommunityAssetWhenSendingTokens"
      return
    self.showCommunityAssetWhenSendingTokensChanged()

  proc displayAssetsBelowBalanceChanged*(self: View) {.signal.}

  proc getDisplayAssetsBelowBalance(self: View): bool {.slot.} =
    return self.delegate.getDisplayAssetsBelowBalance()

  QtProperty[bool] displayAssetsBelowBalance:
    read = getDisplayAssetsBelowBalance
    notify = displayAssetsBelowBalanceChanged

  proc toggleDisplayAssetsBelowBalance*(self: View) {.slot.} =
    if not self.delegate.toggleDisplayAssetsBelowBalance():
      error "Failed to toggle displayAssetsBelowBalance"
      return
    self.displayAssetsBelowBalanceChanged()

  proc displayAssetsBelowBalanceThresholdChanged*(self: View) {.signal.}

  proc getDisplayAssetsBelowBalanceThreshold(self: View): QVariant {.slot.} =
    return newQVariant(self.delegate.getDisplayAssetsBelowBalanceThreshold())

  proc setDisplayAssetsBelowBalanceThreshold(self: View, threshold: string) {.slot.} =
    var num: int64
    try:
      num = parseInt(threshold)
    except ValueError:
      error "Failed to parse displayAssetsBelowBalanceThreshold"
      return
    if not self.delegate.setDisplayAssetsBelowBalanceThreshold(num):
      error "Failed to set displayAssetsBelowBalanceThreshold"
      return
    self.displayAssetsBelowBalanceThresholdChanged()

  QtProperty[QVariant] displayAssetsBelowBalanceThreshold:
    read = getDisplayAssetsBelowBalanceThreshold
    notify = displayAssetsBelowBalanceThresholdChanged


  proc autoRefreshTokensListsChanged(self: View) {.signal.}
  proc emitAutoRefreshTokensListsChanged*(self: View) =
    self.autoRefreshTokensListsChanged()
  proc getAutoRefreshTokensLists(self: View): bool {.slot.} =
    return self.delegate.getAutoRefreshTokensLists()
  proc toggleAutoRefreshTokensLists(self: View) {.slot.} =
    self.delegate.toggleAutoRefreshTokensLists()
    self.autoRefreshTokensListsChanged()
  QtProperty[bool] autoRefreshTokensLists:
    read = getAutoRefreshTokensLists
    notify = autoRefreshTokensListsChanged

  proc tokenAvailableForBridgingViaHop(self: View, tokenChainId: int, tokenAddress: string): bool {.slot.} =
    return self.delegate.tokenAvailableForBridgingViaHop(tokenChainId, tokenAddress)

  proc getListOfTokenKeysAvailableForSwapViaParaswap*(self: View, chainId: int): string {.slot.} =
    let tokenKeys = self.delegate.getListOfTokenKeysAvailableForSwapViaParaswap(chainId)
    return $(%* tokenKeys)

  proc delete*(self: View) =
    self.QObject.delete

