import nimqml
import io_interface, model
import ../../../../../app_service/service/devices/service


QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      model: Model
      modelVariant: QVariant
      devicesLoading: bool
      devicesLoadingError: bool
      localPairingStatus: LocalPairingStatus

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.devicesLoading = false
    result.devicesLoadingError = false
    result.model = newModel()
    result.modelVariant = newQVariant(result.model)
    result.localPairingStatus = newLocalPairingStatus(PairingType.AppSync, LocalPairingMode.Receiver)

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc model*(self: View): Model =
    return self.model

  proc modelChanged*(self: View) {.signal.}
  proc getModel(self: View): QVariant {.slot.} =
    return self.modelVariant
  QtProperty[QVariant] model:
    read = getModel
    notify = modelChanged

  proc deviceSetupChanged*(self: View) {.signal.}
  proc getIsDeviceSetup*(self: View): bool {.slot} =
    return self.model.getIsDeviceSetup(self.delegate.getMyInstallationId())
  QtProperty[bool] isDeviceSetup:
    read = getIsDeviceSetup
    notify = deviceSetupChanged

  proc devicesLoadingChanged*(self: View) {.signal.}
  proc setDevicesLoading*(self: View, value: bool) =
    if self.devicesLoading == value:
      return
    self.devicesLoading = value
    self.devicesLoadingChanged()
  proc getDevicesLoading*(self: View): bool {.slot} =
    return self.devicesLoading
  QtProperty[bool] devicesLoading:
    read = getDevicesLoading
    notify = devicesLoadingChanged

  proc devicesLoadingErrorChanged*(self: View) {.signal.}
  proc setDevicesLoadingError*(self: View, value: bool) =
    if self.devicesLoadingError == value:
      return
    self.devicesLoadingError = value
    self.devicesLoadingErrorChanged()
  proc getDevicesLoadingError*(self: View): bool {.slot} =
    return self.devicesLoadingError
  QtProperty[bool] devicesLoadingError:
    read = getDevicesLoadingError
    notify = devicesLoadingErrorChanged

  proc loadDevices*(self: View) {.slot.} =
    self.delegate.loadDevices()

  proc setInstallationName*(self: View, installationId: string, name: string) {.slot.} =
    self.delegate.setInstallationName(installationId, name)

  proc syncAll*(self: View) {.slot.} =
    self.delegate.syncAllDevices()

  proc advertise*(self: View) {.slot.} =
    self.delegate.advertise()

  # LocalPairing status

  proc localPairingStatusChanged*(self: View) {.signal.}

  proc getLocalPairingState*(self: View): int {.slot.} =
    return self.localPairingStatus.state.int
  QtProperty[int] localPairingState:
    read = getLocalPairingState
    notify = localPairingStatusChanged

  proc getLocalPairingError*(self: View): string {.slot.}  =
    return self.localPairingStatus.error
  proc localPairingPairingErrorChanged*(self: View) {.signal.}
  QtProperty[string] localPairingError:
    read = getLocalPairingError
    notify = localPairingStatusChanged

  proc getLocalPairingInstallationId*(self: View): string {.slot.}  =
    return self.localPairingStatus.installation.id
  QtProperty[string] localPairingInstallationId:
    read = getLocalPairingInstallationId
    notify = localPairingStatusChanged

  proc getLocalPairingInstallationName*(self: View): string {.slot.}  =
    return self.localPairingStatus.installation.metadata.name
  QtProperty[string] localPairingInstallationName:
    read = getLocalPairingInstallationName
    notify = localPairingStatusChanged

  proc getLocalPairingInstallationDeviceType*(self: View): string {.slot.}  =
    return self.localPairingStatus.installation.metadata.deviceType
  QtProperty[string] localPairingInstallationDeviceType:
    read = getLocalPairingInstallationDeviceType
    notify = localPairingStatusChanged

  proc onLocalPairingStatusUpdate*(self: View, status: LocalPairingStatus) =
    self.localPairingStatus = status
    self.localPairingStatusChanged()

  # LocalPairing actions

  proc openPopupWithConnectionStringSignal*(self: View, rawConnectionString: string) {.signal.}
  proc openPopupWithConnectionString*(self: View, rawConnectionString: string) =
    self.openPopupWithConnectionStringSignal(rawConnectionString)

  proc generateConnectionStringAndRunSetupSyncingPopup*(self: View, messageSyncingEnabled: bool) {.slot.} =
    self.delegate.generateConnectionStringAndRunSetupSyncingPopup(messageSyncingEnabled)

  proc validateConnectionString*(self: View, connectionString: string): string {.slot.} =
    return self.delegate.validateConnectionString(connectionString)

  proc inputConnectionStringForBootstrapping*(self: View, connectionString: string) {.slot.} =
    self.delegate.inputConnectionStringForBootstrapping(connectionString)

  proc pairDevice*(self: View, installationId: string): string {.slot.} =
    let error = self.delegate.pairDevice(installationId)
    if error.len == 0:
      self.model.updateItemEnabled(installationId, true)
    return error

  proc unpairDevice*(self: View, installationId: string): string {.slot.} =
    let error = self.delegate.unpairDevice(installationId)
    if error.len == 0:
      self.model.updateItemEnabled(installationId, false)
    return error

  proc delete*(self: View) =
    self.QObject.delete

