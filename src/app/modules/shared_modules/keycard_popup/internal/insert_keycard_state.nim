type
  InsertKeycardState* = ref object of State

proc newInsertKeycardState*(flowType: FlowType, backState: State): InsertKeycardState =
  result = InsertKeycardState()
  result.setup(flowType, StateType.InsertKeycard, backState)

proc delete*(self: InsertKeycardState) =
  self.State.delete

method executePreBackStateCommand*(self: InsertKeycardState, controller: Controller) =
  if self.flowType == FlowType.SetupNewKeycard:
    if not self.getBackState.isNil and self.getBackState.stateType == StateType.SelectExistingKeyPair:
      controller.cancelCurrentFlow()

method executeCancelCommand*(self: InsertKeycardState, controller: Controller) =
  if self.flowType == FlowType.FactoryReset or
    self.flowType == FlowType.SetupNewKeycard or
    self.flowType == FlowType.SetupNewKeycardNewSeedPhrase or
    self.flowType == FlowType.SetupNewKeycardOldSeedPhrase or
    self.flowType == FlowType.ImportFromKeycard or
    self.flowType == FlowType.Authentication or
    self.flowType == FlowType.Sign or
    self.flowType == FlowType.UnlockKeycard or
    self.flowType == FlowType.DisplayKeycardContent or
    self.flowType == FlowType.RenameKeycard or
    self.flowType == FlowType.ChangeKeycardPin or
    self.flowType == FlowType.ChangeKeycardPuk or
    self.flowType == FlowType.ChangePairingCode or
    self.flowType == FlowType.CreateCopyOfAKeycard or
    self.flowType == FlowType.MigrateFromAppToKeycard:
      controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)

method resolveKeycardNextState*(self: InsertKeycardState, keycardFlowType: string, keycardEvent: KeycardEvent,
  controller: Controller): State =
  let state = readingKeycard(self, keycardFlowType, keycardEvent, controller)
  if not state.isNil:
    return state
  if keycardFlowType == ResponseTypeValueInsertCard and
    keycardEvent.error.len > 0 and
    keycardEvent.error == ErrorConnection:
      controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.WronglyInsertedCard, add = true))
      return nil
  if keycardFlowType == ResponseTypeValueCardInserted:
    controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.WronglyInsertedCard, add = false))
    
    # Special handling for LoadAccount flow - return to the state we came from
    # (RepeatPin or PinSet) to continue waiting for ENTER_MNEMONIC event
    if (self.flowType == FlowType.SetupNewKeycard or
        self.flowType == FlowType.SetupNewKeycardNewSeedPhrase or
        self.flowType == FlowType.SetupNewKeycardOldSeedPhrase) and
       controller.getCurrentKeycardServiceFlow() == KCSFlowType.LoadAccount and
       not self.getBackState.isNil:
          let backStateType = self.getBackState.stateType
          if backStateType == StateType.RepeatPin or backStateType == StateType.PinSet:
            # Return to the previous state to continue waiting for mnemonic entry
            return self.getBackState
    
    # Default behavior for other flows
    if self.flowType == FlowType.SetupNewKeycard:
      return createState(StateType.KeycardInserted, self.flowType, self.getBackState)
    return createState(StateType.KeycardInserted, self.flowType, nil)
  return nil