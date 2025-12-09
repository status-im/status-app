type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

from app_service/service/settings/dto/settings import SettingsDto
from app_service/service/accounts/dto/accounts import AccountDto
from app_service/service/keycardV2/dto import KeycardEventDto, KeycardExportedKeysDto
from app_service/service/devices/dto/local_pairing_status import LocalPairingStatus
import app/modules/onboarding/post_onboarding/task

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onAppLoaded*(self: AccessInterface, keyUid: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onMainLoaded*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onNodeLogin*(self: AccessInterface, error: string, account: AccountDto, settings: SettingsDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method initialize*(self: AccessInterface, pin: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method authorize*(self: AccessInterface, pin: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getPasswordStrengthScore*(self: AccessInterface, password, userName: string): int {.base.} =
  raise newException(ValueError, "No implementation available")

method validMnemonic*(self: AccessInterface, mnemonic: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method isMnemonicDuplicate*(self: AccessInterface, mnemonic: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method generateMnemonic*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method validateLocalPairingConnectionString*(self: AccessInterface, connectionString: string): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method inputConnectionStringForBootstrapping*(self: AccessInterface, connectionString: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadMnemonic*(self: AccessInterface, dataJson: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method finishOnboardingFlow*(self: AccessInterface, flowInt: int, dataJson: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method loginRequested*(self: AccessInterface, keyUid: string, loginFlow: int, dataJson: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onLocalPairingStatusUpdate*(self: AccessInterface, status: LocalPairingStatus) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardStateUpdated*(self: AccessInterface, keycardEvent: KeycardEventDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardSetPinFailure*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardAuthorizeFinished*(self: AccessInterface, error: string, authorized: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardLoadMnemonicFailure*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardLoadMnemonicSuccess*(self: AccessInterface, keyUID: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardExportRestoreKeysFailure*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardExportRestoreKeysSuccess*(self: AccessInterface, exportedKeys: KeycardExportedKeysDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardExportLoginKeysFailure*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardExportLoginKeysSuccess*(self: AccessInterface, exportedKeys: KeycardExportedKeysDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onAccountLoginError*(self: AccessInterface, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method exportRecoverKeys*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method startKeycardFactoryReset*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getPostOnboardingTasks*(self: AccessInterface): seq[PostOnboardingTask] {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeycardAccountConverted* (self: AccessInterface, success: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method requestSaveBiometrics*(self: AccessInterface, account: string, credential: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method requestDeleteBiometrics*(self: AccessInterface, account: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method requestLocalBackup*(self: AccessInterface, backupImportFileUrl: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method startKeycardDetection*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

# This way (using concepts) is used only for the modules managed by AppController
type
  DelegateInterface* = concept c
    c.onboardingDidLoad()
    c.appReady()
    c.userLoggedIn()
    c.finishAppLoading()
    c.userLoggedIn()
