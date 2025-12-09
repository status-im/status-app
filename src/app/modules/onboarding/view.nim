import nimqml
import io_interface, states
from app_service/service/keycardV2/dto import KeycardEventDto
from app_service/service/devices/dto/local_pairing_status import LocalPairingState

import models/login_account_model as login_acc_model
import models/login_account_item as login_acc_item

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      keycardEvent: KeycardEventDto
      syncState: LocalPairingState
      addKeyPairState: ProgressState
      pinSettingState: ProgressState
      authorizationState: AuthorizationState
      restoreKeysExportState: ProgressState
      loginAccountsModel: login_acc_model.Model
      loginAccountsModelVariant: QVariant
      convertKeycardAccountState: ProgressState

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.loginAccountsModel = login_acc_model.newModel()
    result.loginAccountsModelVariant = newQVariant(result.loginAccountsModel)

  ### QtSignals ###

  proc appLoaded*(self: View) {.signal.}
  proc accountLoginError*(self: View, error: string, wrongPassword: bool) {.signal.}
  proc saveBiometricsRequested*(self: View, account: string, credential: string) {.signal.}
  proc deleteBiometricsRequested*(self: View, account: string) {.signal.}

  ### QtProperties ###

  proc syncStateChanged*(self: View) {.signal.}
  proc getSyncState(self: View): int {.slot.} =
    return self.syncState.int
  QtProperty[int] syncState:
    read = getSyncState
    notify = syncStateChanged
  proc setSyncState*(self: View, syncState: LocalPairingState) =
    if self.syncState == syncState:
      return
    self.syncState = syncState
    self.syncStateChanged()

  proc pinSettingStateChanged*(self: View) {.signal.}
  proc getPinSettingState*(self: View): int {.slot.} =
    return self.pinSettingState.int
  QtProperty[int] pinSettingState:
    read = getPinSettingState
    notify = pinSettingStateChanged
  proc setPinSettingState*(self: View, pinSettingState: ProgressState) =
    if self.pinSettingState == pinSettingState:
      return
    self.pinSettingState = pinSettingState
    self.pinSettingStateChanged()

  proc authorizationStateChanged*(self: View) {.signal.}
  proc getAuthorizationState*(self: View): int {.slot.} =
    return self.authorizationState.int
  QtProperty[int] authorizationState:
    read = getAuthorizationState
    notify = authorizationStateChanged
  proc setAuthorizationState*(self: View, authorizationState: AuthorizationState) =
    if self.authorizationState == authorizationState:
      return
    self.authorizationState = authorizationState
    self.authorizationStateChanged()

  proc restoreKeysExportStateChanged*(self: View) {.signal.}
  proc getRestoreKeysExportState*(self: View): int {.slot.} =
    return self.restoreKeysExportState.int
  QtProperty[int] restoreKeysExportState:
    read = getRestoreKeysExportState
    notify = restoreKeysExportStateChanged
  proc setRestoreKeysExportState*(self: View, restoreKeysExportState: ProgressState) =
    if self.restoreKeysExportState == restoreKeysExportState:
      return
    self.restoreKeysExportState = restoreKeysExportState
    self.restoreKeysExportStateChanged()

  proc keycardStateChanged*(self: View) {.signal.}
  proc getKeycardState(self: View): int {.slot.} =
    return self.keycardEvent.state.int
  QtProperty[int] keycardState:
    read = getKeycardState
    notify = keycardStateChanged

  proc keycardUIDChanged*(self: View) {.signal.}
  proc getKeycardUID(self: View): string {.slot.} =
    return self.keycardEvent.keycardInfo.keyUID
  QtProperty[string] keycardUID:
    read = getKeycardUID
    notify = keycardUIDChanged

  proc keycardRemainingPinAttemptsChanged*(self: View) {.signal.}
  proc getKeycardRemainingPinAttempts(self: View): int {.slot.} =
    return self.keycardEvent.keycardStatus.remainingAttemptsPIN
  QtProperty[int] keycardRemainingPinAttempts:
    read = getKeycardRemainingPinAttempts
    notify = keycardRemainingPinAttemptsChanged

  proc keycardRemainingPukAttemptsChanged*(self: View) {.signal.}
  proc getKeycardRemainingPukAttempts(self: View): int {.slot.} =
    return self.keycardEvent.keycardStatus.remainingAttemptsPUK
  QtProperty[int] keycardRemainingPukAttempts:
    read = getKeycardRemainingPukAttempts
    notify = keycardRemainingPukAttemptsChanged

  proc addKeyPairStateChanged*(self: View) {.signal.}
  proc getAddKeyPairState(self: View): int {.slot.} =
    return self.addKeyPairState.int
  QtProperty[int] addKeyPairState:
    read = getAddKeyPairState
    notify = addKeyPairStateChanged
  proc setAddKeyPairState*(self: View, addKeyPairState: ProgressState) =
    if self.addKeyPairState == addKeyPairState:
      return
    self.addKeyPairState = addKeyPairState
    self.addKeyPairStateChanged()

  proc setKeycardEvent*(self: View, keycardEvent: KeycardEventDto) =
    self.keycardEvent = keycardEvent
    self.keycardStateChanged()
    self.keycardUIDChanged()
    self.keycardRemainingPinAttemptsChanged()
    self.keycardRemainingPukAttemptsChanged()

  proc getKeycardEvent*(self: View): KeycardEventDto =
    return self.keycardEvent

  proc getLoginAccountsModel(self: View): QVariant {.slot.} =
    return self.loginAccountsModelVariant
  proc setLoginAccountsModelItems*(self: View, accounts: seq[login_acc_item.Item]) =
    self.loginAccountsModel.setItems(accounts)
  QtProperty[QVariant] loginAccountsModel:
    read = getLoginAccountsModel

  proc convertKeycardAccountStateChanged*(self: View) {.signal.}
  proc getConvertKeycardAccountState(self: View): int {.slot.} =
    return self.convertKeycardAccountState.int
  proc setConvertKeycardAccountState*(self: View, value: ProgressState) =
    if self.convertKeycardAccountState == value:
      return
    self.convertKeycardAccountState = value
    self.convertKeycardAccountStateChanged()
  QtProperty[int] convertKeycardAccountState:
    read = getConvertKeycardAccountState
    notify = convertKeycardAccountStateChanged

  ### slots ###

  proc setPin(self: View, pin: string) {.slot.} =
    self.delegate.initialize(pin)

  proc authorize(self: View, pin: string) {.slot.} =
    self.delegate.authorize(pin)

  proc loadMnemonic(self: View, mnemonic: string) {.slot.} =
    self.delegate.loadMnemonic(mnemonic)

  proc getPasswordStrengthScore(self: View, password: string, userName: string): int {.slot.} =
    return self.delegate.getPasswordStrengthScore(password, userName)

  proc validMnemonic(self: View, mnemonic: string): bool {.slot.} =
    return self.delegate.validMnemonic(mnemonic)

  proc isMnemonicDuplicate(self: View, mnemonic: string): bool {.slot.} =
    return self.delegate.isMnemonicDuplicate(mnemonic)

  proc generateMnemonic(self: View): string {.slot.} =
    return self.delegate.generateMnemonic()

  proc validateLocalPairingConnectionString(self: View, connectionString: string): bool {.slot.} =
    return self.delegate.validateLocalPairingConnectionString(connectionString)

  proc inputConnectionStringForBootstrapping(self: View, connectionString: string) {.slot.} =
    self.delegate.inputConnectionStringForBootstrapping(connectionString)

  proc exportRecoverKeys(self: View) {.slot.} =
    self.delegate.exportRecoverKeys()

  proc finishOnboardingFlow(self: View, flowInt: int, dataJson: string): string {.slot.} =
    return self.delegate.finishOnboardingFlow(flowInt, dataJson)

  proc loginRequested(self: View, keyUid: string, loginFlow: int, dataJson: string) {.slot.} =
    self.delegate.loginRequested(keyUid, loginFlow, dataJson)

  proc startKeycardFactoryReset(self: View) {.slot.} =
    self.delegate.startKeycardFactoryReset()

  proc startKeycardDetection(self: View) {.slot.} =
    self.delegate.startKeycardDetection()

  proc delete*(self: View) =
    self.QObject.delete

