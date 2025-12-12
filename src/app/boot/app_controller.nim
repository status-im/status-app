import nimqml, sequtils, chronicles

import app_service/service/general/service as general_service
import app_service/service/keycard/service as keycard_service
import app_service/service/keycardV2/service as keycard_serviceV2
import app_service/service/accounts/service as accounts_service
import app_service/service/contacts/service as contacts_service
import app_service/service/chat/service as chat_service
import app_service/service/community/service as community_service
import app_service/service/message/service as message_service
import app_service/service/token/service as token_service
import app_service/service/collectible/service as collectible_service
import app_service/service/currency/service as currency_service
import app_service/service/ramp/service as ramp_service
import app_service/service/transaction/service as transaction_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/bookmarks/service as bookmark_service
import app_service/service/dapp_permissions/service as dapp_permissions_service
import app_service/service/privacy/service as privacy_service
import app_service/service/node/service as node_service
import app_service/service/profile/service as profile_service
import app_service/service/settings/service as settings_service
import app_service/service/stickers/service as stickers_service
import app_service/service/about/service as about_service
import app_service/service/node_configuration/service as node_configuration_service
import app_service/service/network/service as network_service
import app_service/service/activity_center/service as activity_center_service
import app_service/service/saved_address/service as saved_address_service
import app_service/service/following_address/service as following_address_service
import app_service/service/devices/service as devices_service
import app_service/service/mailservers/service as mailservers_service
import app_service/service/gif/service as gif_service
import app_service/service/ens/service as ens_service
import app_service/service/community_tokens/service as tokens_service
import app_service/service/network_connection/service as network_connection_service
import app_service/service/shared_urls/service as shared_urls_service
import app_service/service/metrics/service as metrics_service
import app_service/service/market/service as market_service

import app/modules/onboarding/module as onboarding_module
import app/modules/onboarding/post_onboarding/[keycard_replacement_task, keycard_convert_account, save_biometrics_task]
import app/modules/main/module as main_module
import app/modules/keycard_channel/module as keycard_channel_module
import app/core/notifications/notifications_manager
import app/global/global_singleton
import app/global/app_signals
import app/core/[main]

import constants as main_constants

when defined(android) or defined(ios):
  import app/mobile/push_notifications

logScope:
  topics = "app-controller"

type
  AppController* = ref object of RootObj
    statusFoundation: StatusFoundation
    notificationsManager*: NotificationsManager

    # Global
    appSettingsVariant: QVariant
    localAppSettingsVariant: QVariant
    localAccountSettingsVariant: QVariant
    localAccountSensitiveSettingsVariant: QVariant
    userProfileVariant: QVariant
    globalUtilsVariant: QVariant
    metricsVariant: QVariant

    # Services
    generalService: general_service.Service
    keycardService*: keycard_service.Service
    keycardServiceV2*: keycard_serviceV2.Service
    accountsService: accounts_service.Service
    contactsService: contacts_service.Service
    chatService: chat_service.Service
    communityService: community_service.Service
    messageService: message_service.Service
    tokenService: token_service.Service
    collectibleService: collectible_service.Service
    currencyService: currency_service.Service
    rampService: ramp_service.Service
    transactionService: transaction_service.Service
    walletAccountService: wallet_account_service.Service
    bookmarkService: bookmark_service.Service
    dappPermissionsService: dapp_permissions_service.Service
    profileService: profile_service.Service
    settingsService: settings_service.Service
    stickersService: stickers_service.Service
    aboutService: about_service.Service
    networkService: network_service.Service
    activityCenterService: activity_center_service.Service
    privacyService: privacy_service.Service
    nodeConfigurationService: node_configuration_service.Service
    savedAddressService: saved_address_service.Service
    followingAddressService: following_address_service.Service
    devicesService: devices_service.Service
    mailserversService: mailservers_service.Service
    nodeService: node_service.Service
    gifService: gif_service.Service
    ensService: ens_service.Service
    tokensService: tokens_service.Service
    networkConnectionService: network_connection_service.Service
    sharedUrlsService: shared_urls_service.Service
    metricsService: metrics_service.MetricsService
    marketService: market_service.Service

    # Modules
    onboardingModule: onboarding_module.AccessInterface
    mainModule: main_module.AccessInterface
    keycardChannelModule: keycard_channel_module.AccessInterface

#################################################
# Forward declaration section
proc load(self: AppController)
proc buildAndRegisterLocalAccountSensitiveSettings(self: AppController)
proc buildAndRegisterUserProfile(self: AppController)
proc runPostOnboardingTasks(self: AppController)

# Startup Module Delegate Interface
proc onboardingDidLoad*(self: AppController)
proc userLoggedIn*(self: AppController): string
proc appReady*(self: AppController)
proc logout*(self: AppController)
proc finishAppLoading*(self: AppController)

# Main Module Delegate Interface
proc mainDidLoad*(self: AppController)
#################################################

proc connect(self: AppController) =
  self.statusFoundation.events.once("nodeStopped") do(a: Args):
    # not sure, but maybe we should take some actions when node stops
    discard

  # Handle runtime log level settings changes
  if not main_constants.runtimeLogLevelSet():
    self.statusFoundation.events.on(node_configuration_service.SIGNAL_NODE_LOG_LEVEL_UPDATE) do(a: Args):
      let args = NodeLogLevelUpdatedArgs(a)
      if args.logLevel == chronicles.LogLevel.DEBUG:
        setLogLevel(chronicles.LogLevel.DEBUG)
      elif defined(production):
        setLogLevel(chronicles.LogLevel.INFO)

proc newAppController*(statusFoundation: StatusFoundation): AppController =
  result = AppController()
  result.statusFoundation = statusFoundation

  # Preparing settings service to be exposed later as global QObject
  result.settingsService = settings_service.newService(statusFoundation.events)
  result.appSettingsVariant = newQVariant(result.settingsService)
  result.notificationsManager = newNotificationsManager(statusFoundation.events, result.settingsService)
  result.metricsService = metrics_service.newService(statusFoundation.threadpool)
  result.metricsVariant = newQVariant(result.metricsService)

  # Global
  result.localAppSettingsVariant = newQVariant(singletonInstance.localAppSettings)
  result.localAccountSettingsVariant = newQVariant(singletonInstance.localAccountSettings)
  result.localAccountSensitiveSettingsVariant = newQVariant(singletonInstance.localAccountSensitiveSettings)
  result.userProfileVariant = newQVariant(singletonInstance.userProfile)
  result.globalUtilsVariant = newQVariant(singletonInstance.utils)

  # Services
  result.generalService = general_service.newService(statusFoundation.events, statusFoundation.threadpool)
  result.keycardService = keycard_service.newService(statusFoundation.events, statusFoundation.threadpool)
  result.keycardServiceV2 = keycard_serviceV2.newService(statusFoundation.events, statusFoundation.threadpool)
  result.nodeConfigurationService = node_configuration_service.newService(statusFoundation.events)
  result.accountsService = accounts_service.newService(statusFoundation.events, statusFoundation.threadpool)
  result.networkService = network_service.newService(statusFoundation.events, result.settingsService)
  result.contactsService = contacts_service.newService(
    statusFoundation.events, statusFoundation.threadpool, result.networkService, result.settingsService
  )
  result.chatService = chat_service.newService(statusFoundation.events, statusFoundation.threadpool, result.contactsService)
  result.activityCenterService = activity_center_service.newService(statusFoundation.events, statusFoundation.threadpool, result.chatService)
  result.tokenService = token_service.newService(
    statusFoundation.events, statusFoundation.threadpool, result.networkService, result.settingsService
  )
  result.collectibleService = collectible_service.newService(
    statusFoundation.events, statusFoundation.threadpool
  )
  result.currencyService = currency_service.newService(
    statusFoundation.events, statusFoundation.threadpool, result.tokenService, result.settingsService
  )
  result.walletAccountService = wallet_account_service.newService(
    statusFoundation.events, statusFoundation.threadpool, result.settingsService, result.accountsService,
    result.tokenService, result.networkService, result.currencyService
  )
  result.messageService = message_service.newService(
    statusFoundation.events,
    statusFoundation.threadpool,
    result.chatService,
    result.contactsService,
    result.tokenService,
    result.walletAccountService,
    result.networkService,
  )
  result.communityService = community_service.newService(statusFoundation.events,
    statusFoundation.threadpool, result.chatService, result.activityCenterService, result.messageService)
  result.rampService = ramp_service.newService(statusFoundation.events, statusFoundation.threadpool)
  result.transactionService = transaction_service.newService(statusFoundation.events, statusFoundation.threadpool,
    result.currencyService, result.networkService, result.settingsService, result.tokenService)
  result.bookmarkService = bookmark_service.newService(statusFoundation.events)
  result.profileService = profile_service.newService(statusFoundation.events, statusFoundation.threadpool, result.settingsService)
  result.stickersService = stickers_service.newService(
    statusFoundation.events,
    statusFoundation.threadpool,
    result.settingsService,
    result.walletAccountService,
    result.transactionService,
    result.networkService,
    result.chatService,
    result.tokenService
  )
  result.aboutService = about_service.newService(statusFoundation.events, statusFoundation.threadpool)
  result.dappPermissionsService = dapp_permissions_service.newService()
  result.privacyService = privacy_service.newService(statusFoundation.events, result.settingsService,
  result.accountsService)
  result.savedAddressService = saved_address_service.newService(statusFoundation.threadpool, statusFoundation.events,
    result.networkService, result.settingsService)
  result.followingAddressService = following_address_service.newService(statusFoundation.threadpool, statusFoundation.events, 
    result.networkService)
  result.devicesService = devices_service.newService(statusFoundation.events, statusFoundation.threadpool,
    result.settingsService, result.accountsService, result.walletAccountService)
  result.mailserversService = mailservers_service.newService(statusFoundation.events, statusFoundation.threadpool,
    result.settingsService, result.nodeConfigurationService)
  result.nodeService = node_service.newService(statusFoundation.events, result.settingsService, result.nodeConfigurationService)
  result.gifService = gif_service.newService(result.settingsService, statusFoundation.events, statusFoundation.threadpool)
  result.ensService = ens_service.newService(statusFoundation.events, statusFoundation.threadpool,
    result.settingsService, result.walletAccountService, result.transactionService,
    result.networkService, result.tokenService)
  result.tokensService = tokens_service.newService(statusFoundation.events, statusFoundation.threadpool,
    result.networkService, result.transactionService, result.tokenService, result.settingsService, result.walletAccountService,
    result.activityCenterService, result.communityService, result.currencyService)
  result.networkConnectionService = network_connection_service.newService(statusFoundation.events,
    result.walletAccountService, result.networkService, result.nodeService, result.tokenService)
  result.sharedUrlsService = shared_urls_service.newService(statusFoundation.events, statusFoundation.threadpool)
  result.marketService = market_service.newService(statusFoundation.events, result.settingsService)

  # Modules
  result.keycardChannelModule = keycard_channel_module.newModule(statusFoundation.events)
  result.onboardingModule = onboarding_module.newModule[AppController](
    result,
    statusFoundation.events,
    result.generalService,
    result.accountsService,
    result.walletAccountService,
    result.devicesService,
    result.keycardServiceV2,
  )
  result.mainModule = main_module.newModule[AppController](
    result,
    statusFoundation.events,
    statusFoundation.urlsManager,
    result.accountsService,
    result.chatService,
    result.communityService,
    result.messageService,
    result.tokenService,
    result.collectibleService,
    result.currencyService,
    result.rampService,
    result.transactionService,
    result.walletAccountService,
    result.bookmarkService,
    result.profileService,
    result.settingsService,
    result.contactsService,
    result.aboutService,
    result.dappPermissionsService,
    result.privacyService,
    result.stickersService,
    result.activityCenterService,
    result.savedAddressService,
    result.followingAddressService,
    result.nodeConfigurationService,
    result.devicesService,
    result.mailserversService,
    result.nodeService,
    result.gifService,
    result.ensService,
    result.tokensService,
    result.networkService,
    result.generalService,
    result.keycardService,
    result.networkConnectionService,
    result.sharedUrlsService,
    result.marketService,
    statusFoundation.threadpool
  )

  # Do connections
  result.connect()

proc delete*(self: AppController) =
  info "logging out..."
  self.generalService.logout()

  singletonInstance.delete
  self.notificationsManager.delete
  self.contactsService.delete
  self.bookmarkService.delete
  self.gifService.delete
  if not self.onboardingModule.isNil:
    self.onboardingModule.delete
    self.onboardingModule = nil
  self.mainModule.delete
  if not self.keycardChannelModule.isNil:
    self.keycardChannelModule.delete
    self.keycardChannelModule = nil

  self.appSettingsVariant.delete
  self.localAppSettingsVariant.delete
  self.localAccountSettingsVariant.delete
  self.localAccountSensitiveSettingsVariant.delete
  self.userProfileVariant.delete
  self.globalUtilsVariant.delete
  self.metricsVariant.delete

  self.accountsService.delete
  self.chatService.delete
  self.communityService.delete
  self.currencyService.delete
  self.collectibleService.delete
  self.tokenService.delete
  self.rampService.delete
  self.transactionService.delete
  self.walletAccountService.delete
  self.aboutService.delete
  self.networkService.delete
  self.activityCenterService.delete
  self.dappPermissionsService.delete
  self.nodeConfigurationService.delete
  self.nodeService.delete
  self.settingsService.delete
  self.stickersService.delete
  self.savedAddressService.delete
  self.devicesService.delete
  self.mailserversService.delete
  self.messageService.delete
  self.privacyService.delete
  self.profileService.delete
  self.generalService.delete
  self.ensService.delete
  self.tokensService.delete
  self.keycardService.delete
  self.keycardServiceV2.delete
  self.networkConnectionService.delete
  self.metricsService.delete
  self.marketService.delete

proc initializeQmlContext(self: AppController) =
  singletonInstance.engine.setRootContextProperty("localAppSettings", self.localAppSettingsVariant)
  singletonInstance.engine.setRootContextProperty("localAccountSettings", self.localAccountSettingsVariant)
  singletonInstance.engine.setRootContextProperty("globalUtils", self.globalUtilsVariant)
  singletonInstance.engine.setRootContextProperty("metrics", self.metricsVariant)

  # Load keycard channel module (available before login for Session API)
  self.keycardChannelModule.load()

  singletonInstance.engine.load(newQUrl("qrc:///main.qml"))

proc onboardingDidLoad*(self: AppController) =
  self.initializeQmlContext()

proc mainDidLoad*(self: AppController) =
  if not self.onboardingModule.isNil:
    self.runPostOnboardingTasks()

  # NB: after onboarding is finished, we need to switch back to the old service (Settings/Keycard)
  # TODO remove `keycardService` when everything is ported to `keycardServiceV2`
  self.keycardService.resetAPI()
  self.keycardService.init()

proc start*(self: AppController) =
  self.keycardServiceV2.init()
  self.generalService.init()
  self.accountsService.init()
  self.devicesService.init()

  self.onboardingModule.load()

proc load(self: AppController) =
  self.settingsService.init()

  self.buildAndRegisterLocalAccountSensitiveSettings()
  self.buildAndRegisterUserProfile()

  self.settingsService.migrateBackupPath()

  self.notificationsManager.init()
  self.profileService.init()
  self.nodeConfigurationService.init()
  self.mailserversService.init()
  self.contactsService.init()
  self.chatService.init()
  self.messageService.init()
  self.communityService.init()
  self.rampService.init()
  self.bookmarkService.init()
  self.dappPermissionsService.init()
  self.transactionService.init()
  self.stickersService.init()
  self.activityCenterService.init()
  self.savedAddressService.init()
  self.followingAddressService.init()
  self.aboutService.init()
  self.ensService.init()
  self.tokensService.init()
  self.gifService.init()
  self.networkConnectionService.init()
  self.marketService.init()

  # Accessible after user login
  singletonInstance.engine.setRootContextProperty("appSettings", self.appSettingsVariant)
  singletonInstance.engine.setRootContextProperty("globalUtils", self.globalUtilsVariant)

  self.networkService.init()
  self.tokenService.init()
  self.collectibleService.init()
  self.currencyService.init()
  self.walletAccountService.init()

  # Apply runtime log level settings
  if not main_constants.runtimeLogLevelSet():
    if self.nodeConfigurationService.isDebugEnabled():
      setLogLevel(chronicles.LogLevel.DEBUG)

  # load main module
  self.mainModule.load(
    self.statusFoundation.events,
    self.settingsService,
    self.nodeConfigurationService,
    self.contactsService,
    self.chatService,
    self.communityService,
    self.messageService,
    self.mailserversService,
  )

proc userLoggedIn*(self: AppController): string =
  try:
    self.generalService.startMessenger()
    
    # After messenger is started, register push notification token if available
    when defined(android) or defined(ios):
      discard registerPushNotificationToken()
    
    return ""
  except Exception as e:
    let errDescription = e.msg
    error "error: ", errDescription
    return errDescription

proc appReady*(self: AppController) =
  self.statusFoundation.appReady()

proc finishAppLoading*(self: AppController) =
  self.load()

  if not self.onboardingModule.isNil:
    let account = self.accountsService.getLoggedInAccount()
    self.onboardingModule.onAppLoaded(account.keyUid)
    self.onboardingModule = nil

  self.mainModule.checkAndPerformProfileMigrationIfNeeded()

  self.notificationsManager.onAppReady()

proc logout*(self: AppController) =
  self.generalService.logout()

proc buildAndRegisterLocalAccountSensitiveSettings(self: AppController) =
  var pubKey = self.settingsService.getPublicKey()
  singletonInstance.localAccountSensitiveSettings.setFileName(pubKey)
  singletonInstance.engine.setRootContextProperty("localAccountSensitiveSettings", self.localAccountSensitiveSettingsVariant)

proc buildAndRegisterUserProfile(self: AppController) =
  let pubKey = self.settingsService.getPublicKey()
  let alias = self.settingsService.getName()
  var preferredName = self.settingsService.getPreferredName()
  let displayName = self.settingsService.getDisplayName()
  let currentUserStatus = self.settingsService.getCurrentUserStatus()

  let loggedInAccount = self.accountsService.getLoggedInAccount()

  singletonInstance.userProfile.setFixedData(alias, loggedInAccount.keyUid, pubKey, loggedInAccount.keycardPairing.len > 0)
  singletonInstance.userProfile.setDisplayName(displayName)
  singletonInstance.userProfile.setPreferredName(preferredName)
  singletonInstance.userProfile.setThumbnailImage(loggedInAccount.images.thumbnail)
  singletonInstance.userProfile.setLargeImage(loggedInAccount.images.large)
  singletonInstance.userProfile.setCurrentUserStatus(currentUserStatus.statusType.int)

  singletonInstance.engine.setRootContextProperty("userProfile", self.userProfileVariant)

proc runPostOnboardingTasks(self: AppController) =
    debug "running post-onboarding tasks"

    let tasks = self.onboardingModule.getPostOnboardingTasks()
    for task in tasks:
      case task.kind:
      of kPostOnboardingTaskKeycardReplacement:
        KeycardReplacementTask(task).run(self.walletAccountService, self.keycardServiceV2)
      else:
        error "unknown post onboarding task"
