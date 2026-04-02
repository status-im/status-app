import nimqml
import io_interface, view, controller
import ../io_interface as delegate_interface
import ../../../global/global_singleton
import ../../../core/eventemitter
import ../../../../app_service/service/profile/service as profile_service
import ../../../../app_service/service/accounts/service as accounts_service
import ../../../../app_service/service/settings/service as settings_service
import ../../../../app_service/service/contacts/service as contacts_service
import ../../../../app_service/service/about/service as about_service
import ../../../../app_service/service/privacy/service as privacy_service
import ../../../../app_service/service/node_configuration/service as node_configuration_service
import ../../../../app_service/service/devices/service as devices_service
import ../../../../app_service/service/mailservers/service as mailservers_service
import ../../../../app_service/service/chat/service as chat_service
import ../../../../app_service/service/stickers/service as stickersService
import ../../../../app_service/service/ens/service as ens_service
import ../../../../app_service/service/network/service as network_service
import ../../../../app_service/service/wallet_account/service as wallet_account_service
import ../../../../app_service/service/general/service as general_service
import ../../../../app_service/service/community/service as community_service
import ../../../../app_service/service/keycard/service as keycard_service
import ../../../../app_service/service/token/service as token_service
import ../../../../app_service/service/node/service as node_service

import ./profile/module as profile_module
import ./contacts/module as contacts_module
import ./privacy/module as privacy_module
import ./about/module as about_module
import ./advanced/module as advanced_module
import ./devices/module as devices_module
import ./sync/module as sync_module
import ./waku/module as waku_module
import ./notifications/module as notifications_module
import ./ens_usernames/module as ens_usernames_module
import ./communities/module as communities_module
import ./keycard/module as keycard_module
import ./keycard_new/module as keycard_new_module
import ./wallet/module as wallet_module

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool

    profileModule: profile_module.AccessInterface
    contactsModule: contacts_module.AccessInterface
    privacyModule: privacy_module.AccessInterface
    aboutModule: about_module.AccessInterface
    advancedModule: advanced_module.AccessInterface
    devicesModule: devices_module.AccessInterface
    syncModule: sync_module.AccessInterface
    wakuModule: waku_module.AccessInterface
    notificationsModule: notifications_module.AccessInterface
    ensUsernamesModule: ens_usernames_module.AccessInterface
    communitiesModule: communities_module.AccessInterface
    keycardModule: keycard_module.AccessInterface
    keycardNewModule: keycard_new_module.AccessInterface
    walletModule: wallet_module.AccessInterface

proc newModule*(delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  accountsService: accounts_service.Service,
  settingsService: settings_service.Service,
  stickersService: stickers_service.Service,
  profileService: profile_service.Service,
  contactsService: contacts_service.Service,
  aboutService: about_service.Service,
  privacyService: privacy_service.Service,
  nodeConfigurationService: node_configuration_service.Service,
  devicesService: devices_service.Service,
  mailserversService: mailservers_service.Service,
  chatService: chat_service.Service,
  ensService: ens_service.Service,
  walletAccountService: wallet_account_service.Service,
  generalService: general_service.Service,
  communityService: community_service.Service,
  networkService: network_service.Service,
  keycardService: keycard_service.Service,
  tokenService: token_service.Service,
  nodeService: node_service.Service
): Module =
  result = Module()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result)
  result.moduleLoaded = false

  result.profileModule = profile_module.newModule(result, events, profileService, settingsService, communityService,
    walletAccountService, tokenService)
  result.contactsModule = contacts_module.newModule(result, events, contactsService, chatService, networkService)
  result.privacyModule = privacy_module.newModule(result, events, settingsService, privacyService,
    generalService)
  result.aboutModule = about_module.newModule(result, events, aboutService)
  result.advancedModule = advanced_module.newModule(result, events, settingsService, stickersService,
    nodeConfigurationService)
  result.devicesModule = devices_module.newModule(result, events, settingsService, devicesService)
  result.syncModule = sync_module.newModule(result, events, settingsService, nodeConfigurationService,
    generalService, devicesService)
  result.wakuModule = waku_module.newModule(result, events, settingsService, nodeConfigurationService)
  result.notificationsModule = notifications_module.newModule(result, events, settingsService, chatService,
    contactsService, communityService)
  result.ensUsernamesModule = ens_usernames_module.newModule(
    result, events, settingsService, ensService, walletAccountService, networkService, tokenService
  )
  result.communitiesModule = communities_module.newModule(result, communityService)
  result.keycardModule = keycard_module.newModule(result, events, keycardService, settingsService, networkService,
    privacyService, accountsService, walletAccountService)

  result.keycardNewModule = keycard_new_module.newModule(result, walletAccountService)

  result.walletModule = wallet_module.newModule(result, events, accountsService, walletAccountService, settingsService,
    networkService, devicesService, nodeService)

  singletonInstance.engine.setRootContextProperty("profileSectionModule", result.viewVariant)

method delete*(self: Module) =
  self.profileModule.delete
  self.contactsModule.delete
  self.privacyModule.delete
  self.aboutModule.delete
  self.advancedModule.delete
  self.devicesModule.delete
  self.syncModule.delete
  self.wakuModule.delete
  self.communitiesModule.delete
  self.keycardModule.delete
  self.keycardNewModule.delete

  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method load*(self: Module) =
  self.view.load()
  self.profileModule.load()
  self.contactsModule.load()
  self.privacyModule.load()
  self.aboutModule.load()
  self.advancedModule.load()
  self.devicesModule.load()
  self.syncModule.load()
  self.wakuModule.load()
  self.notificationsModule.load()
  self.ensUsernamesModule.load()
  self.communitiesModule.load()
  self.keycardModule.load()
  self.keycardNewModule.load()
  self.walletModule.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

proc checkIfModuleDidLoad(self: Module) =
  if(not self.profileModule.isLoaded()):
    return

  if(not self.contactsModule.isLoaded()):
    return

  if(not self.privacyModule.isLoaded()):
    return

  if(not self.aboutModule.isLoaded()):
    return

  if(not self.advancedModule.isLoaded()):
    return

  if(not self.devicesModule.isLoaded()):
    return

  if(not self.syncModule.isLoaded()):
    return

  if(not self.wakuModule.isLoaded()):
    return

  if(not self.notificationsModule.isLoaded()):
    return

  if(not self.ensUsernamesModule.isLoaded()):
    return

  if(not self.communitiesModule.isLoaded()):
    return

  if(not self.keycardModule.isLoaded()):
    return

  if(not self.keycardNewModule.isLoaded()):
    return

  if(not self.walletModule.isLoaded()):
    return

  self.moduleLoaded = true
  self.delegate.profileSectionDidLoad()

method viewDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method profileModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getProfileModule*(self: Module): QVariant =
  self.profileModule.getModuleAsVariant()

method contactsModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getContactsModule*(self: Module): QVariant =
  self.contactsModule.getModuleAsVariant()

method privacyModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getPrivacyModule*(self: Module): QVariant =
  self.privacyModule.getModuleAsVariant()

method aboutModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method advancedModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getAdvancedModule*(self: Module): QVariant =
  self.advancedModule.getModuleAsVariant()

method devicesModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getDevicesModule*(self: Module): QVariant =
  self.devicesModule.getModuleAsVariant()

method syncModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method wakuModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getSyncModule*(self: Module): QVariant =
  self.syncModule.getModuleAsVariant()

method getWakuModule*(self: Module): QVariant =
  self.wakuModule.getModuleAsVariant()

method notificationsModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getNotificationsModule*(self: Module): QVariant =
  self.notificationsModule.getModuleAsVariant()

method ensUsernamesModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getEnsUsernamesModule*(self: Module): QVariant =
  self.ensUsernamesModule.getModuleAsVariant()

method getCommunitiesModule*(self: Module): QVariant =
  self.communitiesModule.getModuleAsVariant()

method communitiesModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getKeycardModule*(self: Module): QVariant =
  self.keycardModule.getModuleAsVariant()

method keycardNewModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getKeycardNewModule*(self: Module): QVariant =
  self.keycardNewModule.getModuleAsVariant()

method walletModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method getWalletModule*(self: Module): QVariant =
  return self.walletModule.getModuleAsVariant()
