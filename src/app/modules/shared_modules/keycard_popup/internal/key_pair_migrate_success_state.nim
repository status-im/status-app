type
  KeyPairMigrateSuccessState* = ref object of State

proc newKeyPairMigrateSuccessState*(flowType: FlowType, backState: State): KeyPairMigrateSuccessState =
  result = KeyPairMigrateSuccessState()
  result.setup(flowType, StateType.KeyPairMigrateSuccess, backState)

proc delete*(self: KeyPairMigrateSuccessState) =
  self.State.delete

method executeCancelCommand*(self: KeyPairMigrateSuccessState, controller: Controller) =
  if self.flowType == FlowType.SetupNewKeycard:
    let profileMigrated = controller.getSelectedKeyPairIsProfile()
    if profileMigrated:
      info "quit the app cause this is not an available option in the context of SetupNewKeycard flow for profile keypair"
      singletonInstance.application.exit()
      return

    controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
  if self.flowType == FlowType.MigrateFromKeycardToApp:
    if controller.getKeyPairForProcessing().getKeyUid() == singletonInstance.userProfile.getKeyUid():
      info "quit the app cause this is not an available option in the context of MigrateFromKeycardToApp flow for profile keypair"
      singletonInstance.application.exit()
      return

    controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
  if self.flowType == FlowType.MigrateFromAppToKeycard:
    info "quit the app cause this is not an available option in the context of MigrateFromAppToKeycard"
    singletonInstance.application.exit()

method executePrePrimaryStateCommand*(self: KeyPairMigrateSuccessState, controller: Controller) =
  if self.flowType == FlowType.SetupNewKeycard:
    let profileMigrated = controller.getSelectedKeyPairIsProfile()
    controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
    if profileMigrated:
      info "restart the app because of successfully migrated profile keypair"
      singletonInstance.application.exit()
      return
  if self.flowType == FlowType.MigrateFromKeycardToApp:
    let profileMigrated = controller.getKeyPairForProcessing().getKeyUid() == singletonInstance.userProfile.getKeyUid()
    controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
    if profileMigrated:
      info "restart the app because of successfully migrated profile keypair"
      singletonInstance.application.exit()
      return
  if self.flowType == FlowType.MigrateFromAppToKeycard:
    info "restart the app because of successfully migrated profile keypair"
    singletonInstance.application.exit()

method executePreSecondaryStateCommand*(self: KeyPairMigrateSuccessState, controller: Controller) =
  if self.flowType == FlowType.MigrateFromKeycardToApp:
    let profileMigrated = controller.getKeyPairForProcessing().getKeyUid() == singletonInstance.userProfile.getKeyUid()
    if profileMigrated:
      return
    controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true, nextFlow = FlowType.FactoryReset,
      forceFlow = controller.getForceFlow(), nextKeyUid = controller.getKeyPairForProcessing().getKeyUid())
