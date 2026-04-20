const noGasErrorCode = "WR-002"

# This method will group the account assets by symbol (in case of communiy, the token address)
proc onAllTokensBuilt(self: Service, response: string) {.slot.} =
  var accountAddresses: seq[string] = @[]
  var groupedAssets: seq[AssetGroupItem] = @[]
  defer:
    let timestamp = getTime().toUnix()
    self.events.emit(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT, TokensPerAccountArgs(
      accountAddresses:accountAddresses,
      assets: groupedAssets,
      timestamp: timestamp
    ))

  try:
    let responseObj = response.parseJson
    var resultObj: JsonNode
    discard responseObj.getProp("result", resultObj)

    # Working table - value-type AssetGroupItem now, so we mutate via mpairs /
    # mgetOrPut rather than relying on ref-object aliasing.
    var groupedAssetsBalances: Table[string, AssetGroupItem] # [crossChainId (or tokenKey if crossChainId is empty), AssetGroupItem]

    # Seed with the existing snapshot.
    for asset in self.groupedAssets:
      if not groupedAssetsBalances.hasKey(asset.key):
        groupedAssetsBalances[asset.key] = asset
      else:
        groupedAssetsBalances.withValue(asset.key, existing):
          existing[].balancesPerAccount.add(asset.balancesPerAccount)

    var allTokensHaveError: bool = true
    if resultObj.kind == JObject:
      for accountAddress, balanceDetailsObj in resultObj:
        accountAddresses.add(accountAddress)

        # Delete all existing entries for the account for whom assets were requested,
        # for a new account the balances per address per chain will simply be appended later
        var assetsToBeDeleted: seq[string] = @[]
        for key, asset in groupedAssetsBalances.mpairs:
          asset.balancesPerAccount = asset.balancesPerAccount.filter(balanceItem => balanceItem.account != accountAddress)
          if asset.balancesPerAccount.len == 0:
            assetsToBeDeleted.add(key)

        for a in assetsToBeDeleted:
          groupedAssetsBalances.del(a)

        if balanceDetailsObj.kind == JArray:
          for balanceDetail in balanceDetailsObj.getElems():
            let tokenItem = createTokenItem(TokenDto(
              address: balanceDetail{"tokenAddress"}.getStr,
              chainId: balanceDetail{"tokenChainId"}.getInt
            ))

            let token = self.tokenService.getTokenByKey(tokenItem.key)
            if token.isNil:
              warn "error: ", procName="onAllTokensBuilt", errName="received balance for an unknown token", tokenKey=tokenItem.key
              continue

            # Expecting "<nil>" values comming from status-go when the entry is nil, but with new format it should never be nil
            var rawBalance: Uint256 = u256(0)
            let rawBalanceStr = balanceDetail{"rawBalance"}.getStr
            if not rawBalanceStr.contains("nil"):
              rawBalance = rawBalanceStr.parse(Uint256)

            if not balanceDetail{"hasError"}.getBool:
              allTokensHaveError = false

            let groupKey = token.groupKey
            discard groupedAssetsBalances.hasKeyOrPut(groupKey, AssetGroupItem(key: groupKey))
            groupedAssetsBalances.withValue(groupKey, existing):
              existing[].balancesPerAccount.add(BalanceItem(
                account: accountAddress,
                groupKey: groupKey,
                tokenKey: token.key,
                tokenAddress: token.address,
                chainId: token.chainId,
                balance: rawBalance
              ))

        # set assetsLoading to false once the tokens are loaded
        self.updateAssetsLoadingState(accountAddress, false)

    groupedAssets = toSeq(groupedAssetsBalances.values)
    if not allTokensHaveError:
      self.hasBalanceCache = true
      # Atomic snapshot swap: any model holding the old CowSeq still sees its
      # data; the next modelsUpdated() pull will diff against this new buffer.
      self.groupedAssets = toCowSeq(groupedAssets)
  except Exception as e:
    error "error: ", procName="onAllTokensBuilt", errName = e.name, errDesription = e.msg

proc buildAllTokensInternal(self: Service, accounts: seq[string], forceRefresh: bool) =
  if not main_constants.WALLET_ENABLED or
    accounts.len == 0:
      return

  # set assetsLoading to true as the tokens are being loaded
  for waddress in accounts:
    self.updateAssetsLoadingState(waddress, true)

  var uniqueAddresses: HashSet[string] = toHashSet(accounts)
  let arg = BuildTokensTaskArg(
    tptr: prepareTokensTask,
    vptr: cast[uint](self.vptr),
    slot: "onAllTokensBuilt",
    accounts: toSeq(uniqueAddresses),
    forceRefresh: forceRefresh
  )
  self.threadpool.start(arg)

proc buildAllTokens*(self: Service, accounts: seq[string], forceRefresh: bool) =
  self.buildTokensDebouncer.call(accounts, forceRefresh)

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

proc getGroupedAssetsList*(self: Service): CowSeq[AssetGroupItem] =
  ## Returns a CoW snapshot of the grouped assets.  Callers receive their
  ## own ref onto the shared backing buffer (O(1) refcount bump).  The
  ## buffer is replaced wholesale by onAllTokensBuilt, so a stale snapshot
  ## remains valid until the caller explicitly pulls a fresh one.
  return self.groupedAssets

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

proc reloadAccountTokens*(self: Service) =
  try:
    discard backend.restartWalletReloadTimer()
  except Exception as e:
    let errDesription = e.msg
    error "error restartWalletReloadTimer: ", errDesription

  let addresses = self.getWalletAddresses()
  self.buildAllTokens(addresses, forceRefresh = true)

  try:
    discard collectibles.refetchOwnedCollectibles()
  except Exception as e:
    let errDesription = e.msg
    error "error refetchOwnedCollectibles: ", errDesription

proc getCurrencyValueForToken*(self: Service, tokenKey: string, amountInt: UInt256): float64 =
  return self.currencyService.getCurrencyValueForToken(tokenKey, amountInt)

proc getCurrencyFormat*(self: Service, key: string): CurrencyFormatDto =
  return self.currencyService.getCurrencyFormat(key)
