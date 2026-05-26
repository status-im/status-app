import nimqml
import io_interface
import ../io_interface as delegate_interface
import view
import ../../../global/global_singleton
import ../../../core/eventemitter
import bookmark/module as bookmark_module
import dapps/module as dapps_module
import current_account/module as current_account_module
import ../../../../app_service/service/bookmarks/service as bookmark_service
import ../../../../app_service/service/settings/service as settings_service
import ../../../../app_service/service/network/service as network_service
import ../../../../app_service/service/dapp_permissions/service as dapp_permissions_service
import ../../../../app_service/service/wallet_account/service as wallet_account_service
import ../../../../app_service/service/token/service as token_service
import ../../../../app_service/service/currency/service as currency_service
import ../../../../app_service/service/saved_address/service as saved_address_service
import ../../../../app_service/service/browser_preferences/service as browser_preferences_service
import ../wallet_section/activity/controller as activity_controller

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    events: EventEmitter
    view: View
    viewVariant: QVariant
    moduleLoaded: bool
    bookmarkModule: bookmark_module.AccessInterface
    dappsModule: dapps_module.AccessInterface
    currentAccountModule: current_account_module.AccessInterface
    activityController: activity_controller.Controller
    browserPreferencesService: browser_preferences_service.Service

proc newModule*(delegate: delegate_interface.AccessInterface,
    events: EventEmitter,
    bookmarkService: bookmark_service.Service,
    settingsService: settings_service.Service,
    networkService: network_service.Service,
    dappPermissionsService: dapp_permissions_service.Service,
    walletAccountService: wallet_account_service.Service,
    tokenService: token_service.Service,
    currencyService: currency_service.Service,
    savedAddressService: saved_address_service.Service,
    browserPreferencesService: browser_preferences_service.Service
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.activityController = activity_controller.newController(
    currencyService,
    tokenService,
    savedAddressService,
    networkService,
    events)
  result.view = view.newView(result, result.activityController)
  result.viewVariant = newQVariant(result.view)
  result.moduleLoaded = false
  result.bookmarkModule = bookmark_module.newModule(result, events, bookmarkService)
  result.dappsModule = dapps_module.newModule(result, dappPermissionsService, walletAccountService)
  result.currentAccountModule = current_account_module.newModule(result, events, walletAccountService, networkService, tokenService, currencyService)
  result.browserPreferencesService = browserPreferencesService

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.activityController.delete
  self.bookmarkModule.delete
  self.dappsModule.delete
  self.currentAccountModule.delete

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("browserSection", self.viewVariant)
  self.currentAccountModule.load()
  self.bookmarkModule.load()
  self.dappsModule.load()
  self.view.load()

method onActivated*(self: Module) =
  self.bookmarkModule.onActivated()
  self.dappsModule.onActivated()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

proc checkIfModuleDidLoad(self: Module) =
  if(not self.bookmarkModule.isLoaded()):
    return

  if(not self.dappsModule.isLoaded()):
    return

  if(not self.currentAccountModule.isLoaded()):
    return

  self.moduleLoaded = true
  self.delegate.browserSectionDidLoad()

method bookmarkDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method dappsDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method viewDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method openUrl*(self: Module, url: string) =
  self.view.sendOpenUrlSignal(url)

method putPreference*(self: Module, category, key, value: string) =
  discard self.browserPreferencesService.put(category, key, value)

method getPreference*(self: Module, category, key: string): string =
  self.browserPreferencesService.get(category, key)

method purgePreferenceCategory*(self: Module, category: string, validKeys: seq[string]) =
  discard self.browserPreferencesService.purgeCategory(category, validKeys)
