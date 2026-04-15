import nimqml
import io_interface
import ../../shared_models/[keypair_model, keypair_item]

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      keycardState: string
      remainingPinAttempts: int
      remainingPukAttempts: int
      availableSlots: int
      keycardUid: string
      keyUid: string
      cardMetadataName: string
      cardMetadataWalletAccountsJson: string
      keyPairModel: KeyPairModel
      keyPairModelVariant: QVariant

  ## Forward declarations
  proc delete*(self: View)

  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.keycardState = ""
    result.remainingPinAttempts = 0
    result.remainingPukAttempts = 0
    result.availableSlots = 0
    result.keycardUid = ""
    result.keyUid = ""
    result.cardMetadataName = ""
    result.cardMetadataWalletAccountsJson = "[]"

  proc stopKeycardAction*(self: View) {.slot.} =
    self.delegate.stopKeycardAction()

  proc keycardGetMetadataSuccess*(self: View) {.signal.}
  proc keycardGetMetadataError*(self: View, error: string) {.signal.}

  proc startGetMetadata*(self: View, pin: string) {.slot.} =
    self.delegate.startGetMetadata(pin)

  proc keycardFactoryResetSuccess*(self: View) {.signal.}
  proc keycardFactoryResetError*(self: View, error: string) {.signal.}

  proc startFactoryReset*(self: View, keycardUid: string) {.slot.} =
    self.delegate.startFactoryReset(keycardUid)

  proc keycardImportKeyPairSuccess*(self: View) {.signal.}
  proc keycardImportKeyPairError*(self: View, error: string) {.signal.}

  proc keycardMoveKeyPairSuccess*(self: View) {.signal.}
  proc keycardMoveKeyPairError*(self: View, error: string) {.signal.}

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

  proc populateKeyPairModel*(self: View) {.slot.} =
    self.delegate.populateKeyPairModel()

  proc getKeyUidForSeedPhrase*(self: View, seedPhrase: string): string {.slot.} =
    return self.delegate.getKeyUidForSeedPhrase(seedPhrase)

  proc isKnownKeyUid*(self: View, keyUid: string): bool {.slot.} =
    return self.delegate.isKnownKeyUid(keyUid)

  proc getKeyPairNameForKeyUid*(self: View, keyUid: string): string {.slot.} =
    return self.delegate.getKeyPairNameForKeyUid(keyUid)

  proc getKeyPairAccountPathsJsonForKeyUid*(self: View, keyUid: string): string {.slot.} =
    return self.delegate.getKeyPairAccountPathsJsonForKeyUid(keyUid)

  proc startImportingKeyPair*(self: View, pin: string, seedPhrase: string, metadataName: string,
    metadataAccounts: string) {.slot.} =
    self.delegate.startImportingKeyPair(pin, seedPhrase, metadataName, metadataAccounts)

  proc generateMnemonic*(self: View): string {.slot.} =
    return self.delegate.generateMnemonic()

  proc startMigratingNonProfileKeypairToKeycard*(self: View, password: string, pin: string, seedPhrase: string,
    metadataName: string, metadataAccounts: string) {.slot.} =
    self.delegate.startMigratingNonProfileKeypairToKeycard(password, pin, seedPhrase, metadataName, metadataAccounts)

  proc keycardStateChanged*(self: View) {.signal.}
  proc getKeycardState*(self: View): string {.slot.} =
    return self.keycardState
  proc setKeycardState*(self: View, state: string) =
    if self.keycardState == state:
      return
    self.keycardState = state
    self.keycardStateChanged()
  QtProperty[string] keycardState:
    read = getKeycardState
    notify = keycardStateChanged

  proc remainingPinAttemptsChanged*(self: View) {.signal.}
  proc getRemainingPinAttempts*(self: View): int {.slot.} =
    return self.remainingPinAttempts
  proc setRemainingPinAttempts*(self: View, value: int) =
    if self.remainingPinAttempts == value:
      return
    self.remainingPinAttempts = value
    self.remainingPinAttemptsChanged()
  QtProperty[int] remainingPinAttempts:
    read = getRemainingPinAttempts
    notify = remainingPinAttemptsChanged

  proc remainingPukAttemptsChanged*(self: View) {.signal.}
  proc getRemainingPukAttempts*(self: View): int {.slot.} =
    return self.remainingPukAttempts
  proc setRemainingPukAttempts*(self: View, value: int) =
    if self.remainingPukAttempts == value:
      return
    self.remainingPukAttempts = value
    self.remainingPukAttemptsChanged()
  QtProperty[int] remainingPukAttempts:
    read = getRemainingPukAttempts
    notify = remainingPukAttemptsChanged

  proc availableSlotsChanged*(self: View) {.signal.}
  proc getAvailableSlots*(self: View): int {.slot.} =
    return self.availableSlots
  proc setAvailableSlots*(self: View, value: int) =
    if self.availableSlots == value:
      return
    self.availableSlots = value
    self.availableSlotsChanged()
  QtProperty[int] availableSlots:
    read = getAvailableSlots
    notify = availableSlotsChanged

  proc keycardUidChanged*(self: View) {.signal.}
  proc getKeycardUid*(self: View): string {.slot.} =
    return self.keycardUid
  proc setKeycardUid*(self: View, value: string) =
    self.keycardUid = value
    self.keycardUidChanged()
  QtProperty[string] keycardUid:
    read = getKeycardUid
    notify = keycardUidChanged

  proc keyUidChanged*(self: View) {.signal.}
  proc getKeyUid*(self: View): string {.slot.} =
    return self.keyUid
  proc setKeyUid*(self: View, value: string) =
    self.keyUid = value
    self.keyUidChanged()
  QtProperty[string] keyUid:
    read = getKeyUid
    notify = keyUidChanged

  proc cardMetadataNameChanged*(self: View) {.signal.}
  proc getCardMetadataName*(self: View): string {.slot.} =
    return self.cardMetadataName
  proc setCardMetadataName*(self: View, value: string) =
    self.cardMetadataName = value
    self.cardMetadataNameChanged()
  QtProperty[string] cardMetadataName:
    read = getCardMetadataName
    notify = cardMetadataNameChanged

  proc cardMetadataWalletAccountsJsonChanged*(self: View) {.signal.}
  proc getCardMetadataWalletAccountsJson*(self: View): string {.slot.} =
    return self.cardMetadataWalletAccountsJson
  proc setCardMetadataWalletAccountsJson*(self: View, value: string) =
    self.cardMetadataWalletAccountsJson = value
    self.cardMetadataWalletAccountsJsonChanged()
  QtProperty[string] cardMetadataWalletAccountsJson:
    read = getCardMetadataWalletAccountsJson
    notify = cardMetadataWalletAccountsJsonChanged

  proc delete*(self: View) =
    self.QObject.delete
