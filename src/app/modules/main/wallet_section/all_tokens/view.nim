import nimqml, sequtils, strutils, json, chronicles, tables, sets

import io_interface, token_lists_model, token_groups_model

const
  LAZY_LOADING_BATCH_SIZE = 100
  LAZY_LOADING_INITIAL_COUNT = 100
  # all QML holders of the all-chains groups share one entry; they pin the default keys
  QML_ALL_CHAINS_HOLDER = -1

type
  ChainTokenGroups = object
    model: TokenGroupsModel
    variant: QVariant
    # the keys each holder pins, by the holder's keys string, with its count
    holderKeys: OrderedTable[string, int]
    pinnedKeys: seq[string]

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      marketHistoryIsLoading: bool
      tokenListsLoading: bool
      pendingMandatoryGroupKeysAllChains: seq[string]
      # the keys each holder pins in the all-chains model
      allChainsHolderKeys: OrderedTable[int, seq[string]]
      allChainsQmlHolders: int

      tokenListsModel: TokenListsModel
      tokenGroupsModel: TokenGroupsModel # refers to tokens of interest for active networks mode
      # One model per chain, shared by every holder of the chain. It lives while
      # the chain is held or its groups stay loaded.
      chainModels: Table[int, ChainTokenGroups]
      chainModelListeners: seq[proc(chainId: int)]
      preparedChainId: int
      tokenGroupsAllChainsModel: TokenGroupsModel # ALL tokens across the active chains (on-demand fetch), for the "All" chip
      searchResultModel: TokenGroupsModel # tokens matching the search keyword, scanned over the same cross-chain catalog

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
    result.tokenGroupsAllChainsModel = newTokenGroupsModel(
      delegate.getTokenGroupsAllChainsModelDataSource(),
      delegate.getTokenMarketValuesDataSource(),
      modelModes = @[ModelMode.NoMarketDetails, ModelMode.UseLazyLoading],
      lazyLoadingBatchSize = LAZY_LOADING_BATCH_SIZE,
      lazyLoadingInitialCount = LAZY_LOADING_INITIAL_COUNT)
    result.searchResultModel = newTokenGroupsModel(
      delegate.getTokenGroupsAllChainsModelDataSource(),
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

  proc getHistoricalDataForTokenByRange*(self: View, tokenKey: string, currency: string, range: int) {.slot.} =
    self.setMarketHistoryIsLoading(true)
    self.delegate.getHistoricalDataForTokenByRange(tokenKey, currency, range)

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

  proc getChainTokenGroupsModelObj*(self: View, chainId: int): TokenGroupsModel =
    ## nil unless the chain is held or its groups stay loaded
    self.chainModels.withValue(chainId, entry):
      return entry.model
    nil

  proc chainTokenGroupsModel*(self: View, chainId: int): QVariant =
    ## The chain's shared model, null unless held. Nim keeps the model.
    self.chainModels.withValue(chainId, entry):
      return entry.variant
    newQVariant()

  # nimqml cannot return a QVariant from a slot that takes arguments, hence the
  # prepare-then-get pair; the store wraps the two calls.
  proc prepareChainTokenGroupsModel*(self: View, chainId: int) {.slot.} =
    self.preparedChainId = chainId

  proc getPreparedChainTokenGroupsModel*(self: View): QVariant {.slot.} =
    self.chainTokenGroupsModel(self.preparedChainId)

  proc onChainTokenGroupsModelUpdated*(self: View, listener: proc(chainId: int)) =
    ## Called after a chain's model is created, reset or deleted.
    self.chainModelListeners.add(listener)

  proc notifyChainModelUpdated(self: View, chainId: int) =
    for listener in self.chainModelListeners:
      listener(chainId)

  proc resetChainModel(self: View, chainId: int) =
    self.chainModels.withValue(chainId, entry):
      entry.model.modelsUpdated(resetModelSize = true, entry.pinnedKeys)
      self.notifyChainModelUpdated(chainId)

  proc chainHolders(self: View, chainId: int): int =
    self.chainModels.withValue(chainId, entry):
      for count in entry.holderKeys.values:
        result += count

  proc updateChainModelsLoading(self: View) =
    for chainId, entry in self.chainModels:
      entry.model.setLoading(self.delegate.getChainTokenGroupsLoading(chainId))

  proc applyChainPinnedKeys(self: View, chainId: int, defaultKeys: seq[string]): bool =
    ## Whether the chain's pinned keys changed; a holder passing "" pins `defaultKeys`.
    self.chainModels.withValue(chainId, entry):
      var keys: seq[string]
      var seen: HashSet[string]
      for holderKeys in entry.holderKeys.keys:
        let holderPins = if holderKeys.len > 0: holderKeys.split("$$") else: defaultKeys
        for key in holderPins:
          if not seen.containsOrIncl(key):
            keys.add(key)
      if keys.toHashSet == entry.pinnedKeys.toHashSet:
        return false
      entry.pinnedKeys = keys
      return true
    false

  proc hasDefaultKeysHolder(self: View, chainId: int): bool =
    self.chainModels.withValue(chainId, entry):
      return entry.holderKeys.hasKey("")
    false

  proc applyChainPinnedKeys(self: View, chainId: int): bool =
    var defaultKeys: seq[string]
    if self.hasDefaultKeysHolder(chainId):
      defaultKeys = self.delegate.getMandatoryTokenGroupKeys()
    self.applyChainPinnedKeys(chainId, defaultKeys)

  proc deleteChainModel(self: View, chainId: int) =
    var entry: ChainTokenGroups
    if not self.chainModels.pop(chainId, entry):
      return
    entry.variant.delete
    entry.model.delete
    self.notifyChainModelUpdated(chainId)

  proc acquireChainTokenGroups*(self: View, chainId: int, mandatoryGroupKeys: string) {.slot.} =
    ## `mandatoryGroupKeys` joined by "$$", empty for the default keys; the
    ## release passes the same.
    if chainId <= 0:
      return
    self.delegate.acquireChainTokenGroups(chainId)
    var created = false
    if not self.chainModels.hasKey(chainId):
      let model = newTokenGroupsModel(
        self.delegate.getTokenGroupsForChainModelDataSource(chainId),
        self.delegate.getTokenMarketValuesDataSource(),
        # the swap and payment request pickers need no market details
        modelModes = @[ModelMode.NoMarketDetails, ModelMode.UseLazyLoading],
        lazyLoadingBatchSize = LAZY_LOADING_BATCH_SIZE,
        lazyLoadingInitialCount = LAZY_LOADING_INITIAL_COUNT)
      self.chainModels[chainId] = ChainTokenGroups(model: model, variant: newQVariant(model))
      created = true
    self.chainModels[chainId].holderKeys.mgetOrPut(mandatoryGroupKeys, 0).inc
    # loaded groups fire no event for a new holder
    if self.applyChainPinnedKeys(chainId) or created:
      self.resetChainModel(chainId)
    self.chainModels[chainId].model.setLoading(self.delegate.getChainTokenGroupsLoading(chainId))

  proc releaseChainTokenGroups*(self: View, chainId: int, mandatoryGroupKeys: string) {.slot.} =
    var held = false
    self.chainModels.withValue(chainId, entry):
      let count = entry.holderKeys.getOrDefault(mandatoryGroupKeys)
      held = count > 0
      if count > 1:
        entry.holderKeys[mandatoryGroupKeys] = count - 1
      elif held:
        entry.holderKeys.del(mandatoryGroupKeys)
    if not held:
      return
    self.delegate.releaseChainTokenGroups(chainId)
    if self.chainHolders(chainId) > 0:
      if self.applyChainPinnedKeys(chainId):
        self.resetChainModel(chainId)
    # dropped while held, as on background: no drop follows
    elif not self.delegate.isChainTokenGroupsActive(chainId):
      self.deleteChainModel(chainId)
    # else unread until the next holder, which applies its keys

  proc onChainGroupsChanged*(self: View, chainId: int, dropped: bool) =
    if dropped and self.chainHolders(chainId) == 0:
      self.deleteChainModel(chainId)
    else:
      self.resetChainModel(chainId)
    self.updateChainModelsLoading()

  proc onWalletTokensRebuilt*(self: View) =
    ## The default keys follow the wallet's tokens.
    var chainIds: seq[int]
    for chainId in self.chainModels.keys:
      if self.hasDefaultKeysHolder(chainId):
        chainIds.add(chainId)
    if chainIds.len == 0:
      return
    let defaultKeys = self.delegate.getMandatoryTokenGroupKeys()
    for chainId in chainIds:
      if self.applyChainPinnedKeys(chainId, defaultKeys):
        self.resetChainModel(chainId)

  proc applyAllChainsMandatoryKeys(self: View) =
    var keys: seq[string]
    var seen: HashSet[string]
    for holderKeys in self.allChainsHolderKeys.values:
      for key in holderKeys:
        if not seen.containsOrIncl(key):
          keys.add(key)
    if keys.toHashSet == self.pendingMandatoryGroupKeysAllChains.toHashSet:
      return
    self.pendingMandatoryGroupKeysAllChains = keys
    # loaded groups fire no event for a new holder
    self.tokenGroupsAllChainsModel.modelsUpdated(resetModelSize = true, keys)

  proc acquireAllChainsTokenGroupsForKeys*(self: View, holder: int, mandatoryGroupKeys: seq[string]) =
    ## `holder` is unique per holder and not negative.
    if mandatoryGroupKeys.len > 0:
      self.allChainsHolderKeys[holder] = mandatoryGroupKeys
    else:
      self.allChainsHolderKeys[holder] = self.delegate.getMandatoryTokenGroupKeys()
    self.applyAllChainsMandatoryKeys()
    self.delegate.acquireAllTokenGroups()

  proc releaseAllChainsTokenGroups*(self: View, holder: int) =
    if not self.allChainsHolderKeys.hasKey(holder):
      return
    self.allChainsHolderKeys.del(holder)
    self.applyAllChainsMandatoryKeys()
    self.delegate.releaseAllTokenGroups()

  proc acquireAllTokenGroups*(self: View) {.slot.} =
    inc self.allChainsQmlHolders
    self.acquireAllChainsTokenGroupsForKeys(QML_ALL_CHAINS_HOLDER, @[])

  proc releaseAllTokenGroups*(self: View) {.slot.} =
    if self.allChainsQmlHolders == 0:
      return
    dec self.allChainsQmlHolders
    if self.allChainsQmlHolders > 0:
      self.delegate.releaseAllTokenGroups()
    else:
      self.releaseAllChainsTokenGroups(QML_ALL_CHAINS_HOLDER)

  proc onAllChainsGroupsChanged*(self: View) =
    self.searchResultModel.refreshSearch()
    self.tokenGroupsAllChainsModel.modelsUpdated(resetModelSize = true, self.pendingMandatoryGroupKeysAllChains)

  proc getTokenByKeyOrGroupKeyFromAllTokens*(self: View, key: string): string {.slot.} =
    let token = self.delegate.getTokenByKeyOrGroupKeyFromAllTokens(key)
    if token.isNil:
      return ""
    return $(%* token)

  proc ensurePricesForGroup*(self: View, key: string) {.slot.} =
    self.delegate.ensurePricesForGroup(key)

  proc getTokenGroupsModelObj*(self: View): TokenGroupsModel =
    ## Non-QML accessor: the raw model instances, so a sibling producer can
    ## snapshot their loaded rows and drive their lazy loading directly.
    self.tokenGroupsModel
  proc getSearchResultModelObj*(self: View): TokenGroupsModel =
    self.searchResultModel
  proc getTokenGroupsAllChainsModelObj*(self: View): TokenGroupsModel =
    self.tokenGroupsAllChainsModel

  proc modelsUpdated*(self: View) =
    self.tokenGroupsModel.modelsUpdated()

  proc tokenListsUpdated(self: View) =
    self.tokenListsModel.modelsUpdated()
    self.tokenListsModelChanged()

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

  proc tokenListsLoadingChanged*(self: View) {.signal.}
  proc getTokenListsLoading*(self: View): bool {.slot.} =
    return self.tokenListsLoading
  proc setTokenListsLoading(self: View, loading: bool) =
    if self.tokenListsLoading == loading:
      return
    self.tokenListsLoading = loading
    self.tokenListsLoadingChanged()
  QtProperty[bool] tokenListsLoading:
    read = getTokenListsLoading
    notify = tokenListsLoadingChanged

  proc acquireTokenLists*(self: View) {.slot.} =
    self.delegate.acquireTokenLists()
    self.setTokenListsLoading(self.delegate.getTokenListsLoading())

  proc releaseTokenLists*(self: View) {.slot.} =
    self.delegate.releaseTokenLists()

  proc onTokenListsChanged*(self: View) =
    self.setTokenListsLoading(self.delegate.getTokenListsLoading())
    self.tokenListsUpdated()

  proc onCatalogueLoadingChanged*(self: View) =
    self.updateChainModelsLoading()
    self.setTokenListsLoading(self.delegate.getTokenListsLoading())

  proc isChainSupportedForSwap*(self: View, chainId: int): bool {.slot.} =
    return self.delegate.isChainSupportedForSwap(chainId)

  proc delete*(self: View) =
    self.QObject.delete

