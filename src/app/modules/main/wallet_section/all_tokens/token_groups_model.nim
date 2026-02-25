import nimqml, tables, strutils, algorithm

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
    tokenMarketDetails: seq[MarketDetailsItem]
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
    result.tokenMarketDetails = @[]
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
    return self.getSourceModel()

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
    if not index.isValid:
      return
    let noMarketDetails = ModelMode.NoMarketDetails in self.modelModes
    if index.row < 0 or index.row >= self.rowCount() or
      (not noMarketDetails and index.row >= self.tokenMarketDetails.len):
      return

    let item = self.getDisplayModel()[index.row]
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
        return newQVariant(self.tokenMarketDetails[index.row])
      of ModelRole.DetailsLoading:
        return newQVariant(self.delegate.getTokensDetailsLoading())
      of ModelRole.MarketDetailsLoading:
        return newQVariant(self.delegate.getTokensMarketValuesLoading())
      of ModelRole.Visible:
        return newQVariant(self.delegate.getTokenPreferences(item.key).visible)
      of ModelRole.Position:
        return newQVariant(self.delegate.getTokenPreferences(item.key).position)

  proc addMarketDetailsItem*(self: TokenGroupsModel, index: int, tokensList: var seq[TokenGroupItem], currencyFormat: var CurrencyFormatDto) =
    # since each token gorup item has at least one token, we're safe to use the first token's key
    let tokenKey = tokensList[index].tokens[0].key
    let tokenPrice = self.marketValuesDelegate.getPriceForToken(tokenKey)
    let tokenMarketValues = self.marketValuesDelegate.getMarketValuesForToken(tokenKey)
    let item = newMarketDetailsItem(tokenKey, tokenPrice, tokenMarketValues, currencyFormat)
    self.tokenMarketDetails.add(item)

  proc modelsUpdated*(self: TokenGroupsModel, resetModelSize: bool = false, mandatoryKeys: seq[string] = @[]) =
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

    if ModelMode.NoMarketDetails in self.modelModes:
      return

    self.tokenMarketDetails = @[]
    var
      tokensList = self.getDisplayModel()
      currencyFormat = self.marketValuesDelegate.getCurrentCurrencyFormat()
    for index in countup(0, self.rowCount()-1):
      self.addMarketDetailsItem(index, tokensList, currencyFormat)

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

    if ModelMode.NoMarketDetails in self.modelModes:
      return

    var
      tokensList = self.getDisplayModel()
      currencyFormat = self.marketValuesDelegate.getCurrentCurrencyFormat()
    for index in countup(first, last):
      self.addMarketDetailsItem(index, tokensList, currencyFormat)

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
      for marketDetails in self.tokenMarketDetails:
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
    for marketDetails in self.tokenMarketDetails:
        marketDetails.updateCurrencyFormat(currencyFormat)

  proc tokenPreferencesUpdated*(self: TokenGroupsModel) =
    let tokenGroupsListLength = self.rowCount()
    if tokenGroupsListLength > 0:
      let index = self.createIndex(0, 0, nil)
      let lastindex = self.createIndex(tokenGroupsListLength-1, 0, nil)
      defer: index.delete
      defer: lastindex.delete
      self.dataChanged(index, lastindex, @[ModelRole.Visible.int, ModelRole.Position.int])

  proc setup(self: TokenGroupsModel) =
    self.QAbstractListModel.setup
    self.tokenMarketDetails = @[]

  proc delete(self: TokenGroupsModel) =
    self.QAbstractListModel.delete

