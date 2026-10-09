const noGasErrorCode = "WR-002"

proc applyAccountsBalances(self: Service, resultObj: JsonNode) =
  var grouped: GroupedBalances
  defer:
    self.events.emit(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT, TokensPerAccountArgs(
      accountAddresses: grouped.accounts,
      assets: grouped.assets,
      timestamp: getTime().toUnix()
    ))

  try:
    # Groups the account assets by crossChainId (or tokenKey if crossChainId is empty)
    grouped = groupAccountBalances(
      self.groupedAssets,
      resultObj,
      proc(key: string): TokenItem = self.tokenService.getTokenByKey(key),
      self.tokenService.areTokensOfInterestLoaded(),
      self.pendingBalances
    )
    for tokenKey in grouped.unknownTokenKeys:
      warn "error: ", procName="applyAccountsBalances", errName="received balance for an unknown token", tokenKey
    # set assetsLoading to false once the tokens are loaded
    for accountAddress in grouped.accounts:
      self.updateAssetsLoadingState(accountAddress, false)

    self.groupedAssets = grouped.assets
    if not grouped.allTokensHaveError:
      self.hasBalanceCache = true
  except Exception as e:
    error "error: ", procName="applyAccountsBalances", errName = e.name, errDesription = e.msg

proc onAllTokensBuilt(self: Service, response: string) {.slot.} =
  var resultObj: JsonNode
  try:
    discard response.parseJson.getProp("result", resultObj)
  except Exception as e:
    error "error: ", procName="onAllTokensBuilt", errName = e.name, errDesription = e.msg
  self.applyAccountsBalances(resultObj)

proc applyPendingBalances(self: Service) =
  if not self.pendingBalances.hasPending or not self.tokenService.areTokensOfInterestLoaded():
    return
  self.applyAccountsBalances(self.pendingBalances.takeAll())

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

proc getGroupedAssetsList*(self: Service): var seq[AssetGroupItem] =
  return self.groupedAssets

# Loading only until market values are cached; refreshes keep the last values.
proc getTokensMarketValuesLoading*(self: Service): bool =
  return self.tokenService.getTokensMarketValuesLoading() and not self.tokenService.getHasMarketValuesCache()

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
