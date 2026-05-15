type
  ImportingFromKeycardState* = ref object of State
    paths: seq[string]
    addresses: seq[string]

proc newImportingFromKeycardState*(flowType: FlowType, backState: State): ImportingFromKeycardState =
  result = ImportingFromKeycardState()
  result.setup(flowType, StateType.ImportingFromKeycard, backState)

proc delete*(self: ImportingFromKeycardState) =
  self.State.delete

proc addAccountsToWallet(self: ImportingFromKeycardState, controller: Controller): bool =
  let kpForProcessing = controller.getKeyPairForProcessing()
  var walletAccounts: seq[WalletAccountDto]
  for account in kpForProcessing.getAccountsModel().getItems():
    self.addresses.add(account.getAddress())
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

proc doMigration(self: ImportingFromKeycardState, controller: Controller) =
  let kpForProcessing = controller.getKeyPairForProcessing()
  var kpDto = KeycardDto(keycardUid: controller.getKeycardUid(),
    keycardName: kpForProcessing.getName(),
    keycardLocked: false,
    accountsAddresses: self.addresses,
    keyUid: kpForProcessing.getKeyUid())
  controller.addKeycardOrAccounts(kpDto, password = "")

method getNextPrimaryState*(self: ImportingFromKeycardState, controller: Controller): State =
  if self.flowType == FlowType.ImportFromKeycard:
    if not self.addAccountsToWallet(controller):
      return createState(StateType.ImportingFromKeycardFailure, self.flowType, nil)
    self.doMigration(controller)
    return nil

method getNextTertiaryState*(self: ImportingFromKeycardState, controller: Controller): State =
  if self.flowType == FlowType.ImportFromKeycard:
    if controller.getAddingMigratedKeypairSuccess():
      return createState(StateType.ImportingFromKeycardSuccess, self.flowType, nil)
    return createState(StateType.ImportingFromKeycardFailure, self.flowType, nil)
