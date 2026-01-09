import nimqml
import io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc fleetChanged*(self: View) {.signal.}
  proc getFleet*(self: View): string {.slot.} =
    return self.delegate.getFleet()
  QtProperty[string] fleet:
    read = getFleet
    notify = fleetChanged

  proc setFleet*(self: View, fleet: string) {.slot.} =
    self.delegate.setFleet(fleet)

  # include this if we decide to not quit the app on fleet change
  # proc emitFleetSignal*(self: View) =
  #   self.fleetChanged()

  proc logDir*(self: View): string {.slot.} =
    return self.delegate.getLogDir()

  proc wakuV2LightClientEnabledChanged*(self: View) {.signal.}
  proc getWakuV2LightClientEnabled*(self: View): bool {.slot.} =
    return self.delegate.getWakuV2LightClientEnabled()
  QtProperty[bool] wakuV2LightClientEnabled:
    read = getWakuV2LightClientEnabled
    notify = wakuV2LightClientEnabledChanged

  proc setWakuV2LightClientEnabled*(self: View, enabled: bool) {.slot.} =
    self.delegate.setWakuV2LightClientEnabled(enabled)

  proc isDebugEnabledChanged*(self: View) {.signal.}
  proc getIsDebugEnabled*(self: View): bool {.slot.} =
    return self.delegate.isDebugEnabled()
  QtProperty[bool] isDebugEnabled:
    read = getIsDebugEnabled
    notify = isDebugEnabledChanged

  proc toggleDebug*(self: View) {.slot.} =
    self.delegate.toggleDebug()

  proc isNimbusProxyEnabledChanged*(self: View) {.signal.}
  proc getIsNimbusProxyEnabled*(self: View): bool {.slot.} =
    return self.delegate.isNimbusProxyEnabled()
  QtProperty[bool] isNimbusProxyEnabled:
    read = getIsNimbusProxyEnabled
    notify = isNimbusProxyEnabledChanged

  proc toggleNimbusProxy*(self: View) {.slot.} =
    self.delegate.toggleNimbusProxy()

  proc getIsRuntimeLogLevelSet*(self: View): bool {.slot.} =
    return self.delegate.isRuntimeLogLevelSet()
  QtProperty[bool] isRuntimeLogLevelSet:
    read = getIsRuntimeLogLevelSet

  proc archiveProtocolEnabledChanged*(self: View) {.signal.}
  proc getArchiveProtocolEnabled*(self: View): bool {.slot.} =
    return self.delegate.isCommunityHistoryArchiveSupportEnabled()
  QtProperty[bool] archiveProtocolEnabled:
    read = getArchiveProtocolEnabled
    notify = archiveProtocolEnabledChanged

  proc enableCommunityHistoryArchiveSupport*(self: View) {.slot.} =
    self.delegate.enableCommunityHistoryArchiveSupport()

  proc disableCommunityHistoryArchiveSupport*(self: View) {.slot.} =
    self.delegate.disableCommunityHistoryArchiveSupport()

  proc toggleWalletSection*(self: View) {.slot.} =
    self.delegate.toggleWalletSection()

  proc toggleBrowserSection*(self: View) {.slot.} =
    self.delegate.toggleBrowserSection()

  proc toggleCommunitySection*(self: View) {.slot.} =
    self.delegate.toggleCommunitySection()

  proc toggleNodeManagementSection*(self: View) {.slot.} =
    self.delegate.toggleNodeManagementSection()

  proc toggleCommunitiesPortalSection*(self: View) {.slot.} =
    self.delegate.toggleCommunitiesPortalSection()

  proc logMaxBackupsChanged*(self: View) {.signal.}
  proc getLogMaxBackups*(self: View): int {.slot.} =
    return self.delegate.getLogMaxBackups()
  QtProperty[int] logMaxBackups:
    read = getLogMaxBackups
    notify = logMaxBackupsChanged

  proc setMaxLogBackups*(self: View, value: int) {.slot.} =
    self.delegate.setMaxLogBackups(value)

  proc delete*(self: View) =
    self.QObject.delete

