proc rebuildMarketDataInternal(self: Service) =
  self.fetchTokensMarketValues() # TODO: if the only place where we can see these details is account's details page, we should fetch this on demand, no need to have local cache
  self.fetchTokensPrices()
  self.refetchOnDemandPrices()

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

proc addNewTokensToGroupsOfInterest(self: Service, tokens: seq[TokenItem]) =
  createTokenGroupsFromTokens(tokens, self.groupsOfInterestByKey)
  self.groupsOfInterest = toSeq(self.groupsOfInterestByKey.values)
  sortTokenGroupsByKey(self.groupsOfInterest)  # deterministic order

proc prefetchSwapSupport(self: Service, chainIds: seq[int] = @[]) =
  if not SWAP_PROVIDER_ENABLED:
    return
  var ids = chainIds
  if ids.len == 0:
    # every active chain, not just the ones enabled in the wallet's network filter:
    # the swap can be pointed at any active chain
    ids = self.networkService.getCurrentNetworksChainIds()
  ids = ids.filterIt(it > 0 and it notin self.swapSupportChainIdsInFlight)
  if ids.len == 0:
    return
  for chainId in ids:
    self.swapSupportChainIdsInFlight.incl(chainId)
  # one request for all chains; the backend asks the active provider
  let arg = PrefetchSwapSupportTaskArg(
    tptr: prefetchSwapSupportTask,
    vptr: cast[uint](self.vptr),
    slot: "prefetchSwapSupportRetrieved",
    chainIds: ids,
  )
  self.threadpool.start(arg)

proc prefetchSwapSupportRetrieved(self: Service, response: string) {.slot.} =
  try:
    let parsedJson = response.parseJson
    if parsedJson.hasKey("chainIds"):
      for chainId in parsedJson["chainIds"]:
        self.swapSupportChainIdsInFlight.excl(chainId.getInt())
    var errorString: string
    discard parsedJson.getProp("error", errorString)
    if errorString.len > 0:
      return
    if not parsedJson.hasKey("supported"):
      return
    # chains the provider couldn't answer for are simply absent and stay unknown
    for chainIdStr, supported in parsedJson["supported"]:
      let chainId = parseInt(chainIdStr)
      if chainId > 0:
        self.chainsSupportedForSwap[chainId] = supported.getBool()
  except Exception as ex:
    error "prefetchSwapSupportRetrieved", err = ex.msg

proc applyRefreshTokensResult(self: Service, res: RefreshTokensApplyResult, action: RefreshCompletionAction) =
  # Slim GUI-thread apply: swap in the structures the worker already built
  # off-thread — same swap-not-clear gate, same knownMissingKeys.clear() on a real
  # tokens-of-interest refresh, same preferences merge, same market rebuild and
  # events. The heavy decode + token-model build no longer runs on the GUI thread.
  # MOVE the worker-built containers into service state — never copy. `res` is
  # exclusively owned after takeTyped, so a copy would be pure waste: it re-refcounts
  # every TokenItem/TokenGroupItem (O(graph)) and (before the {.acyclic.} fix on
  # those types) walked the ORC cycle collector on each ref, which SIGSEGV'd on
  # Android for this cross-thread graph. `move` transfers each container's storage
  # in O(1) and does no per-element work.
  if shouldReplaceTokensCache(res.tokensOfInterestCount, self.groupsOfInterestByKey.len):
    # Swap the pre-built replacement in atomically, rather than clear-then-fill: a
    # wiped-then-refilled table would leave a window where every key lookup misses.
    self.tokensOfInterestByKey = move res.tokensOfInterestByKey
    self.groupsOfInterestByKey = move res.groupsOfInterestByKey
    self.groupsOfInterest = move res.groupsOfInterest
    # Fresh token data invalidates prior "not found" markers and on-demand group
    # lookups: a key that was missing before may now resolve.
    self.knownMissingKeys.clear()
    self.groupTokensLookups.clear()
  else:
    debug "ignoring empty tokens-of-interest refresh; keeping existing token groups cache"

  # Keep tokenPreferencesJson as the backend array string for QML; the worker
  # already decoded the rows — move them into the table (same merge as before).
  self.tokenPreferencesJson = move res.tokenPreferencesJson
  for preferences in res.tokenPreferences.mitems:
    let key = preferences.key
    self.tokenPreferencesTable[key] = move preferences

  if action == rcaApply and res.tokensOfInterestCount == 0 and self.tokensOfInterestReadiness == tmrSuperseded:
    debug "newest tokens refresh has an empty map; token map stays superseded"
  self.tokensOfInterestReadiness = nextTokenMapReadiness(self.tokensOfInterestReadiness, action,
    res.tokensOfInterestCount)
  self.rebuildMarketData()
  self.fetchTokensDetails() # TODO: if the only place where we can see these details is account's details page, we should fetch this on demand, no need to have local cache
  # notify modules
  self.events.emit(SIGNAL_TOKENS_LIST_UPDATED, Args())
  self.events.emit(SIGNAL_TOKEN_PREFERENCES_UPDATED, Args())

proc onAsyncRefreshTokensDone(self: Service, response: string) {.slot.} =
  # The worker already decoded the RPC responses AND built the token structures;
  # claim the ready object by handle — no GUI-thread JSON parse or token-model
  # build. `res` is nil only if the handoff was drained at shutdown.
  let res = takeTyped[RefreshTokensApplyResult](response)
  # Always advance the coordinator so a failed/nil completion never wedges the
  # in-flight gate. On a nil handoff use the in-flight generation (not a stale
  # sentinel) so it cannot re-fire forever.
  let completedGen = if not res.isNil: res.generation else: self.refreshTokensGen.currentGeneration
  # Until a final map is applied, a stale result is still better than none: apply
  # it so held balances resolve, and let the re-fire replace it.
  let c = self.refreshTokensGen.onCompletion(completedGen,
    applyStale = self.tokensOfInterestReadiness.appliesStale)
  if c.action in {rcaDropAndRefire, rcaApplyAndRefire}:
    debug "stale async refresh tokens response; re-firing newest",
      completedGen = completedGen, applied = c.action == rcaApplyAndRefire
    self.startRefreshTokensTask(c.gen)
    if c.action == rcaDropAndRefire:
      return
  if res.isNil:
    return
  if res.error.len > 0:
    error "async refresh tokens failed", errDescription = res.error
    return
  self.applyRefreshTokensResult(res, c.action)

proc onAsyncFetchAllTokenListsDone(self: Service, response: string) {.slot.} =
  # `res` is nil only if the handoff was drained at shutdown
  let res = takeTyped[AllTokenListsApplyResult](response)
  if res.isNil:
    return
  if res.error.len > 0:
    error "async fetch all token lists failed", errDescription = res.error
  # MOVE the worker-built items in, never copy (see applyRefreshTokensResult)
  self.catalogue.tokenLists.complete(res.generation, ok = res.error.len == 0, move res.allTokenLists)

proc fetchPendingMissingTokenKeys(self: Service) =
  # Debounced: drain every key that missed since the last batch and fetch them in
  # one async RPC on the threadpool.
  let keys = self.pendingTokenFetch.takeBatch()
  if keys.len == 0:
    return
  let arg = AsyncFetchMissingTokensTaskArg(
    tptr: asyncFetchMissingTokensTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncFetchMissingTokensDone",
    keys: keys,
  )
  self.threadpool.start(arg)

proc scheduleMissingTokenKeysFetch(self: Service) =
  self.missingTokenKeysFetchDebouncer.call()

proc onAsyncFetchMissingTokensDone(self: Service, response: string) {.slot.} =
  # Decode the envelope and release the batch's keys from the in-flight set
  # regardless of outcome — an undecodable envelope must not leave its keys
  # wedged as permanently in flight (they could never re-enqueue).
  let (env, decodeError) = decodeAndCompleteBatch(self.pendingTokenFetch, response)
  if decodeError.len > 0:
    error "error decoding async fetch missing tokens response", msg = decodeError
    return
  if env.error.len > 0:
    # Transient backend failure: leave the keys unmarked so a later lookup retries
    # (async, off the GUI thread) rather than caching a false "missing".
    error "async fetch missing tokens failed", errDescription = env.error
    return
  try:
    # Index the returned tokens by their (lower-cased) key so each requested key is
    # cached under the exact string that was looked up. This preserves the old
    # getTokenByKey semantics (store under the requested key) even when the request
    # used a checksummed/mixed-case address, so the next lookup Hits instead of
    # re-enqueuing forever.
    var tokenByLowerKey = initTable[string, TokenItem]()
    for token in env.tokens.map(t => createTokenItem(t)):
      tokenByLowerKey[token.key.toLowerAscii] = token
    var foundTokens: seq[TokenItem]
    var foundKeys = initHashSet[string]()
    for requestedKey in env.requestedKeys:
      let matched = tokenByLowerKey.getOrDefault(requestedKey.toLowerAscii)
      if not matched.isNil:
        self.tokensOfInterestByKey[requestedKey] = matched
        foundTokens.add(matched)
        foundKeys.incl(requestedKey)
    if foundTokens.len > 0:
      self.addNewTokensToGroupsOfInterest(foundTokens)
    # Keys the backend did not return are genuinely missing -> feed the negative-cache markers.
    for key in missingFromBatch(env.requestedKeys, foundKeys):
      self.knownMissingKeys.incl(key)
    if foundTokens.len > 0:
      # Notify consumers so they re-read and the late tokens resolve.
      self.events.emit(SIGNAL_TOKENS_LIST_UPDATED, Args())
  except Exception as e:
    error "error processing async fetch missing tokens", msg = e.msg

proc startRefreshTokensTask(self: Service, generation: int) =
  let arg = AsyncRefreshTokensTaskArg(
    tptr: asyncRefreshTokensTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncRefreshTokensDone",
    requestId: generation,
  )
  self.threadpool.start(arg)

proc asyncRefreshTokens(self: Service) =
  # Coalesced: bump the generation and start a task only when none is
  # in flight; an in-flight task re-fires once on completion if newer triggers came.
  let (shouldStart, gen) = self.refreshTokensGen.requestRefresh()
  if shouldStart:
    self.startRefreshTokensTask(gen)

proc startFetchAllTokenListsTask(self: Service, generation: int) =
  let arg = AsyncFetchAllTokenListsTaskArg(
    tptr: asyncFetchAllTokenListsTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncFetchAllTokenListsDone",
    requestId: generation,
  )
  self.threadpool.start(arg)

proc acquireTokenLists*(self: Service) =
  self.catalogue.tokenLists.acquire()

proc releaseTokenLists*(self: Service) =
  self.catalogue.tokenLists.release()

proc getTokenListsLoading*(self: Service): bool =
  return self.catalogue.tokenLists.isLoading

proc init*(self: Service) =
  self.rebuildMarketDataDebouncer = debouncer_service.newDebouncer(
    self.threadpool,
    # this is the delay before the first call to the callback, this is an action that doesn't need to be called immediately, but it's pretty expensive in terms of time/performances
    # for example `wallet-tick-reload` event is emitted for every single chain-account pair, and at the app start can be more such signals received from the statusgo side if the balance have changed.
    # Means it the app contains more accounts the likelihood of having more `wallet-tick-reload` signals is higher, so we need to delay the rebuildMarketData call to avoid unnecessary calls.
    delayMs = 1000,
    checkIntervalMs = 500)
  self.rebuildMarketDataDebouncer.registerCall0(callback = proc() = self.rebuildMarketDataInternal())

  # Coalesce a burst of by-key misses (e.g. a model rebuild) into one batch fetch.
  # Short delay so late tokens resolve quickly while still collapsing the burst.
  self.missingTokenKeysFetchDebouncer = debouncer_service.newDebouncer(
    self.threadpool,
    delayMs = 200,
    checkIntervalMs = 100)
  self.missingTokenKeysFetchDebouncer.registerCall0(callback = proc() = self.fetchPendingMissingTokenKeys())

  self.onDemandPricesDebouncer = debouncer_service.newDebouncer(
    self.threadpool,
    delayMs = 200,
    checkIntervalMs = 100)
  self.onDemandPricesDebouncer.registerCall0(callback = proc() = self.fetchPendingOnDemandPrices())

  self.events.on(SignalType.Wallet.event) do(e:Args):
    var data = WalletSignal(e)
    case data.eventType:
      of "wallet-tick-reload":
        self.rebuildMarketData()
  # update and populate internal list and then emit signal when new custom token detected?
  self.events.on(SignalType.WalletTokensListsUpdated.event) do(e:Args):
    self.asyncRefreshTokens()
    self.catalogue.onTokenListsUpdated()

  self.events.on(SIGNAL_NETWORK_MODE_UPDATED) do(e:Args):
    self.asyncRefreshTokens()
    self.prefetchSwapSupport()
    self.catalogue.onNetworkModeUpdated()

  self.events.on(SIGNAL_NETWORK_ACTIVE_UPDATED) do(e:Args):
    self.catalogue.onActiveNetworksUpdated()

  when main_constants.IS_MOBILE:
    self.events.on(SIGNAL_APP_BACKGROUNDED) do(e: Args):
      self.catalogue.onBackgrounded()

    self.events.on(SIGNAL_APP_FOREGROUNDED) do(e: Args):
      self.catalogue.onForegrounded()

  self.events.on(SIGNAL_CURRENCY_UPDATED) do(e:Args):
    self.resetMarketValuesCache()
    self.rebuildMarketData()

  self.asyncRefreshTokens()
  self.prefetchSwapSupport()

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

proc startFetchChainTokenGroupsTask(self: Service, chainId: int, generation: int) =
  let arg = AsyncBuildGroupsForChainTaskArg(
    tptr: asyncBuildGroupsForChainTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncBuildGroupsForChainDone",
    chainId: chainId,
    generation: generation,
  )
  self.threadpool.start(arg)

proc onAsyncBuildGroupsForChainDone(self: Service, response: string) {.slot.} =
  # The worker already decoded + built the name-sorted groups; MOVE them into state
  # (never copy — see applyRefreshTokensResult) with no GUI-thread JSON parse or
  # group build. `res` is nil only if the handoff was drained at shutdown.
  let res = takeTyped[TokenGroupsApplyResult](response)
  if res.isNil:
    return
  if res.error.len > 0:
    error "async build groups for chain failed", errDescription = res.error
  self.catalogue.chainTokenGroups.complete(res.chainId, res.generation, ok = res.error.len == 0, move res.groups)

proc acquireChainTokenGroups*(self: Service, chainId: int) =
  if chainId <= 0:
    warn "invalid chainId", chainId = chainId
    return
  self.catalogue.chainTokenGroups.acquire(chainId)

proc releaseChainTokenGroups*(self: Service, chainId: int) =
  self.catalogue.chainTokenGroups.release(chainId)

proc getChainTokenGroups*(self: Service, chainId: int): var seq[TokenGroupItem] =
  ## Empty unless the chain's groups are held and loaded.
  return self.catalogue.chainTokenGroups.items(chainId)

proc getChainTokenGroupsLoading*(self: Service, chainId: int): bool =
  return self.catalogue.chainTokenGroups.isLoading(chainId)

proc isChainTokenGroupsActive*(self: Service, chainId: int): bool =
  return self.catalogue.chainTokenGroups.isActive(chainId)

proc startFetchAllTokenGroupsTask(self: Service, generation: int) =
  let arg = AsyncFetchAllTokenGroupsTaskArg(
    tptr: asyncFetchAllTokenGroupsTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncFetchAllTokenGroupsDone",
    generation: generation,
  )
  self.threadpool.start(arg)

proc onAsyncFetchAllTokenGroupsDone(self: Service, response: string) {.slot.} =
  # Worker-built, name-sorted groups moved into state (see onAsyncBuildGroupsForChainDone).
  let res = takeTyped[TokenGroupsApplyResult](response)
  if res.isNil:
    return
  if res.error.len > 0:
    error "async fetch all token groups failed", errDescription = res.error
  self.catalogue.allTokenGroups.complete(res.generation, ok = res.error.len == 0, move res.groups)

proc acquireAllTokenGroups*(self: Service) =
  self.catalogue.allTokenGroups.acquire()

proc releaseAllTokenGroups*(self: Service) =
  self.catalogue.allTokenGroups.release()

proc getAllTokenGroups*(self: Service): var seq[TokenGroupItem] =
  ## Empty unless held and loaded.
  return self.catalogue.allTokenGroups.items

proc getAllTokenGroupsLoading*(self: Service): bool =
  return self.catalogue.allTokenGroups.isLoading

proc getAllTokenLists*(self: Service): var seq[TokenListItem] =
  ## Empty unless held and loaded.
  return self.catalogue.tokenLists.items

################################################################################
## This is a very special function that should not be used anywhere else,
## it covers the backward compatibility with the old payment requests.
##
## Returns the first token on the given chain that matches the symbol or name
## (cause some tokens have different symbols for EVM/BSC chains), case insensitive.
proc getTokenBySymbolOnChain*(self: Service, symbol: string, chainId: int): TokenItem =
  return fetchTokenBySymbolOnChain(chainId, symbol)
################################################################################

proc getTokensOfInterestReadiness*(self: Service): TokenMapReadiness =
  return self.tokensOfInterestReadiness

proc getTokenByKey*(self: Service, key: string): TokenItem =
  if not common_utils.isTokenKey(key):
    return nil
  case classifyTokenLookup(self.tokensOfInterestByKey, self.knownMissingKeys, key)
  of TokenLookupOutcome.Hit:
    return self.tokensOfInterestByKey[key]
  of TokenLookupOutcome.KnownMissing:
    # The backend already reported this key as "not found"; return nil without
    # repeating the blocking RPC. Cleared when a refresh applies fresh token data.
    return nil
  of TokenLookupOutcome.NeedsFetch:
    # No synchronous backend RPC on the GUI thread: enqueue the key
    # for a coalesced async batch and return nil now. When the batch completes the
    # service updates its caches/markers and emits SIGNAL_TOKENS_LIST_UPDATED, so
    # consumers re-read and the token resolves (placeholder -> value).
    if self.pendingTokenFetch.enqueue(key):
      self.scheduleMissingTokenKeysFetch()
    return nil

proc getTokenByChainAddress*(self: Service, chainId: int, address: string): TokenItem =
  let key = common_utils.createTokenKey(chainId, address)
  result = self.getTokenByKey(key)
  if result.isNil and address.toLowerAscii == common_wallet_constants.ZERO_ADDRESS:
    # Native tokens are well-known: resolve them synchronously so paths like the
    # message transaction details never see a nil-first. Once a refresh
    # caches the backend's richer native token, getTokenByKey Hits it instead.
    result = createNativeTokenItem(chainId)

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

# A group outside the tokens of interest: one small synchronous backend lookup,
# cached (empty results too) until the next applied tokens refresh.
proc getTokensOfGroupOnDemand(self: Service, groupKey: string): seq[TokenItem] =
  return self.groupTokensLookups.lookup(groupKey, fetchTokensByGroupKey)

## Note: use this function in a very rare case, when you're sure the token is not present in the models.
## Returns a token that matches the key, or the first token in the group that matches the key.
# Every deployment of a token by its key or group key: the tokens of interest
# first, then an on-demand backend lookup of the group.
proc getTokensByKeyOrGroupKeyFromAllTokens*(self: Service, key: string): seq[TokenItem] =
  if common_utils.isTokenKey(key):
    let token = self.getTokenByKey(key)
    return if token.isNil: @[] else: @[token]
  result = self.getTokensByGroupKey(key)
  if result.len > 0:
    return
  return self.getTokensOfGroupOnDemand(key)

proc getTokenByKeyOrGroupKeyFromAllTokens*(self: Service, key: string): TokenItem =
  let tokens = self.getTokensByKeyOrGroupKeyFromAllTokens(key)
  return if tokens.len > 0: tokens[0] else: nil

proc ensurePricesForGroup*(self: Service, key: string) =
  let keys = if common_utils.isTokenKey(key): @[key]
             else: self.getTokensByKeyOrGroupKeyFromAllTokens(key).mapIt(it.key)
  if keys.len > 0:
    self.ensurePricesForTokens(keys)

proc getTokenByGroupKeyAndChainId*(self: Service, groupKey: string, chainId: int): TokenItem =
  let tokens = self.getTokensByGroupKey(groupKey)
  if tokens.len > 0:
    for token in tokens:
      if token.chainId == chainId:
        return token

  for token in self.getTokensOfGroupOnDemand(groupKey):
    if token.chainId == chainId:
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

proc isChainSupportedForSwap*(self: Service, chainId: int): bool =
  if not SWAP_PROVIDER_ENABLED:
    return false
  if chainId <= 0:
    warn "invalid chainId", chainId = chainId
    return false
  if self.chainsSupportedForSwap.hasKey(chainId):
    return self.chainsSupportedForSwap[chainId]
  # not answered yet (a chain activated after the startup prefetch, or a failed
  # fetch): ask, and don't block meanwhile. Only a provider's "no" blocks a chain;
  # an unsupported one still fails at the route request.
  self.prefetchSwapSupport(@[chainId])
  return true

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
