import nimqml

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
# Delegate for the view must be declared here due to use of QtObject and multi
# inheritance, which is not well supported in Nim.
method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

# Methods called by submodules of this module
method profileModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getProfileModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method contactsModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getContactsModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method mnemonicModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method privacyModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getPrivacyModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method aboutModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method advancedModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getAdvancedModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method devicesModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getDevicesModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method syncModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method wakuModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getSyncModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method getWakuModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method notificationsModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getNotificationsModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method ensUsernamesModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getEnsUsernamesModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method getCommunitiesModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method communitiesModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method keycardNewModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getKeycardNewModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method walletModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getWalletModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")
