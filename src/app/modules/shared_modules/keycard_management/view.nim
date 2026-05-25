import nimqml
import io_interface
import ../../shared_models/[keypair_model, keypair_item]

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      keycardState: string
      keycardStatusAvailable: bool
      remainingPinAttempts: int
      remainingPukAttempts: int
      availableSlots: int
      keycardUid: string
      keyUid: string
      cardMetadataName: string
      cardMetadataWalletAccountsJson: string
      keyPairModel: KeyPairModel
      keyPairModelVariant: QVariant
      keyPairItem: KeyPairItem
      keyPairItemVariant: QVariant

  ## Forward declarations
  proc delete*(self: View)

  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.keycardState = ""
    result.keycardStatusAvailable = false
    result.remainingPinAttempts = 0
    result.remainingPukAttempts = 0
    result.availableSlots = 0
    result.keycardUid = ""
    result.keyUid = ""
    result.cardMetadataName = ""
    result.cardMetadataWalletAccountsJson = "[]"
    result.keyPairItem = newKeyPairItem()
    result.keyPairItemVariant = newQVariant(result.keyPairItem)

  proc stopKeycardAction*(self: View) {.slot.} =
    self.delegate.stopKeycardAction()

  proc keycardInteractionSuccessfullyCompleted*(self: View) {.signal.}

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

  proc keycardMoveProfileKeyPairSuccess*(self: View) {.signal.}
  proc keycardMoveProfileKeyPairError*(self: View, error: string) {.signal.}

  proc keycardAddKeyPairSuccess*(self: View) {.signal.}
  proc keycardAddKeyPairError*(self: View, error: string) {.signal.}

  proc stopUsingKeycardForKeyPairSuccess*(self: View) {.signal.}
  proc stopUsingKeycardForKeyPairError*(self: View, error: string) {.signal.}

  proc stopUsingKeycardForProfileKeyPairSuccess*(self: View) {.signal.}
  proc stopUsingKeycardForProfileKeyPairError*(self: View, error: string) {.signal.}

  proc keycardChangePinSuccess*(self: View) {.signal.}
  proc keycardChangePinError*(self: View, error: string) {.signal.}

  proc startChangeKeycardPIN*(self: View, currentPin: string, newPin: string) {.slot.} =
    self.delegate.startChangeKeycardPIN(currentPin, newPin)

  proc keycardChangePukSuccess*(self: View) {.signal.}
  proc keycardChangePukError*(self: View, error: string) {.signal.}

  proc startChangeKeycardPUK*(self: View, currentPin: string, newPuk: string) {.slot.} =
    self.delegate.startChangeKeycardPUK(currentPin, newPuk)

  proc keycardRenameSuccess*(self: View) {.signal.}
  proc keycardRenameError*(self: View, error: string) {.signal.}

  proc startRenameKeycard*(self: View, currentPin: string, newName: string, metadataAccountsJson: string) {.slot.} =
    self.delegate.startRenameKeycard(currentPin, newName, metadataAccountsJson)

  proc keycardUnblockSuccess*(self: View) {.signal.}
  proc keycardUnblockError*(self: View, error: string) {.signal.}

  proc startUnblockKeycardUsingPuk*(self: View, newPin: string, puk: string) {.slot.} =
    self.delegate.startUnblockKeycardUsingPuk(newPin, puk)

  proc startUnblockKeycardUsingRecoveryPhrase*(self: View, newPin: string, seedPhrase: string,
      metadataName: string, metadataAccountsJson: string) {.slot.} =
    self.delegate.startUnblockKeycardUsingRecoveryPhrase(newPin, seedPhrase, metadataName, metadataAccountsJson)

  proc keycardAsyncLoginSuccess*(self: View, dataJson: string) {.signal.}
  proc keycardAsyncLoginError*(self: View, error: string) {.signal.}

  proc startAsyncLogin*(self: View, keyUid: string, pin: string, generateXPub: bool) {.slot.} =
    self.delegate.startAsyncLogin(keyUid, pin, generateXPub)

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

  proc isKeyPairMigratedToKeycard*(self: View, keyUid: string): bool {.slot.} =
    return self.delegate.isKeyPairMigratedToKeycard(keyUid)

  proc getKeyPairNameForKeyUid*(self: View, keyUid: string): string {.slot.} =
    return self.delegate.getKeyPairNameForKeyUid(keyUid)

  proc getKeyPairAccountPathsJsonForKeyUid*(self: View, keyUid: string): string {.slot.} =
    return self.delegate.getKeyPairAccountPathsJsonForKeyUid(keyUid)

  proc startImportingKeyPair*(self: View, pin: string, seedPhrase: string, metadataName: string,
    metadataAccounts: string) {.slot.} =
    self.delegate.startImportingKeyPair(pin, seedPhrase, metadataName, metadataAccounts)

  proc generateMnemonic*(self: View): string {.slot.} =
    return self.delegate.generateMnemonic()

  proc startMigratingNonProfileKeypairToKeycard*(self: View, password: string, pin: string, seedPhrase: string) {.slot.} =
    self.delegate.startMigratingNonProfileKeypairToKeycard(password, pin, seedPhrase)

  proc isMnemonicBackedUp*(self: View): bool {.slot.} =
    return self.delegate.isMnemonicBackedUp()

  proc getMnemonic*(self: View): string {.slot.} =
    return self.delegate.getMnemonic()

  proc startMigratingProfileKeypairToKeycard*(self: View, password: string, pin: string, seedPhrase: string) {.slot.} =
    self.delegate.startMigratingProfileKeypairToKeycard(password, pin, seedPhrase)

  proc startAddingKeyPairToStatusFromKeycard*(self: View, pin: string, keyUid: string, metadataName: string,
      metadataAccounts: string) {.slot.} =
    self.delegate.startAddingKeyPairToStatusFromKeycard(pin, keyUid, metadataName, metadataAccounts)

  proc startStopUsingKeycardForKeyPair*(self: View, keyUid: string, seedPhrase: string, newPassword: string) {.slot.} =
    self.delegate.startStopUsingKeycardForKeyPair(keyUid, seedPhrase, newPassword)

  proc startStopUsingKeycardForProfileKeyPair*(self: View, seedPhrase: string, newPassword: string) {.slot.} =
    self.delegate.startStopUsingKeycardForProfileKeyPair(seedPhrase, newPassword)

  proc remainingKeypairCapacity*(self: View): int {.slot.} =
    return self.delegate.remainingKeypairCapacity()

  proc remainingAccountCapacity*(self: View): int {.slot.} =
    return self.delegate.remainingAccountCapacity()

  proc notifyKeyPairItemChanged*(self: View) {.signal.}
  proc getKeyPairItem*(self: View): QVariant {.slot.} =
    if self.keyPairItemVariant.isNil:
      return newQVariant()
    return self.keyPairItemVariant
  QtProperty[QVariant] keyPairItem:
    read = getKeyPairItem
    notify = notifyKeyPairItemChanged

  proc resolveKeyPairItemForKeyUid*(self: View, keyUid: string) {.slot.} =
    var item = self.delegate.getKeyPairItemForKeyUid(keyUid)
    if item.isNil:
      item = newKeyPairItem()
    self.keyPairItem.setItem(item)
    self.notifyKeyPairItemChanged()

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

  proc keycardStatusAvailableChanged*(self: View) {.signal.}
  proc getKeycardStatusAvailable*(self: View): bool {.slot.} =
    return self.keycardStatusAvailable
  proc setKeycardStatusAvailable*(self: View, value: bool) =
    if self.keycardStatusAvailable == value:
      return
    self.keycardStatusAvailable = value
    self.keycardStatusAvailableChanged()
  QtProperty[bool] keycardStatusAvailable:
    read = getKeycardStatusAvailable
    notify = keycardStatusAvailableChanged

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
    if not self.keyPairItem.isNil:
      self.keyPairItem.delete
    if not self.keyPairItemVariant.isNil:
      self.keyPairItemVariant.delete
    if not self.keyPairModel.isNil:
      self.keyPairModel.delete
    if not self.keyPairModelVariant.isNil:
      self.keyPairModelVariant.delete
    self.QObject.delete
