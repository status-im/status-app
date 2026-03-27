import nimqml
import io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      keycardState: string
      remainingPinAttempts: int

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

  proc isKeypairMigratedToKeycard*(self: View, keyUid: string): bool {.slot.} =
    return self.delegate.isKeypairMigratedToKeycard(keyUid)

  proc keycardAuthSuccess*(self: View, encryptionPublicKey: string) {.signal.}
  proc keycardAuthError*(self: View, error: string) {.signal.}

  proc startKeycardAuthentication*(self: View, keyUid: string, pin: string) {.slot.} =
    self.delegate.startKeycardAuthentication(keyUid, pin)

  proc stopKeycardAuthentication*(self: View) {.slot.} =
    self.delegate.stopKeycardAuthentication()

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

  proc delete*(self: View) =
    self.QObject.delete
