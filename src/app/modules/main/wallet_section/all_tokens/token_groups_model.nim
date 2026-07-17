import app/modules/shared_models/model_utils
import app/modules/shared/model_sync
import nimqml, tables, strutils, algorithm, sequtils

import io_interface, tokens_model, market_details_item

type
  ModelMode* {.pure.} = enum
    NoMarketDetails
    UseLazyLoading
    IsSearchResult

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1 # token group key
    Name
    Symbol
    Decimals
    LogoUri
    Tokens # list of tokens in the group
    # gorup is community token group if token/tokens have community id
    CommunityId
    Type
    # additional roles
    WebsiteUrl
    Description
    MarketDetails
    DetailsLoading
    MarketDetailsLoading
    Visible
    Position


QtObject:
  type TokenGroupsModel* = ref object of QAbstractListModel
    delegate: io_interface.TokenGroupsModelDataSource
    tokensModel: TokensModel
    marketValuesDelegate: io_interface.TokenMarketValuesDataSource
    # Market details keyed by group key (not row index): identity-independent of
    # insert/remove/move so survivors keep the SAME MarketDetailsItem instance the
    # QML view is bound to.
    tokenMarketDetails: Table[string, MarketDetailsItem]
    # Cached snapshot the main (non-lazy) model diffs against via modelSync,
    # replacing the beginResetModel on every refresh. data()/rowCount read this.
    cachedGroups: seq[TokenGroupItem]
    modelModes: seq[ModelMode]
    lazyLoadingBatchSize: int
    lazyLoadingInitialCount: int
    isLoadingMore: bool # only used with UseLazyLoading model mode
    searchKeyword: string
    fullSearchResults: seq[TokenGroupItem] # only used with IsSearchResult model mode
    loadedItems: seq[TokenGroupItem] # only used with UseLazyLoading model mode
    loadedKeys: Table[string, bool] # only used with UseLazyLoading model mode

  proc setup(self: TokenGroupsModel)
  proc delete(self: TokenGroupsModel)
  proc newTokenGroupsModel*(
    delegate: io_interface.TokenGroupsModelDataSource,
    marketValuesDelegate: io_interface.TokenMarketValuesDataSource,
    modelModes: seq[ModelMode] = @[],
    lazyLoadingBatchSize: int = 0,
    lazyLoadingInitialCount: int = 0,
    ): TokenGroupsModel =
    new(result, delete)
    result.setup
    result.delegate = delegate
    result.marketValuesDelegate = marketValuesDelegate
    result.tokenMarketDetails = initTable[string, MarketDetailsItem]()
    result.modelModes = modelModes
    result.lazyLoadingBatchSize = lazyLoadingBatchSize
    result.lazyLoadingInitialCount = lazyLoadingInitialCount
    result.isLoadingMore = false

  proc getSourceModel(self: TokenGroupsModel): var seq[TokenGroupItem] =
    if ModelMode.IsSearchResult in self.modelModes:
      return self.fullSearchResults
    return self.delegate.getAllTokenGroups()

  proc getDisplayModel(self: TokenGroupsModel): var seq[TokenGroupItem] =
    if ModelMode.UseLazyLoading in self.modelModes or ModelMode.IsSearchResult in self.modelModes:
      return self.loadedItems
    # Main model: read the cached snapshot maintained by modelSync, not the
    # live delegate seq — so the model's rows are what the granular diff produced.
    return self.cachedGroups

  method rowCount(self: TokenGroupsModel, index: QModelIndex = nil): int =
    return self.getDisplayModel().len

  proc countChanged(self: TokenGroupsModel) {.signal.}
  proc getCount(self: TokenGroupsModel): int {.slot.} =
    return self.rowCount()
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc hasMoreItemsChanged(self: TokenGroupsModel) {.signal.}
  proc getHasMoreItems(self: TokenGroupsModel): bool {.slot.} =
    return self.getDisplayModel().len < self.getSourceModel().len
  QtProperty[bool] hasMoreItems:
    read = getHasMoreItems
    notify = hasMoreItemsChanged

  proc isLoadingMoreChanged(self: TokenGroupsModel) {.signal.}
  proc setIsLoadingMore(self: TokenGroupsModel, value: bool) =
    if value == self.isLoadingMore:
      return
    self.isLoadingMore = value
    self.isLoadingMoreChanged()
  proc getIsLoadingMore(self: TokenGroupsModel): bool {.slot.} =
    return self.isLoadingMore
  QtProperty[bool] isLoadingMore:
    read = getIsLoadingMore
    notify = isLoadingMoreChanged

  method roleNames(self: TokenGroupsModel): Table[int, string] =
    {
      ModelRole.Key.int:"key",
      ModelRole.Name.int:"name",
      ModelRole.Symbol.int:"symbol",
      ModelRole.Decimals.int:"decimals",
      ModelRole.LogoUri.int:"logoUri",
      ModelRole.Tokens.int:"tokens",
      ModelRole.CommunityId.int:"communityId",
      ModelRole.Type.int:"type",
      ModelRole.WebsiteUrl.int:"websiteUrl",
      ModelRole.Description.int:"description",
      ModelRole.MarketDetails.int:"marketDetails",
      ModelRole.DetailsLoading.int:"detailsLoading",
      ModelRole.MarketDetailsLoading.int:"marketDetailsLoading",
      ModelRole.Visible.int:"visible",
      ModelRole.Position.int:"position"
    }.toTable

  proc getTokensModelDataSource*(self: TokenGroupsModel, index: int): TokensModelDataSource =
    return (
      getTokens: proc(): var seq[TokenItem] = self.getDisplayModel()[index].tokens,
    )

  method data(self: TokenGroupsModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)

    let noMarketDetails = ModelMode.NoMarketDetails in self.modelModes

    let item = self.getDisplayModel()[index.row]

    if not noMarketDetails and not self.tokenMarketDetails.hasKey(item.key):
      return

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Key:
        return newQVariant(item.key)
      of ModelRole.Name:
        return newQVariant(item.name)
      of ModelRole.Symbol:
        return newQVariant(item.symbol)
      of ModelRole.Decimals:
        return newQVariant(item.decimals)
      of ModelRole.LogoUri:
        return newQVariant(item.logoUri)
      of ModelRole.Tokens:
        self.tokensModel = newTokensModel(self.getTokensModelDataSource(index.row))
        self.tokensModel.modelsUpdated()
        return newQVariant(self.tokensModel)
      of ModelRole.CommunityId:
        # since each token gorup item has at least one token, we're safe to use the first token's data
        return newQVariant(item.tokens[0].communityData.id)
      of ModelRole.Type:
        return newQVariant(ord(item.`type`))
      of ModelRole.WebsiteUrl:
        if self.delegate.getTokensDetailsLoading():
          return newQVariant("")
        # since each token gorup item has at least one token, we're safe to use the first token's key
        let tokenKey = item.tokens[0].key
        return newQVariant(self.delegate.getTokenDetails(tokenKey).assetWebsiteUrl)
      of ModelRole.Description:
        if item.isCommunityTokenGroup():
          # since each token gorup item has at least one token, we're safe to use the first token's data
          return newQVariant(self.delegate.getCommunityTokenDescription(item.tokens[0].chainId, item.tokens[0].address))
        if self.delegate.getTokensDetailsLoading():
          return newQVariant("")
        # since each token gorup item has at least one token, we're safe to use the first token's key
        let tokenKey = item.tokens[0].key
        return newQVariant(self.delegate.getTokenDetails(tokenKey).description)
      of ModelRole.MarketDetails:
        if noMarketDetails:
          return newQVariant("")
        return newQVariant(self.tokenMarketDetails[item.key])
      of ModelRole.DetailsLoading:
        return newQVariant(self.delegate.getTokensDetailsLoading())
      of ModelRole.MarketDetailsLoading:
        return newQVariant(self.delegate.getTokensMarketValuesLoading())
      of ModelRole.Visible:
        return newQVariant(self.delegate.getTokenPreferences(item.key).visible)
      of ModelRole.Position:
        return newQVariant(self.delegate.getTokenPreferences(item.key).position)

  proc priceForTokenGroup(self: TokenGroupsModel, tokens: openArray[TokenItem]): tuple[tokenKey: string, price: float64] =
    for token in tokens:
      let price = self.marketValuesDelegate.getPriceForToken(token.key)
      if price > 0:
        return (token.key, price)
    if tokens.len > 0:
      return (tokens[0].key, self.marketValuesDelegate.getPriceForToken(tokens[0].key))
    return ("", 0.0)

  proc buildMarketDetailsItem(self: TokenGroupsModel, group: TokenGroupItem, currencyFormat: CurrencyFormatDto): MarketDetailsItem =
    let (tokenKey, tokenPrice) = self.priceForTokenGroup(group.tokens)
    let tokenMarketValues = self.marketValuesDelegate.getMarketValuesForToken(tokenKey)
    return newMarketDetailsItem(tokenKey, tokenPrice, tokenMarketValues, currencyFormat)

  proc syncKey(it: TokenGroupItem): string = it.key

  proc rebuildMarketDetails(self: TokenGroupsModel, groups: seq[TokenGroupItem]) =
    ## Rebuild tokenMarketDetails (keyed by group key) for the given display list,
    ## PRESERVING the existing MarketDetailsItem instance for a surviving group key
    ## (QML is bound to it, and the market-values signal path updates it in place),
    ## creating a new one only for a new key, and dropping removed keys. Keying by
    ## group key makes this immune to insert/remove/move — no index realignment.
    if ModelMode.NoMarketDetails in self.modelModes:
      return
    let currencyFormat = self.marketValuesDelegate.getCurrentCurrencyFormat()
    # Groups with no tokens carry no market details; drop them before reconciling
    # so a tokenless key never gets an instance (matches the pre-modelSync skip).
    let withTokens = groups.filterIt(it.tokens.len > 0)
    reconcileByKey(self.tokenMarketDetails, withTokens,
      create = proc(group: TokenGroupItem): MarketDetailsItem =
        self.buildMarketDetailsItem(group, currencyFormat),
      update = proc(existing: MarketDetailsItem, group: TokenGroupItem) =
        # A surviving group can change its representative token (e.g. a previously
        # unpriced token in the group gains a price). Only repoint when it actually
        # changed, so the common stable refresh stays a genuine no-op (no churn).
        let (tokenKey, tokenPrice) = self.priceForTokenGroup(group.tokens)
        if existing.tokenKey != tokenKey:
          existing.updateRepresentativeToken(tokenKey, tokenPrice,
            self.marketValuesDelegate.getMarketValuesForToken(tokenKey)))

  proc syncRoles(oldItem, newItem: TokenGroupItem): seq[int] =
    ## Item-derived roles only (Name/Symbol/Decimals/LogoUri/Type/Tokens/CommunityId).
    ## Service-getter roles (WebsiteUrl/Description/Visible/Position/*Loading) are
    ## driven by their own separate dataChanged signals and are NOT folded in here.
    ## TokenItem holds only static metadata (no balances), so a plain refresh with an
    ## unchanged group set yields no role changes — the common, zero-work case.
    result = @[]
    if oldItem.name != newItem.name: result.add(ModelRole.Name.int)
    if oldItem.symbol != newItem.symbol: result.add(ModelRole.Symbol.int)
    if oldItem.decimals != newItem.decimals: result.add(ModelRole.Decimals.int)
    if oldItem.logoUri != newItem.logoUri: result.add(ModelRole.LogoUri.int)
    if oldItem.`type` != newItem.`type`: result.add(ModelRole.Type.int)
    # Tokens is a ref seq — compare by content signature, not reference identity.
    # Includes customToken (tokens_model shows it) so a customToken flip on a
    # surviving token key re-reads the Tokens sub-model.
    let oldSig = oldItem.tokens.mapIt((it.key, it.name, it.symbol, it.decimals,
      it.chainId, it.address, it.logoUri, it.communityData.id, it.customToken, it.`type`))
    let newSig = newItem.tokens.mapIt((it.key, it.name, it.symbol, it.decimals,
      it.chainId, it.address, it.logoUri, it.communityData.id, it.customToken, it.`type`))
    if oldSig != newSig:
      result.add(ModelRole.Tokens.int)
      result.add(ModelRole.MarketDetails.int)
      result.add(ModelRole.CommunityId.int)
      # Description is community-branched (isCommunityTokenGroup); a community-status
      # flip is captured by communityData.id in the signature above, so re-read it.
      result.add(ModelRole.Description.int)

  proc modelsUpdated*(self: TokenGroupsModel, resetModelSize: bool = false, mandatoryKeys: seq[string] = @[]) =
    let isMainModel = ModelMode.UseLazyLoading notin self.modelModes and
                      ModelMode.IsSearchResult notin self.modelModes

    # Incremental path: the main model on a plain refresh diffs the new
    # groups against its cached snapshot and emits granular insert/remove/
    # dataChanged instead of a full beginResetModel (which tears down every QML
    # delegate and rebuilds every per-row sub-model). syncModel detects the
    # hash-order reorder of the group set via LIS and degrades it to
    # remove+insert. Market details are re-keyed by group key so surviving
    # groups keep their MarketDetailsItem instance across the diff.
    if isMainModel and not resetModelSize:
      # CORRECTNESS DEPENDENCY: this old-vs-new diff only works because the token
      # service swaps in FRESH TokenGroupItem instances each refresh
      # (swap-not-clear) rather than mutating in place — cachedGroups holds
      # the prior fresh instances as the snapshot. If a future change mutates the
      # group items in place, cachedGroups would alias newGroups and every diff
      # would see "no change". Keep the swap.
      let newGroups = self.getSourceModel()
      # Build market-details keys BEFORE modelSync announces beginInsertRows
      # for any new group: data(MarketDetails) early-returns an empty QVariant when
      # the row's key is missing from the table, and nothing emits dataChanged
      # afterwards — so a newly-inserted row would render empty until an unrelated
      # signal fired. rebuildMarketDetails is identity-preserving, so survivors keep
      # their instances and the transient gating of a being-removed row is harmless.
      self.rebuildMarketDetails(newGroups)
      self.modelSync(self.cachedGroups, newGroups)
      self.hasMoreItemsChanged()
      return

    self.beginResetModel()
    defer:
      self.endResetModel()
      self.hasMoreItemsChanged()

    # if resetModelSize is false, the model remains as it was in terms of the number of items and the items themselves
    # if resetModelSize is true, the model is reset to the initial state/size
    # resetting the model size makes sense only if the model mode is UseLazyLoading
    if resetModelSize and ModelMode.UseLazyLoading in self.modelModes:
      self.loadedItems = @[]
      self.loadedKeys = initTable[string, bool]()
      let sourceModel = self.getSourceModel()

      # add mandatory items to loaded items
      if mandatoryKeys.len > 0:
        for key in mandatoryKeys:
          for item in sourceModel:
            if item.key == key:
              self.loadedItems.add(item)
              self.loadedKeys[key] = true
              break

      # reset the loaded items to the initial count
      if self.loadedItems.len > self.lazyLoadingInitialCount:
        for i in countup(self.lazyLoadingInitialCount, self.loadedItems.len-1):
          let key = self.loadedItems[i].key
          self.loadedKeys.del(key)
        self.loadedItems = self.loadedItems[0..self.lazyLoadingInitialCount-1]
      else:
        for item in sourceModel:
          if self.loadedKeys.hasKey(item.key):
            continue
          self.loadedItems.add(item)
          self.loadedKeys[item.key] = true
          if self.loadedItems.len >= self.lazyLoadingInitialCount:
            break

    self.rebuildMarketDetails(self.getDisplayModel())

  proc fetchMore*(self: TokenGroupsModel) {.slot.} =
    if not self.getHasMoreItems() or self.isLoadingMore:
      return
    self.setIsLoadingMore(true)

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    let sourceModel = self.getSourceModel()
    let first = self.rowCount()
    let last = min(first + self.lazyLoadingBatchSize - 1, sourceModel.len - 1)
    self.beginInsertRows(parentModelIndex, first, last)
    defer:
      self.endInsertRows()
      self.setIsLoadingMore(false)
      self.hasMoreItemsChanged()

    if ModelMode.UseLazyLoading in self.modelModes:
      for index in countup(first, last):
        let key = sourceModel[index].key
        if self.loadedKeys.hasKey(key):
          continue
        self.loadedKeys[key] = true
        self.loadedItems.add(sourceModel[index])

    self.rebuildMarketDetails(self.getDisplayModel())

  proc getSearchRelevance(item: TokenGroupItem, keywordLower: string): int =
    if keywordLower.len == 0:
      return 0

    let symbol = item.symbol.toLowerAscii()
    let name = item.name.toLowerAscii()
    let key = item.key.toLowerAscii()

    if symbol == keywordLower:
      return 100
    if name == keywordLower:
      return 95
    if symbol.startsWith(keywordLower):
      return 90
    if name.startsWith(keywordLower):
      return 85

    let symbolIndex = symbol.find(keywordLower)
    if symbolIndex > 0:
      return 70 - min(symbolIndex, 20)

    let nameIndex = name.find(keywordLower)
    if nameIndex > 0:
      return 60 - min(nameIndex, 20)

    let keyIndex = key.find(keywordLower)
    if keyIndex == 0:
      return 50
    if keyIndex > 0:
      return 40 - min(keyIndex, 20)

    return -1

  proc search*(self: TokenGroupsModel, keyword: string) {.slot.} =
    self.searchKeyword = keyword.strip()
    self.fullSearchResults = @[]
    if self.searchKeyword.len > 0:
      let keywordLower = self.searchKeyword.toLowerAscii()
      var scoredResults: seq[(int, int, TokenGroupItem)] = @[]
      for index, item in self.delegate.getAllTokenGroups():
        let relevance = getSearchRelevance(item, keywordLower)
        if relevance >= 0:
          scoredResults.add((relevance, index, item))

      scoredResults.sort(proc(a, b: (int, int, TokenGroupItem)): int =
        if a[0] > b[0]:
          return -1
        if a[0] < b[0]:
          return 1
        if a[1] < b[1]:
          return -1
        if a[1] > b[1]:
          return 1
        return 0
      )

      for scoredItem in scoredResults:
        self.fullSearchResults.add(scoredItem[2])

    self.modelsUpdated(resetModelSize = true)

  proc tokensMarketValuesUpdated*(self: TokenGroupsModel) =
    if ModelMode.NoMarketDetails in self.modelModes:
      return
    if not self.delegate.getTokensMarketValuesLoading():
      for marketDetails in self.tokenMarketDetails.values:
        marketDetails.updateTokenPrice(self.marketValuesDelegate.getPriceForToken(marketDetails.tokenKey))
        marketDetails.updateTokenMarketValues(self.marketValuesDelegate.getMarketValuesForToken(marketDetails.tokenKey))

  proc tokensMarketValuesAboutToUpdate*(self: TokenGroupsModel) =
    let tokenGroupsListLength = self.rowCount()
    if tokenGroupsListLength > 0:
      let index = self.createIndex(0, 0, nil)
      let lastindex = self.createIndex(tokenGroupsListLength-1, 0, nil)
      defer: index.delete
      defer: lastindex.delete
      self.dataChanged(index, lastindex, @[ModelRole.MarketDetailsLoading.int])

  proc tokensDetailsUpdated*(self: TokenGroupsModel) =
    let tokenGroupsListLength = self.rowCount()
    if tokenGroupsListLength > 0:
      let index = self.createIndex(0, 0, nil)
      let lastindex = self.createIndex(tokenGroupsListLength-1, 0, nil)
      defer: index.delete
      defer: lastindex.delete
      self.dataChanged(index, lastindex, @[ModelRole.Description.int, ModelRole.WebsiteUrl.int, ModelRole.DetailsLoading.int])

  proc currencyFormatsUpdated*(self: TokenGroupsModel) =
    if ModelMode.NoMarketDetails in self.modelModes:
      return
    let currencyFormat = self.marketValuesDelegate.getCurrentCurrencyFormat()
    for marketDetails in self.tokenMarketDetails.values:
        marketDetails.updateCurrencyFormat(currencyFormat)

  proc tokenPreferencesUpdated*(self: TokenGroupsModel) =
    let tokenGroupsListLength = self.rowCount()
    if tokenGroupsListLength > 0:
      let index = self.createIndex(0, 0, nil)
      let lastindex = self.createIndex(tokenGroupsListLength-1, 0, nil)
      defer: index.delete
      defer: lastindex.delete
      self.dataChanged(index, lastindex, @[ModelRole.Visible.int, ModelRole.Position.int])

  proc marketDetailsItemForKey*(self: TokenGroupsModel, groupKey: string): MarketDetailsItem =
    ## Test/inspection accessor: the MarketDetailsItem instance held for a group
    ## key, or nil if none. Used to assert identity preservation across a diff.
    self.tokenMarketDetails.getOrDefault(groupKey, nil)

  proc groupKeysInOrder*(self: TokenGroupsModel): seq[string] =
    ## Test/inspection accessor: the group keys in display order (what QML sees).
    self.getDisplayModel().mapIt(it.key)

  proc setup(self: TokenGroupsModel) =
    self.QAbstractListModel.setup
    self.tokenMarketDetails = initTable[string, MarketDetailsItem]()

  proc delete(self: TokenGroupsModel) =
    self.QAbstractListModel.delete
