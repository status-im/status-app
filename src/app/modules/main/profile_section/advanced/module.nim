import nimqml, chronicles
import io_interface
import ../io_interface as delegate_interface
import view, controller

import ../../../../../constants
import ../../../../core/eventemitter
import ../../../../../app_service/service/settings/service as settings_service
import ../../../../../app_service/service/stickers/service as stickers_service
import ../../../../../app_service/service/node_configuration/service as node_configuration_service

export io_interface

logScope:
  topics = "profile-section-advanced-module"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool

proc newModule*(delegate: delegate_interface.AccessInterface, events: EventEmitter,
  settingsService: settings_service.Service,
  stickersService: stickers_service.Service,
  nodeConfigurationService: node_configuration_service.Service): Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, settingsService, stickersService, nodeConfigurationService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.advancedModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method getFleet*(self: Module): string =
  return self.controller.getFleet()

method setFleet*(self: Module, fleet: string) =
  self.controller.setFleet(fleet)

method onFleetSet*(self: Module) =
  info "quit the app because of successful fleet change"
  quit(QuitSuccess) # quits the app TODO: change this to logout instead when supported

method getLogDir*(self: Module): string =
  return constants.LOGDIR

method getWakuV2LightClientEnabled*(self: Module): bool =
  return self.controller.getWakuV2LightClientEnabled()

method setWakuV2LightClientEnabled*(self: Module, enabled: bool) =
  self.controller.setWakuV2LightClientEnabled(enabled)

method onWakuV2LightClientSet*(self: Module) =
  info "quit the app because of successful WakuV2 light client change"
  quit(QuitSuccess) # quits the app TODO: change this to logout instead when supported

method isDebugEnabled*(self: Module): bool =
  self.controller.isDebugEnabled()

method toggleDebug*(self: Module) =
  self.controller.toggleDebug()

method onDebugToggled*(self: Module) =
  self.view.isDebugEnabledChanged()

method isNimbusProxyEnabled*(self: Module): bool =
  self.controller.isNimbusProxyEnabled()

method toggleNimbusProxy*(self: Module) =
  self.controller.toggleNimbusProxy()

method onNimbusProxyToggled*(self: Module) =
  self.view.isNimbusProxyEnabledChanged()

method isRuntimeLogLevelSet*(self: Module): bool =
  return constants.runtimeLogLevelSet()

method isCommunityHistoryArchiveSupportEnabled*(self: Module): bool =
  return self.controller.isCommunityHistoryArchiveSupportEnabled()

method enableCommunityHistoryArchiveSupport*(self: Module) =
  if self.controller.enableCommunityHistoryArchiveSupport():
    self.view.archiveProtocolEnabledChanged()

method disableCommunityHistoryArchiveSupport*(self: Module) =
  if self.controller.disableCommunityHistoryArchiveSupport():
    self.view.archiveProtocolEnabledChanged()

method toggleWalletSection*(self: Module) =
  self.controller.toggleWalletSection()

method toggleBrowserSection*(self: Module) =
  self.controller.toggleBrowserSection()

method toggleCommunitySection*(self: Module) =
  self.controller.toggleCommunitySection()

method toggleCommunitiesPortalSection*(self: Module) =
  self.controller.toggleCommunitiesPortalSection()

method toggleNodeManagementSection*(self: Module) =
  self.controller.toggleNodeManagementSection()

method getLogMaxBackups*(self: Module): int =
  self.controller.getLogMaxBackups()

method setMaxLogBackups*(self: Module, value: int) =
  self.controller.setMaxLogBackups(value)

method onLogMaxBackupsChanged*(self: Module) =
  self.view.logMaxBackupsChanged()
