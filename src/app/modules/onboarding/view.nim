import nimqml, json
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
      loginAccountsModel: login_acc_model.Model
      loginAccountsModelVariant: QVariant
      convertKeycardAccountState: ProgressState
      keycardModule: QVariant

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.loginAccountsModel = login_acc_model.newModel()
    result.loginAccountsModelVariant = newQVariant(result.loginAccountsModel)
    result.keycardModule = newQVariant()

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

  proc keycardEventChanged*(self: View) {.signal.}
  proc setKeycardEvent*(self: View, keycardEvent: KeycardEventDto) =
    self.keycardEvent = keycardEvent
    self.keycardEventChanged()

  proc getKeycardState(self: View): int {.slot.} =
    return self.keycardEvent.state.int
  QtProperty[int] keycardState:
    read = getKeycardState
    notify = keycardEventChanged

  proc getKeycardKeyUID(self: View): string {.slot.} =
    return self.keycardEvent.keycardInfo.keyUID
  QtProperty[string] keycardKeyUID:
    read = getKeycardKeyUID
    notify = keycardEventChanged

  proc getKeycardUID(self: View): string {.slot.} =
    return self.keycardEvent.keycardInfo.instanceUID
  QtProperty[string] keycardUID:
    read = getKeycardUID
    notify = keycardEventChanged

  proc getKeycardRemainingPinAttempts(self: View): int {.slot.} =
    return self.keycardEvent.keycardStatus.remainingAttemptsPIN
  QtProperty[int] keycardRemainingPinAttempts:
    read = getKeycardRemainingPinAttempts
    notify = keycardEventChanged

  proc getKeycardRemainingPukAttempts(self: View): int {.slot.} =
    return self.keycardEvent.keycardStatus.remainingAttemptsPUK
  QtProperty[int] keycardRemainingPukAttempts:
    read = getKeycardRemainingPukAttempts
    notify = keycardEventChanged

  proc getKeycardStatusAvailable(self: View): bool {.slot.} =
    return self.keycardEvent.keycardStatus.keyInitialized
  QtProperty[bool] keycardStatusAvailable:
    read = getKeycardStatusAvailable
    notify = keycardEventChanged

  proc getKeycardAvailableSlots(self: View): int {.slot.} =
    return self.keycardEvent.keycardInfo.availableSlots
  QtProperty[int] keycardAvailableSlots:
    read = getKeycardAvailableSlots
    notify = keycardEventChanged

  proc getKeycardCardMetadataName(self: View): string {.slot.} =
    return self.keycardEvent.metadata.name
  QtProperty[string] keycardCardMetadataName:
    read = getKeycardCardMetadataName
    notify = keycardEventChanged

  proc getKeycardCardMetadataWalletAccountsJson(self: View): string {.slot.} =
    var walletsJson = newJArray()
    for acc in self.keycardEvent.metadata.walletAccounts:
      walletsJson.add(%*{
        "path": acc.path,
        "address": acc.address,
        "publicKey": acc.publicKey,
      })
    return $walletsJson
  QtProperty[string] keycardCardMetadataWalletAccountsJson:
    read = getKeycardCardMetadataWalletAccountsJson
    notify = keycardEventChanged

  proc getLoginAccountsModel(self: View): QVariant {.slot.} =
    return self.loginAccountsModelVariant
  proc setLoginAccountsModelItems*(self: View, accounts: seq[login_acc_item.Item]) =
    self.loginAccountsModel.setItems(accounts)
  QtProperty[QVariant] loginAccountsModel:
    read = getLoginAccountsModel

  proc removeLoginAccountItem*(self: View, keyUid: string) =
    self.loginAccountsModel.removeItem(keyUid)

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

  proc keycardModuleChanged*(self: View) {.signal.}
  proc getKeycardModule(self: View): QVariant {.slot.} =
    return self.keycardModule
  proc setKeycardModule*(self: View, value: QVariant) =
    self.keycardModule = value
    self.keycardModuleChanged()
  QtProperty[QVariant] keycardModule:
    read = getKeycardModule
    notify = keycardModuleChanged

  ### slots ###

  proc getPasswordStrengthScore(self: View, password: string, userName: string): int {.slot.} =
    return self.delegate.getPasswordStrengthScore(password, userName)

  proc validMnemonic(self: View, mnemonic: string): bool {.slot.} =
    return self.delegate.validMnemonic(mnemonic)

  proc isMnemonicDuplicate(self: View, mnemonic: string): bool {.slot.} =
    return self.delegate.isMnemonicDuplicate(mnemonic)

  proc validateLocalPairingConnectionString(self: View, connectionString: string): bool {.slot.} =
    return self.delegate.validateLocalPairingConnectionString(connectionString)

  proc inputConnectionStringForBootstrapping(self: View, connectionString: string) {.slot.} =
    self.delegate.inputConnectionStringForBootstrapping(connectionString)

  proc finishOnboardingFlow(self: View, flowInt: int, dataJson: string): string {.slot.} =
    return self.delegate.finishOnboardingFlow(flowInt, dataJson)

  proc loginRequested(self: View, keyUid: string, loginFlow: int, dataJson: string) {.slot.} =
    self.delegate.loginRequested(keyUid, loginFlow, dataJson)

  proc prepareKeycardModule(self: View) {.slot.} =
    self.delegate.prepareKeycardModule()

  proc destroyKeycardModule(self: View) {.slot.} =
    self.delegate.destroyKeycardModule()

  proc requestDeleteMultiaccount(self: View, keyUid: string): string {.slot.} =
    return self.delegate.requestDeleteMultiaccount(keyUid)

  proc cleanupAfterMainTransition(self: View) {.slot.} =
    self.delegate.cleanupAfterMainTransition()

  proc delete*(self: View) =
    self.QObject.delete

