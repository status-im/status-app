import io_interface, chronicles

import ../../../../core/eventemitter
import ../../../../../app_service/service/settings/service as settings_service
import ../../../../../app_service/service/privacy/service as privacy_service
import ../../../../../app_service/service/general/service as general_service

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    settingsService: settings_service.Service
    privacyService: privacy_service.Service
    generalService: general_service.Service

proc newController*(delegate: io_interface.AccessInterface, events: EventEmitter,
  settingsService: settings_service.Service,
  privacyService: privacy_service.Service,
  generalService: general_service.Service): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.settingsService = settingsService
  result.privacyService = privacyService
  result.generalService = generalService

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =

  self.events.on(SIGNAL_MNEMONIC_REMOVED) do(e: Args):
    self.delegate.mnemonicBackedUp()

  self.events.on(SIGNAL_PASSWORD_CHANGED) do(e: Args):
    var args = OperationSuccessArgs(e)
    self.delegate.onPasswordChanged(args.success, args.errorMsg)

  self.events.on(SIGNAL_URL_UNFURLING_MODE_UPDATED) do(e: Args):
    var args = UrlUnfurlingModeArgs(e)
    self.delegate.onUrlUnfurlingModeUpdated(args.value.int)

  self.events.on(SIGNAL_MESSAGES_FROM_CONTACTS_ONLY_UPDATED) do(e: Args):
    self.delegate.messagesFromContactsOnlyChanged()

proc isMnemonicBackedUp*(self: Controller): bool =
  return self.privacyService.isMnemonicBackedUp()

proc changePassword*(self: Controller, password: string, newPassword: string) =
  self.privacyService.changePassword(password, newPassword)

proc getMnemonic*(self: Controller): string =
  return self.privacyService.getMnemonic()

proc removeMnemonic*(self: Controller) =
  self.privacyService.removeMnemonic()

proc mnemonicWasShown*(self: Controller) =
  self.settingsService.mnemonicWasShown()

proc getMessagesFromContactsOnly*(self: Controller): bool =
  return self.settingsService.getMessagesFromContactsOnly()

proc setMessagesFromContactsOnly*(self: Controller, value: bool): bool =
  return self.settingsService.saveMessagesFromContactsOnly(value)

proc getSyncingOnMobileNetwork*(self: Controller): bool =
  return self.settingsService.getSyncingOnMobileNetwork()

proc setSyncingOnMobileNetwork*(self: Controller, value: bool): bool =
  return self.settingsService.saveSyncingOnMobileNetwork(value)

proc urlUnfurlingMode*(self: Controller): int =
  return int(self.settingsService.urlUnfurlingMode())

proc setUrlUnfurlingMode*(self: Controller, value: int) =
  let mode = toUrlUnfurlingMode(value)
  if not self.settingsService.saveUrlUnfurlingMode(mode):
    error "failed to save url unfurling mode setting", value

proc getPasswordStrengthScore*(self: Controller, password, userName: string): int =
  return self.generalService.getPasswordStrengthScore(password, userName)
