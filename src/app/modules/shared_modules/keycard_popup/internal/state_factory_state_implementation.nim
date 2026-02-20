proc ensureReaderAndCardPresence*(state: State, keycardFlowType: string, keycardEvent: KeycardEvent, controller: Controller): State =
  ## Check for some specific errors
  if keycardFlowType == ResponseTypeValueKeycardFlowResult and
    keycardEvent.error.len > 0 and
    keycardEvent.error == ErrorPCSC:
      return createState(StateType.NoPCSCService, state.flowType, nil)
  ## Handling factory reset or authentication or unlock keycard flow
  if state.flowType == FlowType.FactoryReset or
    state.flowType == FlowType.Authentication or
    state.flowType == FlowType.Sign or
    state.flowType == FlowType.UnlockKeycard or
    state.flowType == FlowType.DisplayKeycardContent or
    state.flowType == FlowType.RenameKeycard or
    state.flowType == FlowType.ChangeKeycardPin or
    state.flowType == FlowType.ChangeKeycardPuk or
    state.flowType == FlowType.ChangePairingCode or
    state.flowType == FlowType.CreateCopyOfAKeycard or
    state.flowType == FlowType.SetupNewKeycardNewSeedPhrase or
    state.flowType == FlowType.SetupNewKeycardOldSeedPhrase or
    state.flowType == FlowType.ImportFromKeycard or
    state.flowType == FlowType.MigrateFromAppToKeycard:
      if keycardFlowType == ResponseTypeValueKeycardFlowResult and
        keycardEvent.error.len > 0 and
        (keycardEvent.error == ErrorNoReader or
        keycardEvent.error == ErrorReaderList):
          controller.reRunCurrentFlowLater()
          if state.stateType == StateType.PluginReader:
            return state
          return createState(StateType.PluginReader, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueInsertCard and
        keycardEvent.error.len > 0 and
        keycardEvent.error == ErrorConnection:
          controller.reRunCurrentFlowLater()
          if state.stateType == StateType.InsertKeycard:
            return state
          return createState(StateType.InsertKeycard, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueCardInserted:
        controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.WronglyInsertedCard, add = false))
        return createState(StateType.KeycardInserted, state.flowType, nil)

  ## Handling setup new keycard flow
  if state.flowType == FlowType.SetupNewKeycard:
    if keycardFlowType == ResponseTypeValueKeycardFlowResult and
      keycardEvent.error.len > 0 and
      (keycardEvent.error == ErrorConnection or
      keycardEvent.error == ErrorNoReader or
      keycardEvent.error == ErrorReaderList):
        controller.reRunCurrentFlowLater()
        if state.stateType == StateType.PluginReader:
          return nil
        return createState(StateType.PluginReader, state.flowType, state)
    if keycardFlowType == ResponseTypeValueInsertCard and
      keycardEvent.error.len > 0 and
      keycardEvent.error == ErrorConnection:
        controller.reRunCurrentFlowLater()
        if state.stateType == StateType.InsertKeycard:
          return nil
        if state.stateType == StateType.SelectExistingKeyPair:
          return createState(StateType.InsertKeycard, state.flowType, state)
        return createState(StateType.InsertKeycard, state.flowType, state.getBackState)
    if keycardFlowType == ResponseTypeValueCardInserted:
      controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.WronglyInsertedCard, add = false))
      if state.stateType == StateType.SelectExistingKeyPair:
        return createState(StateType.InsertKeycard, state.flowType, state)
      return createState(StateType.KeycardInserted, state.flowType, state.getBackState)

proc ensureReaderAndCardPresenceAndResolveNextState*(state: State, keycardFlowType: string, keycardEvent: KeycardEvent, controller: Controller): State =
  let ensureState = ensureReaderAndCardPresence(state, keycardFlowType, keycardEvent, controller)
  if not ensureState.isNil:
    return ensureState
  ## Handling factory reset flow
  if state.flowType == FlowType.FactoryReset:
    if keycardFlowType == ResponseTypeValueEnterPIN:
      return createState(StateType.EnterPin, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          return createState(StateType.FactoryResetConfirmation, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
      if keycardEvent.error == ErrorNotAKeycard:
        return createState(StateType.NotKeycard, state.flowType, nil)
      if keycardEvent.error == ErrorFreePairingSlots:
        return createState(StateType.FactoryResetConfirmation, state.flowType, nil)
      if keycardEvent.error == ErrorPUKRetries:
        return createState(StateType.FactoryResetConfirmation, state.flowType, nil)
    ##############################################
    ## This part is here just to provide a first aid to one who run into setting custom pairing flow
    ## since that flow is developed and available in `master` branch, but other flows are affected by
    ## the cahnge made in that one.
    ## That flow is not a subject of MVP and will be handled after MVP accross app properly,
    ## issue: https://github.com/status-im/status-app/issues/8065
    if keycardFlowType == ResponseTypeValueEnterPairing and
      keycardEvent.error.len > 0:
      if keycardEvent.error == ErrorPairing:
        return createState(StateType.FactoryResetConfirmation, state.flowType, nil)
    ##############################################
    if keycardFlowType == ResponseTypeValueKeycardFlowResult:
      if keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorOk:
          return createState(StateType.FactoryResetSuccess, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorNoData:
          return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
      if keycardEvent.error.len == 0:
        if keycardEvent.cardMetadata.name.len > 0 and keycardEvent.cardMetadata.walletAccounts.len > 0:
          controller.setContainsMetadata(true)
          return createState(StateType.RecognizedKeycard, state.flowType, nil)

  ## Handling setup new keycard flow
  if state.flowType == FlowType.SetupNewKeycard:
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorHasKeys:
          return createState(StateType.KeycardNotEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPIN:
      if controller.getCurrentKeycardServiceFlow() == KCSFlowType.GetMetadata:
        return createState(StateType.EnterPin, state.flowType, nil)
      return createState(StateType.KeycardNotEmpty, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult and
      keycardEvent.error.len > 0:
      controller.setKeycardData("")
      if keycardEvent.error == ErrorOk:
        return createState(StateType.FactoryResetSuccess, state.flowType, nil)
      if keycardEvent.error == ErrorNoData:
        return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
      if keycardEvent.error == ErrorNoKeys:
        return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterNewPIN and
      keycardEvent.error.len > 0 and
      keycardEvent.error == ErrorRequireInit:
        if state.stateType == StateType.SelectExistingKeyPair:
          return createState(StateType.RecognizedKeycard, state.flowType, state)
        return createState(StateType.RecognizedKeycard, state.flowType, state.getBackState)

  ## Handling setup new keycard new seed phrase flow
  if state.flowType == FlowType.SetupNewKeycardNewSeedPhrase:
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorHasKeys:
          return createState(StateType.KeycardNotEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPIN:
      if controller.getCurrentKeycardServiceFlow() == KCSFlowType.GetMetadata:
        return createState(StateType.EnterPin, state.flowType, nil)
      return createState(StateType.KeycardNotEmpty, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult and
      keycardEvent.error.len > 0:
      controller.setKeycardData("")
      if keycardEvent.error == ErrorOk:
        return createState(StateType.FactoryResetSuccess, state.flowType, nil)
      if keycardEvent.error == ErrorNoData:
        return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
      if keycardEvent.error == ErrorNoKeys:
        return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterNewPIN and
      keycardEvent.error.len > 0 and
      keycardEvent.error == ErrorRequireInit:
        return createState(StateType.RecognizedKeycard, state.flowType, nil)

  ## Handling setup new keycard old seed phrase flow
  if state.flowType == FlowType.SetupNewKeycardOldSeedPhrase:
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorHasKeys:
          return createState(StateType.KeycardNotEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPIN:
      if controller.getCurrentKeycardServiceFlow() == KCSFlowType.GetMetadata:
        return createState(StateType.EnterPin, state.flowType, nil)
      return createState(StateType.KeycardNotEmpty, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult and
      keycardEvent.error.len > 0:
      controller.setKeycardData("")
      if keycardEvent.error == ErrorOk:
        return createState(StateType.FactoryResetSuccess, state.flowType, nil)
      if keycardEvent.error == ErrorNoData:
        return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
      if keycardEvent.error == ErrorNoKeys:
        return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterNewPIN and
      keycardEvent.error.len > 0 and
      keycardEvent.error == ErrorRequireInit:
        return createState(StateType.RecognizedKeycard, state.flowType, nil)

  ## Handling import from keycard flow
  if state.flowType == FlowType.ImportFromKeycard:
    controller.setKeyPairForProcessing(newKeyPairItem(keyUid = keycardEvent.keyUid)) # must set keypair in case of running some other flow which needs e.g. keyuid. like unlock flow
    if controller.isKeyPairAlreadyAdded(keycardEvent.keyUid):
      controller.prepareKeyPairForProcessing(keycardEvent.keyUid)
      return createState(StateType.SeedPhraseAlreadyInUse, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPIN and
      keycardEvent.error.len == 0:
        return createState(StateType.RecognizedKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.DisableSeedPhraseForUnlock, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.DisableSeedPhraseForUnlock, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult or
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorNoData:
          return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)

  ## Handling authentiaction flow
  if state.flowType == FlowType.Authentication:
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPIN:
      if keycardEvent.keyUid == controller.getKeyUidWhichIsBeingAuthenticating() or keycardEvent.keyUid.len == 0:
        if singletonInstance.userProfile.getUsingBiometricLogin():
          if keycardEvent.error.len > 0 and
            keycardEvent.error == ErrorPIN:
              controller.setRemainingAttempts(keycardEvent.pinRetries)
              if keycardEvent.pinRetries > 0:
                if not controller.usePinFromBiometrics():
                  return createState(StateType.WrongKeychainPin, state.flowType, nil)
                return createState(StateType.WrongPin, state.flowType, nil)
              controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
              return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
          return createState(StateType.BiometricsReadyToSign, state.flowType, nil)
        return createState(StateType.EnterPin, state.flowType, nil)
      return createState(StateType.WrongKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult:
      if keycardEvent.error.len == 0:
        controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
        return nil

  ## Handling sign flow
  if state.flowType == FlowType.Sign:
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPIN:
      if keycardEvent.keyUid == controller.getKeyUidWhichIsBeingSigning() or keycardEvent.keyUid.len == 0:
        if singletonInstance.userProfile.getUsingBiometricLogin():
          if keycardEvent.error.len > 0 and
            keycardEvent.error == ErrorPIN:
              controller.setRemainingAttempts(keycardEvent.pinRetries)
              if keycardEvent.pinRetries > 0:
                if not controller.usePinFromBiometrics():
                  return createState(StateType.WrongKeychainPin, state.flowType, nil)
                return createState(StateType.WrongPin, state.flowType, nil)
              controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
              return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
          return createState(StateType.BiometricsReadyToSign, state.flowType, nil)
        return createState(StateType.EnterPin, state.flowType, nil)
      return createState(StateType.WrongKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult:
      if keycardEvent.error.len == 0:
        controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
        return nil

  ## Handling unlock keycard flow
  if state.flowType == FlowType.UnlockKeycard:
    if controller.getCurrentKeycardServiceFlow() == KCSFlowType.GetMetadata:
      if keycardFlowType == ResponseTypeValueEnterPIN and
        keycardEvent.error.len == 0:
          return createState(StateType.KeycardAlreadyUnlocked, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueSwapCard and
        keycardEvent.error.len > 0:
          if keycardEvent.error == ErrorNotAKeycard:
            return createState(StateType.NotKeycard, state.flowType, nil)
          if keycardEvent.error == ErrorNoKeys:
            return createState(StateType.KeycardEmpty, state.flowType, nil)
          if keycardEvent.error == ErrorFreePairingSlots:
            return createState(StateType.RecognizedKeycard, state.flowType, nil)
          if keycardEvent.error == ErrorPUKRetries:
            return createState(StateType.RecognizedKeycard, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueEnterPUK and
        keycardEvent.error.len == 0:
          controller.setKeycardUid(keycardEvent.instanceUID)
          return createState(StateType.RecognizedKeycard, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueKeycardFlowResult or
        keycardEvent.error.len > 0:
          if keycardEvent.error == ErrorNoKeys:
            return createState(StateType.KeycardEmpty, state.flowType, nil)
          if keycardEvent.error == ErrorNoData:
            return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)

  if state.flowType == FlowType.DisplayKeycardContent:
    controller.setKeyPairForProcessing(newKeyPairItem(keyUid = keycardEvent.keyUid)) # must set keypair in case of running some other flow which needs e.g. keyuid. like unlock flow
    if keycardFlowType == ResponseTypeValueEnterPIN and
      keycardEvent.error.len == 0:
        return createState(StateType.RecognizedKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.DisableSeedPhraseForUnlock, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.DisableSeedPhraseForUnlock, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult or
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorNoData:
          return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)

  if state.flowType == FlowType.RenameKeycard:
    if keycardFlowType == ResponseTypeValueEnterPIN and
      keycardEvent.error.len == 0:
        return createState(StateType.RecognizedKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult or
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorNoData:
          return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)

  if state.flowType == FlowType.ChangeKeycardPin:
    if keycardFlowType == ResponseTypeValueEnterPIN and
      keycardEvent.error.len == 0:
        return createState(StateType.RecognizedKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult:
      if keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorNoData:
          return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
      if keycardEvent.error.len == 0:
        controller.keycardPinChanged(controller.getPin())
        return createState(StateType.ChangingKeycardPinSuccess, state.flowType, nil)
      ## in all other cases if we fall through here, we assume it's changing pin failor, but that we not interfare with
      ## `nil` for `ensureState` we just do this `if` cause we can get here only from `ChangingKeycardPin` state.
      if state.stateType == StateType.ChangingKeycardPin:
        return createState(StateType.ChangingKeycardPinFailure, state.flowType, nil)

  if state.flowType == FlowType.ChangeKeycardPuk:
    if keycardFlowType == ResponseTypeValueEnterPIN and
      keycardEvent.error.len == 0:
        return createState(StateType.RecognizedKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult:
      if keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorNoData:
          return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
      if keycardEvent.error.len == 0:
        return createState(StateType.ChangingKeycardPukSuccess, state.flowType, nil)
      ## in all other cases if we fall through here, we assume it's changing puk failor, but that we not interfare with
      ## `nil` for `ensureState` we just do this `if` cause we can get here only from `ChangingKeycardPuk` state.
      if state.stateType == StateType.ChangingKeycardPuk:
        return createState(StateType.ChangingKeycardPukFailure, state.flowType, nil)

  if state.flowType == FlowType.ChangePairingCode:
    if keycardFlowType == ResponseTypeValueEnterPIN and
      keycardEvent.error.len == 0:
        return createState(StateType.RecognizedKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueKeycardFlowResult:
      if keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorNoData:
          return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
      if keycardEvent.error.len == 0:
        return createState(StateType.ChangingKeycardPairingCodeSuccess, state.flowType, nil)
      ## in all other cases if we fall through here, we assume it's changing pairing code failor, but that we not interfare with
      ## `nil` for `ensureState` we just do this `if` cause we can get here only from `ChangingKeycardPairingCode` state.
      if state.stateType == StateType.ChangingKeycardPairingCode:
        return createState(StateType.ChangingKeycardPairingCodeFailure, state.flowType, nil)

  if state.flowType == FlowType.CreateCopyOfAKeycard:
    if isPredefinedKeycardDataFlagSet(controller.getKeycardData(), PredefinedKeycardData.CopyFromAKeycardPartDone):
      if controller.getKeycardUid().len > 0 and controller.getKeycardUid() == keycardEvent.instanceUID:
        return createState(StateType.SameKeycard, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueSwapCard and
        keycardEvent.error.len > 0:
          if keycardEvent.error == ErrorNotAKeycard:
            return createState(StateType.NotKeycard, state.flowType, nil)
          if keycardEvent.error == ErrorHasKeys:
            return createState(StateType.KeycardNotEmpty, state.flowType, nil)
          if keycardEvent.error == ErrorFreePairingSlots:
            controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
            return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
          if keycardEvent.error == ErrorPUKRetries:
            controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
            return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueEnterPIN:
        if controller.getCurrentKeycardServiceFlow() == KCSFlowType.GetMetadata:
          return createState(StateType.EnterPin, state.flowType, nil)
        return createState(StateType.KeycardNotEmpty, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueEnterPUK and
        keycardEvent.error.len == 0:
          if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
            controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
            return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueKeycardFlowResult and
        keycardEvent.error.len > 0:
        controller.setKeycardData("")
        # we're still in part 2, so set kc data appropriatelly after cleaning
        controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.CopyFromAKeycardPartDone, add = true))
        if keycardEvent.error == ErrorOk:
          return createState(StateType.FactoryResetSuccess, state.flowType, nil)
        if keycardEvent.error == ErrorNoData:
          return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueEnterNewPIN and
        keycardEvent.error.len > 0 and
        keycardEvent.error == ErrorRequireInit:
          return createState(StateType.CopyToKeycard, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueEnterMnemonic and
        keycardEvent.error.len > 0 and
        keycardEvent.error == ErrorLoadingKeys:
          return createState(StateType.CopyToKeycard, state.flowType, nil)
    else:
      if keycardFlowType == ResponseTypeValueEnterPIN and
        keycardEvent.error.len == 0:
          return createState(StateType.RecognizedKeycard, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueEnterPUK and
        keycardEvent.error.len == 0:
          if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
            controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
            return createState(StateType.MaxPinRetriesReached, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueSwapCard and
        keycardEvent.error.len > 0:
          if keycardEvent.error == ErrorNotAKeycard:
            return createState(StateType.NotKeycard, state.flowType, nil)
          if keycardEvent.error == ErrorNoKeys:
            return createState(StateType.KeycardEmpty, state.flowType, nil)
          if keycardEvent.error == ErrorFreePairingSlots:
            controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
            return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
          if keycardEvent.error == ErrorPUKRetries:
            controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
            return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
      if keycardFlowType == ResponseTypeValueKeycardFlowResult or
        keycardEvent.error.len > 0:
          if keycardEvent.error == ErrorNoKeys:
            return createState(StateType.KeycardEmpty, state.flowType, nil)
          if keycardEvent.error == ErrorNoData:
            return createState(StateType.KeycardEmptyMetadata, state.flowType, nil)

  ## Handling migration from the app to a Keycard flow
  if state.flowType == FlowType.MigrateFromAppToKeycard:
    if keycardEvent.keyUid.len > 0 and keycardEvent.keyUid != controller.getKeyPairForProcessing().getKeyUid():
      return createState(StateType.WrongKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueSwapCard and
      keycardEvent.error.len > 0:
        if keycardEvent.error == ErrorNotAKeycard:
          return createState(StateType.NotKeycard, state.flowType, nil)
        if keycardEvent.error == ErrorNoKeys:
          return createState(StateType.KeycardEmpty, state.flowType, nil)
        if keycardEvent.error == ErrorFreePairingSlots:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPairingSlotsReached, state.flowType, nil)
        if keycardEvent.error == ErrorPUKRetries:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPukRetriesReached, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPIN and
      keycardEvent.error.len == 0:
        return createState(StateType.RecognizedKeycard, state.flowType, nil)
    if keycardFlowType == ResponseTypeValueEnterPUK and
      keycardEvent.error.len == 0:
        if keycardEvent.pinRetries == 0 and keycardEvent.pukRetries > 0:
          controller.setKeycardData(updatePredefinedKeycardData(controller.getKeycardData(), PredefinedKeycardData.UseGeneralMessageForLockedState, add = true))
          return createState(StateType.MaxPinRetriesReached, state.flowType, nil)

proc readingKeycard*(state: State, keycardFlowType: string, keycardEvent: KeycardEvent, controller: Controller): State =
  controller.setKeycardUid("")
  if state.flowType == FlowType.UnlockKeycard or
    state.flowType == FlowType.RenameKeycard or
    state.flowType == FlowType.ChangeKeycardPin or
    state.flowType == FlowType.ChangeKeycardPuk or
    state.flowType == FlowType.ChangePairingCode or
    state.flowType == FlowType.MigrateFromAppToKeycard or
    (state.flowType == FlowType.CreateCopyOfAKeycard and
    not isPredefinedKeycardDataFlagSet(controller.getKeycardData(), PredefinedKeycardData.CopyFromAKeycardPartDone)) or
    state.flowType == FlowType.FactoryReset and
    not controller.getKeyPairForProcessing().isNil:
      # this part is only for the flows which are card specific (the card we're running a flow for is known in advance)
      let ensureKeycardPresenceState = ensureReaderAndCardPresence(state, keycardFlowType, keycardEvent, controller)
      if ensureKeycardPresenceState.isNil: # means the keycard is inserted
        let nextState = ensureReaderAndCardPresenceAndResolveNextState(state, keycardFlowType, keycardEvent, controller)
        if not nextState.isNil and
          (nextState.stateType == StateType.KeycardEmpty or
          nextState.stateType == StateType.NotKeycard or
          nextState.stateType == StateType.KeycardEmptyMetadata):
            return nextState
        let keyUid = controller.getKeyPairForProcessing().getKeyUid()
        if keyUid.len > 0 and keycardEvent.keyUid.len > 0:
          if keyUid != keycardEvent.keyUid:
            return createState(StateType.WrongKeycard, state.flowType, nil)
          controller.setKeycardUid(keycardEvent.instanceUID)
        return nextState
      return ensureKeycardPresenceState

  # this is used in case a keycard is inserted and we jump to the first meaningful screen
  return ensureReaderAndCardPresenceAndResolveNextState(state, keycardFlowType, keycardEvent, controller)
