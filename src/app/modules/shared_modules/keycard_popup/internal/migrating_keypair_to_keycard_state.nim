type
  MigratingKeypairToKeycardState* = ref object of State
    authenticationDone: bool
    authenticationOk: bool
    addingMigratedKeypairDone: bool
    addingMigratedKeypairOk: bool
    profileConversionDone: bool
    profileConversionOk: bool

proc newMigratingKeypairToKeycardState*(flowType: FlowType, backState: State): MigratingKeypairToKeycardState =
  result = MigratingKeypairToKeycardState()
  result.setup(flowType, StateType.MigratingKeypairToKeycard, backState)
  result.authenticationDone = false
  result.authenticationOk = false
  result.addingMigratedKeypairDone = false
  result.addingMigratedKeypairOk = false
  result.profileConversionDone = false
  result.profileConversionOk = false

proc delete*(self: MigratingKeypairToKeycardState) =
  self.State.delete

proc doMigration(self: MigratingKeypairToKeycardState, controller: Controller) =
  let selectedKeyPairDto = controller.getSelectedKeyPairDto()
  let password = controller.getPassword()
  controller.addKeycardOrAccounts(selectedKeyPairDto, password)

proc runStoreMetadataFlow(self: MigratingKeypairToKeycardState, controller: Controller) =
  let selectedKeyPairDto = controller.getSelectedKeyPairDto()
  controller.runStoreMetadataFlow(selectedKeyPairDto.keycardName, controller.getPin(), controller.getSelectedKeyPairWalletPaths())

method executePrePrimaryStateCommand*(self: MigratingKeypairToKeycardState, controller: Controller) =
  if self.flowType == FlowType.SetupNewKeycard:
    if controller.getSelectedKeyPairIsProfile():
      controller.authenticateUser()
      return
    self.doMigration(controller)
  if self.flowType == FlowType.MigrateFromAppToKeycard:
    controller.convertRegularProfileKeypairToKeycard()
    return

method executePreTertiaryStateCommand*(self: MigratingKeypairToKeycardState, controller: Controller) =
  ## Tertiary action is called after each async action during migration process.
  if self.flowType == FlowType.SetupNewKeycard:
    if controller.getSelectedKeyPairIsProfile():
      if not self.authenticationDone:
        self.authenticationDone = true
        let password = controller.getPassword()
        self.authenticationOk = controller.verifyPassword(password)
        if self.authenticationOk:
          controller.convertRegularProfileKeypairToKeycard()
          return
      if not self.profileConversionDone:
        self.profileConversionDone = true
        self.profileConversionOk = controller.getConvertingProfileSuccess()
        if self.profileConversionOk:
          self.runStoreMetadataFlow(controller)
    else:
      if not self.addingMigratedKeypairDone:
        self.addingMigratedKeypairDone = true
        self.addingMigratedKeypairOk = controller.getAddingMigratedKeypairSuccess()
        if self.addingMigratedKeypairOk:
          self.runStoreMetadataFlow(controller)
    return
  if self.flowType == FlowType.MigrateFromAppToKeycard:
    if not self.profileConversionDone:
      self.profileConversionDone = true
      self.profileConversionOk = controller.getConvertingProfileSuccess()


method getNextTertiaryState*(self: MigratingKeypairToKeycardState, controller: Controller): State =
  if self.flowType == FlowType.SetupNewKeycard:
    if controller.getSelectedKeyPairIsProfile():
      if self.authenticationDone and not self.authenticationOk or
        self.profileConversionDone and not self.profileConversionOk:
          return createState(StateType.KeyPairMigrateFailure, self.flowType, nil)
    else:
      if self.addingMigratedKeypairDone and not self.addingMigratedKeypairOk:
        return createState(StateType.KeyPairMigrateFailure, self.flowType, nil)
  if self.flowType == FlowType.MigrateFromAppToKeycard:
    if self.profileConversionDone and not self.profileConversionOk:
        return createState(StateType.KeyPairMigrateFailure, self.flowType, nil)
    if self.profileConversionOk:
      return createState(StateType.KeyPairMigrateSuccess, self.flowType, nil)

method resolveKeycardNextState*(self: MigratingKeypairToKeycardState, keycardFlowType: string, keycardEvent: KeycardEvent,
  controller: Controller): State =
  let state = ensureReaderAndCardPresenceAndResolveNextState(self, keycardFlowType, keycardEvent, controller)
  if not state.isNil:
    return state
  if self.flowType == FlowType.SetupNewKeycard:
    if keycardFlowType == ResponseTypeValueKeycardFlowResult and
      keycardEvent.error.len == 0:
        return createState(StateType.KeyPairMigrateSuccess, self.flowType, nil)
