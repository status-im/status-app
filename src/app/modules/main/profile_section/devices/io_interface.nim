import nimqml, tables
import app_service/service/devices/service
from app_service/service/keycard/service import KeyDetails

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method getModuleAsVariant*(self: AccessInterface): QVariant {.base.} =
  raise newException(ValueError, "No implementation available")

method updateOrAddDevice*(self: AccessInterface, installation: InstallationDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method updateInstallationName*(self: AccessInterface, installationId: string, name: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getMyInstallationId*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method onDevicesLoaded*(self: AccessInterface, allDevices: seq[InstallationDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method onDevicesLoadingErrored*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadDevices*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method setInstallationName*(self: AccessInterface, installationId: string, name: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method syncAllDevices*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method advertise*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method generateConnectionStringAndRunSetupSyncingPopup*(self: AccessInterface, messageSyncingEnabled: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method onLoggedInUserAuthenticated*(self: AccessInterface, pin: string, password: string, keyUid: string, additinalPathsDetails: Table[string, KeyDetails]) {.base.} =
  raise newException(ValueError, "No implementation available")

proc validateConnectionString*(self: AccessInterface, connectionString: string): string =
  raise newException(ValueError, "No implementation available")

method inputConnectionStringForBootstrapping*(self: AccessInterface, connectionString: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onLocalPairingStatusUpdate*(self: AccessInterface, status: LocalPairingStatus) {.base.} =
  raise newException(ValueError, "No implementation available")

method pairDevice*(self: AccessInterface, installationId: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method unpairDevice*(self: AccessInterface, installationId: string): string {.base.} =
  raise newException(ValueError, "No implementation available")

method deleteDevice*(self: AccessInterface, installationId: string): string {.base.} =
  raise newException(ValueError, "No implementation available")
