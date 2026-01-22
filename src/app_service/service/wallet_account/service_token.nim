const noGasErrorCode = "WR-002"

# Helper to parse hex balance string to Uint256
proc parseHexBalance(hexStr: string): Uint256 =
  if hexStr.len == 0 or hexStr == "0x0":
    return u256(0)
  var cleanHex = hexStr
  if cleanHex.startsWith("0x") or cleanHex.startsWith("0X"):
    cleanHex = cleanHex[2..^1]
  if cleanHex.len == 0:
    return u256(0)
  return fromHex(Uint256, cleanHex)

# Build grouped assets list from flat assets list using token service group keys
proc rebuildGroupedAssets*(self: Service) =
  var groupedAssetsMap: Table[string, AssetGroupItem] = initTable[string, AssetGroupItem]()
  var accountAddresses: HashSet[string]

  var keys: seq[string] = @[]
  for flatAsset in self.flatAssets:
    keys.add(flatAsset.tokenKey)
    accountAddresses.incl(flatAsset.account)
  let tokens = self.tokenService.getTokensByKeys(keys)
  for flatAsset in self.flatAssets:
    let token = tokens.getOrDefault(flatAsset.tokenKey, nil)
    if token.isNil:
      warn "error: ", procName="rebuildGroupedAssets", errName="received balance for an unknown token", tokenKey=flatAsset.tokenKey
      continue
    let groupKey = token.groupKey
    if not groupedAssetsMap.hasKey(groupKey):
      groupedAssetsMap[groupKey] = AssetGroupItem(key: groupKey, balancesPerAccount: @[])
    groupedAssetsMap[groupKey].balancesPerAccount.add(BalanceItem(
      account: flatAsset.account,
      groupKey: groupKey,
      tokenKey: flatAsset.tokenKey,
      chainId: flatAsset.chainId,
      tokenAddress: flatAsset.tokenAddress,
      balance: flatAsset.balance
    ))
  self.groupedAssets = toSeq(groupedAssetsMap.values)

  let timestamp = getTime().toUnix()
  self.events.emit(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT, TokensPerAccountArgs(
    accountAddresses: toSeq(accountAddresses),
    assets: self.groupedAssets,
    timestamp: timestamp
  ))

# Response format from getAllTokenBalances:
# {
#   "<accountAddress>": {
#     "<chainId>": {
#       "balances": { "<tokenAddress>": "<balanceHex>" },
#       "state": { "state": <int>, "atBlockNumber": <string>, "atBlockHash": <string>, "fetchedAt": <int64> }
#     }
#   }
# }
proc onGetAllTokenBalancesResponse(self: Service, response: string) {.slot.} =
  try:
    let responseObj = response.parseJson
    var resultObj: JsonNode
    discard responseObj.getProp("result", resultObj)

    if resultObj.isNil or resultObj.kind != JObject:
      return

    # Collect all account addresses from the response
    var accountsInResponse: HashSet[string]
    var chainIdsInResponse: HashSet[int]
    for accountAddress, chainIdsObj in resultObj:
      if chainIdsObj.kind != JObject:
        continue
      accountsInResponse.incl(accountAddress)
      for chainIdStr, _ in chainIdsObj:
        if chainDataObj.kind != JObject:
          continue
        chainIdsInResponse.incl(parseInt(chainIdStr))

    # Remove existing flat assets for accounts+chainIDs in the response
    self.flatAssets = self.flatAssets.filter(asset => not accountsInResponse.contains(asset.account))

    # Parse response: result[accountAddress][chainId].balances[tokenAddress] = balanceHex
    for accountAddress, chainIdsObj in resultObj:
      if chainIdsObj.kind != JObject:
        continue

      # Initialize balance states for this account if not exists
      if not self.balanceStates.hasKey(accountAddress):
        self.balanceStates[accountAddress] = initTable[int, BalanceState]()

      for chainIdStr, chainDataObj in chainIdsObj:
        if chainDataObj.kind != JObject:
          continue

        let chainId = parseInt(chainIdStr)

        # Extract and store state information
        var stateObj: JsonNode
        discard chainDataObj.getProp("state", stateObj)

        if not stateObj.isNil and stateObj.kind == JObject:
          var balanceState = BalanceState()
          if stateObj.hasKey("state"):
            balanceState.state = stateObj["state"].getInt()
          if stateObj.hasKey("atBlockNumber") and stateObj["atBlockNumber"].kind != JNull:
            balanceState.atBlockNumber = stateObj["atBlockNumber"].getStr()
          if stateObj.hasKey("atBlockHash"):
            balanceState.atBlockHash = stateObj["atBlockHash"].getStr()
          if stateObj.hasKey("fetchedAt"):
            balanceState.fetchedAt = stateObj["fetchedAt"].getInt()

          self.balanceStates[accountAddress][chainId] = balanceState

        # Get balances from the chainDataObj
        var balancesObj: JsonNode
        discard chainDataObj.getProp("balances", balancesObj)

        if balancesObj.isNil or balancesObj.kind != JObject:
          continue

        for tokenAddress, balanceNode in balancesObj:
          var rawBalance: Uint256 = u256(0)
          if balanceNode.kind == JString:
            rawBalance = parseHexBalance(balanceNode.getStr)

          self.flatAssets.add(FlatBalanceItem(
            account: accountAddress,
            chainId: chainId,
            tokenAddress: tokenAddress,
            tokenKey: utils.createTokenKey(chainId, tokenAddress),
            balance: rawBalance
          ))

      # Set assetsLoading to false for this account
      self.updateAssetsLoadingState(accountAddress, false)

    self.hasBalanceCache = true

    # Rebuild grouped assets from flat assets
    self.rebuildGroupedAssets()

  except Exception as e:
    error "error: ", procName="onGetAllTokenBalancesResponse", errName = e.name, errDesription = e.msg

# Refresh token balances cache for specific accounts and chains
proc refreshAllTokenBalancesCache(self: Service, accounts: seq[string], chainIds: seq[int]) =
  if not main_constants.WALLET_ENABLED or
    accounts.len == 0 or
    chainIds.len == 0:
      return

  # Set assetsLoading to true as the tokens are being loaded
  for waddress in accounts:
    self.updateAssetsLoadingState(waddress, true)

  var uniqueAddresses: HashSet[string] = toHashSet(accounts)
  let arg = GetAllTokenBalancesTaskArg(
    tptr: getAllTokenBalancesTask,
    vptr: cast[uint](self.vptr),
    slot: "onGetAllTokenBalancesResponse",
    accounts: toSeq(uniqueAddresses),
    chainIds: chainIds
  )
  self.threadpool.start(arg)

# Returns the total currency balance for the given wallet accounts and chain ids
proc getTotalCurrencyBalance*(self: Service, walletAccounts: seq[string], chainIds: seq[int]): float64 =
  var totalBalance: float64 = 0.0
  for assetGroupItem in self.groupedAssets:
    for balanceItem in assetGroupItem.balancesPerAccount:
      if not walletAccounts.contains(balanceItem.account) or not chainIds.contains(balanceItem.chainId):
        continue
      let price = self.tokenService.getPriceForToken(balanceItem.tokenKey)
      let value = self.getCurrencyValueForToken(balanceItem.tokenKey, balanceItem.balance)
      totalBalance = totalBalance + (value*price)
  return totalBalance

proc getGroupedAssetsList*(self: Service): var seq[AssetGroupItem] =
  return self.groupedAssets

proc getBalanceState*(self: Service, account: string, chainId: int): BalanceState =
  if self.balanceStates.hasKey(account) and self.balanceStates[account].hasKey(chainId):
    return self.balanceStates[account][chainId]
  return nil

proc getTokensMarketValuesLoading*(self: Service): bool =
  return self.tokenService.getTokensMarketValuesLoading()

proc getHasBalanceCache*(self: Service): bool =
  return self.hasBalanceCache

proc getChainsWithNoGasFromError*(self: Service, errCode: string, errDescription: string): Table[int, string] =
  ## Extracts the chainId and token from the error description for chains with no gas.
  ## If the error code is not "WR-002", an empty table is returned.
  result = initTable[int, string]()

  if errCode == noGasErrorCode:
    try:
      let jsonData = parseJson(errDescription)
      let token: string = jsonData["token"].getStr()
      let chainId: int = jsonData["chainId"].getInt()
      result[chainId] = token
    except Exception as e:
      error "error: ", procName="getChainsWithNoGasFromError", errName=e.name, errDesription=e.msg

proc getCurrency*(self: Service): string =
  return self.settingsService.getCurrency()

proc getOrFetchBalanceForAddressInPreferredCurrency*(self: Service, address: string): tuple[balance: float64, fetched: bool] =
  let acc = self.getAccountByAddress(address)
  if acc.isNil:
    result.balance = 0.0
    result.fetched = false
    return
  let chainIds = self.networkService.getCurrentNetworksChainIds()
  result.balance = self.getTotalCurrencyBalance(@[acc.address], chainIds)
  result.fetched = true

# Returns token balance for the given wallet account and token key
proc getTokenBalance*(self: Service, walletAccount: string, tokenKey: string): float64 =
  if tokenKey.len == 0:
    return 0.0
  for assetGroupItem in self.groupedAssets:
    for balanceItem in assetGroupItem.balancesPerAccount:
      if balanceItem.account != walletAccount or balanceItem.tokenKey != tokenKey:
        continue
      return self.getCurrencyValueForToken(balanceItem.tokenKey, balanceItem.balance)
  return 0.0

proc reloadAccountBalances*(self: Service) =
  try:
    discard backend.refetchAllTokenBalances()
  except Exception as e:
    let errDesription = e.msg
    error "error reloadAccountBalances: ", errDesription

proc getCurrencyValueForToken*(self: Service, tokenKey: string, amountInt: UInt256): float64 =
  return self.currencyService.getCurrencyValueForToken(tokenKey, amountInt)

proc getCurrencyFormat*(self: Service, key: string): CurrencyFormatDto =
  return self.currencyService.getCurrencyFormat(key)
