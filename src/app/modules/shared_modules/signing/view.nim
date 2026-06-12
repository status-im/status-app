import nimqml
import io_interface
import app/modules/shared_models/keypair_item

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      keycardState: string
      remainingPinAttempts: int
      keyPairForProcessing: KeyPairItem
      keyPairForProcessingVariant: QVariant

  ## Forward declarations
  proc delete*(self: View)

  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.keycardState = ""
    result.remainingPinAttempts = 0

  proc verifyPassword*(self: View, password: string): bool {.slot.} =
    return self.delegate.verifyPassword(password)

  proc signMessage*(self: View, address: string, password: string, txHash: string): string {.slot.} =
    return self.delegate.signMessage(address, password, txHash)

  proc isKeypairMigratedToColdWallet*(self: View, keyUid: string): bool {.slot.} =
    return self.delegate.isKeypairMigratedToColdWallet(keyUid)

  proc buildKeyPairForProcessing*(self: View, keyUid: string) {.slot.} =
    discard self.delegate.buildKeyPairForProcessing(keyUid)

  proc keycardSignSuccess*(self: View, r: string, s: string, v: int) {.signal.}
  proc keycardSignError*(self: View, error: string) {.signal.}

  proc startKeycardSigning*(self: View, keyUid: string, pin: string, txHash: string, path: string) {.slot.} =
    self.delegate.startKeycardSigning(keyUid, pin, txHash, path)

  proc stopKeycardSigning*(self: View) {.slot.} =
    self.delegate.stopKeycardSigning()

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

  proc keyPairForProcessingChanged*(self: View) {.signal.}
  proc setKeyPairForProcessing*(self: View, item: KeyPairItem) =
    if self.keyPairForProcessing.isNil:
      self.keyPairForProcessing = newKeyPairItem()
    if self.keyPairForProcessingVariant.isNil:
      self.keyPairForProcessingVariant = newQVariant(self.keyPairForProcessing)
    self.keyPairForProcessing.setItem(item)
    self.keyPairForProcessingChanged()
  proc getKeyPairForProcessingVariant(self: View): QVariant {.slot.} =
    if self.keyPairForProcessingVariant.isNil:
      return newQVariant()
    return self.keyPairForProcessingVariant
  QtProperty[QVariant] keyPairForProcessing:
    read = getKeyPairForProcessingVariant
    notify = keyPairForProcessingChanged

  proc delete*(self: View) =
    if not self.keyPairForProcessing.isNil:
      self.keyPairForProcessing.delete
    if not self.keyPairForProcessingVariant.isNil:
      self.keyPairForProcessingVariant.delete
    self.QObject.delete
