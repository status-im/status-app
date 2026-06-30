import nimqml
import io_interface
import internal/[state, state_wrapper]
import ../../shared_models/[keypair_model, keypair_item]

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      returnToFlow: FlowType
      forceFlow: bool # used to disable any possibility of closing the popup, the user is forced to complete the flow or forcibly close the app (no other way to close the popup)
      disablePopup: bool # used to disable popup after each action, to block users do multiple clikcs which the action is ongoing
      currentState: StateWrapper
      currentStateVariant: QVariant
      keyPairModel: KeyPairModel
      keyPairModelVariant: QVariant
      keyPairStoredOnKeycardIsKnown: bool
      keyPairHelper: KeyPairItem
      keyPairHelperVariant: QVariant
      keyPairForProcessing: KeyPairItem
      keyPairForProcessingVariant: QVariant
      keycardData: string # used to temporary store the data coming from keycard, depends on current state different data may be stored
      remainingAttempts: int

  proc delete*(self: View)

  proc onBackActionClicked*(self: View) {.slot.} =
    self.delegate.onBackActionClicked()

  proc onCancelActionClicked*(self: View) {.slot.} =
    self.delegate.onCancelActionClicked()

  proc onPrimaryActionClicked*(self: View) {.slot.} =
    self.delegate.onPrimaryActionClicked()

  proc onSecondaryActionClicked*(self: View) {.slot.} =
    self.delegate.onSecondaryActionClicked()

  proc onTertiaryActionClicked*(self: View) {.slot.} =
    self.delegate.onTertiaryActionClicked()

  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.currentState = newStateWrapper()
    result.currentStateVariant = newQVariant(result.currentState)
    result.remainingAttempts = -1
    result.returnToFlow = FlowType.General
    result.forceFlow = false
    result.disablePopup = false

    discard QObject.connect(result.currentState, backActionClicked, result, onBackActionClicked, ConnectionType.QueuedConnection)
    discard QObject.connect(result.currentState, cancelActionClicked, result, onCancelActionClicked, ConnectionType.QueuedConnection)
    discard QObject.connect(result.currentState, primaryActionClicked, result, onPrimaryActionClicked, ConnectionType.QueuedConnection)
    discard QObject.connect(result.currentState, secondaryActionClicked, result, onSecondaryActionClicked, ConnectionType.QueuedConnection)
    discard QObject.connect(result.currentState, tertiaryActionClicked, result, onTertiaryActionClicked, ConnectionType.QueuedConnection)

  proc keycardPinChanged*(self: View, pin: string) {.signal.}

  proc returnToFlowChanged*(self: View) {.signal.}
  proc getReturnToFlowStr(self: View): string {.slot.} =
    return $self.returnToFlow
  QtProperty[string] returnToFlow:
    read = getReturnToFlowStr
    notify = returnToFlowChanged
  proc getReturnToFlow*(self: View): FlowType =
    return self.returnToFlow
  proc setReturnToFlow*(self: View, value: FlowType) =
    self.returnToFlow = value
    self.returnToFlowChanged()

  proc forceFlowChanged*(self: View) {.signal.}
  proc getForceFlow*(self: View): bool {.slot.} =
    return self.forceFlow
  QtProperty[bool] forceFlow:
    read = getForceFlow
    notify = forceFlowChanged
  proc setForceFlow*(self: View, value: bool) =
    self.forceFlow = value
    self.forceFlowChanged()

  proc diablePopupChanged*(self: View) {.signal.}
  proc getDisablePopup*(self: View): bool {.slot.} =
    return self.disablePopup
  QtProperty[bool] disablePopup:
    read = getDisablePopup
    notify = diablePopupChanged
  proc setDisablePopup*(self: View, value: bool) =
    self.disablePopup = value
    self.diablePopupChanged()

  proc currentStateObj*(self: View): State =
    return self.currentState.getStateObj()

  proc setCurrentState*(self: View, state: State) =
    self.setDisablePopup(false)
    self.currentState.setStateObj(state)
  proc getCurrentState(self: View): QVariant {.slot.} =
    return self.currentStateVariant
  QtProperty[QVariant] currentState:
    read = getCurrentState

  proc keycardDataChanged*(self: View) {.signal.}
  proc setKeycardData*(self: View, value: string) {.slot.} =
    if self.keycardData == value:
      return
    self.keycardData = value
    self.keycardDataChanged()
  proc getKeycardData*(self: View): string {.slot.} =
    return self.keycardData
  QtProperty[string] keycardData:
    read = getKeycardData
    write = setKeycardData
    notify = keycardDataChanged

  proc remainingAttemptsChanged*(self: View) {.signal.}
  proc setRemainingAttempts*(self: View, value: int) =
    if self.remainingAttempts == value:
      return
    self.remainingAttempts = value
    self.remainingAttemptsChanged()
  proc getRemainingAttempts*(self: View): int {.slot.} =
    return self.remainingAttempts
  QtProperty[int] remainingAttempts:
    read = getRemainingAttempts
    notify = remainingAttemptsChanged

  proc keyPairModel*(self: View): KeyPairModel =
    return self.keyPairModel

  proc keyPairModelChanged(self: View) {.signal.}
  proc getKeyPairModel(self: View): QVariant {.slot.} =
    if self.keyPairModelVariant.isNil:
      return newQVariant()
    return self.keyPairModelVariant
  QtProperty[QVariant] keyPairModel:
    read = getKeyPairModel
    notify = keyPairModelChanged

  proc createKeyPairModel*(self: View, items: seq[KeyPairItem]) =
    if self.keyPairModel.isNil:
      self.keyPairModel = newKeyPairModel()
    if self.keyPairModelVariant.isNil:
      self.keyPairModelVariant = newQVariant(self.keyPairModel)
    self.keyPairModel.setItems(items)
    self.keyPairModelChanged()

  proc setSelectedKeyPair*(self: View, keyUid: string) {.slot.} =
    let item = self.keyPairModel.findItemByKeyUid(keyUid)
    self.delegate.setSelectedKeyPair(item)

  proc getKeyPairStoredOnKeycardIsKnown*(self: View): bool {.slot.} =
    return self.keyPairStoredOnKeycardIsKnown
  QtProperty[bool] keyPairStoredOnKeycardIsKnown:
    read = getKeyPairStoredOnKeycardIsKnown
  proc setKeyPairStoredOnKeycardIsKnown*(self: View, value: bool) =
    self.keyPairStoredOnKeycardIsKnown = value

  proc getKeyPairForProcessing*(self: View): KeyPairItem =
    return self.keyPairForProcessing
  proc getKeyPairForProcessingAsVariant*(self: View): QVariant {.slot.} =
    if self.keyPairForProcessingVariant.isNil:
      return newQVariant()
    return self.keyPairForProcessingVariant
  QtProperty[QVariant] keyPairForProcessing:
    read = getKeyPairForProcessingAsVariant
  proc setKeyPairForProcessing*(self: View, item: KeyPairItem) =
    if self.keyPairForProcessing.isNil:
      self.keyPairForProcessing = newKeyPairItem()
    if self.keyPairForProcessingVariant.isNil:
      self.keyPairForProcessingVariant = newQVariant(self.keyPairForProcessing)
    self.keyPairForProcessing.setItem(item)
  proc setLockedPropForKeyPairForProcessing*(self: View, locked: bool) =
    if self.keyPairForProcessing.isNil:
      return
    self.keyPairForProcessing.setLocked(locked)

  proc getKeyPairHelper*(self: View): KeyPairItem =
    return self.keyPairHelper
  proc getKeyPairHelperAsVariant*(self: View): QVariant {.slot.} =
    if self.keyPairHelperVariant.isNil:
      return newQVariant()
    return self.keyPairHelperVariant
  QtProperty[QVariant] keyPairHelper:
    read = getKeyPairHelperAsVariant
  proc setKeyPairHelper*(self: View, item: KeyPairItem) =
    if self.keyPairHelper.isNil:
      self.keyPairHelper = newKeyPairItem()
    if self.keyPairHelperVariant.isNil:
      self.keyPairHelperVariant = newQVariant(self.keyPairHelper)
    self.keyPairHelper.setItem(item)

  proc setPin*(self: View, value: string) {.slot.} =
    self.delegate.setPin(value)

  proc setPuk*(self: View, value: string) {.slot.} =
    self.delegate.setPuk(value)

  proc setPassword*(self: View, value: string) {.slot.} =
    self.delegate.setPassword(value)

  proc setNewPassword*(self: View, value: string) {.slot.} =
    self.delegate.setNewPassword(value)

  proc getNewPassword*(self: View): string {.slot.} =
    self.delegate.getNewPassword()

  proc getNameFromKeycard*(self: View): string {.slot.} =
    return self.delegate.getNameFromKeycard()

  proc setPairingCode*(self: View, value: string) {.slot.} =
    self.delegate.setPairingCode(value)

  proc checkRepeatedKeycardPinWhileTyping*(self: View, pin: string): bool {.slot.} =
    return self.delegate.checkRepeatedKeycardPinWhileTyping(pin)

  proc checkRepeatedKeycardPukWhileTyping*(self: View, puk: string): bool {.slot.} =
    return self.delegate.checkRepeatedKeycardPukWhileTyping(puk)

  proc getMnemonic*(self: View): string {.slot.} =
    return self.delegate.getMnemonic()

  proc setSeedPhrase*(self: View, value: string) {.slot.} =
    self.delegate.setSeedPhrase(value)

  proc getSeedPhrase*(self: View): string {.slot.} =
    return self.delegate.getSeedPhrase()

  proc validSeedPhrase*(self: View, value: string): bool {.slot.} =
    return self.delegate.validSeedPhrase(value)

  proc migratingProfileKeyPair*(self: View): bool {.slot.} =
    return self.delegate.migratingProfileKeyPair()

  proc remainingAccountCapacity*(self: View): int {.slot.} =
    return self.delegate.remainingAccountCapacity()

  proc delete*(self: View) =
    self.QObject.delete

