import nimqml
import io_interface
import internal/[state, state_wrapper]
import app/modules/shared_models/[keypair_model, derived_address_model]

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      currentState: StateWrapper
      currentStateVariant: QVariant
      keypairModel: KeyPairModel
      keypairModelVariant: QVariant
      selectedKeypair: KeyPairItem
      selectedKeypairVariant: QVariant
      privateKeyAccAddress: DerivedAddressItem
      privateKeyAccAddressVariant: QVariant
      enteredPrivateKeyMatchTheKeypair: bool
      connectionString: string
      connectionStringError: string

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.currentState = newStateWrapper()
    result.currentStateVariant = newQVariant(result.currentState)
    result.selectedKeypair = newKeyPairItem()
    result.selectedKeypairVariant = newQVariant(result.selectedKeypair)
    result.privateKeyAccAddress = newDerivedAddressItem()
    result.privateKeyAccAddressVariant = newQVariant(result.privateKeyAccAddress)
    result.enteredPrivateKeyMatchTheKeypair = false

    signalConnect(result.currentState, "backActionClicked()", result, "onBackActionClicked()", 2)
    signalConnect(result.currentState, "cancelActionClicked()", result, "onCancelActionClicked()", 2)
    signalConnect(result.currentState, "primaryActionClicked()", result, "onPrimaryActionClicked()", 2)
    signalConnect(result.currentState, "secondaryActionClicked()", result, "onSecondaryActionClicked()", 2)

  proc currentStateObj*(self: View): State =
    return self.currentState.getStateObj()

  proc setCurrentState*(self: View, state: State) =
    self.currentState.setStateObj(state)
  proc getCurrentState(self: View): QVariant {.slot.} =
    return self.currentStateVariant
  QtProperty[QVariant] currentState:
    read = getCurrentState

  proc onBackActionClicked*(self: View) {.slot.} =
    self.delegate.onBackActionClicked()

  proc onCancelActionClicked*(self: View) {.slot.} =
    self.delegate.onCancelActionClicked()

  proc onPrimaryActionClicked*(self: View) {.slot.} =
    self.delegate.onPrimaryActionClicked()

  proc onSecondaryActionClicked*(self: View) {.slot.} =
    self.delegate.onSecondaryActionClicked()

  proc authenticationRequested*(self: View, keyUid: string) {.signal.}
  proc emitAuthenticationRequested*(self: View, keyUid: string) =
    self.authenticationRequested(keyUid)

  proc authenticationCompleted*(self: View, password: string, pin: string, keyUid: string) {.slot.} =
    self.delegate.onUserAuthenticated(pin, password, keyUid)

  proc getSelectedKeypair*(self: View): KeyPairItem =
    return self.selectedKeypair
  proc getSelectedKeypairAsVariant*(self: View): QVariant {.slot.} =
    return self.selectedKeypairVariant
  QtProperty[QVariant] selectedKeypair:
    read = getSelectedKeypairAsVariant

  proc setSelectedKeypairItem*(self: View, item: KeyPairItem) =
    self.selectedKeypair.setItem(item)

  proc setSelectedKeyPair*(self: View, keyUid: string) {.slot.} =
    self.delegate.setSelectedKeyPairByKeyUid(keyUid)

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

  proc changePrivateKey*(self: View, privateKey: string) {.slot.} =
    self.delegate.changePrivateKey(privateKey)

  proc changeSeedPhrase*(self: View, seedPhrase: string) {.slot.} =
    self.delegate.changeSeedPhrase(seedPhrase)

  proc validSeedPhrase*(self: View, seedPhrase: string): bool {.slot.} =
    return self.delegate.validSeedPhrase(seedPhrase)

  proc enteredPrivateKeyMatchTheKeypairChanged(self: View) {.signal.}
  proc getEnteredPrivateKeyMatchTheKeypair*(self: View): bool {.slot.} =
    return self.enteredPrivateKeyMatchTheKeypair
  QtProperty[bool] enteredPrivateKeyMatchTheKeypair:
    read = getEnteredPrivateKeyMatchTheKeypair
    notify = enteredPrivateKeyMatchTheKeypairChanged

  proc setEnteredPrivateKeyMatchTheKeypair*(self: View, value: bool) =
    self.enteredPrivateKeyMatchTheKeypair = value
    self.enteredPrivateKeyMatchTheKeypairChanged()

  proc keypairModel*(self: View): KeyPairModel =
    return self.keypairModel

  proc keypairModelChanged(self: View) {.signal.}
  proc getKeypairModel(self: View): QVariant {.slot.} =
    if self.keypairModelVariant.isNil:
      return newQVariant()
    return self.keypairModelVariant
  QtProperty[QVariant] keypairModel:
    read = getKeypairModel
    notify = keypairModelChanged

  proc createKeypairModel*(self: View, items: seq[KeyPairItem]) =
    if self.keypairModel.isNil:
      self.keypairModel = newKeyPairModel()
    if self.keypairModelVariant.isNil:
      self.keypairModelVariant = newQVariant(self.keypairModel)
    self.keypairModel.setItems(items)
    self.keypairModelChanged()

  proc connectionStringChanged(self: View) {.signal.}
  proc getConnectionString*(self: View): string {.slot.} =
    return self.connectionString
  proc setConnectionString*(self: View, connectionScreen: string) {.slot.} =
    self.connectionString = connectionScreen
    self.connectionStringChanged()
  QtProperty[string] connectionString:
    read = getConnectionString
    write = setConnectionString
    notify = connectionStringChanged

  proc connectionStringErrorChanged(self: View) {.signal.}
  proc getConnectionStringError*(self: View): string {.slot.} =
    return self.connectionStringError
  QtProperty[string] connectionStringError:
    read = getConnectionStringError
    notify = connectionStringErrorChanged
  proc setConnectionStringError*(self: View, error: string) =
    self.connectionStringError = error
    self.connectionStringErrorChanged()

  proc generateConnectionStringForExporting*(self: View) {.slot.} =
    self.delegate.generateConnectionStringForExporting()

  proc validateConnectionString*(self: View, connectionString: string): string {.slot.} =
    return self.delegate.validateConnectionString(connectionString)

  proc delete*(self: View) =
    self.QObject.delete

