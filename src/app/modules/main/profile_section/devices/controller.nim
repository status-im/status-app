import chronicles
import io_interface

import app/core/eventemitter
import app_service/service/settings/service as settings_service
import app_service/service/devices/service as devices_service

import app/modules/shared_modules/keycard_popup/io_interface as keycard_shared_module

const UNIQUE_SYNCING_LOGGED_IN_USER_AUTHENTICATION_IDENTIFIER* = "Syncing-LoggedInUser-Authentication"

logScope:
  topics = "profile-section-devices-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    settingsService: settings_service.Service
    devicesService: devices_service.Service

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  settingsService: settings_service.Service,
  devicesService: devices_service.Service): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.settingsService = settingsService
  result.devicesService = devicesService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_DEVICES_LOADED) do(e: Args):
    let args = DevicesArg(e)
    self.delegate.onDevicesLoaded(args.devices)

  self.events.on(SIGNAL_ERROR_LOADING_DEVICES) do(e: Args):
    self.delegate.onDevicesLoadingErrored()

  self.events.on(SIGNAL_UPDATE_DEVICE) do(e: Args):
    let args = UpdateInstallationArgs(e)
    self.delegate.updateOrAddDevice(args.installation)

  self.events.on(SIGNAL_INSTALLATION_NAME_UPDATED) do(e: Args):
    let args = UpdateInstallationNameArgs(e)
    self.delegate.updateInstallationName(args.installationId, args.name)

  self.events.on(SIGNAL_SHARED_KEYCARD_MODULE_USER_AUTHENTICATED) do(e: Args):
    let args = SharedKeycarModuleArgs(e)
    if args.uniqueIdentifier != UNIQUE_SYNCING_LOGGED_IN_USER_AUTHENTICATION_IDENTIFIER:
      return
    self.delegate.onLoggedInUserAuthenticated(args.pin, args.password, args.keyUid, args.additinalPathsDetails)

  self.events.on(SIGNAL_LOCAL_PAIRING_STATUS_UPDATE) do(e: Args):
    let args = LocalPairingStatus(e)
    if args.pairingType != PairingType.AppSync:
      return
    self.delegate.onLocalPairingStatusUpdate(args)


proc getMyInstallationId*(self: Controller): string =
  return self.settingsService.getInstallationId()

proc asyncLoadDevices*(self: Controller) =
  self.devicesService.asyncLoadDevices()

proc getAllDevices*(self: Controller): seq[InstallationDto] =
  return self.devicesService.getAllDevices()

proc setInstallationName*(self: Controller, installationId: string, name: string) =
  self.devicesService.setInstallationName(installationId, name)

proc syncAllDevices*(self: Controller) =
  self.devicesService.syncAllDevices()

proc advertise*(self: Controller) =
  self.devicesService.advertise()

#
# Pairing status
#

proc authenticateLoggedInUser*(self: Controller, additionalBip44Paths: seq[string] = @[]) =
  var data = SharedKeycarModuleAuthenticationArgs(
    uniqueIdentifier: UNIQUE_SYNCING_LOGGED_IN_USER_AUTHENTICATION_IDENTIFIER,
    additionalBip44Paths: additionalBip44Paths
  )
  self.events.emit(SIGNAL_SHARED_KEYCARD_MODULE_AUTHENTICATE_USER, data)

#
# Backend actions
#

proc validateConnectionString*(self: Controller, connectionString: string): string =
  return self.devicesService.validateConnectionString(connectionString)

proc getConnectionStringForBootstrappingAnotherDevice*(self: Controller, password, chatKey: string, messageSyncingEnabled: bool): string =
  return self.devicesService.getConnectionStringForBootstrappingAnotherDevice(password, chatKey, messageSyncingEnabled)

proc inputConnectionStringForBootstrapping*(self: Controller, connectionString: string) =
  self.devicesService.inputConnectionStringForBootstrapping(connectionString)

proc pairDevice*(self: Controller, installationId: string): string =
  return self.devicesService.pairDevice(installationId)

proc unpairDevice*(self: Controller, installationId: string): string =
  return self.devicesService.unpairDevice(installationId)
