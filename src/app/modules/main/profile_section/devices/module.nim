import nimqml, tables, strutils, chronicles
import io_interface
import ../io_interface as delegate_interface
import view, controller, model, item

import app/global/global_singleton
import app/core/eventemitter
import app_service/common/account_constants
import app_service/service/settings/service as settings_service
import app_service/service/devices/service as devices_service
from app_service/service/keycard/service import KeyDetails

export io_interface

logScope:
  topics = "profile-section-devices-module"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool
    messageSyncingEnabled: bool

proc newModule*(delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  settingsService: settings_service.Service,
  devicesService: devices_service.Service): Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, settingsService, devicesService)
  result.moduleLoaded = false
  result.messageSyncingEnabled = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method getMyInstallationId(self: Module): string =
  return self.controller.getMyInstallationId()

proc isMyDevice(self: Module, installationId: string): bool =
  let myInstallationId = self.controller.getMyInstallationId()
  return installationId == myInstallationId

method loadDevices*(self: Module) =
  self.view.setDevicesLoading(true)
  self.controller.asyncLoadDevices()

method onDevicesLoadingErrored*(self: Module) =
  self.view.setDevicesLoading(false)
  self.view.setDevicesLoadingError(true)

method onDevicesLoaded*(self: Module, allDevices: seq[InstallationDto]) =
  var items: seq[Item]
  for d in allDevices:
    let item = initItem(d, self.isMyDevice(d.id))
    items.add(item)
  self.view.model().setItems(items)
  self.view.setDevicesLoading(false)
  self.view.deviceSetupChanged()

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.devicesModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method setInstallationName*(self: Module, installationId: string, name: string) =
  self.controller.setInstallationName(installationId, name)

method syncAllDevices*(self: Module) =
  self.controller.syncAllDevices()

method advertise*(self: Module) =
  self.controller.advertise()

method updateOrAddDevice*(self: Module, installation: InstallationDto) =
  if(self.view.model().isItemWithInstallationIdAdded(installation.id)):
    self.view.model().updateItem(installation)
  else:
    let item = initItem(installation, self.isMyDevice(installation.id))
    self.view.model().addItem(item)

method updateInstallationName*(self: Module, installationId: string, name: string) =
  self.view.model().updateItemName(installationId, name)

method generateConnectionStringAndRunSetupSyncingPopup*(self: Module, messageSyncingEnabled: bool) =
  self.messageSyncingEnabled = messageSyncingEnabled
  var additionalBip44Paths: seq[string]
  if singletonInstance.userProfile.getIsKeycardUser():
    additionalBip44Paths.add(account_constants.PATH_WHISPER)
  self.controller.authenticateLoggedInUser(additionalBip44Paths)

method onLoggedInUserAuthenticated*(self: Module, pin: string, password: string, keyUid: string, additinalPathsDetails: Table[string, KeyDetails]) =
  var chatKey = ""
  if singletonInstance.userProfile.getIsKeycardUser() and
    additinalPathsDetails.contains(account_constants.PATH_WHISPER):
      chatKey = additinalPathsDetails[account_constants.PATH_WHISPER].privateKey
      if chatKey.startsWith("0x"):
        chatKey = chatKey[2..^1]
  let connectionString = self.controller.getConnectionStringForBootstrappingAnotherDevice(password, chatKey, self.messageSyncingEnabled)
  if password.len == 0 and pin.len == 0:
    return
  self.view.openPopupWithConnectionString(connectionString)

proc validateConnectionString*(self: Module, connectionString: string): string =
  return self.controller.validateConnectionString(connectionString)

method inputConnectionStringForBootstrapping*(self: Module, connectionString: string) =
  self.controller.inputConnectionStringForBootstrapping(connectionString)

method onLocalPairingStatusUpdate*(self: Module, status: LocalPairingStatus) =
  self.view.onLocalPairingStatusUpdate(status)

method pairDevice*(self: Module, installationId: string): string =
  return self.controller.pairDevice(installationId)

method unpairDevice*(self: Module, installationId: string): string =
  return self.controller.unpairDevice(installationId)
