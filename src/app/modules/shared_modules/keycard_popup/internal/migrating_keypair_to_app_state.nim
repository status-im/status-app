type
  MigratingKeypairToAppState* = ref object of State
    migrationOk: bool

proc newMigratingKeypairToAppState*(flowType: FlowType, backState: State): MigratingKeypairToAppState =
  result = MigratingKeypairToAppState()
  result.setup(flowType, StateType.MigratingKeypairToApp, backState)

proc delete*(self: MigratingKeypairToAppState) =
  self.State.delete

method executePrePrimaryStateCommand*(self: MigratingKeypairToAppState, controller: Controller) =
  if self.flowType == FlowType.MigrateFromKeycardToApp:
    let sp = controller.getSeedPhrase()
    let password = controller.getPassword()
    let kpForProcessing = controller.getKeyPairForProcessing()
    let migratingProfile = controller.getKeyPairForProcessing().getKeyUid() == singletonInstance.userProfile.getKeyUid()
    if migratingProfile:
      let newPassword = controller.getNewPassword()
      if singletonInstance.localAccountSettings.getStoreToKeychainValue() == LS_VALUE_STORE:
        controller.tryToStoreDataToKeychain(newPassword)
      controller.convertKeycardProfileKeypairToRegular(sp, password, newPassword)
      return
    controller.migrateNonProfileColdWalletKeypairToApp(kpForProcessing.getKeyUid(), sp, password,
      doPasswordHashing = not singletonInstance.userProfile.getMigratedToColdWallet())

method executePreTertiaryStateCommand*(self: MigratingKeypairToAppState, controller: Controller) =
  ## Tertiary action is called after each async action during migration process.
  if self.flowType == FlowType.MigrateFromKeycardToApp:
    let migratingProfile = controller.getKeyPairForProcessing().getKeyUid() == singletonInstance.userProfile.getKeyUid()
    if migratingProfile:
      self.migrationOk = controller.getConvertingProfileSuccess()
      return
    self.migrationOk = controller.getAddingMigratedKeypairSuccess()

method getNextTertiaryState*(self: MigratingKeypairToAppState, controller: Controller): State =
  if self.flowType == FlowType.MigrateFromKeycardToApp:
    if not self.migrationOk:
      return createState(StateType.KeyPairMigrateFailure, self.flowType, nil)
    return createState(StateType.KeyPairMigrateSuccess, self.flowType, nil)