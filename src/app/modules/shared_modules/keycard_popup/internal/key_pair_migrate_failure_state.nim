type
  KeyPairMigrateFailureState* = ref object of State

proc newKeyPairMigrateFailureState*(flowType: FlowType, backState: State): KeyPairMigrateFailureState =
  result = KeyPairMigrateFailureState()
  result.setup(flowType, StateType.KeyPairMigrateFailure, backState)

proc delete*(self: KeyPairMigrateFailureState) =
  self.State.delete

method executePrePrimaryStateCommand*(self: KeyPairMigrateFailureState, controller: Controller) =
  var profileMigrated = false
  if self.flowType == FlowType.SetupNewKeycard:
    profileMigrated = controller.getSelectedKeyPairIsProfile()
  elif self.flowType == FlowType.MigrateFromKeycardToApp or
    self.flowType == FlowType.MigrateFromAppToKeycard:
      profileMigrated = controller.getKeyPairForProcessing().getKeyUid() == singletonInstance.userProfile.getKeyUid()

  if not profileMigrated:
    controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
    return
  info "quit the app because of profile migration failure"
  singletonInstance.application.exit()

method executeCancelCommand*(self: KeyPairMigrateFailureState, controller: Controller) =
  var profileMigrated = false
  if self.flowType == FlowType.SetupNewKeycard:
    profileMigrated = controller.getSelectedKeyPairIsProfile()
  elif self.flowType == FlowType.MigrateFromKeycardToApp or
    self.flowType == FlowType.MigrateFromAppToKeycard:
      profileMigrated = controller.getKeyPairForProcessing().getKeyUid() == singletonInstance.userProfile.getKeyUid()

  if not profileMigrated:
    controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
    return
  info "quit the app because of profile migration failure"
  singletonInstance.application.exit()