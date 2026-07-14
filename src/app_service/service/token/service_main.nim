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
  sortTokenGroupsByKey(self.groupsOfInterest)  # deterministic order

proc applyAllTokenListsResult(self: Service, res: AllTokenListsApplyResult) =
  # Slim GUI-thread apply: the worker already built the token-list items; MOVE
  # them in (never copy — see applyRefreshTokensResult).
  self.allTokenLists = move res.allTokenLists

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

proc prefetchLiFiSupport(self: Service) =
  let chainIds = self.networkService.getEnabledChainIds()
  if chainIds.len == 0:
    return
  # One task per chain so the cache fills incrementally as each RPC completes.
  for chainId in chainIds:
    if chainId <= 0:
      continue
    let arg = PrefetchLiFiSupportTaskArg(
      tptr: prefetchLiFiSupportTask,
      vptr: cast[uint](self.vptr),
      slot: "prefetchLiFiSupportRetrieved",
      chainId: chainId,
    )
    self.threadpool.start(arg)

proc prefetchLiFiSupportRetrieved(self: Service, response: string) {.slot.} =
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
    self.chainsSupportedForSwapViaLiFi[chainId] = supported
  except Exception as ex:
    error "prefetchLiFiSupportRetrieved", err = ex.msg

proc applyRefreshTokensResult(self: Service, res: RefreshTokensApplyResult) =
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
    # Fresh token data invalidates prior "not found" markers: a key that was
    # missing before may now resolve.
    self.knownMissingKeys.clear()
  else:
    debug "ignoring empty tokens-of-interest refresh; keeping existing token groups cache"

  # Keep tokenPreferencesJson as the backend array string for QML; the worker
  # already decoded the rows — move them into the table (same merge as before).
  self.tokenPreferencesJson = move res.tokenPreferencesJson
  for preferences in res.tokenPreferences.mitems:
    let key = preferences.key
    self.tokenPreferencesTable[key] = move preferences

  if shouldReplaceTokensCache(res.allTokensCount, self.allTokensByGroupKey.len):
    # Same swap-not-clear discipline as the tokens-of-interest cache above.
    self.allTokensByGroupKey = move res.allTokensByGroupKey
  else:
    debug "ignoring empty all-tokens refresh; keeping existing all tokens cache"
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
  let c = self.refreshTokensGen.onCompletion(completedGen)
  if c.action == rcaDropAndRefire:
    debug "dropping stale async refresh tokens response; re-firing newest",
      completedGen = completedGen
    # A dropped flagged result discards the catalogue it fetched — the re-fire must
    # re-fetch it, in addition to any want queued by the triggers that made us stale.
    let refireFetchAllTokens = self.pendingFetchAllTokens or self.inFlightFetchAllTokens
    self.pendingFetchAllTokens = false
    self.inFlightFetchAllTokens = refireFetchAllTokens
    self.startRefreshTokensTask(c.gen, refireFetchAllTokens)
    return
  # rcaApply: this is the newest generation.
  if res.isNil:
    return
  if res.error.len > 0:
    error "async refresh tokens failed", errDescription = res.error
    return
  self.applyRefreshTokensResult(res)

proc onAsyncFetchAllTokenListsDone(self: Service, response: string) {.slot.} =
  let res = takeTyped[AllTokenListsApplyResult](response)
  let completedGen = if not res.isNil: res.generation else: self.fetchAllTokenListsGen.currentGeneration
  let c = self.fetchAllTokenListsGen.onCompletion(completedGen)
  if c.action == rcaDropAndRefire:
    debug "dropping stale async fetch all token lists response; re-firing newest",
      completedGen = completedGen
    self.startFetchAllTokenListsTask(c.gen) # keeps tokenListsLoading true
    return
  # rcaApply: newest generation, nothing more in flight.
  self.tokenListsLoading = false
  if res.isNil:
    return
  if res.error.len > 0:
    error "async fetch all token lists failed", errDescription = res.error
    return
  self.applyAllTokenListsResult(res)
  self.events.emit(SIGNAL_TOKEN_LISTS_LOADED, Args())

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
  try:
    let env = Json.decode(response, FetchMissingTokensResponse, allowUnknownFields = true)
    # Release the batch's keys from the in-flight set regardless of outcome.
    self.pendingTokenFetch.completeBatch(env.requestedKeys)
    if env.error.len > 0:
      # Transient backend failure: leave the keys unmarked so a later lookup retries
      # (async, off the GUI thread) rather than caching a false "missing".
      error "async fetch missing tokens failed", errDescription = env.error
      return
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

proc startRefreshTokensTask(self: Service, generation: int, fetchAllTokens: bool = false) =
  let arg = AsyncRefreshTokensTaskArg(
    tptr: asyncRefreshTokensTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncRefreshTokensDone",
    requestId: generation,
    fetchAllTokens: fetchAllTokens,
  )
  self.threadpool.start(arg)

# fetchAllTokens must be true only when the full catalogue can change (init /
# token-lists-updated); routine refreshes skip the ~3MB getAllTokens fetch+decode.
# The want is ORed across coalesced triggers and consumed when
# a task actually starts, so a flagged trigger arriving while a task is in flight
# still gets its catalogue fetch on the eventual re-fire.
proc asyncRefreshTokens(self: Service, fetchAllTokens: bool = false) =
  # Coalesced: bump the generation and start a task only when none is
  # in flight; an in-flight task re-fires once on completion if newer triggers came.
  if fetchAllTokens:
    self.pendingFetchAllTokens = true
  let (shouldStart, gen) = self.refreshTokensGen.requestRefresh()
  if shouldStart:
    self.inFlightFetchAllTokens = self.pendingFetchAllTokens
    self.pendingFetchAllTokens = false
    self.startRefreshTokensTask(gen, self.inFlightFetchAllTokens)

proc startFetchAllTokenListsTask(self: Service, generation: int) =
  self.tokenListsLoading = true
  let arg = AsyncFetchAllTokenListsTaskArg(
    tptr: asyncFetchAllTokenListsTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncFetchAllTokenListsDone",
    requestId: generation,
  )
  self.threadpool.start(arg)

proc asyncFetchAllTokenLists*(self: Service) =
  let (shouldStart, gen) = self.fetchAllTokenListsGen.requestRefresh()
  if shouldStart:
    self.startFetchAllTokenListsTask(gen)

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

  # Coalesce a burst of by-key misses (e.g. a model rebuild) into one batch fetch.
  # Short delay so late tokens resolve quickly while still collapsing the burst.
  self.missingTokenKeysFetchDebouncer = debouncer_service.newDebouncer(
    self.threadpool,
    delayMs = 200,
    checkIntervalMs = 100)
  self.missingTokenKeysFetchDebouncer.registerCall0(callback = proc() = self.fetchPendingMissingTokenKeys())

  self.events.on(SignalType.Wallet.event) do(e:Args):
    var data = WalletSignal(e)
    case data.eventType:
      of "wallet-tick-reload":
        self.rebuildMarketData()
  # update and populate internal list and then emit signal when new custom token detected?
  self.events.on(SignalType.WalletTokensListsUpdated.event) do(e:Args):
    self.asyncRefreshTokens(fetchAllTokens = true)
    self.asyncFetchAllTokenLists()

  self.events.on(SIGNAL_NETWORK_MODE_UPDATED) do(e:Args):
    self.asyncRefreshTokens()
    self.prefetchParaswapSupport()
    self.prefetchLiFiSupport()

  self.events.on(SIGNAL_CURRENCY_UPDATED) do(e:Args):
    self.rebuildMarketData()

  self.asyncRefreshTokens(fetchAllTokens = true)
  self.prefetchParaswapSupport()
  self.prefetchLiFiSupport()

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

proc buildGroupsForChainTo*(self: Service, chainId: int) =
  if chainId <= 0:
    warn "invalid chainId", chainId = chainId
    return
  self.groupsForChainToLoading = true
  let arg = AsyncBuildGroupsForChainTaskArg(
    tptr: asyncBuildGroupsForChainTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncBuildGroupsForChainToDone",
    chainId: chainId,
  )
  self.threadpool.start(arg)

proc onAsyncBuildGroupsForChainToDone(self: Service, response: string) {.slot.} =
  self.groupsForChainToLoading = false
  try:
    let env = Json.decode(response, BuildGroupsForChainResponse, allowUnknownFields = true)
    if env.error.len > 0:
      error "async build groups for chain (to) failed", errDescription = env.error
      self.events.emit(SIGNAL_GROUPS_FOR_CHAIN_TO_LOADED, Args())
      return
    let tokens = env.tokens.map(t => createTokenItem(t))
    var groupsByKey = initTable[string, TokenGroupItem](tokens.len)
    createTokenGroupsFromTokens(tokens, groupsByKey)
    self.groupsForChainTo = toSeq(groupsByKey.values)
    sortTokenGroupsByName(self.groupsForChainTo)
    self.events.emit(SIGNAL_GROUPS_FOR_CHAIN_TO_LOADED, Args())
  except Exception as e:
    error "error processing async build groups for chain (to)", msg = e.msg
    self.events.emit(SIGNAL_GROUPS_FOR_CHAIN_TO_LOADED, Args())

proc getGroupsForChainToLoading*(self: Service): bool =
  return self.groupsForChainToLoading

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

proc getGroupsForChainTo*(self: Service): var seq[TokenGroupItem] =
  return self.groupsForChainTo

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

## Checks if the chain is supported for swap via LI.FI
proc isChainSupportedForSwapViaLiFi*(self: Service, chainId: int): bool =
  if chainId <= 0:
    warn "invalid chainId", chainId = chainId
    return false
  if self.chainsSupportedForSwapViaLiFi.hasKey(chainId):
    return self.chainsSupportedForSwapViaLiFi[chainId]
  let supported = isChainSupportedForSwapViaLiFi(chainId)
  self.chainsSupportedForSwapViaLiFi[chainId] = supported
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
