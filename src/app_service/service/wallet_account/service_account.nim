  proc storeWatchOnlyAccount(self: Service, account: WalletAccountDto) =
    if self.watchOnlyAccounts.hasKey(account.address):
      error "trying to store an already existing watch only account"
      return
    self.watchOnlyAccounts[account.address] = account

proc storeKeypair(self: Service, keypair: KeypairDto) =
  if keypair.keyUid.len == 0:
    error "trying to store a keypair with empty keyUid"
    return
  if self.keypairs.hasKey(keypair.keyUid):
    error "trying to store an already existing keypair"
    return
  self.keypairs[keypair.keyUid] = keypair

# replaces only keypair/accounts fields that could be changed
proc replaceKeypair(self: Service, keypair: KeypairDto) =
  if keypair.keyUid.len == 0:
    error "trying to replace a keypair with empty keyUid"
    return
  if not self.keypairs.hasKey(keypair.keyUid):
    error "trying to replace a non existing keypair"
    return
  var localKp = self.keypairs[keypair.keyUid]
  localKp.name = keypair.name
  localKp.lastUsedDerivationIndex = keypair.lastUsedDerivationIndex
  localKp.syncedFrom = keypair.syncedFrom
  localKp.removed = keypair.removed
  localKp.keycards = keypair.keycards
  for locAcc in localKp.accounts:
    for acc in keypair.accounts:
      if cmpIgnoreCase(locAcc.address, acc.address) != 0:
        continue
      locAcc.name = acc.name
      locAcc.colorId = acc.colorId
      locAcc.emoji = acc.emoji
      locAcc.operable = acc.operable
      locAcc.removed = acc.removed
      break

proc storeAccountToKeypair(self: Service, account: WalletAccountDto) =
  if account.keyUid.len == 0:
    error "trying to store a keypair related account with empty keyUid"
    return
  if self.keypairs[account.keyUid].accounts.filter(acc => cmpIgnoreCase(acc.address, account.address) == 0).len != 0:
    error "trying to store an already existing keytpair related account"
    return
  self.keypairs[account.keyUid].accounts.add(account)

proc getKeypairs*(self: Service): seq[KeypairDto] =
  return toSeq(self.keypairs.values)

proc getKeypairByKeyUid*(self: Service, keyUid: string): KeypairDto =
  if not self.keypairs.hasKey(keyUid):
    return
  return self.keypairs[keyUid]

# This one should be used in a very rare cases, when we need to get keypair from db before service is initialized
proc getKeypairByKeyUidFromDb*(self: Service, keyUid: string): KeypairDto =
  return getKeypairByKeyUidFromDb(keyUid)

proc getKeypairByAccountAddress*(self: Service, address: string): KeypairDto =
  for _, kp in self.keypairs:
    for acc in kp.accounts:
      if cmpIgnoreCase(acc.address, address) == 0:
        return kp

proc getWatchOnlyAccounts*(self: Service): seq[WalletAccountDto] =
  return toSeq(self.watchOnlyAccounts.values)

proc getWatchOnlyAccountByAddress*(self: Service, address: string): WalletAccountDto =
  if not self.watchOnlyAccounts.hasKey(address):
    return
  return self.watchOnlyAccounts[address]

proc getAccountByAddress*(self: Service, address: string): WalletAccountDto =
  result = self.getWatchOnlyAccountByAddress(address)
  if not result.isNil:
    return
  for _, kp in self.keypairs:
    let accounts = kp.accounts.filter(acc => cmpIgnoreCase(acc.address, address) == 0)
    if accounts.len == 1:
      return accounts[0]

proc getAccountsByAddresses*(self: Service, addresses: seq[string]): seq[WalletAccountDto] =
  for address in addresses:
    let acc = self.getAccountByAddress(address)
    if acc.isNil:
      continue
    result.add(acc)

proc getWalletAccounts*(self: Service, excludeWatchOnly: bool = false): seq[WalletAccountDto] =
  for _, kp in self.keypairs:
    if kp.keypairType == KeypairTypeProfile:
      for acc in kp.accounts:
        if acc.isChat:
          continue
        result.add(acc)
      continue
    result.add(kp.accounts)
  if not excludeWatchOnly:
    result.add(toSeq(self.watchOnlyAccounts.values))
  result.sort(walletAccountsCmp)

proc getWalletAddresses*(self: Service): seq[string] =
  return self.getWalletAccounts().map(a => a.address)

proc updateAssetsLoadingState(self: Service, address: string, loading: bool) =
  var acc = self.getAccountByAddress(address)
  if acc.isNil:
    return
  acc.assetsLoading = loading

#################################################
# TODO: remove functions below
#
# The only need for a function `getIndex` below is for switching selected account.
# Switching an account in UI by the index on which an account is stored in wallet settings service cache
# is completely wrong approach we need to handle that properly, at least by using position.
proc getIndex*(self: Service, address: string): int =
  let accounts = self.getWalletAccounts()
  for i in 0 ..< accounts.len:
    if cmpIgnoreCase(accounts[i].address, address) == 0:
      return i
# The same for `getWalletAccount`, both of them need to be removed. Parts of the app which are using them
# need refactor for sure.
proc getWalletAccount*(self: Service, accountIndex: int): WalletAccountDto =
  let accounts = self.getWalletAccounts()
  if accountIndex < 0 or accountIndex >= accounts.len:
    return
  return accounts[accountIndex]
#################################################

proc startWallet(self: Service) =
  if(not main_constants.WALLET_ENABLED):
    return
  discard backend.startWallet()

proc init*(self: Service) =
  try:
    self.buildTokensDebouncer = debouncer_service.newDebouncer(
      self.threadpool,
      # this is the delay before the first call to the callback, this is an action that doesn't need to be called immediately, but it's pretty expensive in terms of time/performances
      # for example `wallet-tick-reload` event is emitted for every single chain-account pair, and at the app start can be more such signals received from the statusgo side if the balance have changed.
      # Means it the app contains more accounts the likelihood of having more `wallet-tick-reload` signals is higher, so we need to delay the rebuildMarketData call to avoid unnecessary calls.
      delayMs = 1000,
      checkIntervalMs = 500)
    self.buildTokensDebouncer.registerCall2(callback = proc(accounts: seq[string], forceRefresh: bool) = self.buildAllTokensInternal(accounts, forceRefresh))

    var addressesToGetENSName: seq[string] = @[]
    let chainId = self.networkService.getAppNetwork().chainId
    let woAccounts = getWatchOnlyAccountsFromDb()
    for acc in woAccounts:
      addressesToGetENSName.add(acc.address)
      self.storeWatchOnlyAccount(acc)
    let keypairs = getKeypairsFromDb()
    for kp in keypairs:
      for acc in kp.accounts:
        addressesToGetENSName.add(acc.address)
      self.storeKeypair(kp)

    self.fetchENSNamesForAddressesAsync(addressesToGetENSName, chainId)

    let addresses = self.getWalletAddresses()
    self.startWallet()
  except Exception as e:
    let errDesription = e.msg
    error "error: ", errDesription
    return

  self.events.on(SignalType.Message.event) do(e: Args):
    var receivedData = MessageSignal(e)
    if receivedData.watchOnlyAccounts.len > 0:
      for acc in receivedData.watchOnlyAccounts:
        self.handleWalletAccount(acc)
    if receivedData.keypairs.len > 0:
      for kp in receivedData.keypairs:
        self.handleKeypair(kp)
    if receivedData.accountsPositions.len > 0:
      self.updateAccountsPositions()
      self.events.emit(SIGNAL_WALLET_ACCOUNT_POSITION_UPDATED, Args())

  self.events.on(SignalType.Wallet.event) do(e:Args):
    var data = WalletSignal(e)
    case data.eventType:
      of "wallet-tick-reload":
        let addresses = self.getWalletAddresses()
        self.buildAllTokens(addresses, forceRefresh = true)
      of EventWatchOnlyAccountRetrieved:
        var watchOnlyAccountPayload: JsonNode
        try:
          watchOnlyAccountPayload = data.message.parseJson
          let account = watchOnlyAccountPayload["WatchOnlyAccount"].toWalletAccountDto()
          self.handleWalletAccount(account)
        except CatchableError:
          return

  self.events.on(SIGNAL_CURRENCY_UPDATED) do(e:Args):
    self.buildAllTokens(self.getWalletAddresses(), forceRefresh = false)

  self.events.on(SIGNAL_TOKENS_LIST_UPDATED) do(e:Args):
    self.buildAllTokens(self.getWalletAddresses(), forceRefresh = false)

  self.events.on(SIGNAL_PASSWORD_PROVIDED) do(e: Args):
    let args = AuthenticationArgs(e)
    self.cleanKeystoreFiles(args.password)
    self.importPartiallyOperableAccounts(args.keyUid, args.password)

  let addresses = self.getWalletAddresses()
  self.buildAllTokens(addresses, forceRefresh = true)

proc addNewKeypairsAccountsToLocalStoreAndNotify(self: Service, notify: bool = true) =
  var addressesToFetchBalanceFor: seq[string] = @[]
  let chainId = self.networkService.getAppNetwork().chainId
  let allLocalAaccounts = self.getWalletAccounts()
  # check if there is new watch only account
  let woAccountsDb = getWatchOnlyAccountsFromDb()
  for woAccDb in woAccountsDb:
    var found = false
    for localAcc in allLocalAaccounts:
      if cmpIgnoreCase(localAcc.address, woAccDb.address) == 0:
        found = true
        break
    if found:
      continue
    self.storeWatchOnlyAccount(woAccDb)
    self.fetchENSNamesForAddressesAsync(@[woAccDb.address], chainId)
    addressesToFetchBalanceFor.add(woAccDb.address)
    if notify:
      self.events.emit(SIGNAL_WALLET_ACCOUNT_SAVED, AccountArgs(account: woAccDb))
  # check if there is new keypair or any account added to an existing keypair
  let keypairsDb = getKeypairsFromDb()
  for kpDb in keypairsDb:
    var localKp = self.getKeypairByKeyUid(kpDb.keyUid)
    if localKp.isNil:
      self.storeKeypair(kpDb)
      let addresses = kpDb.accounts.map(a => a.address)
      self.fetchENSNamesForAddressesAsync(addresses, chainId)
      addressesToFetchBalanceFor.add(addresses)
      for acc in kpDb.accounts:
        if acc.isChat:
          continue
        if notify:
          self.events.emit(SIGNAL_WALLET_ACCOUNT_SAVED, AccountArgs(account: acc))
    else:
      for accDb in kpDb.accounts:
        var found = false
        for localAcc in allLocalAaccounts:
          if cmpIgnoreCase(localAcc.address, accDb.address) == 0:
            found = true
            break
        if found:
          continue
        self.storeAccountToKeypair(accDb)
        self.fetchENSNamesForAddressesAsync(@[accDb.address], chainId)
        if accDb.isChat:
          continue
        addressesToFetchBalanceFor.add(accDb.address)
        if notify:
          self.events.emit(SIGNAL_WALLET_ACCOUNT_SAVED, AccountArgs(account: accDb))
  self.buildAllTokens(addressesToFetchBalanceFor, forceRefresh = true)

proc removeAccountFromLocalStoreAndNotify(self: Service, address: string, notify: bool = true) =
  var acc = self.getAccountByAddress(address)
  if acc.isNil:
    return
  if acc.keyUid.len == 0:
    self.watchOnlyAccounts.del(acc.address)
  else:
    var index = -1
    for i in 0 ..< self.keypairs[acc.keyUid].accounts.len:
      if cmpIgnoreCase(self.keypairs[acc.keyUid].accounts[i].address, acc.address) == 0:
        index = i
        break
    if index == -1:
      error "cannot find account with the address to remove", address=address
      return
    self.keypairs[acc.keyUid].accounts.del(index)
    if self.keypairs[acc.keyUid].accounts.len == 0:
      self.keypairs.del(acc.keyUid)
  if notify:
    self.events.emit(SIGNAL_WALLET_ACCOUNT_DELETED, AccountArgs(account: acc))

proc updateKeypairOperabilityInLocalStoreAndNotify*(self: Service, importedKeyUids: seq[string]) =
  var updatedKeypairs: seq[KeypairDto]
  let localKeypairs = self.getKeypairs()
  for keyUid in importedKeyUids:
    var foundKp: KeypairDto = nil
    for kp in localKeypairs:
      if keyUid == kp.keyUid:
        foundKp = kp
        break
    if foundKp.isNil:
      error "there is no known keypair", keyUid=keyUid, procName="updateKeypairOperabilityInLocalStoreAndNotify"
      return
    for acc in foundKp.accounts:
      acc.operable = AccountFullyOperable
    updatedKeypairs.add(foundKp)
  if updatedKeypairs.len == 0:
    return
  self.events.emit(SIGNAL_IMPORTED_KEYPAIRS, KeypairsArgs(keypairs: updatedKeypairs))

proc updateAccountsPositions(self: Service) =
  let dbAccounts = getAccountsFromDb()
  for dbAcc in dbAccounts:
    var localAcc = self.getAccountByAddress(dbAcc.address)
    if localAcc.isNil:
      continue
    localAcc.position = dbAcc.position

proc updateAccountInLocalStoreAndNotify(self: Service, address, name, colorId, emoji: string, ensName: string = "",
  operable: string = "", positionUpdated: Option[bool] = none(bool), notify: bool = true) =
  if address.len > 0:
    var account = self.getAccountByAddress(address)
    if account.isNil:
      return
    if name.len > 0 or colorId.len > 0 or emoji.len > 0 or operable.len > 0 or ensName.len > 0:
      if name.len > 0 and name != account.name:
        account.name = name
      if colorId.len > 0 and colorId != account.colorId:
        account.colorId = colorId
      if emoji.len > 0 and emoji != account.emoji:
        account.emoji = emoji
      if ensName.len > 0 and ensName != account.ens:
        account.ens = ensName
      if operable.len > 0 and operable != account.operable and
        (operable == AccountNonOperable or operable == AccountPartiallyOperable or operable == AccountFullyOperable):
          account.operable = operable
      if notify:
        self.events.emit(SIGNAL_WALLET_ACCOUNT_UPDATED, AccountArgs(account: account))
  else:
    if not positionUpdated.isSome:
      return
    if positionUpdated.get:
      ## if reordering was successfully stored, we need to update local storage
      self.updateAccountsPositions()
    if notify:
      self.events.emit(SIGNAL_WALLET_ACCOUNT_POSITION_UPDATED, Args())

## if password is not provided local keystore file won't be created
proc addWalletAccount*(self: Service, password: string, doPasswordHashing: bool, name, address, path, publicKey,
  keyUid, accountType, colorId, emoji: string, hideFromTotalBalance: bool): string =
  try:
    var response: RpcResponse[JsonNode]
    if password.len == 0:
      response = status_go_accounts.addAccountWithoutKeystoreFileCreation(name, address, path, publicKey, keyUid,
        accountType, colorId, emoji, hideFromTotalBalance)
    else:
      var finalPassword = password
      if doPasswordHashing:
        finalPassword = utils.hashPassword(password)
      response = status_go_accounts.addAccount(finalPassword, name, address, path, publicKey, keyUid, accountType,
        colorId, emoji, hideFromTotalBalance)
    if not response.error.isNil:
      error "status-go error", procName="addWalletAccount", errCode=response.error.code, errDesription=response.error.message
      return response.error.message
    self.addNewKeypairsAccountsToLocalStoreAndNotify()
    return ""
  except Exception as e:
    error "error: ", procName="addWalletAccount", errName=e.name, errDesription=e.msg
    return e.msg

## Mandatory fields for account: `path`, `name`, `emoji`, `colorId`
proc addNewPrivateKeyKeypair*(self: Service, privateKey, password: string, doPasswordHashing: bool,
  keypairName: string, accountCreationDetails: AccountCreationDetails): string =
  if password.len == 0:
    let err = "for adding new private key account, password must be provided"
    error "error", err
    return err
  var finalPassword = password
  if doPasswordHashing:
    finalPassword = utils.hashPassword(password)
  try:
    var response = status_go_accounts.addKeypairViaPrivateKey(privateKey, finalPassword, keypairName, accountCreationDetails)
    if not response.error.isNil:
      error "status-go error adding keypair", procName="addNewPrivateKeyKeypair", errCode=response.error.code, errDesription=response.error.message
      return response.error.message
    self.addNewKeypairsAccountsToLocalStoreAndNotify()
    return ""
  except Exception as e:
    error "error: ", procName="addNewPrivateKeyKeypair", errName=e.name, errDesription=e.msg
    return e.msg

proc makePrivateKeyKeypairFullyOperable*(self: Service, keyUid, privateKey, password: string, doPasswordHashing: bool): string =
  if password.len == 0:
    let err = "for making a private key keypair fully operable, password must be provided"
    error "error", err
    return err
  var finalPassword = password
  if doPasswordHashing:
    finalPassword = utils.hashPassword(password)
  try:
    var response = status_go_accounts.makePrivateKeyKeypairFullyOperable(privateKey, finalPassword)
    if not response.error.isNil:
      error "status-go error", procName="makePrivateKeyKeypairFullyOperable", errCode=response.error.code, errDesription=response.error.message
      return response.error.message
    self.updateKeypairOperabilityInLocalStoreAndNotify(@[keyUid])
    return ""
  except Exception as e:
    error "error: ", procName="makePrivateKeyKeypairFullyOperable", errName=e.name, errDesription=e.msg
    return e.msg

## Mandatory fields for all accounts are `path`, `name`, `emoji`, `colorId`
proc addNewSeedPhraseKeypair*(self: Service, seedPhrase, password: string, doPasswordHashing: bool,
  keypairName: string, accountCreationDetails: AccountCreationDetails): string =
  var finalPassword = password
  if password.len > 0 and doPasswordHashing:
    finalPassword = utils.hashPassword(password)
  try:
    var response = status_go_accounts.addKeypairViaSeedPhrase(seedPhrase, finalPassword, keypairName, accountCreationDetails)
    if not response.error.isNil:
      error "status-go error adding keypair", procName="addNewSeedPhraseKeypair", errCode=response.error.code, errDesription=response.error.message
      return response.error.message

    self.addNewKeypairsAccountsToLocalStoreAndNotify()
    return ""
  except Exception as e:
    error "error: ", procName="addNewSeedPhraseKeypair", errName=e.name, errDesription=e.msg
    return e.msg

proc addNewKeycardStoredKeypair*(self: Service, keyUid, keypairName, rootWalletMasterKey: string, accounts: seq[WalletAccountDto]): string =
  try:
    var response = status_go_accounts.addKeypairStoredToKeycard(keyUid, rootWalletMasterKey, keypairName, accounts)
    if not response.error.isNil:
      error "status-go error adding keypair", procName="addNewKeycardStoredKeypair", errCode=response.error.code, errDesription=response.error.message
      return response.error.message

    for i in 0 ..< accounts.len:
      self.addNewKeypairsAccountsToLocalStoreAndNotify()
    return ""
  except Exception as e:
    error "error: ", procName="addNewKeycardStoredKeypair", errName=e.name, errDesription=e.msg
    return e.msg

proc makeSeedPhraseKeypairFullyOperable*(self: Service, keyUid, mnemonic, password: string, doPasswordHashing: bool): string =
  if password.len == 0:
    let err = "for making a private key keypair fully operable, password must be provided"
    error "error", err
    return err
  var finalPassword = password
  if doPasswordHashing:
    finalPassword = utils.hashPassword(password)
  try:
    var response = status_go_accounts.makeSeedPhraseKeypairFullyOperable(mnemonic, finalPassword)
    if not response.error.isNil:
      error "status-go error", procName="makeSeedPhraseKeypairFullyOperable", errCode=response.error.code, errDesription=response.error.message
      return response.error.message
    self.updateKeypairOperabilityInLocalStoreAndNotify(@[keyUid])
    return ""
  except Exception as e:
    error "error: ", procName="makeSeedPhraseKeypairFullyOperable", errName=e.name, errDesription=e.msg
    return e.msg

proc makePartiallyOperableAccoutsFullyOperable(self: Service, password: string, doPasswordHashing: bool) =
  if password.len == 0:
    error "for making partially operable accounts a fully operable, password must be provided"
    return
  var finalPassword = password
  if doPasswordHashing:
    finalPassword = utils.hashPassword(password)
  try:
    var response = status_go_accounts.makePartiallyOperableAccoutsFullyOperable(finalPassword)
    if not response.error.isNil:
      error "status-go error", procName="makePartiallyOperableAccoutsFullyOperable", errCode=response.error.code, errDesription=response.error.message
      return
    let affectedAccounts = map(response.result.getElems(), x => x.getStr())
    for acc in affectedAccounts:
      self.updateAccountInLocalStoreAndNotify(acc, name = "", colorId = "", emoji = "", ensName = "", operable = AccountFullyOperable)
  except Exception as e:
    error "error: ", procName="makeSeedPhraseKeypairFullyOperable", errName=e.name, errDesription=e.msg

proc cleanKeystoreFiles(self: Service, password: string) =
  if password.len == 0:
    error "for making partially operable accounts a fully operable, password must be provided"
    return
  var finalPassword = password
  if not singletonInstance.userProfile.getIsKeycardUser():
    finalPassword = utils.hashPassword(password)
  try:
    var response = status_go_accounts.cleanKeystoreFiles(finalPassword)
    if not response.error.isNil:
      error "status-go error", procName="cleanKeystoreFiles", errCode=response.error.code, errDesription=response.error.message
  except Exception as e:
    error "error: ", procName="makeSeedPhraseKeypairFullyOperable", errName=e.name, errDesription=e.msg

proc onNonProfileKeycardKeypairMigratedToApp*(self: Service, response: string) {.slot.} =
  var data = KeycardArgs(
    success: false,
    keycard: KeycardDto()
  )
  try:
    let responseObj = response.parseJson
    discard responseObj.getProp("success", data.success)
    discard responseObj.getProp("keyUid", data.keycard.keyUid)
    let kp = self.getKeypairByKeyUid(data.keycard.keyUid)
    if kp.isNil:
      data.success = false
    else:
      kp.keycards = @[]
  except Exception as e:
    error "error handling migrated keycard response", errDesription=e.msg
  self.events.emit(SIGNAL_ALL_KEYCARDS_DELETED, data)

proc migrateNonProfileKeycardKeypairToAppAsync*(self: Service, keyUid, seedPhrase, password: string, doPasswordHashing: bool) =
  var finalPassword = password
  if doPasswordHashing:
    finalPassword = utils.hashPassword(password)
  let arg = MigrateNonProfileKeycardKeypairToAppTaskArg(
    tptr: migrateNonProfileKeycardKeypairToAppTask,
    vptr: cast[uint](self.vptr),
    slot: "onNonProfileKeycardKeypairMigratedToApp",
    keyUid: keyUid,
    seedPhrase: seedPhrase,
    password: finalPassword
  )
  self.threadpool.start(arg)

proc onENSNamesFetched*(self: Service, response: string) {.slot.} =
  try:
    let responseObj = response.parseJson
    if responseObj{"error"}.kind != JNull and responseObj{"error"}.getStr != "":
      raise newException(CatchableError, responseObj["error"].getStr)
    for address, name in responseObj["result"].pairs:
      let ensName = name.getStr
      if ensName.len == 0:
        continue
      self.updateAccountInLocalStoreAndNotify(address, name = "", colorId = "", emoji = "", ensName)
  except Exception as e:
    error "error getting ENS names for accounts", errDesription=e.msg

proc fetchENSNamesForAddressesAsync(self: Service, addresses: seq[string], chainId: int) =
  let arg = FetchENSNamesForAddressesTaskArg(
    tptr: fetchENSNamesForAddressesTask,
    vptr: cast[uint](self.vptr),
    slot: "onENSNamesFetched",
    addresses: addresses,
    chainId: chainId
  )
  self.threadpool.start(arg)

proc getRandomMnemonic*(self: Service): string =
  try:
    let response = status_go_accounts.getRandomMnemonic()
    if not response.error.isNil:
      error "status-go error", procName="getRandomMnemonic", errCode=response.error.code, errDesription=response.error.message
      return ""
    return response.result.getStr
  except Exception as e:
    error "error: ", procName="getRandomMnemonic", errName=e.name, errDesription=e.msg
    return ""

proc deleteAccount*(self: Service, address: string, password: string) =
  try:
    var finalPassword = password
    if not singletonInstance.userProfile.getIsKeycardUser():
      finalPassword = utils.hashPassword(password)
    let response = status_go_accounts.deleteAccount(address, finalPassword)
    if not response.error.isNil:
      error "status-go error", procName="deleteAccount", errCode=response.error.code, errDesription=response.error.message
      return
    self.removeAccountFromLocalStoreAndNotify(address)
  except Exception as e:
    error "error: ", procName="deleteAccount", errName = e.name, errDesription = e.msg

proc deleteKeypair*(self: Service, keyUid: string, password: string) =
  try:
    let kp = self.getKeypairByKeyUid(keyUid)
    if kp.isNil:
      error "there is no known keypair", keyUid=keyUid, procName="deleteKeypair"
      return
    var finalPassword = password
    if not singletonInstance.userProfile.getIsKeycardUser():
      finalPassword = utils.hashPassword(password)
    let response = status_go_accounts.deleteKeypair(keyUid, finalPassword)
    if not response.error.isNil:
      error "status-go error", procName="deleteKeypair", errCode=response.error.code, errDesription=response.error.message
      return
    self.updateAccountsPositions()
    let addresses = kp.accounts.map(a => a.address)
    for address in addresses:
      self.removeAccountFromLocalStoreAndNotify(address)
    self.events.emit(SIGNAL_KEYPAIR_DELETED, KeypairArgs(keyPairName: kp.name))
  except Exception as e:
    error "error: ", procName="deleteKeypair", errName = e.name, errDesription = e.msg

proc updateCurrency*(self: Service, newCurrency: string) =
  discard self.settingsService.saveCurrency(newCurrency)

proc setNetworksState*(self: Service, chainIds: seq[int], enabled: bool) =
  self.networkService.setNetworksState(chainIds, enabled)
  self.events.emit(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED, Args())

proc setNetworkActive*(self: Service, chainId: int, active: bool) =
  self.networkService.setNetworkActive(chainId, active)
  # TODO: This should be some common response to network changes
  let addresses = self.getWalletAddresses()
  self.buildAllTokens(addresses, forceRefresh = true)
  self.events.emit(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED, Args())

proc toggleTestNetworksEnabled*(self: Service) =
  discard self.settingsService.toggleTestNetworksEnabled()
  let addresses = self.getWalletAddresses()
  self.buildAllTokens(addresses, forceRefresh = true)
  self.events.emit(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED, Args())

proc updateWalletAccount*(self: Service, address: string, accountName: string, colorId: string, emoji: string): bool =
  try:
    var account = self.getAccountByAddress(address)
    if account.isNil:
      error "account's address is not among known addresses: ", address=address, procName="updateWalletAccount"
      return false
    let response = status_go_accounts.updateAccount(accountName, account.address, account.path, account.publicKey,
      account.keyUid, account.walletType, colorId, emoji, account.isWallet, account.isChat, account.hideFromTotalBalance)
    if not response.error.isNil:
      error "status-go error", procName="updateWalletAccount", errCode=response.error.code, errDesription=response.error.message
      return false
    self.updateAccountInLocalStoreAndNotify(address, accountName, colorId, emoji)
    return true
  except Exception as e:
    error "error: ", procName="updateWalletAccount", errName=e.name, errDesription=e.msg
  return false

proc updateWatchAccountHiddenFromTotalBalance*(self: Service, address: string, hideFromTotalBalance: bool): bool =
  try:
    var account = self.getAccountByAddress(address)
    if account.isNil:
      error "account's address is not among known addresses: ", address=address, procName="updateWatchAccountHiddenFromTotalBalance"
      return false
    let response = status_go_accounts.updateAccount(account.name, account.address, account.path, account.publicKey,
      account.keyUid, account.walletType, account.colorId, account.emoji, account.isWallet, account.isChat, hideFromTotalBalance)
    if not response.error.isNil:
      error "status-go error", procName="updateWatchAccountHiddenFromTotalBalance", errCode=response.error.code, errDesription=response.error.message
      return false
    if hideFromTotalBalance != account.hideFromTotalBalance:
      account.hideFromTotalBalance = hideFromTotalBalance
    self.events.emit(SIGNAL_WALLET_ACCOUNT_HIDDEN_UPDATED, AccountArgs(account: account))
    return true
  except Exception as e:
    error "error: ", procName="updateWatchAccountHiddenFromTotalBalance", errName=e.name, errDesription=e.msg
  return false

proc moveAccountFinally*(self: Service, fromPosition: int, toPosition: int) =
  var updated = false
  try:
    let response = backend.moveWalletAccount(fromPosition, toPosition)
    if not response.error.isNil:
      error "status-go error", procName="moveAccountFinally", errCode=response.error.code, errDesription=response.error.message
    updated = true
  except Exception as e:
    error "error: ", procName="moveAccountFinally", errName=e.name, errDesription=e.msg
  self.updateAccountInLocalStoreAndNotify(address = "", name = "", colorId = "", emoji = "", ensName = "", operable = "", some(updated))

proc updateKeypairName*(self: Service, keyUid: string, name: string) =
  try:
    let kp = self.getKeypairByKeyUid(keyUid)
    if kp.isNil:
      error "there is no known keypair", keyUid=keyUid, procName="updateKeypairName"
      return
    let response = backend.updateKeypairName(keyUid, name)
    if not response.error.isNil:
      error "status-go error", procName="updateKeypairName", errCode=response.error.code, errDesription=response.error.message
      return
    var data = KeypairArgs(
      keypair: KeypairDto(
        keyUid: keyUid,
        name: name
        ),
      oldKeypairName: kp.name
      )
    kp.name = name
    self.events.emit(SIGNAL_KEYPAIR_NAME_CHANGED, data)
  except Exception as e:
    error "error: ", procName="updateKeypairName", errName=e.name, errDesription=e.msg

proc fetchDerivedAddresses*(self: Service, password: string, derivedFrom: string, paths: seq[string], hashPassword: bool) =
  let arg = FetchDerivedAddressesTaskArg(
    password: if hashPassword: utils.hashPassword(password) else: password,
    derivedFrom: derivedFrom,
    paths: paths,
    tptr: fetchDerivedAddressesTask,
    vptr: cast[uint](self.vptr),
    slot: "onDerivedAddressesFetched",
  )
  self.threadpool.start(arg)

proc onDerivedAddressesFetched*(self: Service, jsonString: string) {.slot.} =
  let response = parseJson(jsonString)
  var derivedAddress: seq[DerivedAddressDto] = @[]
  derivedAddress = response["derivedAddresses"].getElems().map(x => x.toDerivedAddressDto())
  let error = response["error"].getStr()
  self.events.emit(SIGNAL_WALLET_ACCOUNT_DERIVED_ADDRESSES_FETCHED, DerivedAddressesArgs(
    derivedAddresses: derivedAddress,
    error: error
  ))

proc fetchDerivedAddressesForMnemonic*(self: Service, mnemonic: string, paths: seq[string])=
  let arg = FetchDerivedAddressesForMnemonicTaskArg(
    mnemonic: mnemonic,
    paths: paths,
    tptr: fetchDerivedAddressesForMnemonicTask,
    vptr: cast[uint](self.vptr),
    slot: "onDerivedAddressesForMnemonicFetched",
  )
  self.threadpool.start(arg)

proc onDerivedAddressesForMnemonicFetched*(self: Service, jsonString: string) {.slot.} =
  let response = parseJson(jsonString)
  var derivedAddress: seq[DerivedAddressDto] = @[]
  derivedAddress = response["derivedAddresses"].getElems().map(x => x.toDerivedAddressDto())
  let error = response["error"].getStr()
  self.events.emit(SIGNAL_WALLET_ACCOUNT_DERIVED_ADDRESSES_FROM_MNEMONIC_FETCHED, DerivedAddressesArgs(
    derivedAddresses: derivedAddress,
    error: error
  ))

proc fetchDetailsForAddress(self: Service, uniqueId: string, address: string) =
  let network = self.networkService.getAppNetwork()
  let arg = FetchDetailsForAddressTaskArg(
    uniqueId: uniqueId,
    address: address,
    tptr: fetchDetailsForAddressTask,
    vptr: cast[uint](self.vptr),
    slot: "onAddressDetailsFetched",
  )
  self.threadpool.start(arg)

proc fetchDetailsForAddresses*(self: Service, uniqueId: string, addresses: seq[string]) =
  var data = DerivedAddressesArgs()
  for address in addresses:
    try:
      let response = status_go_accounts.addressExists(address)
      if not response.error.isNil:
        data.error = response.error.message
        raise newException(CatchableError, response.error.message)
      let alreadyAdded = response.result.getBool
      data.derivedAddresses.add(DerivedAddressDto(address: address, alreadyCreated: alreadyAdded))
      if not alreadyAdded:
        self.fetchDetailsForAddress(uniqueId, address)
    except Exception as e:
      error "error: ", procName="fetchDetailsForAddresses", errName=e.name, errDesription=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_WALLET_ACCOUNT_ADDRESS_ALREADY_ADDED_FETCHED, data)

proc onAddressDetailsFetched*(self: Service, jsonString: string) {.slot.} =
  var data = DerivedAddressesArgs()
  try:
    let response = parseJson(jsonString)
    data.uniqueId = response["uniqueId"].getStr()
    let addrDto = response{"details"}.toDerivedAddressDto()
    data.derivedAddresses.add(addrDto)
    data.error = response["error"].getStr()
  except Exception as e:
    error "error: ", procName="fetchAddressDetails", errName = e.name, errDesription = e.msg
    data.error = e.msg
  self.events.emit(SIGNAL_WALLET_ACCOUNT_ADDRESS_DETAILS_FETCHED, data)

proc handleWalletAccount(self: Service, account: WalletAccountDto, notify: bool = true) =
  if account.removed:
    self.updateAccountsPositions()
    self.removeAccountFromLocalStoreAndNotify(account.address, notify)
  else:
    var localAcc = self.getAccountByAddress(account.address)
    if not localAcc.isNil:
      self.updateAccountInLocalStoreAndNotify(account.address, account.name, account.colorId, account.emoji,
        account.ens, account.operable, none(bool), notify)
    else:
      self.addNewKeypairsAccountsToLocalStoreAndNotify(notify)

proc handleKeypair(self: Service, keypair: KeypairDto) =
  let localKp = self.getKeypairByKeyUid(keypair.keyUid)
  if not localKp.isNil:
    # sotore only keypair fields which may change
    localKp.name = keypair.name
    localKp.lastUsedDerivationIndex = keypair.lastUsedDerivationIndex
    localKp.syncedFrom = keypair.syncedFrom
    localKp.keycards = keypair.keycards
    # - first remove removed accounts from the UI
    let addresses = localKp.accounts.map(a => a.address)
    for address in addresses:
      let accAddress = address
      if keypair.accounts.filter(a => cmpIgnoreCase(a.address, accAddress) == 0).len == 0:
        self.handleWalletAccount(WalletAccountDto(address: accAddress, removed: true), notify = false)
    # - second add/update new/existing accounts
    for acc in keypair.accounts:
      self.handleWalletAccount(acc, notify = false)
  else:
    self.addNewKeypairsAccountsToLocalStoreAndNotify(notify = false)

  # notify all interested parts about the keypair change
  self.events.emit(SIGNAL_KEYPAIR_SYNCED, KeypairArgs(keypair: keypair))

proc onFetchChainIdForUrl*(self: Service, jsonString: string) {.slot.} =
  let response = parseJson(jsonString)
  self.events.emit(SIGNAL_WALLET_ACCOUNT_CHAIN_ID_FOR_URL_FETCHED, ChainIdForUrlArgs(
    chainId: response{"chainId"}.getInt,
    success: response{"success"}.getBool,
    url: response{"url"}.getStr,
    isMainUrl: response{"isMainUrl"}.getBool
  ))

proc fetchChainIdForUrl*(self: Service, url: string, isMainUrl: bool) =
  let arg = FetchChainIdForUrlTaskArg(
    tptr: fetchChainIdForUrlTask,
    vptr: cast[uint](self.vptr),
    slot: "onFetchChainIdForUrl",
    url: url,
    isMainUrl: isMainUrl
  )
  self.threadpool.start(arg)

proc getEnabledChainIds*(self: Service): seq[int] =
  return self.networkService.getEnabledChainIds()

proc areTestNetworksEnabled*(self: Service): bool =
  return self.settingsService.areTestNetworksEnabled()

proc hasPairedDevices*(self: Service): bool =
  return hasPairedDevices()

proc importPartiallyOperableAccounts(self: Service, keyUid: string, password: string) =
  ## Whenever user provides a password/pin we need to make all partially operable accounts (if any exists) a fully operable.
  if  keyUid != singletonInstance.userProfile.getKeyUid():
    return
  self.makePartiallyOperableAccoutsFullyOperable(password, not singletonInstance.userProfile.getIsKeycardUser())

proc addressWasShown*(self: Service, address: string) =
  try:
    let response = status_go_accounts.addressWasShown(address)
    if not response.error.isNil:
      raise newException(CatchableError, response.error.message)
  except Exception as e:
    error "error: ", procName="addressWasShown", errName=e.name, errDesription=e.msg

proc getNumOfAddressesToGenerateForKeypair*(self: Service, keyUid: string): int =
  try:
    let response = status_go_accounts.getNumOfAddressesToGenerateForKeypair(keyUid)
    if not response.error.isNil:
      raise newException(CatchableError, response.error.message)
    return response.result.getInt
  except Exception as e:
    error "error: ", procName="getNumOfAddressesToGenerateForKeypair", errName=e.name, errDesription=e.msg

proc resolveSuggestedPathForKeypair*(self: Service, keyUid: string): string =
  try:
    let response = status_go_accounts.resolveSuggestedPathForKeypair(keyUid)
    if not response.error.isNil:
      raise newException(CatchableError, response.error.message)
    return response.result.getStr
  except Exception as e:
    error "error: ", procName="resolveSuggestedPathForKeypair", errName=e.name, errDesription=e.msg

proc remainingAccountCapacity*(self: Service): int =
  try:
    let response = status_go_accounts.remainingAccountCapacity()
    if not response.error.isNil:
      raise newException(CatchableError, response.error.message)
    return response.result.getInt
  except Exception as e:
    error "error: ", procName="remainingAccountCapacity", errName=e.name, errDesription=e.msg

proc remainingKeypairCapacity*(self: Service): int =
  try:
    let response = status_go_accounts.remainingKeypairCapacity()
    if not response.error.isNil:
      raise newException(CatchableError, response.error.message)
    return response.result.getInt
  except Exception as e:
    error "error: ", procName="remainingKeypairCapacity", errName=e.name, errDesription=e.msg

proc remainingWatchOnlyAccountCapacity*(self: Service): int =
  try:
    let response = status_go_accounts.remainingWatchOnlyAccountCapacity()
    if not response.error.isNil:
      raise newException(CatchableError, response.error.message)
    return response.result.getInt
  except Exception as e:
    error "error: ", procName="remainingWatchOnlyAccountCapacity", errName=e.name, errDesription=e.msg
