import chronicles
import io_interface

import ../../../../global/app_signals
import ../../../../core/eventemitter
import ../../../../../app_service/service/settings/service as settings_service
import ../../../../../app_service/service/stickers/service as stickers_service
import ../../../../../app_service/service/node_configuration/service as node_configuration_service

logScope:
  topics = "profile-section-advanced-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    settingsService: settings_service.Service
    stickersService: stickers_service.Service
    nodeConfigurationService: node_configuration_service.Service

proc newController*(delegate: io_interface.AccessInterface, events: EventEmitter,
  settingsService: settings_service.Service,
  stickersService: stickers_service.Service,
  nodeConfigurationService: node_configuration_service.Service): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.settingsService = settingsService
  result.nodeConfigurationService = nodeConfigurationService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  discard

proc getFleet*(self: Controller): string =
  return self.settingsService.getFleetAsString()

proc setFleet*(self: Controller, fleet: string) =
  if not self.settingsService.saveFleet(fleet):
    # in the future we may do a call from here to show a popup about this error
    error "an error occurred, we couldn't set fleet"
    return

  self.delegate.onFleetSet()

proc getLogMaxBackups*(self: Controller): int =
  return self.nodeConfigurationService.getLogMaxBackups()

proc setMaxLogBackups*(self: Controller, value: int) =
  if(not self.nodeConfigurationService.setMaxLogBackups(value)):
    # in the future we may do a call from here to show a popup about this error
    error "an error occurred, we couldn't set the Max Log Backups"
    return

  self.delegate.onLogMaxBackupsChanged()

proc getWakuV2LightClientEnabled*(self: Controller): bool =
  return self.nodeConfigurationService.isLightClient()

proc setWakuV2LightClientEnabled*(self: Controller, enabled: bool) =
  if (not self.nodeConfigurationService.setLightClient(enabled)):
    # in the future we may do a call from here to show a popup about this error
    error "an error occurred, we couldn't set WakuV2 light client"
    return

  self.delegate.onWakuV2LightClientSet()

proc isDebugEnabled*(self: Controller): bool =
  return self.nodeConfigurationService.isDebugEnabled()

proc toggleDebug*(self: Controller) =
  var logLevel = LogLevel.DEBUG
  if(self.isDebugEnabled()):
    logLevel = LogLevel.INFO

  if(not self.nodeConfigurationService.setLogLevel(logLevel)):
    # in the future we may do a call from here to show a popup about this error
    error "an error occurred, we couldn't toggle debug level"
    return

  self.delegate.onDebugToggled()

proc isNimbusProxyEnabled*(self: Controller): bool =
  return self.nodeConfigurationService.isNimbusProxyEnabled()

proc toggleNimbusProxy*(self: Controller) =
  let enabled = self.nodeConfigurationService.isNimbusProxyEnabled()

  if not self.nodeConfigurationService.setNimbusProxyConfigEnabled(not enabled):
    error "an error occurred, we couldn't toggle nimbus proxy"
    return

  self.delegate.onNimbusProxyToggled()

proc toggleCommunitiesPortalSection*(self: Controller) =
  self.events.emit(TOGGLE_SECTION, ToggleSectionArgs(sectionType: SectionType.CommunitiesPortal))

proc toggleWalletSection*(self: Controller) =
  self.events.emit(TOGGLE_SECTION, ToggleSectionArgs(sectionType: SectionType.Wallet))

proc toggleBrowserSection*(self: Controller) =
  self.events.emit(TOGGLE_SECTION, ToggleSectionArgs(sectionType: SectionType.Browser))

proc toggleCommunitySection*(self: Controller) =
  self.events.emit(TOGGLE_SECTION, ToggleSectionArgs(sectionType: SectionType.Community))

proc toggleNodeManagementSection*(self: Controller) =
  self.events.emit(TOGGLE_SECTION, ToggleSectionArgs(sectionType: SectionType.NodeManagement))

proc isCommunityHistoryArchiveSupportEnabled*(self: Controller): bool =
  self.nodeConfigurationService.isCommunityHistoryArchiveSupportEnabled()

proc enableCommunityHistoryArchiveSupport*(self: Controller): bool =
  self.nodeConfigurationService.enableCommunityHistoryArchiveSupport()

proc disableCommunityHistoryArchiveSupport*(self: Controller): bool =
  self.nodeConfigurationService.disableCommunityHistoryArchiveSupport()
