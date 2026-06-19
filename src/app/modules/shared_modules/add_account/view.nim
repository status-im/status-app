import nimqml
import dotherside_ext
import io_interface
import internal/[state, state_wrapper]
import ../../shared_models/[keypair_model, keypair_item, derived_address_model]

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      currentState: StateWrapper
      currentStateVariant: QVariant
      originModel: KeyPairModel
      originModelVariant: QVariant
      selectedOrigin: KeyPairItem
      selectedOriginVariant: QVariant
      derivedAddressModel: DerivedAddressModel
      derivedAddressModelVariant: QVariant
      selectedDerivedAddress: DerivedAddressItem
      selectedDerivedAddressVariant: QVariant
      watchOnlyAccAddress: DerivedAddressItem
      watchOnlyAccAddressVariant: QVariant
      privateKeyAccAddress: DerivedAddressItem
      privateKeyAccAddressVariant: QVariant
      accountName: string
      newKeyPairName: string
      selectedEmoji: string
      selectedColorId: string
      storedAccountName: string # used only in edit mode
      storedSelectedEmoji: string # used only in edit mode
      storedSelectedColorId: string # used only in edit mode
      derivationPath: string
      suggestedDerivationPath: string
      actionAuthenticated: bool
      scanningForActivityIsOngoing: bool
      editMode: bool
      disablePopup: bool # unables user to interact with the popup (action buttons are disabled as well as close popup button)

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

  proc onQuaternaryActionClicked*(self: View) {.slot.} =
    self.delegate.onQuaternaryActionClicked()

  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.currentState = newStateWrapper()
    result.currentStateVariant = newQVariant(result.currentState)
    result.originModel = newKeyPairModel()
    result.originModelVariant = newQVariant(result.originModel)
    result.selectedOrigin = newKeyPairItem()
    result.selectedOriginVariant = newQVariant(result.selectedOrigin)
    result.derivedAddressModel = newDerivedAddressModel()
    result.derivedAddressModelVariant = newQVariant(result.derivedAddressModel)
    result.selectedDerivedAddress = newDerivedAddressItem()
    result.selectedDerivedAddressVariant = newQVariant(result.selectedDerivedAddress)
    result.watchOnlyAccAddress = newDerivedAddressItem()
    result.watchOnlyAccAddressVariant = newQVariant(result.watchOnlyAccAddress)
    result.privateKeyAccAddress = newDerivedAddressItem()
    result.privateKeyAccAddressVariant = newQVariant(result.privateKeyAccAddress)
    result.actionAuthenticated = false
    result.scanningForActivityIsOngoing = false
    result.editMode = false
    result.disablePopup = false

    discard QObject.connect(result.currentState, backActionClicked, result, onBackActionClicked, ConnectionType.QueuedConnection)
    discard QObject.connect(result.currentState, cancelActionClicked, result, onCancelActionClicked, ConnectionType.QueuedConnection)
    discard QObject.connect(result.currentState, primaryActionClicked, result, onPrimaryActionClicked, ConnectionType.QueuedConnection)
    discard QObject.connect(result.currentState, secondaryActionClicked, result, onSecondaryActionClicked, ConnectionType.QueuedConnection)
    discard QObject.connect(result.currentState, tertiaryActionClicked, result, onTertiaryActionClicked, ConnectionType.QueuedConnection)
    discard QObject.connect(result.currentState, quaternaryActionClicked, result, onQuaternaryActionClicked, ConnectionType.QueuedConnection)

  proc currentStateObj*(self: View): State =
    return self.currentState.getStateObj()

  proc setCurrentState*(self: View, state: State) =
    self.currentState.setStateObj(state)
  proc getCurrentState(self: View): QVariant {.slot.} =
    return self.currentStateVariant
  QtProperty[QVariant] currentState:
    read = getCurrentState

  proc editModeChanged*(self: View) {.signal.}
  proc getEditMode*(self: View): bool {.slot.} =
    return self.editMode
  QtProperty[bool] editMode:
    read = getEditMode
    notify = editModeChanged
  proc setEditMode*(self: View, value: bool) =
    self.editMode = value
    self.editModeChanged()

  proc disablePopupChanged*(self: View) {.signal.}
  proc getDisablePopup*(self: View): bool {.slot.} =
    return self.disablePopup
  QtProperty[bool] disablePopup:
    read = getDisablePopup
    notify = disablePopupChanged
  proc setDisablePopup*(self: View, value: bool) =
    self.disablePopup = value
    self.disablePopupChanged()

  proc getSeedPhrase*(self: View): string {.slot.} =
    return self.delegate.getSeedPhrase()

  proc originModelChanged*(self: View) {.signal.}
  proc getOriginModel*(self: View): QVariant {.slot.} =
    if self.originModelVariant.isNil:
      return newQVariant()
    return self.originModelVariant
  QtProperty[QVariant] originModel:
    read = getOriginModel
    notify = originModelChanged

  proc originModel*(self: View): KeyPairModel =
    return self.originModel

  proc setOriginModelItems*(self: View, items: seq[KeyPairItem]) =
    self.originModel.setItems(items)
    self.originModelChanged()

  proc getSelectedOrigin*(self: View): KeyPairItem =
    return self.selectedOrigin
  proc getSelectedOriginAsVariant*(self: View): QVariant {.slot.} =
    return self.selectedOriginVariant
  QtProperty[QVariant] selectedOrigin:
    read = getSelectedOriginAsVariant

  proc setSelectedOrigin*(self: View, item: KeyPairItem) =
    self.selectedOrigin.setItem(item)

  proc getDerivedAddressModel(self: View): QVariant {.slot.} =
    if self.derivedAddressModelVariant.isNil:
      return newQVariant()
    return self.derivedAddressModelVariant
  QtProperty[QVariant] derivedAddressModel:
    read = getDerivedAddressModel

  proc derivedAddressModel*(self: View): DerivedAddressModel =
    return self.derivedAddressModel

  proc getSelectedDerivedAddress*(self: View): DerivedAddressItem =
    return self.selectedDerivedAddress

  proc selectedDerivedAddressChanged*(self: View) {.signal.}
  proc getSelectedDerivedAddressVariant*(self: View): QVariant {.slot.} =
    return self.selectedDerivedAddressVariant
  QtProperty[QVariant] selectedDerivedAddress:
    read = getSelectedDerivedAddressVariant
    notify = selectedDerivedAddressChanged

  proc setSelectedDerivedAddress*(self: View, item: DerivedAddressItem) =
    self.selectedDerivedAddress.setItem(item)
    self.selectedDerivedAddressChanged()

  proc getWatchOnlyAccAddress*(self: View): DerivedAddressItem =
    return self.watchOnlyAccAddress

  proc watchOnlyAccAddressChanged*(self: View) {.signal.}
  proc getWatchOnlyAccAddressVariant*(self: View): QVariant {.slot.} =
    return self.watchOnlyAccAddressVariant
  QtProperty[QVariant] watchOnlyAccAddress:
    read = getWatchOnlyAccAddressVariant
    notify = watchOnlyAccAddressChanged

  proc setWatchOnlyAccAddress*(self: View, item: DerivedAddressItem) =
    self.watchOnlyAccAddress.setItem(item)
    self.watchOnlyAccAddressChanged()

  proc getPrivateKeyAccAddress*(self: View): DerivedAddressItem =
    return self.privateKeyAccAddress

  proc privateKeyAccAddressChanged*(self: View) {.signal.}
  proc getPrivateKeyAccAddressVariant*(self: View): QVariant {.slot.} =
    return self.privateKeyAccAddressVariant
  QtProperty[QVariant] privateKeyAccAddress:
    read = getPrivateKeyAccAddressVariant
    notify = privateKeyAccAddressChanged

  proc setPrivateKeyAccAddress*(self: View, item: DerivedAddressItem) =
    self.privateKeyAccAddress.setItem(item)
    self.privateKeyAccAddressChanged()

  proc actionAuthenticatedChanged*(self: View) {.signal.}
  proc getActionAuthenticated*(self: View): bool {.slot.} =
    return self.actionAuthenticated
  proc setActionAuthenticated*(self: View, value: bool) {.slot.} =
    self.actionAuthenticated = value
    self.actionAuthenticatedChanged()
  QtProperty[bool] actionAuthenticated:
    read = getActionAuthenticated
    write = setActionAuthenticated
    notify = actionAuthenticatedChanged

  proc scanningForActivityChanged*(self: View) {.signal.}
  proc getScanningForActivityIsOngoing*(self: View): bool {.slot.} =
    return self.scanningForActivityIsOngoing
  proc setScanningForActivityIsOngoing*(self: View, value: bool) {.slot.} =
    self.scanningForActivityIsOngoing = value
    self.scanningForActivityChanged()
  QtProperty[bool] scanningForActivityIsOngoing:
    read = getScanningForActivityIsOngoing
    write = setScanningForActivityIsOngoing
    notify = scanningForActivityChanged

  proc accountNameChanged*(self: View) {.signal.}
  proc setAccountName*(self: View, value: string) {.slot.} =
    if self.accountName == value:
      return
    self.accountName = value
    self.accountNameChanged()
  proc getAccountName*(self: View): string {.slot.} =
    return self.accountName
  QtProperty[string] accountName:
    read = getAccountName
    write = setAccountName
    notify = accountNameChanged

  proc newKeyPairNameChanged*(self: View) {.signal.}
  proc setNewKeyPairName*(self: View, value: string) {.slot.} =
    if self.newKeyPairName == value:
      return
    self.newKeyPairName = value
    self.newKeyPairNameChanged()
  proc getNewKeyPairName*(self: View): string {.slot.} =
    return self.newKeyPairName
  QtProperty[string] newKeyPairName:
    read = getNewKeyPairName
    write = setNewKeyPairName
    notify = newKeyPairNameChanged

  proc selectedEmojiChanged*(self: View) {.signal.}
  proc setSelectedEmoji*(self: View, value: string) {.slot.} =
    if self.selectedEmoji == value:
      return
    self.selectedEmoji = value
    self.selectedEmojiChanged()
  proc getSelectedEmoji*(self: View): string {.slot.} =
    return self.selectedEmoji
  QtProperty[string] selectedEmoji:
    read = getSelectedEmoji
    write = setSelectedEmoji
    notify = selectedEmojiChanged

  proc selectedColorIdChanged*(self: View) {.signal.}
  proc setSelectedColorId*(self: View, value: string) {.slot.} =
    if self.selectedColorId == value:
      return
    self.selectedColorId = value
    self.selectedColorIdChanged()
  proc getSelectedColorId*(self: View): string {.slot.} =
    return self.selectedColorId
  QtProperty[string] selectedColorId:
    read = getSelectedColorId
    write = setSelectedColorId
    notify = selectedColorIdChanged

  proc getStoredAccountName*(self: View): string {.slot.} =
    return self.storedAccountName
  proc setStoredAccountName*(self: View, value: string) =
    self.storedAccountName = value

  proc getStoredSelectedEmoji*(self: View): string {.slot.} =
    return self.storedSelectedEmoji
  proc setStoredSelectedEmoji*(self: View, value: string) =
    self.storedSelectedEmoji = value

  proc getStoredSelectedColorId*(self: View): string {.slot.} =
    return self.storedSelectedColorId
  proc setStoredSelectedColorId*(self: View, value: string) =
    self.storedSelectedColorId = value

  proc derivationPathChanged*(self: View) {.signal.}
  proc getDerivationPath*(self: View): string {.slot.} =
    return self.derivationPath
  proc setDerivationPath*(self: View, value: string) {.slot.} =
    if self.derivationPath == value:
      return
    self.derivationPath = value
    self.derivationPathChanged()
  QtProperty[string] derivationPath:
    read = getDerivationPath
    write = setDerivationPath
    notify = derivationPathChanged

  proc suggestedDerivationPathChanged*(self: View) {.signal.}
  proc getSuggestedDerivationPath*(self: View): string {.slot.} =
    return self.suggestedDerivationPath
  QtProperty[string] suggestedDerivationPath:
    read = getSuggestedDerivationPath
    notify = suggestedDerivationPathChanged

  proc setSuggestedDerivationPath*(self: View, value: string) =
    self.suggestedDerivationPath = value
    self.suggestedDerivationPathChanged()

  proc changeSelectedOrigin*(self: View, keyUid: string) {.slot.} =
    self.delegate.changeSelectedOrigin(keyUid)

  proc changeDerivationPath*(self: View, path: string) {.slot.} =
    self.delegate.changeDerivationPath(path)

  proc changeSelectedDerivedAddress*(self: View, address: string) {.slot.} =
    self.delegate.changeSelectedDerivedAddress(address)

  proc changeWatchOnlyAccountAddress*(self: View, address: string) {.slot.} =
    self.delegate.changeWatchOnlyAccountAddress(address)

  proc changePrivateKey*(self: View, privateKey: string) {.slot.} =
    self.delegate.changePrivateKey(privateKey)

  proc changeSeedPhrase*(self: View, seedPhrase: string) {.slot.} =
    self.delegate.changeSeedPhrase(seedPhrase)

  proc validSeedPhrase*(self: View, seedPhrase: string): bool {.slot.} =
    return self.delegate.validSeedPhrase(seedPhrase)

  proc resetDerivationPath*(self: View) {.slot.} =
    self.delegate.resetDerivationPath()

  proc authenticateForEditingDerivationPath*(self: View) {.slot.} =
    self.delegate.authenticateForEditingDerivationPath()

  proc authenticationRequested*(self: View, keyUid: string) {.signal.}
  proc emitAuthenticationRequested*(self: View, keyUid: string) =
    self.authenticationRequested(keyUid)

  proc authenticationCompleted*(self: View, password: string, pin: string, keyUid: string) {.slot.} =
    self.delegate.onUserAuthenticated(pin, password, keyUid)

  proc startScanningForActivity*(self: View) {.slot.} =
    self.delegate.startScanningForActivity()

  proc confirmSavedAddressRemoval*(self: View, name: string, address: string) {.signal.}
  proc sendConfirmSavedAddressRemovalSignal*(self: View, name: string, address: string) =
    self.confirmSavedAddressRemoval(name, address)

  proc removingSavedAddressConfirmed*(self: View, address: string) {.slot.} =
    self.delegate.removingSavedAddressConfirmed(address)

  proc removingSavedAddressRejected*(self: View) {.slot.} =
    self.setDisablePopup(false)

  proc isChecksumValidForAddress*(self: View, address: string): bool {.slot.} =
    return self.delegate.isChecksumValidForAddress(address)

  proc remainingAccountCapacity*(self: View): int {.slot.} =
    return self.delegate.remainingAccountCapacity()

  proc remainingKeypairCapacity*(self: View): int {.slot.} =
    return self.delegate.remainingKeypairCapacity()

  proc remainingWatchOnlyAccountCapacity*(self: View): int {.slot.} =
    return self.delegate.remainingWatchOnlyAccountCapacity()

  proc delete*(self: View) =
    self.QObject.delete

