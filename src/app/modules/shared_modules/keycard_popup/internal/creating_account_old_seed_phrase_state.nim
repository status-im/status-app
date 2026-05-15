type
  CreatingAccountOldSeedPhraseState* = ref object of State
    paths: seq[string]
    addresses: seq[string]

proc newCreatingAccountOldSeedPhraseState*(flowType: FlowType, backState: State): CreatingAccountOldSeedPhraseState =
  result = CreatingAccountOldSeedPhraseState()
  result.setup(flowType, StateType.CreatingAccountOldSeedPhrase, backState)

proc delete*(self: CreatingAccountOldSeedPhraseState) =
  self.State.delete

proc resolvePaths(self: CreatingAccountOldSeedPhraseState, controller: Controller) =
  let kpForProcessing = controller.getKeyPairForProcessing()
  var i = 0
  for account in kpForProcessing.getAccountsModel().getItems():
    account.setPath(PATH_WALLET_ROOT & "/" & $i)
    self.paths.add(account.getPath())
    i.inc

proc findIndexForPath(self: CreatingAccountOldSeedPhraseState, path: string): int =
  var ind = -1
  for p in self.paths:
    ind.inc
    if p == path:
      return ind
  return ind

proc resolveAddresses(self: CreatingAccountOldSeedPhraseState, controller: Controller, keycardEvent: KeycardEvent): bool =
  if keycardEvent.generatedWalletAccounts.len != self.paths.len:
    return false
  let kpForProcessing = controller.getKeyPairForProcessing()
  for account in kpForProcessing.getAccountsModel().getItems():
    let index = self.findIndexForPath(account.getPath())
    if index == -1:
      ## should never be here
      return false
    kpForProcessing.setDerivedFrom(keycardEvent.masterKeyAddress)
    account.setAddress(keycardEvent.generatedWalletAccounts[index].address)
    account.setPubKey(keycardEvent.generatedWalletAccounts[index].publicKey)
    self.addresses.add(keycardEvent.generatedWalletAccounts[index].address)
  return true

proc addAccountsToWallet(self: CreatingAccountOldSeedPhraseState, controller: Controller): bool =
  let kpForProcessing = controller.getKeyPairForProcessing()
  var walletAccounts: seq[WalletAccountDto]
  for account in kpForProcessing.getAccountsModel().getItems():
    walletAccounts.add(WalletAccountDto(
      address: account.getAddress(),
      keyUid: kpForProcessing.getKeyUid(),
      publicKey: account.getPubKey(),
      walletType: SEED,
      path: account.getPath(),
      name: account.getName(),
      colorId: account.getColorId(),
      emoji: account.getEmoji()
    ))
  return controller.addNewColdWalletStoredKeypair(
    keyUid = kpForProcessing.getKeyUid(),
    keypairName = kpForProcessing.getName(),
    walletXPub = "",
    coldWallet = ColdWalletTypeStatusKeycard,
    rootWalletMasterKey = kpForProcessing.getDerivedFrom(),
    accounts = walletAccounts
  )

proc doMigration(self: CreatingAccountOldSeedPhraseState, controller: Controller) =
  let kpForProcessing = controller.getKeyPairForProcessing()
  var kpDto = KeycardDto(keycardUid: controller.getKeycardUid(),
    keycardName: kpForProcessing.getName(),
    keycardLocked: false,
    accountsAddresses: self.addresses,
    keyUid: kpForProcessing.getKeyUid())
  controller.addKeycardOrAccounts(kpDto, password = "")

proc runStoreMetadataFlow(self: CreatingAccountOldSeedPhraseState, controller: Controller) =
  let kpForProcessing = controller.getKeyPairForProcessing()
  controller.runStoreMetadataFlow(kpForProcessing.getName(), controller.getPin(), self.paths)

method executePrePrimaryStateCommand*(self: CreatingAccountOldSeedPhraseState, controller: Controller) =
  if self.flowType == FlowType.SetupNewKeycardOldSeedPhrase:
    self.resolvePaths(controller)
    controller.runDeriveAccountFlow(bip44Paths = self.paths, controller.getPin())

method executePreTertiaryStateCommand*(self: CreatingAccountOldSeedPhraseState, controller: Controller) =
  ## Tertiary action is called after each async action during migration process, in this case after `addKeycardOrAccounts`.
  if self.flowType == FlowType.SetupNewKeycardOldSeedPhrase:
    if controller.getAddingMigratedKeypairSuccess():
      self.runStoreMetadataFlow(controller)

method getNextTertiaryState*(self: CreatingAccountOldSeedPhraseState, controller: Controller): State =
  if self.flowType == FlowType.SetupNewKeycardOldSeedPhrase:
    if not controller.getAddingMigratedKeypairSuccess():
      return createState(StateType.CreatingAccountOldSeedPhraseFailure, self.flowType, nil)

method resolveKeycardNextState*(self: CreatingAccountOldSeedPhraseState, keycardFlowType: string, keycardEvent: KeycardEvent,
  controller: Controller): State =
  let state = ensureReaderAndCardPresenceAndResolveNextState(self, keycardFlowType, keycardEvent, controller)
  if not state.isNil:
    return state
  if self.flowType == FlowType.SetupNewKeycardOldSeedPhrase:
    if controller.getCurrentKeycardServiceFlow() == KCSFlowType.ExportPublic:
        if keycardFlowType == ResponseTypeValueKeycardFlowResult and
          keycardEvent.error.len == 0:
            if not self.resolveAddresses(controller, keycardEvent):
              return createState(StateType.CreatingAccountOldSeedPhraseFailure, self.flowType, nil)
            if not self.addAccountsToWallet(controller):
              return createState(StateType.CreatingAccountOldSeedPhraseFailure, self.flowType, nil)
            self.doMigration(controller)
            return nil # returning nil, cause we need to remain in this state
    if controller.getCurrentKeycardServiceFlow() == KCSFlowType.StoreMetadata:
      if keycardFlowType == ResponseTypeValueKeycardFlowResult and
        keycardEvent.error.len == 0:
          return createState(StateType.CreatingAccountOldSeedPhraseSuccess, self.flowType, nil)
      return createState(StateType.CreatingAccountOldSeedPhraseFailure, self.flowType, nil)
