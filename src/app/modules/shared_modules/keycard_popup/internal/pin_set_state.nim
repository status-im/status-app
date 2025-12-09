type
  PinSetState* = ref object of State

proc newPinSetState*(flowType: FlowType, backState: State): PinSetState =
  result = PinSetState()
  result.setup(flowType, StateType.PinSet, backState)

proc delete*(self: PinSetState) =
  self.State.delete
  
method getNextPrimaryState*(self: PinSetState, controller: Controller): State =
  if self.flowType == FlowType.SetupNewKeycard:
    if controller.isProfileMnemonicBackedUp() or not controller.getSelectedKeyPairIsProfile():
      return createState(StateType.EnterSeedPhrase, self.flowType, nil)
    else:
      return createState(StateType.SeedPhraseDisplay, self.flowType, nil)
  if self.flowType == FlowType.SetupNewKeycardNewSeedPhrase:
    return createState(StateType.SeedPhraseDisplay, self.flowType, nil)
  if self.flowType == FlowType.SetupNewKeycardOldSeedPhrase:
    return createState(StateType.EnterKeycardName, self.flowType, nil)
  if self.flowType == FlowType.UnlockKeycard:
    if controller.unlockUsingSeedPhrase():
      return createState(StateType.UnlockingKeycard, self.flowType, nil)
    else:
      if controller.getValidPuk():
        return createState(StateType.UnlockingKeycard, self.flowType, nil)
      return createState(StateType.WrongPuk, self.flowType, self.getBackState)

method executeCancelCommand*(self: PinSetState, controller: Controller) =
  if self.flowType == FlowType.SetupNewKeycard or
    self.flowType == FlowType.SetupNewKeycardNewSeedPhrase or
    self.flowType == FlowType.SetupNewKeycardOldSeedPhrase or
    self.flowType == FlowType.UnlockKeycard:
      controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)

method resolveKeycardNextState*(self: PinSetState, keycardFlowType: string, keycardEvent: KeycardEvent, 
  controller: Controller): State =
  # Handle temporary card disconnection during LoadAccount flow (after card initialization)
  # This can happen if the user hasn't tapped "Continue" yet and the card disconnects
  if self.flowType == FlowType.SetupNewKeycard or
    self.flowType == FlowType.SetupNewKeycardNewSeedPhrase or
    self.flowType == FlowType.SetupNewKeycardOldSeedPhrase:
      # INSERT_CARD during LoadAccount flow means card is reconnecting after initialization
      if keycardFlowType == ResponseTypeValueInsertCard and 
        keycardEvent.error.len > 0 and
        keycardEvent.error == ErrorConnection and
        controller.getCurrentKeycardServiceFlow() == KCSFlowType.LoadAccount:
          # Don't cancel the flow - transition to InsertKeycard state and wait for reconnection
          controller.reRunCurrentFlowLater()
          return createState(StateType.InsertKeycard, self.flowType, self)
      # CARD_INSERTED after temporary disconnection - stay in PinSet and continue
      if keycardFlowType == ResponseTypeValueCardInserted and
        controller.getCurrentKeycardServiceFlow() == KCSFlowType.LoadAccount:
          # Card reconnected successfully, stay in PinSet
          return nil
  
  # No specific handling needed - this state transitions via primary button
  return nil