proc rebuildMarketDataInternal(self: Service) =
  self.fetchTokensMarketValues() # TODO: if the only place where we can see these details is account's details page, we should fetch this on demand, no need to have local cache
  self.fetchTokensPrices()

proc rebuildMarketData*(self: Service) =
  self.rebuildMarketDataDebouncer.call()

proc createTokenGroupsFromTokens(tokens: seq[TokenItem], groupsByKey: var Table[string, TokenGroupItem]) =
  for token in tokens:
    let groupKey = token.groupKey
    if not groupsByKey.hasKey(groupKey):
      groupsByKey[groupKey] = TokenGroupItem(
        key: groupKey,
        name: token.name,
        symbol: token.symbol,
        decimals: token.decimals,
        logoUri: token.logoUri
      )
    groupsByKey[groupKey].addToken(token)

proc sortTokenGroupsByName(groups: var seq[TokenGroupItem]) =
  groups.sort(
    proc(a: TokenGroupItem, b: TokenGroupItem): int =
      return a.name.cmp(b.name)
  )

proc addNewTokensToGroupsOfInterest(self: Service, tokens: seq[TokenItem]) =
  createTokenGroupsFromTokens(tokens, self.groupsOfInterestByKey)
  self.groupsOfInterest = toSeq(self.groupsOfInterestByKey.values)

proc applyAllTokenListsData(self: Service, allTokenListsJson: JsonNode) =
  let tokenListsDtos = if allTokenListsJson.isNil or allTokenListsJson.kind == JNull: @[]
    else: Json.decode($allTokenListsJson, seq[TokenListDto], allowUnknownFields = true)
  self.allTokenLists = tokenListsDtos.map(tl => createTokenListItem(tl))

proc applyRefreshTokensData(self: Service, tokensOfInterestJson: JsonNode, tokenPrefsJson: JsonNode) =
  # Parse tokens of interest
  self.tokensOfInterestByKey.clear()
  self.groupsOfInterestByKey.clear()
  let tokenDtos = if tokensOfInterestJson.isNil or tokensOfInterestJson.kind == JNull: @[]
    else: Json.decode($tokensOfInterestJson, seq[TokenDtoSafe], allowUnknownFields = true)
  let tokens = tokenDtos.map(t => createTokenItem(t))

  for token in tokens:
    self.tokensOfInterestByKey[token.key] = token

  self.addNewTokensToGroupsOfInterest(tokens)

  # Parse token preferences
  self.tokenPreferencesJson = "[]"
  if not tokenPrefsJson.isNil and tokenPrefsJson.kind == JArray:
    self.tokenPreferencesJson = $tokenPrefsJson
    for preferences in tokenPrefsJson:
      let dto = Json.decode($preferences, TokenPreferencesDto, allowUnknownFields = true)
      self.tokenPreferencesTable[dto.key] = TokenPreferencesItem(
        key: dto.key,
        position: dto.position,
        groupPosition: dto.groupPosition,
        visible: dto.visible,
        communityId: dto.communityId)

  self.rebuildMarketData()
  self.fetchTokensDetails()
  # notify modules
  self.events.emit(SIGNAL_TOKENS_LIST_UPDATED, Args())
  self.events.emit(SIGNAL_TOKEN_PREFERENCES_UPDATED, Args())

proc onAsyncRefreshTokensDone(self: Service, response: string) {.slot.} =
  try:
    let rpcResponseObj = response.parseJson
    let errStr = rpcResponseObj["error"].getStr()
    if errStr.len > 0:
      error "async refresh tokens failed", errDescription = errStr
      return
    self.applyRefreshTokensData(
      rpcResponseObj["tokensOfInterest"],
      rpcResponseObj["tokenPreferences"],
    )
  except Exception as e:
    error "error processing async refresh tokens", msg = e.msg

proc onAsyncFetchAllTokenListsDone(self: Service, response: string) {.slot.} =
  self.tokenListsLoading = false
  try:
    let rpcResponseObj = response.parseJson
    let errStr = rpcResponseObj["error"].getStr()
    if errStr.len > 0:
      error "async fetch all token lists failed", errDescription = errStr
      return
    self.applyAllTokenListsData(rpcResponseObj["allTokenLists"])
    self.events.emit(SIGNAL_TOKEN_LISTS_LOADED, Args())
  except Exception as e:
    error "error processing async fetch all token lists", msg = e.msg

proc asyncRefreshTokens(self: Service) =
  let arg = AsyncRefreshTokensTaskArg(
    tptr: asyncRefreshTokensTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncRefreshTokensDone",
  )
  self.threadpool.start(arg)

proc asyncFetchAllTokenLists*(self: Service) =
  self.tokenListsLoading = true
  let arg = AsyncFetchAllTokenListsTaskArg(
    tptr: asyncFetchAllTokenListsTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncFetchAllTokenListsDone",
  )
  self.threadpool.start(arg)

proc getTokenListsLoading*(self: Service): bool =
  return self.tokenListsLoading

proc init*(self: Service) =
  self.rebuildMarketDataDebouncer = debouncer_service.newDebouncer(
    self.threadpool,
    # this is the delay before the first call to the callback, this is an action that doesn't need to be called immediately, but it's pretty expensive in terms of time/performances
    # for example `wallet-tick-reload` event is emitted for every single chain-account pair, and at the app start can be more such signals received from the statusgo side if the balance have changed.
    # Means it the app contains more accounts the likelihood of having more `wallet-tick-reload` signals is higher, so we need to delay the rebuildMarketData call to avoid unnecessary calls.
    delayMs = 1000,
    checkIntervalMs = 500)
  self.rebuildMarketDataDebouncer.registerCall0(callback = proc() = self.rebuildMarketDataInternal())

  self.events.on(SignalType.Wallet.event) do(e:Args):
    var data = WalletSignal(e)
    case data.eventType:
      of "wallet-tick-reload":
        self.rebuildMarketData()
  # update and populate internal list and then emit signal when new custom token detected?
  self.events.on(SignalType.WalletTokensListsUpdated.event) do(e:Args):
    self.asyncRefreshTokens()
    self.asyncFetchAllTokenLists()

  self.events.on(SIGNAL_NETWORK_MODE_UPDATED) do(e:Args):
    self.asyncRefreshTokens()

  self.events.on(SIGNAL_CURRENCY_UPDATED) do(e:Args):
    self.rebuildMarketData()

  self.asyncRefreshTokens()

proc getMandatoryTokenGroupKeys*(self: Service): seq[string] =
  let tokenKeys = getMandatoryTokenKeys()
  let tokens = getTokensByKeys(tokenKeys)
  var groupKeysMap: Table[string, bool] = initTable[string, bool]()
  for token in tokens:
    groupKeysMap[token.groupKey] = true
  return toSeq(groupKeysMap.keys)

proc getCurrency*(self: Service): string =
  return self.settingsService.getCurrency()

proc getGroupsOfInterest*(self: Service): var seq[TokenGroupItem] =
  return self.groupsOfInterest

proc buildGroupsForChain*(self: Service, chainId: int) =
  if chainId <= 0:
    warn "invalid chainId", chainId = chainId
    return
  self.groupsForChainLoading = true
  let arg = AsyncBuildGroupsForChainTaskArg(
    tptr: asyncBuildGroupsForChainTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncBuildGroupsForChainDone",
    chainId: chainId,
  )
  self.threadpool.start(arg)

proc onAsyncBuildGroupsForChainDone(self: Service, response: string) {.slot.} =
  self.groupsForChainLoading = false
  try:
    let rpcResponseObj = response.parseJson
    let errStr = rpcResponseObj["error"].getStr()
    if errStr.len > 0:
      error "async build groups for chain failed", errDescription = errStr
      self.events.emit(SIGNAL_GROUPS_FOR_CHAIN_LOADED, Args())
      return
    let tokensJson = rpcResponseObj["tokens"]
    let tokenDtos = if tokensJson.isNil or tokensJson.kind == JNull: @[]
      else: Json.decode($tokensJson, seq[TokenDtoSafe], allowUnknownFields = true)
    let tokens = tokenDtos.map(t => createTokenItem(t))
    var groupsByKey = initTable[string, TokenGroupItem]()
    createTokenGroupsFromTokens(tokens, groupsByKey)
    self.groupsForChain = toSeq(groupsByKey.values)
    sortTokenGroupsByName(self.groupsForChain)
    self.events.emit(SIGNAL_GROUPS_FOR_CHAIN_LOADED, Args())
  except Exception as e:
    error "error processing async build groups for chain", msg = e.msg
    self.events.emit(SIGNAL_GROUPS_FOR_CHAIN_LOADED, Args())

proc getGroupsForChainLoading*(self: Service): bool =
  return self.groupsForChainLoading

proc asyncFetchAllTokenGroups*(self: Service) =
  self.allTokenGroupsLoading = true
  let arg = AsyncFetchAllTokenGroupsTaskArg(
    tptr: asyncFetchAllTokenGroupsTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncFetchAllTokenGroupsDone",
  )
  self.threadpool.start(arg)

proc onAsyncFetchAllTokenGroupsDone(self: Service, response: string) {.slot.} =
  self.allTokenGroupsLoading = false
  try:
    let rpcResponseObj = response.parseJson
    let errStr = rpcResponseObj["error"].getStr()
    if errStr.len > 0:
      error "async fetch all token groups failed", errDescription = errStr
      self.events.emit(SIGNAL_ALL_TOKEN_GROUPS_LOADED, Args())
      return
    let tokensJson = rpcResponseObj["tokens"]
    let tokenDtos = if tokensJson.isNil or tokensJson.kind == JNull: @[]
      else: Json.decode($tokensJson, seq[TokenDtoSafe], allowUnknownFields = true)
    let tokens = tokenDtos.map(t => createTokenItem(t))
    var groupsByKey = initTable[string, TokenGroupItem]()
    createTokenGroupsFromTokens(tokens, groupsByKey)
    self.allTokenGroupsForActiveNetworks = toSeq(groupsByKey.values)
    sortTokenGroupsByName(self.allTokenGroupsForActiveNetworks)
    self.events.emit(SIGNAL_ALL_TOKEN_GROUPS_LOADED, Args())
  except Exception as e:
    error "error processing async fetch all token groups", msg = e.msg
    self.events.emit(SIGNAL_ALL_TOKEN_GROUPS_LOADED, Args())

proc getAllTokenGroupsForActiveNetworksMode*(self: Service): seq[TokenGroupItem] =
  return self.allTokenGroupsForActiveNetworks

proc getAllTokenGroupsLoading*(self: Service): bool =
  return self.allTokenGroupsLoading

proc getGroupsForChain*(self: Service): var seq[TokenGroupItem] =
  return self.groupsForChain

proc getAllTokenLists*(self: Service): var seq[TokenListItem] =
  return self.allTokenLists

################################################################################
## This is a very special function that should not be used anywhere else,
## it covers the backward compatibility with the old payment requests.
##
## Itterates over all tokens for the given chain and returns the first token
## that matches the symbol or name (cause some tokens have different symbols for EVM/BSC chains), case insensitive.
proc getTokenBySymbolOnChain*(self: Service, symbol: string, chainId: int): TokenItem =
  let tokens = getTokensByChain(chainId)
  for token in tokens:
    if cmpIgnoreCase(token.symbol, symbol) == 0 or cmpIgnoreCase(token.name, symbol) == 0:
      return token
  return nil
################################################################################

proc getTokenByKey*(self: Service, key: string): TokenItem =
  if not common_utils.isTokenKey(key):
    return nil
  if self.tokensOfInterestByKey.hasKey(key):
    return self.tokensOfInterestByKey[key]
  let tokens = getTokensByKeys(@[key])
  if tokens.len > 0:
    # add newly found tokens to the groups of interest
    self.addNewTokensToGroupsOfInterest(tokens)

    self.tokensOfInterestByKey[key] = tokens[0]
    return self.tokensOfInterestByKey[key]
  return nil

proc getTokenByChainAddress*(self: Service, chainId: int, address: string): TokenItem =
  let key = common_utils.createTokenKey(chainId, address)
  return self.getTokenByKey(key)

proc getTokensByGroupKey*(self: Service, groupKey: string): seq[TokenItem] =
  if not self.groupsOfInterestByKey.hasKey(groupKey):
    # If the group key is not at the same time a token key (e.g. "usd-coin") it was already added to the
    # groupsOfInterestByKey table at the app start or when tokens were refreshed the last time.
    # That means that the group key is definitelly a token key, so we need to add it to the groupsOfInterestByKey table.
    if not common_utils.isTokenKey(groupKey):
      return @[]
    let token = self.getTokenByKey(groupKey)
    if token.isNil:
      return @[]
    let group = TokenGroupItem(
      key: token.groupKey,
      name: token.name,
      symbol: token.symbol,
      decimals: token.decimals,
      logoUri: token.logoUri,
      tokens: @[token]
    )
    self.groupsOfInterestByKey[token.groupKey] = group
    return @[token]
  return self.groupsOfInterestByKey[groupKey].tokens

## Note: use this function in a very rare case, when you're sure the token is not present in the models.
## Returns a token that matches the key, or the first token in the group that matches the key.
proc getTokenByKeyOrGroupKeyFromAllTokens*(self: Service, key: string): TokenItem =
  if common_utils.isTokenKey(key):
    return self.getTokenByKey(key)
  var tokens = self.getTokensByGroupKey(key)
  if tokens.len > 0:
    return tokens[0]
  tokens = getAllTokens()
  let matchedTokens = tokens.filter(t => t.groupKey == key)
  if matchedTokens.len > 0:
    return matchedTokens[0]
  return nil

proc getTokenByGroupKeyAndChainId*(self: Service, groupKey: string, chainId: int): TokenItem =
  let tokens = self.getTokensByGroupKey(groupKey)
  if tokens.len > 0:
    for token in tokens:
      if token.chainId == chainId:
        return token
  return nil

## Checks if the chain is supported for swap via Paraswap
proc isChainSupportedForSwapViaParaswap*(self: Service, chainId: int): bool =
  if chainId <= 0:
    warn "invalid chainId", chainId = chainId
    return false
  if self.chainsSupportedForSwapViaParaswap.hasKey(chainId):
    return self.chainsSupportedForSwapViaParaswap[chainId]
  let supported = isChainSupportedForSwapViaParaswap(chainId)
  self.chainsSupportedForSwapViaParaswap[chainId] = supported
  return supported

proc getTokenListUpdatedAt*(self: Service): int64 =
  return self.tokenListUpdatedAt

proc getTokenDetails*(self: Service, tokenKey: string): TokenDetailsItem =
  if not self.tokenDetailsTable.hasKey(tokenKey):
    return TokenDetailsItem()
  return self.tokenDetailsTable[tokenKey]

proc getMarketValuesForToken*(self: Service, tokenKey: string): TokenMarketValuesItem =
  if not self.tokenMarketValuesTable.hasKey(tokenKey):
    return TokenMarketValuesItem()
  return self.tokenMarketValuesTable[tokenKey]

proc getPriceForToken*(self: Service, tokenKey: string): float64 =
  if not self.tokenPriceTable.hasKey(tokenKey):
    return 0.0
  return self.tokenPriceTable[tokenKey]

proc getTokensDetailsLoading*(self: Service): bool =
  return self.tokensDetailsLoading

proc getHasMarketValuesCache*(self: Service): bool =
  return self.hasMarketDetailsCache and self.hasPriceValuesCache

proc addNewCommunityToken*(self: Service, token: TokenItem) =
  if self.groupsOfInterestByKey.hasKey(token.groupKey):
    let tokens = self.groupsOfInterestByKey[token.groupKey].tokens
    for t in tokens:
      if t.key == token.key:
        return
  self.asyncRefreshTokens()
