import nimqml
import app/modules/shared_modules/keypair_import/module as keypair_import_module
import app_service/service/devices/service as devices_service

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

# View Delegate Interface
# Delegate for the view must be declared here due to use of QtObject and multi
# inheritance, which is not well supported in Nim.
method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

# Methods called by submodules of this module
method accountsModuleDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getAccountsModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method getCollectiblesModel*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method getKeypairImportModule*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method onKeypairImportModuleLoaded*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method destroyKeypairImportPopup*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method runKeypairImportPopup*(self: AccessInterface, keyUid: string, mode: ImportKeypairModuleMode) {.base.} =
  raise newException(ValueError, "No implementation available")

method hasPairedDevices*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method onLocalPairingStatusUpdate*(self: AccessInterface, data: LocalPairingStatus) {.base.} =
  raise newException(ValueError, "No implementation available")

method getRpcStats*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method resetRpcStats*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method refetchTxHistory*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getAutoApplyKeypairMigrations*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method setAutoApplyKeypairMigrations*(self: AccessInterface, value: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method onAutoApplyKeypairMigrationsUpdated*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")