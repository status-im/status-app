import nimqml, chronicles

import ../../../../../app/global/global_singleton

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface

import ../../../../core/eventemitter
import ../../../../../app_service/service/settings/service as settings_service
import ../../../../../app_service/service/privacy/service as privacy_service
import ../../../../../app_service/service/general/service as general_service

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(delegate: delegate_interface.AccessInterface, events: EventEmitter,
  settingsService: settings_service.Service,
  privacyService: privacy_service.Service,
  generalService: general_service.Service):
  Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, settingsService, privacyService, generalService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete

method load*(self: Module) =
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.privacyModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

method changePassword*(self: Module, password: string, newPassword: string) =
  self.controller.changePassword(password, newPassword)

method isMnemonicBackedUp*(self: Module): bool =
  return self.controller.isMnemonicBackedUp()

method mnemonicBackedUp*(self: Module) =
  self.view.emitMnemonicBackedUpSignal()

method onPasswordChanged*(self: Module, success: bool, errorMsg: string) =
  if singletonInstance.localAccountSettings.getStoreToKeychainValue() != LS_VALUE_NEVER:
    singletonInstance.localAccountSettings.setStoreToKeychainValue(LS_VALUE_NOT_NOW)

  self.view.emitPasswordChangedSignal(success, errorMsg)

method getMnemonic*(self: Module): string =
  self.controller.getMnemonic()

method removeMnemonic*(self: Module) =
  self.controller.removeMnemonic()

method mnemonicWasShown*(self: Module) =
  self.controller.mnemonicWasShown()

method getMessagesFromContactsOnly*(self: Module): bool =
  return self.controller.getMessagesFromContactsOnly()

method setMessagesFromContactsOnly*(self: Module, value: bool) =
  if(not self.controller.setMessagesFromContactsOnly(value)):
    error "an error occurred while saving messages from contacts only flag"

method getSyncingOnMobileNetwork*(self: Module): bool =
  return self.controller.getSyncingOnMobileNetwork()

method setSyncingOnMobileNetwork*(self: Module, value: bool) =
  if(not self.controller.setSyncingOnMobileNetwork(value)):
    error "an error occurred while saving syncing on mobile network flag"

method urlUnfurlingMode*(self: Module): int =
  return self.controller.urlUnfurlingMode()

method setUrlUnfurlingMode*(self: Module, value: int) =
  self.controller.setUrlUnfurlingMode(value)

method getPasswordStrengthScore*(self: Module, password: string): int =
  return self.controller.getPasswordStrengthScore(password, singletonInstance.userProfile.getUsername())

method onUrlUnfurlingModeUpdated*(self: Module, mode: int) =
  self.view.emitUrlUnfurlingModeUpdated(mode)

method messagesFromContactsOnlyChanged*(self: Module) =
  self.view.messagesFromContactsOnlyChanged()
