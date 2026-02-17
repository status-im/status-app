import nimqml, tables, strutils, sequtils, sugar, chronicles

import io_interface
import view, controller
import internal/[state, state_factory]
import app/modules/shared/[keypairs, wallet_utils]
import app/modules/shared_models/[keypair_model, keypair_item, currency_amount]
import app/global/global_singleton
import app/core/eventemitter

import app/global/app_translatable_constants as atc
const dummyUsage = atc.KEYCARD_ACCOUNT_NAME_OF_UNKNOWN_WALLET_ACCOUNT # dummy usage to prevent false-alarm warning

import app_service/common/utils
import app_service/service/keycard/constants
import app_service/service/keycard/service as keycard_service
import app_service/service/settings/service as settings_service
import app_service/service/network/service as network_service
import app_service/service/privacy/service as privacy_service
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service

export io_interface

logScope:
  topics = "keycard-popup-module"

type
  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    view: View
    viewVariant: QVariant
    controller: Controller
    initialized: bool
    tmpLocalState: State # used when flow is run, until response arrives to determine next state appropriatelly
    authenticationPopupIsAlreadyRunning: bool
    runningFlow: FlowType # in general used to mark the global shared flow that is being running (`Authentication` or `Sign`)

    # temporary variables used to store data while we're wiating for keycard lib to get ready
    tmpFlowToRun: FlowType
    tmpKeyUid: string
    tmpBip44Paths: seq[string]
    tmpTxHash: string
    tmpForceFlow: bool
    tmpReturnToFlow: FlowType
    tmpPin: string

proc newModule*[T](delegate: T,
  uniqueIdentifier: string,
  events: EventEmitter,
  keycardService: keycard_service.Service,
  settingsService: settings_service.Service,
  networkService: network_service.Service,
  privacyService: privacy_service.Service,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service):
  Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, uniqueIdentifier, events, keycardService, settingsService,
    networkService, privacyService, accountsService, walletAccountService)
  result.initialized = false
  result.authenticationPopupIsAlreadyRunning = false
  result.runningFlow = FlowType.General

{.push warning[Deprecated]: off.}

## Forward declarations
proc proceedWithSyncKeycardBasedOnAppState[T](self: Module[T], keyUid: string, pin: string)
proc proceedWithRunFlow[T](self: Module[T], flowToRun: FlowType, keyUid: string, bip44Paths: seq[string], txHash: string, forceFlow: bool, returnToFlow: FlowType)

method delete*[T](self: Module[T]) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

proc init[T](self: Module[T], fullConnect = true) =
  if not self.initialized:
    self.initialized = true
    self.controller.cleanReceivedKeycardData()
    self.controller.init(fullConnect)

method keycardReady*[T](self: Module[T]) =
  if self.tmpPin.len > 0:
    self.proceedWithSyncKeycardBasedOnAppState(self.tmpKeyUid, self.tmpPin)
  else:
    self.proceedWithRunFlow(self.tmpFlowToRun, self.tmpKeyUid, self.tmpBip44Paths, self.tmpTxHash, self.tmpForceFlow, self.tmpReturnToFlow)

method getModuleAsVariant*[T](self: Module[T]): QVariant =
  return self.viewVariant

method getReturnToFlow*[T](self: Module[T]): FlowType =
  return self.view.getReturnToFlow()

method getForceFlow*[T](self: Module[T]): bool =
  return self.view.getForceFlow()

method getPin*[T](self: Module[T]): string =
  return self.controller.getPin()

method getKeycardData*[T](self: Module[T]): string =
  return self.view.getKeycardData()

method setKeycardData*[T](self: Module[T], value: string) =
  self.view.setKeycardData(value)

method setRemainingAttempts*[T](self: Module[T], value: int) =
  self.view.setRemainingAttempts(value)

method setPin*[T](self: Module[T], value: string) =
  self.controller.setPin(value)

method setPuk*[T](self: Module[T], value: string) =
  self.controller.setPuk(value)

method setPassword*[T](self: Module[T], value: string) =
  self.controller.setPassword(value)

method setNewPassword*[T](self: Module[T], value: string) =
  self.controller.setNewPassword(value)

method getNewPassword*[T](self: Module[T]): string =
  return self.controller.getNewPassword()

method getKeyPairForProcessing*[T](self: Module[T]): KeyPairItem =
  return self.view.getKeyPairForProcessing()

method getKeyPairHelper*[T](self: Module[T]): KeyPairItem =
  return self.view.getKeyPairHelper()

method getNameFromKeycard*[T](self: Module[T]): string =
  return self.controller.getMetadataFromKeycard().name

method setPairingCode*[T](self: Module[T], value: string) =
  self.controller.setPairingCode(value)

method checkRepeatedKeycardPinWhileTyping*[T](self: Module[T], pin: string): bool =
  self.controller.setPinMatch(false)
  let storedPin = self.controller.getPin()
  if pin.len > storedPin.len:
    return false
  elif pin.len < storedPin.len:
    for i in 0 ..< pin.len:
      if pin[i] != storedPin[i]:
        return false
    return true
  else:
    let match = pin == storedPin
    self.controller.setPinMatch(match)
    return match

method checkRepeatedKeycardPukWhileTyping*[T](self: Module[T], puk: string): bool =
  self.controller.setPukMatch(false)
  let storedPuk = self.controller.getPuk()
  if puk.len > storedPuk.len:
    return false
  elif puk.len < storedPuk.len:
    for i in 0 ..< puk.len:
      if puk[i] != storedPuk[i]:
        return false
    return true
  else:
    let match = puk == storedPuk
    self.controller.setPukMatch(match)
    return match

method getCurrentFlowType*[T](self: Module[T]): FlowType =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "sm_cannot resolve current state"
    return FlowType.General
  return currStateObj.flowType()

method getMnemonic*[T](self: Module[T]): string =
  let flowType = self.getCurrentFlowType()
  if flowType == FlowType.SetupNewKeycard:
    return self.controller.getProfileMnemonic()
  if flowType == FlowType.SetupNewKeycardNewSeedPhrase or
    flowType == FlowType.SetupNewKeycardOldSeedPhrase:
      return self.controller.getSeedPhrase()

method setSeedPhrase*[T](self: Module[T], value: string) =
  self.controller.setSeedPhrase(value)

method getSeedPhrase*[T](self: Module[T]): string =
  return self.controller.getSeedPhrase()

method validSeedPhrase*[T](self: Module[T], value: string): bool =
  return self.controller.validSeedPhrase(value)

method migratingProfileKeyPair*[T](self: Module[T]): bool =
  let flowType = self.getCurrentFlowType()
  if flowType == FlowType.SetupNewKeycard:
    return self.controller.getSelectedKeyPairIsProfile()
  return self.controller.getKeyPairForProcessing().getKeyUid() == singletonInstance.userProfile.getKeyUid()

proc preActionActivities[T](self: Module[T], currFlowType: FlowType, currStateType: StateType) =
  if currStateType == StateType.ManageKeycardAccounts or
    currStateType == StateType.CreatePin or
    currStateType == StateType.RepeatPin or
    currStateType == StateType.CreatePuk or
    currStateType == StateType.RepeatPuk or
    currStateType == StateType.EnterPuk or
    currStateType == StateType.WrongPuk:
      self.view.setDisablePopup(false)
      return
  if currStateType == StateType.EnterPin or
    currStateType == StateType.CreatePin or
    currStateType == StateType.RepeatPin or
    currStateType == StateType.WrongPin:
      let disable = self.controller.getPin().len == PINLengthForStatusApp
      self.view.setDisablePopup(disable)
      return
  if currStateType == StateType.CreatePuk or
    currStateType == StateType.RepeatPuk:
      let disable = self.controller.getPUK().len == PUKLengthForStatusApp
      self.view.setDisablePopup(disable)
      return
  self.view.setDisablePopup(true)

proc isUserCancelledNfcEvent(keycardFlowType: string, keycardEvent: KeycardEvent): bool =
  if keycardFlowType != ResponseTypeValueKeycardFlowResult:
    return false
  return keycardEvent.cancelled

proc preStateActivities[T](self: Module[T], currFlowType: FlowType, nextStateType: StateType) =
  if nextStateType == StateType.MaxPinRetriesReached or
    nextStateType == StateType.MaxPukRetriesReached or
    nextStateType == StateType.MaxPairingSlotsReached or
    nextStateType == StateType.UnlockKeycardOptions:
      ## in case the card is locked on another device, we're updating its state in the DB
      let (_, flowEvent) = self.controller.getLastReceivedKeycardData()
      self.controller.setCurrentKeycardStateToLocked(flowEvent.keyUid, flowEvent.instanceUID)

  if currFlowType == FlowType.Authentication or
    currFlowType == FlowType.Sign:
      self.view.setLockedPropForKeyPairForProcessing(nextStateType == StateType.MaxPinRetriesReached)

  if currFlowType == FlowType.UnlockKeycard:
    if nextStateType == StateType.UnlockKeycardOptions:
      let (_, flowEvent) = self.controller.getLastReceivedKeycardData()
      let offerPuk = flowEvent.pukRetries > 0
      self.controller.setKeycardData(updatePredefinedKeycardData(self.controller.getKeycardData(), PredefinedKeycardData.OfferPukForUnlock, add = offerPuk))

proc reEvaluateKeyPairForProcessing[T](self: Module[T], currFlowType: FlowType, currStateType: StateType) =
  if currFlowType == FlowType.UnlockKeycard or
    currFlowType == FlowType.RenameKeycard or
    currFlowType == FlowType.ChangeKeycardPin or
    currFlowType == FlowType.ChangeKeycardPuk or
    currFlowType == FlowType.ChangePairingCode or
    currFlowType == FlowType.CreateCopyOfAKeycard:
      if currStateType != StateType.PluginReader and
        currStateType != StateType.ReadingKeycard:
          return
      let (_, flowEvent) = self.controller.getLastReceivedKeycardData()
      var keycardUid = ""
      if self.getKeyPairForProcessing().getKeyUid() == flowEvent.keyUid:
        keycardUid = flowEvent.instanceUID
      self.prepareKeyPairForProcessing(self.getKeyPairForProcessing().getKeyUid(), keycardUid)

proc handleKeycardSyncing[T](self: Module[T]) =
  if not self.controller.keycardSyncingInProgress():
    return
  let kcsFlowType = self.controller.getCurrentKeycardServiceFlow()
  if kcsFlowType == KCSFlowType.GetMetadata:
    let (eventType, flowEvent) = self.controller.getLastReceivedKeycardData()
    if flowEvent.keyUid != self.controller.getKeyUidWhichIsBeingSyncing():
      self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)
      return
    if eventType == ResponseTypeValueKeycardFlowResult and (flowEvent.error.len == 0 or flowEvent.error == ErrorNoData):
      var kpDto = KeycardDto(keycardUid: flowEvent.instanceUID,
        keycardName: flowEvent.cardMetadata.name,
        keycardLocked: false,
        accountsAddresses: @[],
        keyUid: flowEvent.keyUid)
      let alreadySetKeycards = self.controller.getAllKnownKeycards().filter(kp => kp.keycardUid == flowEvent.instanceUID)
      if alreadySetKeycards.len <= 1:
        var accountsToRemove: seq[string]
        if alreadySetKeycards.len == 1:
          accountsToRemove = alreadySetKeycards[0].accountsAddresses
        let appAccounts = self.controller.getWalletAccounts()
        var activeValidPathsToStoreToAKeycard: seq[string]
        var containsPathOutOfTheDefaultStatusDerivationTree = false
        for appAcc in appAccounts:
          if appAcc.keyUid != flowEvent.keyUid:
            continue
          # do not sync if any wallet's account has path out of the default Status derivation tree
          if utils.isPathOutOfTheDefaultStatusDerivationTree(appAcc.path):
            containsPathOutOfTheDefaultStatusDerivationTree = true
            break
          activeValidPathsToStoreToAKeycard.add(appAcc.path)
          var index = -1
          var found = false
          for acc in accountsToRemove:
            index.inc
            if cmpIgnoreCase(acc, appAcc.address) == 0:
              found = true
              break
          if found and index > -1:
            # if account address which is present in the wallet is still present in accounts addresses of a keycard,
            # then it needs to be present in `keypairs` table in db, so remove it from the list
            accountsToRemove.delete(index)
          else:
            # we store to db only accounts we haven't stored before, accounts which are already on a keycard (in metadata)
            # we assume they are already in the db
            kpDto.accountsAddresses.add(appAcc.address)
        if not containsPathOutOfTheDefaultStatusDerivationTree:
          if accountsToRemove.len > 0:
            self.controller.removeMigratedAccountsForKeycard(kpDto.keyUid, kpDto.keycardUid, accountsToRemove)
          if kpDto.accountsAddresses.len > 0:
            self.controller.addKeycardOrAccounts(kpDto, password = "")
          # if all accounts are removed from the app, there is no point in storing empty accounts list to a keycard, cause in that case
          # keypair which is on that keycard won't be known to the app, that means keypair was removed from the app
          if activeValidPathsToStoreToAKeycard.len > 0:
            ##  we need to store paths to a keycard if the num of paths in the app and on a keycard is diffrent
            ## or if the paths are different
            var storeToKeycard = activeValidPathsToStoreToAKeycard.len != flowEvent.cardMetadata.walletAccounts.len
            if not storeToKeycard:
              for wa in flowEvent.cardMetadata.walletAccounts:
                if not utils.arrayContains(activeValidPathsToStoreToAKeycard, wa.path):
                  storeToKeycard = true
                  break
            if storeToKeycard:
              self.controller.runStoreMetadataFlow(flowEvent.cardMetadata.name, self.controller.getPin(), activeValidPathsToStoreToAKeycard)
              return
      elif alreadySetKeycards.len > 1:
        error "it's impossible to have more then one keycard with the same uid", keycarUid=flowEvent.instanceUID
  self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
  self.controller.rebuildKeycards()

method syncKeycardBasedOnAppState*[T](self: Module[T], keyUid: string, pin: string) =
  ## This method must not be called directly. If you want to initiate keycard syncing please emit
  ## `SIGNAL_SHARED_KEYCARD_MODULE_TRY_KEYCARD_SYNC` signal
  if pin.len != PINLengthForStatusApp:
    debug "cannot sync with the pin which doesn't meet app expectations"
    return
  if keyUid.len == 0:
    debug "cannot sync with the empty keyUid"
    return
  self.tmpKeyUid = keyUid
  self.tmpPin = pin
  self.controller.checkKeycardAvailability()

proc proceedWithSyncKeycardBasedOnAppState[T](self: Module[T], keyUid: string, pin: string) =
  self.init(fullConnect = false)
  self.controller.setKeyUidWhichIsBeingSyncing(keyUid)
  self.controller.setPin(pin)
  self.controller.setKeycardSyncingInProgress(true)
  self.controller.runGetMetadataFlow(resolveAddress = true, exportMasterAddr = true, pin)

method onBackActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "sm_cannot resolve current state"
    return
  debug "sm_back_action", currFlow=currStateObj.flowType(), currState=currStateObj.stateType()
  self.preActionActivities(currStateObj.flowType(), currStateObj.stateType())
  currStateObj.executePreBackStateCommand(self.controller)
  let backState = currStateObj.getBackState()
  if backState.isNil:
    return
  self.preStateActivities(backState.flowType(), backState.stateType())
  self.view.setCurrentState(backState)
  currStateObj.executePostBackStateCommand(self.controller)
  debug "sm_back_action - set state", setCurrFlow=backState.flowType(), newCurrState=backState.stateType()

method onCancelActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "sm_cannot resolve current state"
    return
  debug "sm_cancel_action", currFlow=currStateObj.flowType(), currState=currStateObj.stateType()
  self.preActionActivities(currStateObj.flowType(), currStateObj.stateType())
  currStateObj.executeCancelCommand(self.controller)

method onPrimaryActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "sm_cannot resolve current state"
    return
  debug "sm_primary_action", currFlow=currStateObj.flowType(), currState=currStateObj.stateType()
  self.preActionActivities(currStateObj.flowType(), currStateObj.stateType())
  currStateObj.executePrePrimaryStateCommand(self.controller)
  let nextState = currStateObj.getNextPrimaryState(self.controller)
  if nextState.isNil:
    return
  self.preStateActivities(nextState.flowType(), nextState.stateType())
  self.reEvaluateKeyPairForProcessing(currStateObj.flowType(), currStateObj.stateType())
  self.view.setCurrentState(nextState)
  currStateObj.executePostPrimaryStateCommand(self.controller)
  debug "sm_primary_action - set state", setCurrFlow=nextState.flowType(), setCurrState=nextState.stateType()

method onSecondaryActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "sm_cannot resolve current state"
    return
  debug "sm_secondary_action", currFlow=currStateObj.flowType(), currState=currStateObj.stateType()
  self.preActionActivities(currStateObj.flowType(), currStateObj.stateType())
  currStateObj.executePreSecondaryStateCommand(self.controller)
  let nextState = currStateObj.getNextSecondaryState(self.controller)
  if nextState.isNil:
    return
  self.preStateActivities(nextState.flowType(), nextState.stateType())
  self.reEvaluateKeyPairForProcessing(currStateObj.flowType(), currStateObj.stateType())
  self.view.setCurrentState(nextState)
  currStateObj.executePostSecondaryStateCommand(self.controller)
  debug "sm_secondary_action - set state", setCurrFlow=nextState.flowType(), setCurrState=nextState.stateType()

method onTertiaryActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "sm_cannot resolve current state"
    return
  debug "sm_tertiary_action", currFlow=currStateObj.flowType(), currState=currStateObj.stateType()
  self.preActionActivities(currStateObj.flowType(), currStateObj.stateType())
  currStateObj.executePreTertiaryStateCommand(self.controller)
  let nextState = currStateObj.getNextTertiaryState(self.controller)
  if nextState.isNil:
    return
  self.preStateActivities(nextState.flowType(), nextState.stateType())
  self.reEvaluateKeyPairForProcessing(currStateObj.flowType(), currStateObj.stateType())
  self.view.setCurrentState(nextState)
  currStateObj.executePostTertiaryStateCommand(self.controller)
  debug "sm_tertiary_action - set state", setCurrFlow=nextState.flowType(), setCurrState=nextState.stateType()

method onKeycardResponse*[T](self: Module[T], keycardFlowType: string, keycardEvent: KeycardEvent) =
  if isUserCancelledNfcEvent(keycardFlowType, keycardEvent):
    info "nfc reader dismissed, terminating keycard flow", flowType=keycardFlowType, error=keycardEvent.error
    self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false, allowKeycardSync = false)
    return
  if self.controller.keycardSyncingInProgress():
    self.handleKeycardSyncing()
    return
  ## Check local state first, in case postponed flow is run
  if not self.tmpLocalState.isNil:
    let nextState = self.tmpLocalState.resolveKeycardNextState(keycardFlowType, keycardEvent, self.controller)
    defer:
      self.tmpLocalState.delete
      self.tmpLocalState = nil
    if nextState.isNil:
      return
    self.preStateActivities(nextState.flowType(), nextState.stateType())
    self.reEvaluateKeyPairForProcessing(self.tmpLocalState.flowType(), self.tmpLocalState.stateType())
    self.view.setCurrentState(nextState)
    debug "sm_on_keycard_response - from_local - set state", setCurrFlow=nextState.flowType(), setCurrState=nextState.stateType()
    return
  ## Check regular flows
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    return
  debug "sm_on_keycard_response", currFlow=currStateObj.flowType(), currState=currStateObj.stateType()
  let nextState = currStateObj.resolveKeycardNextState(keycardFlowType, keycardEvent, self.controller)
  if nextState.isNil:
    return
  self.preStateActivities(nextState.flowType(), nextState.stateType())
  self.reEvaluateKeyPairForProcessing(currStateObj.flowType(), currStateObj.stateType())
  self.view.setCurrentState(nextState)
  debug "sm_on_keycard_response - set state", setCurrFlow=nextState.flowType(), setCurrState=nextState.stateType()

proc prepareKeyPairItemForAuthentication[T](self: Module[T], keyUid: string) =
  var item = newKeyPairItem()
  let items = keypairs.buildKeyPairsList(self.controller.getKeypairs(), excludeAlreadyMigratedPairs = false,
    excludePrivateKeyKeypairs = false)
  for it in items:
    if it.getKeyUid() == keyUid:
      item = it
      break
  if item.getName().len == 0:
    error "sm_cannot find keypair among known keypairs for the given keyUid for authentication", keyUid=keyUid
  item.setPubKey("")
  item.setImage("")
  item.setIcon("keycard")
  item.setPairType(KeyPairType.Unknown.int)
  self.view.setKeyPairForProcessing(item)

method setKeyPairForProcessing*[T](self: Module[T], item: KeyPairItem) =
  if item.isNil:
    error "keypair item must not be nil"
    return
  self.view.setKeyPairForProcessing(item)

method prepareKeyPairForProcessing*[T](self: Module[T], keyUid: string, keycardUid = "") =
  var item = newKeyPairItem()
  let items = keypairs.buildKeyPairsList(self.controller.getKeypairs(), excludeAlreadyMigratedPairs = false,
    excludePrivateKeyKeypairs = false)
  for it in items:
    if it.getKeyUid() == keyUid:
      item = it
      break
  if item.getName().len == 0:
    error "sm_cannot find keypair among known keypairs for the given keyUid for processing", keyUid=keyUid
  if keycardUid.len > 0:
    let keyPairs = self.controller.getAllKnownKeycards()
    for kp in keyPairs:
      if kp.keycardUid == keycardUid:
        item.setLocked(kp.keycardLocked)
  if item.getPairType() != KeyPairType.Profile.int:
    item.setIcon("keycard")
  self.view.setKeyPairForProcessing(item)

proc displayKeycardFlowStartedState[T](self: Module[T], flowType: FlowType, backState: State, displayStartedState: bool = true) =
  self.tmpLocalState = newReadingKeycardState(flowType, backState)
  if not displayStartedState:
    return
  let keycardFlowStartedState = newKeycardFlowStartedState(flowType, backState)
  self.view.setCurrentState(keycardFlowStartedState)
  self.controller.readyToDisplayPopup()
  debug "sm_cannot - display reading state", setCurrFlow=keycardFlowStartedState.flowType(), setCurrState=keycardFlowStartedState.stateType()

method runFlow*[T](self: Module[T], flowToRun: FlowType, keyUid = "", bip44Paths: seq[string] = @[], txHash = "", forceFlow = false, returnToFlow = FlowType.General) =
  ## In case of `Authentication` or `Sign` flow, if keyUid is provided, that keypair will be authenticated,
  ## otherwise the logged in profile will be authenticated.
  if flowToRun == FlowType.General:
    self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)
    error "sm_cannot run an general flow"
    return
  self.tmpFlowToRun = flowToRun
  self.tmpKeyUid = keyUid
  self.tmpBip44Paths = bip44Paths
  self.tmpTxHash = txHash
  self.tmpForceFlow = forceFlow
  self.tmpReturnToFlow = returnToFlow
  self.controller.checkKeycardAvailability()

proc proceedWithRunFlow[T](self: Module[T], flowToRun: FlowType, keyUid: string, bip44Paths: seq[string], txHash: string, forceFlow: bool, returnToFlow: FlowType) =
  self.init()
  self.view.setForceFlow(forceFlow)
  self.view.setReturnToFlow(returnToFlow)
  if flowToRun == FlowType.FactoryReset:
    if keyUid.len > 0:
      self.prepareKeyPairForProcessing(keyUid)
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runGetMetadataFlow(resolveAddress = true)
    return
  if flowToRun == FlowType.SetupNewKeycard:
    let items = keypairs.buildKeyPairsList(self.controller.getKeypairs(), excludeAlreadyMigratedPairs = true,
      excludePrivateKeyKeypairs = false)
    if keyUid.len == 0:
      self.view.createKeyPairModel(items)
      self.view.setCurrentState(newSelectExistingKeyPairState(flowToRun, nil))
      self.controller.readyToDisplayPopup()
    else:
      let filteredItems = items.filter(x => x.getKeyUid() == keyUid)
      if filteredItems.len != 1:
        error "sm_cannot resolve a keypair being migrated"
        self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)
        return
      self.setSelectedKeyPair(filteredItems[0])
      self.displayKeycardFlowStartedState(flowToRun, nil)
      self.controller.runLoadAccountFlow()
    return
  if flowToRun == FlowType.Authentication:
    self.runningFlow = flowToRun
    if keyUid.len == 0 or keyUid == singletonInstance.userProfile.getKeyUid():
      if singletonInstance.userProfile.getIsKeycardUser():
        self.prepareKeyPairItemForAuthentication(singletonInstance.userProfile.getKeyUid())
        self.displayKeycardFlowStartedState(flowToRun, nil)
        self.controller.runAuthenticationFlow(singletonInstance.userProfile.getKeyUid(), bip44Paths)
        if singletonInstance.userProfile.getUsingBiometricLogin():
          self.controller.connectKeychainSignals()
          self.controller.tryToObtainDataFromKeychain()
        return
      self.view.setCurrentState(newEnterPasswordState(flowToRun, nil))
      if singletonInstance.userProfile.getUsingBiometricLogin():
        self.displayKeycardFlowStartedState(flowToRun, nil, displayStartedState = false)
        self.controller.connectKeychainSignals()
        self.controller.tryToObtainDataFromKeychain()
      else:
        self.authenticationPopupIsAlreadyRunning = true
        self.controller.readyToDisplayPopup()
      return
    else:
      self.prepareKeyPairItemForAuthentication(keyUid)
      self.displayKeycardFlowStartedState(flowToRun, nil)
      self.controller.runAuthenticationFlow(keyUid, bip44Paths)
      if singletonInstance.userProfile.getUsingBiometricLogin():
        self.controller.connectKeychainSignals()
        self.controller.tryToObtainDataFromKeychain()
      return
  if flowToRun == FlowType.Sign:
    if bip44Paths.len == 0 or bip44Paths[0].len == 0:
      error "sm_cannot path must be set when signing"
      self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)
      return
    if txHash.len == 0:
      error "sm_cannot txHash must be set when signing"
      self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)
      return
    var finalKeyUid = keyUid
    if keyUid.len == 0:
      finalKeyUid = singletonInstance.userProfile.getKeyUid()
    let keypair = self.controller.getKeypairByKeyUid(finalKeyUid)
    if keypair.isNil:
      error "sm_cannot resolve a keypair for signing"
      self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)
      return
    if not keypair.migratedToKeycard():
      error "sm_cannot sign flow is spcified only for keycard migrated keypairs"
      self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)
      return
    self.runningFlow = flowToRun
    self.prepareKeyPairItemForAuthentication(keyUid)
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runSignFlow(keyUid, bip44Paths[0], txHash)
    if finalKeyUid == singletonInstance.userProfile.getKeyUid() and
      singletonInstance.userProfile.getUsingBiometricLogin():
        self.controller.connectKeychainSignals()
        self.controller.tryToObtainDataFromKeychain()
    return
  if flowToRun == FlowType.UnlockKeycard:
    ## since we can run unlock keycard flow from an already running flow, in order to avoid changing displayed keypair
    ## (locked keypair) we have to set keycard uid of a keycard used in the flow we're jumping from to `UnlockKeycard` flow.
    self.prepareKeyPairForProcessing(keyUid, self.controller.getKeycardUid())
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runGetMetadataFlow(resolveAddress = true)
    return
  if flowToRun == FlowType.DisplayKeycardContent:
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runGetMetadataFlow(resolveAddress = true)
    return
  if flowToRun == FlowType.RenameKeycard:
    self.prepareKeyPairForProcessing(keyUid)
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runGetMetadataFlow(resolveAddress = true) # we're firstly displaying the keycard content
    return
  if flowToRun == FlowType.ChangeKeycardPin:
    self.prepareKeyPairForProcessing(keyUid)
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runChangePinFlow()
    return
  if flowToRun == FlowType.ChangeKeycardPuk:
    self.prepareKeyPairForProcessing(keyUid)
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runChangePukFlow()
    return
  if flowToRun == FlowType.ChangePairingCode:
    self.prepareKeyPairForProcessing(keyUid)
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runChangePairingFlow()
    return
  if flowToRun == FlowType.CreateCopyOfAKeycard:
    self.prepareKeyPairForProcessing(keyUid)
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runGetMetadataFlow(resolveAddress = true)
    return
  if flowToRun == FlowType.SetupNewKeycardNewSeedPhrase:
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runLoadAccountFlow()
    return
  if flowToRun == FlowType.SetupNewKeycardOldSeedPhrase:
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runLoadAccountFlow()
    return
  if flowToRun == FlowType.ImportFromKeycard:
    self.displayKeycardFlowStartedState(flowToRun, nil)
    self.controller.runGetMetadataFlow(resolveAddress = true, exportMasterAddr = true)
    return
  if flowToRun == FlowType.MigrateFromKeycardToApp:
    if keyUid.len == 0:
      error "sm_cannot run a migration from keycard to app flow without knowing in advance a keypair being migrated"
      self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)
      return
    self.prepareKeyPairForProcessing(keyUid)
    self.view.setCurrentState(newMigrateKeypairToAppState(flowToRun, nil))
    self.controller.readyToDisplayPopup()
    return
  if flowToRun == FlowType.MigrateFromAppToKeycard:
    if keyUid != singletonInstance.userProfile.getKeyUid():
      error "sm_cannot MigrateFromAppToKeycard flow can be run only for the profile keypair and should not be run directly"
      self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = false)
      quit() # quit the app
    self.prepareKeyPairForProcessing(keyUid)
    self.view.setCurrentState(newMigrateKeypairToKeycardState(flowToRun, nil))
    self.controller.readyToDisplayPopup()
    return

method setSelectedKeyPair*[T](self: Module[T], item: KeyPairItem) =
  var paths: seq[string]
  var keycardDto = KeycardDto(keycardUid: "", # will be set during migration
    keycardName: item.getName(),
    keycardLocked: item.getLocked(),
    keyUid: item.getKeyUid())
  for a in item.getAccountsModel().getItems():
    paths.add(a.getPath())
    keycardDto.accountsAddresses.add(a.getAddress())
  self.controller.setSelectedKeyPair(isProfile = item.getPairType() == KeyPairType.Profile.int,
    paths, keycardDto)
  self.setKeyPairForProcessing(item)

method onTokensRebuilt*[T](self: Module[T], accountAddresses: seq[string], assets: seq[AssetGroupItem]) =
  if self.getKeyPairForProcessing().isNil and self.getKeyPairHelper().isNil:
    return
  var totalTokenBalance = 0.0
  let currency = self.controller.getCurrency()
  let currencyFormat = self.controller.getCurrencyFormat(currency)
  for address in accountAddresses:
    let accAdd = address
    for assetGroupItem in assets:
      let filteredBalances = assetGroupItem.balancesPerAccount.filter(b =>  b.account == accAdd)
      for balanceItem in filteredBalances:
          totalTokenBalance += self.controller.getCurrencyValueForToken(balanceItem.tokenKey, balanceItem.balance)
      let balance =  currencyAmountToItem(totalTokenBalance, currencyFormat)
      if not self.getKeyPairForProcessing().isNil:
        self.getKeyPairForProcessing().setBalanceForAddress(address, balance)
      if not self.getKeyPairHelper().isNil:
        self.getKeyPairHelper().setBalanceForAddress(address, balance)

proc buildKeyPairItemBasedOnCardMetadata[T](self: Module[T], cardMetadata: CardMetadata):
  tuple[item: KeyPairItem, knownKeyPair: bool] =
  result.item = newKeyPairItem(keyUid = "",
    pubKey = "",
    locked = false,
    name = cardMetadata.name,
    image = "",
    icon = "keycard")
  let currKp = self.getKeyPairForProcessing()
  if not currKp.isNil:
    result.item.setKeyUid(currKp.getKeyUid())
    result.item.setPubKey(currKp.getPubKey())
  result.knownKeyPair = true
  # resolve known accounts first
  let accounts = self.controller.getWalletAccounts()
  for acc in accounts:
    for cardAcc in cardMetadata.walletAccounts:
      if acc.isChat or acc.walletType == WalletTypeWatch or cmpIgnoreCase(acc.address, cardAcc.address) != 0:
        continue
      var icon = ""
      if acc.emoji.len == 0:
        icon = "wallet"
      result.item.addAccount(newKeyPairAccountItem(acc.name, acc.path, acc.address, acc.publicKey, acc.emoji, acc.colorId, icon,
        balance = newCurrencyAmount(), balanceFetched = true, operability = acc.operable))
  # handle unknown accounts
  var addressesToFetchBalanceFor: seq[string] = @[]
  var unknownAccountNumber = 0
  for cardAcc in cardMetadata.walletAccounts:
    var found = false
    for acc in accounts:
      if cmpIgnoreCase(acc.address, cardAcc.address) == 0:
        found = true
        break
    if not found:
      let (balance, balanceFetched) = self.controller.getOrFetchBalanceForAddressInPreferredCurrency(cardAcc.address)
      if not balanceFetched:
        addressesToFetchBalanceFor.add(cardAcc.address)
      result.knownKeyPair = false
      unknownAccountNumber.inc
      let currencyFormat = self.controller.getCurrencyFormat(self.controller.getCurrency())
      let name = atc.KEYCARD_ACCOUNT_NAME_OF_UNKNOWN_WALLET_ACCOUNT & $unknownAccountNumber
      result.item.addAccount(newKeyPairAccountItem(name, cardAcc.path, cardAcc.address, pubKey = cardAcc.publicKey,
        emoji = "", colorId = "undefined", icon = "wallet", currencyAmountToItem(balance, currencyFormat), balanceFetched))
  self.controller.buildAllTokens(addressesToFetchBalanceFor, forceRefresh = true)

method updateKeyPairForProcessing*[T](self: Module[T], cardMetadata: CardMetadata) =
  let(item, knownKeyPair) = self.buildKeyPairItemBasedOnCardMetadata(cardMetadata)
  self.view.setKeyPairStoredOnKeycardIsKnown(knownKeyPair)
  self.view.setKeyPairForProcessing(item)

method updateKeyPairHelper*[T](self: Module[T], cardMetadata: CardMetadata) =
  let(item, knownKeyPair) = self.buildKeyPairItemBasedOnCardMetadata(cardMetadata)
  self.view.setKeyPairStoredOnKeycardIsKnown(knownKeyPair)
  self.view.setKeyPairHelper(item)

method onUserAuthenticated*[T](self: Module[T], password: string, pin: string) =
  if password.len == 0:
    self.view.setDisablePopup(false)
    return
  let flowType = self.getCurrentFlowType()
  if flowType == FlowType.SetupNewKeycard or
    flowType == FlowType.MigrateFromKeycardToApp or
    flowType == FlowType.MigrateFromAppToKeycard:
      self.controller.setPassword(password)
      self.onTertiaryActionClicked()

method keychainObtainedDataFailure*[T](self: Module[T], errorDescription: string, errorType: string) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil or
    currStateObj.stateType() == StateType.EnterPassword or
    currStateObj.stateType() == StateType.WrongPassword or
    currStateObj.stateType() == StateType.BiometricsPasswordFailed:
      self.view.setCurrentState(newBiometricsPasswordFailedState(FlowType.Authentication, nil))
      if not self.authenticationPopupIsAlreadyRunning:
        self.authenticationPopupIsAlreadyRunning = true
        self.controller.readyToDisplayPopup()
      return
  if not currStateObj.isNil:
    self.view.setCurrentState(newBiometricsPinFailedState(self.runningFlow, nil))

method keychainObtainedDataSuccess*[T](self: Module[T], data: string) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil or
    currStateObj.stateType() == StateType.EnterPassword or
    currStateObj.stateType() == StateType.WrongPassword or
    currStateObj.stateType() == StateType.BiometricsPasswordFailed:
      if self.controller.verifyPassword(data):
        self.controller.setPassword(data)
        self.controller.terminateCurrentFlow(lastStepInTheCurrentFlow = true)
      else:
        self.view.setCurrentState(newEnterBiometricsPasswordState(FlowType.Authentication, nil))
        if not self.authenticationPopupIsAlreadyRunning:
          self.authenticationPopupIsAlreadyRunning = true
          self.controller.readyToDisplayPopup()
      return
  if not currStateObj.isNil:
    if data.len == PINLengthForStatusApp:
      self.controller.setPin(data)
      self.controller.enterKeycardPin(data)
    else:
      self.view.setCurrentState(newBiometricsPinInvalidState(self.runningFlow, nil))

method remainingAccountCapacity*[T](self: Module[T]): int =
  return self.controller.remainingAccountCapacity()

method keycardPinChanged*[T](self: Module[T], pin: string) =
  self.view.keycardPinChanged(pin)

{.pop.}
