import nimqml

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

method onFleetSet*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onWakuV2LightClientSet*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onDebugToggled*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onNimbusProxyToggled*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getFleet*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method setFleet*(self: AccessInterface, fleet: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getLogDir*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method getWakuV2LightClientEnabled*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method setWakuV2LightClientEnabled*(self: AccessInterface, enabled: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method isDebugEnabled*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method isRuntimeLogLevelSet*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method isCommunityHistoryArchiveSupportEnabled*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method enableCommunityHistoryArchiveSupport*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method disableCommunityHistoryArchiveSupport*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleDebug*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isNimbusProxyEnabled*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleNimbusProxy*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleCommunitiesPortalSection*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleWalletSection*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleBrowserSection*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleCommunitySection*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method toggleNodeManagementSection*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getLogMaxBackups*(self: AccessInterface): int {.base.} =
  raise newException(ValueError, "No implementation available")

method setMaxLogBackups*(self: AccessInterface, value: int) {.base.} =
  raise newException(ValueError, "No implementation available")

method onLogMaxBackupsChanged*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")
