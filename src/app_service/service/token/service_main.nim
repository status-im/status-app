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

proc applyAllTokenListsData(self: Service, tokenListsDtos: seq[TokenListDto]) =
  self.allTokenLists = tokenListsDtos.map(tl => createTokenListItem(tl))

proc prefetchParaswapSupport(self: Service) =
  let chainIds = self.networkService.getEnabledChainIds()
  if chainIds.len == 0:
    return
  # One task per chain so the cache fills incrementally as each RPC completes.
  for chainId in chainIds:
    if chainId <= 0:
      continue
    let arg = PrefetchParaswapSupportTaskArg(
      tptr: prefetchParaswapSupportTask,
      vptr: cast[uint](self.vptr),
      slot: "prefetchParaswapSupportRetrieved",
      chainId: chainId,
    )
    self.threadpool.start(arg)

proc prefetchParaswapSupportRetrieved(self: Service, response: string) {.slot.} =
  try:
    let parsedJson = response.parseJson
    var errorString: string
    discard parsedJson.getProp("error", errorString)
    if errorString.len > 0:
      return
    if not parsedJson.hasKey("chainId") or not parsedJson.hasKey("supported"):
      return
    let chainId = parsedJson["chainId"].getInt()
    if chainId <= 0:
      return
    let supported = parsedJson["supported"].getBool()
    self.chainsSupportedForSwapViaParaswap[chainId] = supported
  except Exception as ex:
    error "prefetchParaswapSupportRetrieved", err = ex.msg

proc applyRefreshTokensData(self: Service, tokenDtos: seq[TokenDtoSafe], allTokenDtos: seq[TokenDtoSafe], tokenPrefsNode: JsonNode) =
  let tokens = tokenDtos.map(t => createTokenItem(t))

  # Token catalogue changed -> previously-unresolvable keys may now resolve.
  if tokenDtos.len > 0 or allTokenDtos.len > 0:
    self.notFoundKeys.clear()

  if tokens.len > 0 or self.groupsOfInterestByKey.len == 0:
    self.tokensOfInterestByKey.clear()
    self.groupsOfInterestByKey.clear()
    for token in tokens:
      self.tokensOfInterestByKey[token.key] = token
    self.addNewTokensToGroupsOfInterest(tokens)
  else:
    debug "ignoring empty tokens-of-interest refresh; keeping existing token groups cache"

  # Keep tokenPreferencesJson as the backend array string for QML; fill table from decoded DTOs.
  self.tokenPreferencesJson = "[]"
  if not tokenPrefsNode.isNil and tokenPrefsNode.kind == JArray:
    self.tokenPreferencesJson = $tokenPrefsNode
    for preferences in tokenPrefsNode:
      let dto = Json.decode($preferences, TokenPreferencesDto, allowUnknownFields = true)
      self.tokenPreferencesTable[dto.key] = TokenPreferencesItem(
        key: dto.key,
        position: dto.position,
        groupPosition: dto.groupPosition,
        visible: dto.visible,
        communityId: dto.communityId)

  if allTokenDtos.len > 0 or self.allTokensByGroupKey.len == 0:
    self.allTokensByGroupKey.clear()
    for dto in allTokenDtos:
      let item = createTokenItem(dto)
      self.allTokensByGroupKey.mgetOrPut(item.groupKey, @[]).add(item)
  else:
    debug "ignoring empty all-tokens refresh; keeping existing all tokens cache"
  self.rebuildMarketData()
  self.fetchTokensDetails() # TODO: if the only place where we can see these details is account's details page, we should fetch this on demand, no need to have local cache
  # notify modules
  self.events.emit(SIGNAL_TOKENS_LIST_UPDATED, Args())
  self.events.emit(SIGNAL_TOKEN_PREFERENCES_UPDATED, Args())

proc onAsyncRefreshTokensDone(self: Service, response: string) {.slot.} =
  try:
    let env = Json.decode(response, RefreshTokensResponse, allowUnknownFields = true)
    if env.error.len > 0:
      error "async refresh tokens failed", errDescription = env.error
      return
    if env.requestId != self.refreshTokensRequestId:
      debug "ignoring stale async refresh tokens response",
        requestId = env.requestId, latestRequestId = self.refreshTokensRequestId
      return
    self.applyRefreshTokensData(env.tokensOfInterest, env.allTokens, env.tokenPreferences)
  except Exception as e:
    error "error processing async refresh tokens", msg = e.msg

proc onAsyncFetchAllTokenListsDone(self: Service, response: string) {.slot.} =
  self.tokenListsLoading = false
  try:
    let env = Json.decode(response, FetchAllTokenListsResponse, allowUnknownFields = true)
    if env.error.len > 0:
      error "async fetch all token lists failed", errDescription = env.error
      return
    self.applyAllTokenListsData(env.allTokenLists)
    self.events.emit(SIGNAL_TOKEN_LISTS_LOADED, Args())
  except Exception as e:
    error "error processing async fetch all token lists", msg = e.msg

proc asyncRefreshTokens(self: Service) =
  inc self.refreshTokensRequestId
  let arg = AsyncRefreshTokensTaskArg(
    tptr: asyncRefreshTokensTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncRefreshTokensDone",
    requestId: self.refreshTokensRequestId,
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
    self.prefetchParaswapSupport()

  self.events.on(SIGNAL_CURRENCY_UPDATED) do(e:Args):
    self.rebuildMarketData()

  self.asyncRefreshTokens()
  self.prefetchParaswapSupport()

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
    let env = Json.decode(response, BuildGroupsForChainResponse, allowUnknownFields = true)
    if env.error.len > 0:
      error "async build groups for chain failed", errDescription = env.error
      self.events.emit(SIGNAL_GROUPS_FOR_CHAIN_LOADED, Args())
      return
    let tokens = env.tokens.map(t => createTokenItem(t))
    var groupsByKey = initTable[string, TokenGroupItem](tokens.len)
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
    let env = Json.decode(response, FetchAllTokenGroupsResponse, allowUnknownFields = true)
    if env.error.len > 0:
      error "async fetch all token groups failed", errDescription = env.error
      self.events.emit(SIGNAL_ALL_TOKEN_GROUPS_LOADED, Args())
      return
    let tokens = env.tokens.map(t => createTokenItem(t))
    var groupsByKey = initTable[string, TokenGroupItem](tokens.len)
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
  if self.notFoundKeys.contains(key):
    return nil
  let tokens = getTokensByKeys(@[key])
  if tokens.len > 0:
    # add newly found tokens to the groups of interest
    self.addNewTokensToGroupsOfInterest(tokens)

    self.tokensOfInterestByKey[key] = tokens[0]
    return self.tokensOfInterestByKey[key]
  self.notFoundKeys.incl(key)
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
  if self.allTokensByGroupKey.hasKey(key):
    let indexed = self.allTokensByGroupKey[key]
    if indexed.len > 0:
      return indexed[0]
  tokens = getAllTokens()
  let matchedTokens = tokens.filter(t => t.groupKey == key)
  if matchedTokens.len > 0:
    return matchedTokens[0]
  return nil

proc findTokenByGroupKeyAndChainIdInTable(
    tokensByGroupKey: Table[string, seq[TokenItem]],
    groupKey: string,
    chainId: int,
): TokenItem =
  if not tokensByGroupKey.hasKey(groupKey):
    return nil
  for token in tokensByGroupKey[groupKey]:
    if token.chainId == chainId:
      return token
  return nil

proc getTokenByGroupKeyAndChainId*(self: Service, groupKey: string, chainId: int): TokenItem =
  let tokens = self.getTokensByGroupKey(groupKey)
  if tokens.len > 0:
    for token in tokens:
      if token.chainId == chainId:
        return token

  var token = findTokenByGroupKeyAndChainIdInTable(self.allTokensByGroupKey, groupKey, chainId)
  if not token.isNil:
    return token

  for cachedToken in self.tokensOfInterestByKey.values:
    if cachedToken.groupKey == groupKey and cachedToken.chainId == chainId:
      return cachedToken

  if groupKey == common_wallet_constants.ETH_GROUP_KEY or
     groupKey == common_wallet_constants.BNB_GROUP_KEY:
    return createNativeTokenItem(chainId)

  if groupKey == common_wallet_constants.STATUS_GROUP_KEY or
     groupKey == common_wallet_constants.STATUS_TEST_TOKEN_GROUP_KEY:
    return createStatusTokenItem(chainId)

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
