import nimqml, chronicles, json, strutils, sequtils, tables, times

import app/core/eventemitter
import app/core/signals/types
when defined(android):
  import app/android/safutils
import app_service/common/types as common_types
import backend/newsfeed as status_newsfeed
import backend/mailservers as status_mailservers
import backend/settings as status_settings
import backend/status_update as status_update
import app/global/global_singleton
import constants

import ./dto/settings as settings_dto
import ../stickers/dto/stickers as stickers_dto

export settings_dto
export stickers_dto

# Default values:
const DEFAULT_CURRENCY* = "USD"

# Signals:
const SIGNAL_NETWORK_MODE_UPDATED* = "networkModeUpdated"
const SIGNAL_CURRENCY_UPDATED* = "currencyUpdated"
const SIGNAL_DISPLAY_NAME_UPDATED* = "displayNameUpdated"
const SIGNAL_BIO_UPDATED* = "bioUpdated"
const SIGNAL_MNEMONIC_REMOVED* = "mnemonicRemoved"
const SIGNAL_CURRENT_USER_STATUS_UPDATED* = "currentUserStatusUpdated"
const SIGNAL_PROFILE_MIGRATION_NEEDED_UPDATED* = "profileMigrationNeededUpdated"
const SIGNAL_URL_UNFURLING_MODE_UPDATED* = "urlUnfurlingModeUpdated"
const SIGNAL_PINNED_MAILSERVER_CHANGED* = "pinnedMailserverChanged"
const SIGNAL_AUTO_REFRESH_TOKENS_UPDATED* = "autoRefreshTokensUpdated"
const SIGNAL_DISPLAY_ASSET_BELOW_BALANCE_UPDATED* = "displayAssetsBelowBalanceUpdated"
const SIGNAL_DISPLAY_ASSET_BELOW_BALANCE_THRESHOLD_UPDATED* = "displayAssetsBelowBalanceThresholdUpdated"
const SIGNAL_MESSAGES_FROM_CONTACTS_ONLY_UPDATED* = "messagesFromContactsOnlyUpdated"
const SIGNAL_SHOW_COMMUNITY_ASSET_WHEN_SENDING_TOKENS_UPDATED* = "showCommunityAssetWhenSendingTokensUpdated"

logScope:
  topics = "settings-service"

type
  SettingsTextValueArgs* = ref object of Args
    value*: string

  CurrentUserStatusArgs* = ref object of Args
    statusType*: StatusType
    text*: string

  SettingsBoolValueArgs* = ref object of Args
    value*: bool

  UrlUnfurlingModeArgs* = ref object of Args
    value*: UrlUnfurlingMode

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    settings: SettingsDto
    initialized: bool
    notifExemptionsCache: Table[string, NotificationsExemptions]

  # Forward declaration
  proc initNotificationSettings*(self: Service)
  proc getNotifSettingAllowNotifications*(self: Service): bool
  proc getNotifSettingOneToOneChats*(self: Service): string
  proc getNotifSettingGroupChats*(self: Service): string
  proc getNotifSettingPersonalMentions*(self: Service): string
  proc getNotifSettingGlobalMentions*(self: Service): string
  proc getNotifSettingAllMessages*(self: Service): string
  proc getNotifSettingContactRequests*(self: Service): string
  proc getNotificationSoundsEnabled*(self: Service): bool
  proc getNotificationVolume*(self: Service): int
  proc getNotificationMessagePreview*(self: Service): int

  proc delete*(self: Service)
  proc newService*(events: EventEmitter): Service =
    new(result, delete)
    result.events = events
    result.initialized = false
    result.notifExemptionsCache = initTable[string, NotificationsExemptions]()
    result.QObject.setup

  proc parseSettingsField(self: Service, settingsField: SettingsFieldDto) =
    case settingsField.name
    of KEY_CURRENCY:
      self.settings.currency = settingsField.value.getStr
      self.events.emit(SIGNAL_CURRENCY_UPDATED, SettingsTextValueArgs(value: self.settings.currency))
    of KEY_DISPLAY_NAME:
      self.settings.displayName = settingsField.value.getStr
      self.events.emit(SIGNAL_DISPLAY_NAME_UPDATED, SettingsTextValueArgs(value: self.settings.displayName))
    of KEY_PREFERRED_NAME:
      self.settings.preferredName = settingsField.value.getStr
      singletonInstance.userProfile.setPreferredName(self.settings.preferredName)
    of KEY_BIO:
      self.settings.bio = settingsField.value.getStr
      self.events.emit(SIGNAL_BIO_UPDATED, SettingsTextValueArgs(value: self.settings.bio))
    of KEY_MNEMONIC:
      self.settings.mnemonic = ""
      self.events.emit(SIGNAL_MNEMONIC_REMOVED, Args())
    of PROFILE_MIGRATION_NEEDED:
      self.settings.profileMigrationNeeded = settingsField.value.getBool
      self.events.emit(SIGNAL_PROFILE_MIGRATION_NEEDED_UPDATED, SettingsBoolValueArgs(value: self.settings.profileMigrationNeeded))
    of KEY_URL_UNFURLING_MODE:
      self.settings.urlUnfurlingMode = toUrlUnfurlingMode(settingsField.value.getInt)
      self.events.emit(SIGNAL_URL_UNFURLING_MODE_UPDATED, UrlUnfurlingModeArgs(value: self.settings.urlUnfurlingMode))
    of KEY_AUTO_REFRESH_TOKENS:
      self.settings.autoRefreshTokens = settingsField.value.getBool
      self.events.emit(SIGNAL_AUTO_REFRESH_TOKENS_UPDATED, SettingsBoolValueArgs(value: self.settings.autoRefreshTokens))
    of KEY_DISPLAY_ASSETS_BELOW_BALANCE:
      if self.settings.displayAssetsBelowBalance != settingsField.value.getBool:
        self.settings.displayAssetsBelowBalance = settingsField.value.getBool
        self.events.emit(SIGNAL_DISPLAY_ASSET_BELOW_BALANCE_UPDATED, Args())
    of KEY_DISPLAY_ASSETS_BELOW_BALANCE_THRESHOLD:
      if self.settings.displayAssetsBelowBalanceThreshold != settingsField.value.getInt:
        self.settings.displayAssetsBelowBalanceThreshold = settingsField.value.getInt
        self.events.emit(SIGNAL_DISPLAY_ASSET_BELOW_BALANCE_THRESHOLD_UPDATED, Args())
    of KEY_MESSAGES_FROM_CONTACTS_ONLY:
      if self.settings.messagesFromContactsOnly != settingsField.value.getBool:
        self.settings.messagesFromContactsOnly = settingsField.value.getBool
        self.events.emit(SIGNAL_MESSAGES_FROM_CONTACTS_ONLY_UPDATED, Args())
    of KEY_SHOW_COMMUNITY_ASSET_WHEN_SENDING_TOKENS:
      if self.settings.showCommunityAssetWhenSendingTokens != settingsField.value.getBool:
        self.settings.showCommunityAssetWhenSendingTokens = settingsField.value.getBool
        self.events.emit(SIGNAL_SHOW_COMMUNITY_ASSET_WHEN_SENDING_TOKENS_UPDATED, Args())
    else:
      discard

  proc init*(self: Service) =
    try:
      let response = status_settings.getSettings()
      self.settings = response.result.toSettingsDto()
      self.settings.newsFeedEnabled = status_newsfeed.enabled().result.getBool
      self.settings.newsNotificationsEnabled = status_newsfeed.notificationsEnabled().result.getBool
      self.settings.newsRSSEnabled = status_newsfeed.rssEnabled().result.getBool
      self.initNotificationSettings()
    except Exception as e:
      let errDesription = e.msg
      error "error: ", errDesription

    self.events.on(SignalType.Message.event) do(e: Args):
      var receivedData = MessageSignal(e)

      if receivedData.currentStatus.len > 0:
        var statusUpdate = receivedData.currentStatus[0]
        self.events.emit(SIGNAL_CURRENT_USER_STATUS_UPDATED, CurrentUserStatusArgs(statusType: statusUpdate.statusType, text: statusUpdate.text))

      if receivedData.settings.len > 0:
        for settingsField in receivedData.settings:
          self.parseSettingsField(settingsField)

    self.events.on(SignalType.BackedUpSettings.event) do(e: Args):
      var receivedData = BackedUpSettingsSignal(e)
      self.parseSettingsField(receivedData.backedUpSettingField)

    self.initialized = true

  # Backup Path migration
  # New local setting needs to be initialized from old setting value
  # TODO remove this migration in 2.37 (one release cycle interval)
  proc migrateBackupPath*(self: Service) =
    when defined(android):
      # On Android we cannot use arbitrary paths without requesting storage permissions
      return
    if singletonInstance.localAccountSensitiveSettings.getLocalBackupChosenPathSetting().len == 0 and self.settings.backupPath.len > 0:
      singletonInstance.localAccountSensitiveSettings.setLocalBackupChosenPath(self.settings.backupPath)

  proc initNotificationSettings(self: Service) =
    # set initial values from RPC before initialization is done
    # not interested in return values here
    discard self.getNotifSettingAllowNotifications()
    discard self.getNotifSettingOneToOneChats()
    discard self.getNotifSettingGroupChats()
    discard self.getNotifSettingPersonalMentions()
    discard self.getNotifSettingGlobalMentions()
    discard self.getNotifSettingAllMessages()
    discard self.getNotifSettingContactRequests()
    discard self.getNotificationSoundsEnabled()
    discard self.getNotificationVolume()
    discard self.getNotificationMessagePreview()


  proc saveSetting(self: Service, attribute: string, value: string | JsonNode | bool | int | int64): bool =
    try:
      let response = status_settings.saveSettings(attribute, value)
      if(not response.error.isNil):
        error "error saving settings: ", errDescription = response.error.message
        return false
      return true
    except Exception as e:
      let errDesription = e.msg
      error "saving settings error: ", errDesription
    return false

  proc saveAddress*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_ADDRESS, value)):
      self.settings.address = value
      return true
    return false

  proc getAddress*(self: Service): string =
    return self.settings.address

  proc saveCurrency*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_CURRENCY, value)):
      self.settings.currency = value.toLowerAscii()
      self.events.emit(SIGNAL_CURRENCY_UPDATED, SettingsTextValueArgs(value: self.settings.currency))
      return true
    return false

  proc getCurrency*(self: Service): string =
    if(self.settings.currency.len == 0):
      self.settings.currency = DEFAULT_CURRENCY

    return self.settings.currency.toUpperAscii()

  proc saveDappsAddress*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_DAPPS_ADDRESS, value)):
      self.settings.dappsAddress = value
      return true
    return false

  proc getDappsAddress*(self: Service): string =
    return self.settings.dappsAddress

  proc saveEip1581Address*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_EIP1581_ADDRESS, value)):
      self.settings.eip1581Address = value
      return true
    return false

  proc getEip1581Address*(self: Service): string =
    return self.settings.eip1581Address

  proc saveInstallationId*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_INSTALLATION_ID, value)):
      self.settings.installationId = value
      return true
    return false

  proc getInstallationId*(self: Service): string =
    return self.settings.installationId

  proc savePreferredName*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_PREFERRED_NAME, value)):
      self.settings.preferredName = value
      return true
    return false

  proc getPreferredName*(self: Service): string =
    return self.settings.preferredName

  proc getDisplayName*(self: Service): string =
    return self.settings.displayName

  proc saveDisplayName*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_DISPLAY_NAME, value)):
      self.settings.displayName = value
      self.events.emit(SIGNAL_DISPLAY_NAME_UPDATED, SettingsTextValueArgs(value: self.settings.displayName))
      return true
    return false

  proc saveKeyUid*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_KEY_UID, value)):
      self.settings.keyUid = value
      return true
    return false

  proc getKeyUid*(self: Service): string =
    return self.settings.keyUid

  proc saveLatestDerivedPath*(self: Service, value: int): bool =
    if(self.saveSetting(KEY_LATEST_DERIVED_PATH, value)):
      self.settings.latestDerivedPath = value
      return true
    return false

  proc getLatestDerivedPath*(self: Service): int =
    self.settings.latestDerivedPath

  proc saveLinkPreviewRequestEnabled*(self: Service, value: bool): bool =
    if(self.saveSetting(KEY_LINK_PREVIEW_REQUEST_ENABLED, value)):
      self.settings.linkPreviewRequestEnabled = value
      return true
    return false

  proc getLinkPreviewRequestEnabled*(self: Service): bool =
    self.settings.linkPreviewRequestEnabled

  proc saveMessagesFromContactsOnly*(self: Service, value: bool): bool =
    if(self.saveSetting(KEY_MESSAGES_FROM_CONTACTS_ONLY, value)):
      self.settings.messagesFromContactsOnly = value
      return true
    return false

  proc getMessagesFromContactsOnly*(self: Service): bool =
    self.settings.messagesFromContactsOnly

  proc saveMnemonic*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_MNEMONIC, value)):
      self.settings.mnemonic = value
      self.events.emit(SIGNAL_MNEMONIC_REMOVED, Args())
      return true
    return false

  proc getMnemonic*(self: Service): string =
    return self.settings.mnemonic

  proc saveName*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_NAME, value)):
      self.settings.name = value
      return true
    return false

  proc getName*(self: Service): string =
    return self.settings.name

  proc savePhotoPath*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_PHOTO_PATH, value)):
      self.settings.photoPath = value
      return true
    return false

  proc getPhotoPath*(self: Service): string =
    return self.settings.photoPath

  proc savePreviewPrivacy*(self: Service, value: bool): bool =
    if(self.saveSetting(KEY_PREVIEW_PRIVACY, value)):
      self.settings.previewPrivacy = value
      return true
    return false

  proc getPreviewPrivacy*(self: Service): bool =
    self.settings.previewPrivacy

  proc savePublicKey*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_PUBLIC_KEY, value)):
      self.settings.publicKey = value
      return true
    return false

  proc getPublicKey*(self: Service): string =
    return self.settings.publicKey

  proc saveDefaultSyncPeriod*(self: Service, value: int): bool =
    if(self.saveSetting(KEY_DEFAULT_SYNC_PERIOD, value)):
      self.settings.defaultSyncPeriod = value
      return true
    return false

  proc getDefaultSyncPeriod*(self: Service): int =
    self.settings.defaultSyncPeriod

  proc saveSendPushNotifications*(self: Service, value: bool): bool =
    if(self.saveSetting(KEY_SEND_PUSH_NOTIFICATIONS, value)):
      self.settings.sendPushNotifications = value
      return true
    return false

  proc getSendPushNotifications*(self: Service): bool =
    self.settings.sendPushNotifications

  proc saveAppearance*(self: Service, value: int): bool =
    if(self.saveSetting(KEY_APPEARANCE, value)):
      self.settings.appearance = value
      return true
    return false

  proc getAppearance*(self: Service): int =
    self.settings.appearance

  proc toggleUseMailservers*(self: Service, value: bool): bool =
    try:
      let response = status_mailservers.toggleUseMailservers(value)
      if not response.error.isNil:
        error "error saving use mailservers: ", errDescription = response.error.message
        return false
      self.settings.useMailservers = value
    except Exception as e:
      let errDesription = e.msg
      error "saving use mailservers error: ", errDesription
      return false
    return true

  proc getUseMailservers*(self: Service): bool =
    self.settings.useMailservers

  proc saveWalletRootAddress*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_WALLET_ROOT_ADDRESS, value)):
      self.settings.walletRootAddress = value
      return true
    return false

  proc getWalletRootAddress*(self: Service): string =
    return self.settings.walletRootAddress

  proc getSendStatusUpdates*(self: Service): bool =
    self.settings.sendStatusUpdates

  proc saveSendStatusUpdates*(self: Service, newStatus: StatusType): bool =
    try:
      # The new user status needs to always be broadcast, so we need to update
      # the settings accordingly and might turn it off afterwards (if user has
      # set status to "inactive")
      const propagateStatus = true
      if(self.saveSetting(KEY_SEND_STATUS_UPDATES, propagateStatus) != true):
          return false
      discard status_update.setUserStatus(newStatus.int)
      self.settings.currentUserStatus.statusType = newStatus
      let sendPingsWithStatusUpdates = (newStatus == StatusType.AlwaysOnline or newStatus == StatusType.Automatic)
      if(self.saveSetting(KEY_SEND_STATUS_UPDATES, sendPingsWithStatusUpdates)):
        self.settings.sendStatusUpdates = sendPingsWithStatusUpdates
        return true
      return false
    except:
      return false

  proc saveFleet*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_FLEET, value)):
      self.settings.fleet = value
      return true
    return false

  proc getFleetAsString*(self: Service): string =
    result = self.settings.fleet

  proc getCurrentUserStatus*(self: Service): CurrentUserStatus =
    self.settings.currentUserStatus

  proc setDefaultSyncPeriod*(self: Service, value: int): bool =
    if(self.saveSetting(KEY_DEFAULT_SYNC_PERIOD,value)):
      self.settings.defaultSyncPeriod = value
      return true
    return false

  proc areTestNetworksEnabled*(self: Service): bool =
    return self.settings.testNetworksEnabled

  proc toggleTestNetworksEnabled*(self: Service): bool =
    let newValue = not self.settings.testNetworksEnabled
    if(self.saveSetting(KEY_TEST_NETWORKS_ENABLED, newValue)):
      self.settings.testNetworksEnabled = newValue
      self.events.emit(SIGNAL_NETWORK_MODE_UPDATED, SettingsBoolValueArgs(value: self.settings.testNetworksEnabled))
      return true
    return false

  proc tokenGroupByCommunity*(self: Service): bool =
    return self.settings.tokenGroupByCommunity

  proc toggleTokenGroupByCommunity*(self: Service): bool =
    let newValue = not self.settings.tokenGroupByCommunity
    if(self.saveSetting(KEY_TOKEN_GROUP_BY_COMMUNITY, newValue)):
      self.settings.tokenGroupByCommunity = newValue
      return true
    return false

  proc showCommunityAssetWhenSendingTokens*(self: Service): bool =
    return self.settings.showCommunityAssetWhenSendingTokens

  proc toggleShowCommunityAssetWhenSendingTokens*(self: Service): bool =
    let newValue = not self.settings.showCommunityAssetWhenSendingTokens
    if(self.saveSetting(KEY_SHOW_COMMUNITY_ASSET_WHEN_SENDING_TOKENS, newValue)):
      self.settings.showCommunityAssetWhenSendingTokens = newValue
      return true
    return false

  proc displayAssetsBelowBalance*(self: Service): bool =
    return self.settings.displayAssetsBelowBalance

  proc toggleDisplayAssetsBelowBalance*(self: Service): bool =
    let newValue = not self.settings.displayAssetsBelowBalance
    if(self.saveSetting(KEY_DISPLAY_ASSETS_BELOW_BALANCE, newValue)):
      self.settings.displayAssetsBelowBalance = newValue
      return true
    return false

  proc displayAssetsBelowBalanceThreshold*(self: Service): int64 =
    return self.settings.displayAssetsBelowBalanceThreshold

  proc setDisplayAssetsBelowBalanceThreshold*(self: Service, value: int64): bool =
    if(self.saveSetting(KEY_DISPLAY_ASSETS_BELOW_BALANCE_THRESHOLD, value)):
      self.settings.displayAssetsBelowBalanceThreshold = value
      return true
    return false

  proc collectibleGroupByCommunity*(self: Service): bool =
    return self.settings.collectibleGroupByCommunity

  proc toggleCollectibleGroupByCommunity*(self: Service): bool =
    let newValue = not self.settings.collectibleGroupByCommunity
    if(self.saveSetting(KEY_COLLECTIBLE_GROUP_BY_COMMUNITY, newValue)):
      self.settings.collectibleGroupByCommunity = newValue
      return true
    return false

  proc collectibleGroupByCollection*(self: Service): bool =
    return self.settings.collectibleGroupByCollection

  proc toggleCollectibleGroupByCollection*(self: Service): bool =
    let newValue = not self.settings.collectibleGroupByCollection
    if(self.saveSetting(KEY_COLLECTIBLE_GROUP_BY_COLLECTION, newValue)):
      self.settings.collectibleGroupByCollection = newValue
      return true
    return false

  proc urlUnfurlingMode*(self: Service): UrlUnfurlingMode =
    return self.settings.urlUnfurlingMode

  proc saveUrlUnfurlingMode*(self: Service, value: UrlUnfurlingMode): bool =
    if not self.saveSetting(KEY_URL_UNFURLING_MODE, int(value)):
      return false
    self.settings.urlUnfurlingMode = value
    self.events.emit(SIGNAL_URL_UNFURLING_MODE_UPDATED, UrlUnfurlingModeArgs(value: self.settings.urlUnfurlingMode))
    return true

  proc notifSettingAllowNotificationsChanged*(self: Service) {.signal.}
  proc getNotifSettingAllowNotifications*(self: Service): bool {.slot.} =
    if self.initialized:
      return self.settings.notificationsAllowNotifications

    result = true #default value
    try:
      let response = status_settings.getAllowNotifications()
      if(not response.error.isNil):
        error "error reading allow notification setting: ", errDescription = response.error.message
        return
      result = response.result.getBool
      self.settings.notificationsAllowNotifications = result
    except Exception as e:
      let errDesription = e.msg
      error "reading allow notification setting error: ", errDesription

  proc setNotifSettingAllowNotifications*(self: Service, value: bool) {.slot.} =
    try:
      let response = status_settings.setAllowNotifications(value)
      if(not response.error.isNil):
        error "error saving allow notification setting: ", errDescription = response.error.message
        return
      self.settings.notificationsAllowNotifications = value
      self.notifSettingAllowNotificationsChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving allow notification setting error: ", errDesription

  QtProperty[bool] notifSettingAllowNotifications:
    read = getNotifSettingAllowNotifications
    write = setNotifSettingAllowNotifications
    notify = notifSettingAllowNotificationsChanged

  proc notifSettingOneToOneChatsChanged*(self: Service) {.signal.}
  proc getNotifSettingOneToOneChats*(self: Service): string {.slot.} =
    if self.initialized:
      return self.settings.notificationsOneToOneChats

    result = VALUE_NOTIF_SEND_ALERTS #default value
    try:
      let response = status_settings.getOneToOneChats()
      if(not response.error.isNil):
        error "error reading one to one setting: ", errDescription = response.error.message
        return
      result = response.result.getStr
      self.settings.notificationsOneToOneChats = result
    except Exception as e:
      let errDesription = e.msg
      error "reading one to one setting error: ", errDesription

  proc setNotifSettingOneToOneChats*(self: Service, value: string) {.slot.} =
    try:
      let response = status_settings.setOneToOneChats(value)
      if(not response.error.isNil):
        error "error saving one to one setting: ", errDescription = response.error.message
        return
      self.settings.notificationsOneToOneChats = value
      self.notifSettingOneToOneChatsChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving one to one setting error: ", errDesription

  QtProperty[string] notifSettingOneToOneChats:
    read = getNotifSettingOneToOneChats
    write = setNotifSettingOneToOneChats
    notify = notifSettingOneToOneChatsChanged

  proc notifSettingGroupChatsChanged*(self: Service) {.signal.}
  proc getNotifSettingGroupChats*(self: Service): string {.slot.} =
    if self.initialized:
      return self.settings.notificationsGroupChats

    result = VALUE_NOTIF_SEND_ALERTS #default value
    try:
      let response = status_settings.getGroupChats()
      if(not response.error.isNil):
        error "error reading group chats setting: ", errDescription = response.error.message
        return
      result = response.result.getStr
      self.settings.notificationsGroupChats = result
    except Exception as e:
      let errDesription = e.msg
      error "reading group chats setting error: ", errDesription

  proc setNotifSettingGroupChats*(self: Service, value: string) {.slot.} =
    try:
      let response = status_settings.setGroupChats(value)
      if(not response.error.isNil):
        error "error saving group chats setting: ", errDescription = response.error.message
        return
      self.settings.notificationsGroupChats = value
      self.notifSettingGroupChatsChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving group chats setting error: ", errDesription

  QtProperty[string] notifSettingGroupChats:
    read = getNotifSettingGroupChats
    write = setNotifSettingGroupChats
    notify = notifSettingGroupChatsChanged

  proc notifSettingPersonalMentionsChanged*(self: Service) {.signal.}
  proc getNotifSettingPersonalMentions*(self: Service): string {.slot.} =
    if self.initialized:
      return self.settings.notificationsPersonalMentions

    result = VALUE_NOTIF_SEND_ALERTS #default value
    try:
      let response = status_settings.getPersonalMentions()
      if(not response.error.isNil):
        error "error reading personal mentions setting: ", errDescription = response.error.message
        return
      result = response.result.getStr
      self.settings.notificationsPersonalMentions = result
    except Exception as e:
      let errDesription = e.msg
      error "reading personal mentions setting error: ", errDesription

  proc setNotifSettingPersonalMentions*(self: Service, value: string) {.slot.} =
    try:
      let response = status_settings.setPersonalMentions(value)
      if(not response.error.isNil):
        error "error saving personal mentions setting: ", errDescription = response.error.message
        return
      self.settings.notificationsPersonalMentions = value
      self.notifSettingPersonalMentionsChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving personal mentions setting error: ", errDesription

  QtProperty[string] notifSettingPersonalMentions:
    read = getNotifSettingPersonalMentions
    write = setNotifSettingPersonalMentions
    notify = notifSettingPersonalMentionsChanged

  proc notifSettingGlobalMentionsChanged*(self: Service) {.signal.}
  proc getNotifSettingGlobalMentions*(self: Service): string {.slot.} =
    if self.initialized:
      return self.settings.notificationsGlobalMentions

    result = VALUE_NOTIF_SEND_ALERTS #default value
    try:
      let response = status_settings.getGlobalMentions()
      if(not response.error.isNil):
        error "error reading global mentions setting: ", errDescription = response.error.message
        return
      result = response.result.getStr
      self.settings.notificationsGlobalMentions = result
    except Exception as e:
      let errDesription = e.msg
      error "reading global mentions setting error: ", errDesription

  proc setNotifSettingGlobalMentions*(self: Service, value: string) {.slot.} =
    try:
      let response = status_settings.setGlobalMentions(value)
      if(not response.error.isNil):
        error "error saving global mentions setting: ", errDescription = response.error.message
        return
      self.settings.notificationsGlobalMentions = value
      self.notifSettingGlobalMentionsChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving global mentions setting error: ", errDesription

  QtProperty[string] notifSettingGlobalMentions:
    read = getNotifSettingGlobalMentions
    write = setNotifSettingGlobalMentions
    notify = notifSettingGlobalMentionsChanged

  proc notifSettingAllMessagesChanged*(self: Service) {.signal.}
  proc getNotifSettingAllMessages*(self: Service): string {.slot.} =
    if self.initialized:
      return self.settings.notificationsAllMessages

    result = VALUE_NOTIF_TURN_OFF #default value
    try:
      let response = status_settings.getAllMessages()
      if(not response.error.isNil):
        error "error reading all messages setting: ", errDescription = response.error.message
        return
      result = response.result.getStr
      self.settings.notificationsAllMessages = result
    except Exception as e:
      let errDesription = e.msg
      error "reading all messages setting error: ", errDesription

  proc setNotifSettingAllMessages*(self: Service, value: string) {.slot.} =
    try:
      let response = status_settings.setAllMessages(value)
      if(not response.error.isNil):
        error "error saving all messages setting: ", errDescription = response.error.message
        return
      self.settings.notificationsAllMessages = value
      self.notifSettingAllMessagesChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving all messages setting error: ", errDesription

  QtProperty[string] notifSettingAllMessages:
    read = getNotifSettingAllMessages
    write = setNotifSettingAllMessages
    notify = notifSettingAllMessagesChanged

  proc notifSettingContactRequestsChanged*(self: Service) {.signal.}
  proc getNotifSettingContactRequests*(self: Service): string {.slot.} =
    if self.initialized:
      return self.settings.notificationsContactRequests

    result = VALUE_NOTIF_SEND_ALERTS #default value
    try:
      let response = status_settings.getContactRequests()
      if(not response.error.isNil):
        error "error reading contact request setting: ", errDescription = response.error.message
        return
      result = response.result.getStr
      self.settings.notificationsContactRequests = result
    except Exception as e:
      let errDesription = e.msg
      error "reading contact request setting error: ", errDesription

  proc setNotifSettingContactRequests*(self: Service, value: string) {.slot.} =
    try:
      let response = status_settings.setContactRequests(value)
      if(not response.error.isNil):
        error "error saving contact request setting: ", errDescription = response.error.message
        return
      self.settings.notificationsContactRequests = value
      self.notifSettingContactRequestsChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving contact request setting error: ", errDesription

  QtProperty[string] notifSettingContactRequests:
    read = getNotifSettingContactRequests
    write = setNotifSettingContactRequests
    notify = notifSettingContactRequestsChanged

  proc notificationSoundsEnabledChanged*(self: Service) {.signal.}
  proc getNotificationSoundsEnabled*(self: Service): bool {.slot.} =
    if self.initialized:
      return self.settings.notificationsSoundsEnabled

    result = true #default value
    try:
      let response = status_settings.getSoundEnabled()
      if(not response.error.isNil):
        error "error reading sound enabled setting: ", errDescription = response.error.message
        return
      result = response.result.getBool
      self.settings.notificationsSoundsEnabled = result
    except Exception as e:
      let errDesription = e.msg
      error "reading sound enabled setting error: ", errDesription

  proc setNotificationSoundsEnabled*(self: Service, value: bool) {.slot.} =
    try:
      let response = status_settings.setSoundEnabled(value)
      if(not response.error.isNil):
        error "error saving sound enabled setting: ", errDescription = response.error.message
        return
      self.settings.notificationsSoundsEnabled = value
      self.notificationSoundsEnabledChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving sound enabled setting error: ", errDesription

  QtProperty[bool] notificationSoundsEnabled:
    read = getNotificationSoundsEnabled
    write = setNotificationSoundsEnabled
    notify = notificationSoundsEnabledChanged

  proc notificationVolumeChanged*(self: Service) {.signal.}
  proc getNotificationVolume*(self: Service): int {.slot.} =
    if self.initialized:
      return self.settings.notificationsVolume

    result = 50 #default value
    try:
      let response = status_settings.getVolume()
      if(not response.error.isNil):
        error "error reading volume setting: ", errDescription = response.error.message
        return
      result = response.result.getInt
      self.settings.notificationsVolume = result
    except Exception as e:
      let errDesription = e.msg
      error "reading volume setting error: ", errDesription

  proc setNotificationVolume*(self: Service, value: int) {.slot.} =
    try:
      let response = status_settings.setVolume(value)
      if(not response.error.isNil):
        error "error saving volume setting: ", errDescription = response.error.message
        return
      self.settings.notificationsVolume = value
      self.notificationVolumeChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving volume setting error: ", errDesription

  QtProperty[int] volume:
    read = getNotificationVolume
    write = setNotificationVolume
    notify = notificationVolumeChanged


  proc notificationMessagePreviewChanged*(self: Service) {.signal.}
  proc getNotificationMessagePreview*(self: Service): int {.slot.} =
    if self.initialized:
      return self.settings.notificationsMessagePreview

    result = 2 #default value
    try:
      let response = status_settings.getMessagePreview()
      if(not response.error.isNil):
        error "error reading message preview setting: ", errDescription = response.error.message
        return
      result = response.result.getInt
      self.settings.notificationsMessagePreview = result
    except Exception as e:
      let errDesription = e.msg
      error "reading message preview setting error: ", errDesription

  proc setNotificationMessagePreview*(self: Service, value: int) {.slot.} =
    try:
      let response = status_settings.setMessagePreview(value)
      if(not response.error.isNil):
        error "error saving message preview setting: ", errDescription = response.error.message
        return
      self.settings.notificationsMessagePreview = value
      self.notificationMessagePreviewChanged()
    except Exception as e:
      let errDesription = e.msg
      error "saving message preview setting error: ", errDesription

  QtProperty[int] notificationMessagePreview:
    read = getNotificationMessagePreview
    write = setNotificationMessagePreview
    notify = notificationMessagePreviewChanged

  proc setNotifSettingExemptions*(self: Service, id: string, exemptions: NotificationsExemptions): bool =
    result = false
    try:
      let response = status_settings.setExemptions(id, exemptions.muteAllMessages, exemptions.personalMentions,
      exemptions.globalMentions, exemptions.otherMessages)
      if(not response.error.isNil):
        error "error saving exemptions setting: ", id = id, errDescription = response.error.message
        return
      self.notifExemptionsCache[id] = exemptions
      result = true
    except Exception as e:
      let errDesription = e.msg
      error "saving exemptions setting error: ", id = id, errDesription

  proc removeNotifSettingExemptions*(self: Service, id: string): bool =
    result = false
    try:
      let response = status_settings.deleteExemptions(id)
      if(not response.error.isNil):
        error "error deleting exemptions setting: ", id = id, errDescription = response.error.message
        return
      result = true
    except Exception as e:
      let errDesription = e.msg
      error "saving deleting exemptions setting: ", id = id, errDesription

  proc getNotifSettingExemptions*(self: Service, id: string): NotificationsExemptions =
    if self.notifExemptionsCache.hasKey(id):
      return self.notifExemptionsCache[id]

    #default values
    result.muteAllMessages = false
    result.personalMentions = VALUE_NOTIF_SEND_ALERTS
    result.globalMentions = VALUE_NOTIF_SEND_ALERTS
    result.otherMessages = VALUE_NOTIF_TURN_OFF
    try:
      var response = status_settings.getExemptionMuteAllMessages(id)
      if(not response.error.isNil):
        error "error reading exemptions mute all messages request setting: ", id = id, errDescription = response.error.message
        return
      result.muteAllMessages = response.result.getBool

      response = status_settings.getExemptionPersonalMentions(id)
      if(not response.error.isNil):
        error "error reading exemptions personal mentions request setting: ", id = id, errDescription = response.error.message
        return
      result.personalMentions = response.result.getStr

      response = status_settings.getExemptionGlobalMentions(id)
      if(not response.error.isNil):
        error "error reading exemptions global mentions request setting: ", id = id, errDescription = response.error.message
        return
      result.globalMentions = response.result.getStr

      response = status_settings.getExemptionOtherMessages(id)
      if(not response.error.isNil):
        error "error reading exemptions other messages request setting: ", id = id, errDescription = response.error.message
        return
      result.otherMessages = response.result.getStr

    except Exception as e:
      let errDesription = e.msg
      error "reading exemptions setting error: ", id = id, errDesription

    self.notifExemptionsCache[id] = result

  proc getBio*(self: Service): string =
    self.settings.bio

  proc saveBio*(self: Service, value: string): bool =
    if(self.saveSetting(KEY_BIO, value)):
      self.settings.bio = value
      self.events.emit(SIGNAL_BIO_UPDATED, SettingsTextValueArgs(value: self.settings.bio))
      return true
    return false

  proc getProfileMigrationNeeded*(self: Service): bool =
    self.settings.profileMigrationNeeded

  proc mnemonicWasShown*(self: Service) =
    let response = status_settings.mnemonicWasShown()
    if(not response.error.isNil):
      error "error saving mnemonic was shown setting: ", errDescription = response.error.message
      return

  proc toggleAutoRefreshTokens*(self: Service): bool =
    let newValue = not self.settings.autoRefreshTokens
    if self.saveSetting(KEY_AUTO_REFRESH_TOKENS, newValue):
      self.settings.autoRefreshTokens = newValue
      return true

  proc getAutoRefreshTokens*(self: Service): bool =
    return self.settings.autoRefreshTokens

  proc getLastTokensUpdate*(self: Service): int64 =
    var lastTokensUpdate: string
    try:
      let response = status_settings.lastTokensUpdate()
      if not response.error.isNil:
        error "fetching lastTokensUpdate: ", errDescription = response.error.message
        return

      lastTokensUpdate = response.result.getStr
      let dateTime = parse(lastTokensUpdate, DATE_TIME_FORMAT_2)
      self.settings.lastTokensUpdate = dateTime.toTime().toUnix()
    except Exception as e:
      error "parse lastTokensUpdate: ", data=lastTokensUpdate, errName = e.name, errDesription = e.msg
    return self.settings.lastTokensUpdate

  ### News Feed Settings ###
  proc notifSettingStatusNewsChanged*(self: Service) {.signal.}

  proc toggleNewsFeedEnabled*(self: Service, enabled: bool, notificationsEnabled: bool): bool =
    try:
      var response = status_newsfeed.setEnabled(enabled)
      if not response.error.isNil:
        raise newException(RpcException, response.error.message)

      response = status_newsfeed.setNotificationsEnabled(notificationsEnabled)
      if not response.error.isNil:
        raise newException(RpcException, response.error.message)

      self.settings.newsFeedEnabled = enabled
      self.settings.newsNotificationsEnabled = notificationsEnabled
      self.notifSettingStatusNewsChanged()
      return true
    except Exception as e:
      error "error: ", procName="toggleNewsFeedEnabled", errName = e.name, errDesription = e.msg
      return false

  proc getNotifSettingStatusNews*(self: Service): string {.slot.} =
    result = VALUE_NOTIF_SEND_ALERTS # Default value

    var newsFeedEnabled = false
    var newsOSNotificationsEnabled = false

    if self.initialized:
      newsFeedEnabled = self.settings.newsFeedEnabled
      newsOSNotificationsEnabled = self.settings.newsNotificationsEnabled
    else:
      try:
        var response = status_newsfeed.enabled()
        if not response.error.isNil:
          error "error reading news feed enabled setting: ", errDescription = response.error.message
          return
        newsFeedEnabled = response.result.getBool

        response = status_newsfeed.notificationsEnabled()
        if not response.error.isNil:
          error "error reading news notifications enabled setting: ", errDescription = response.error.message
          return
        newsOSNotificationsEnabled = response.result.getBool
      except Exception as e:
        let errDesription = e.msg
        error "reading news settings error: ", errDesription
        return

    # We convert the bools to the right setting
    # Send alerts means the News Feed is enabled + OS notifications are enabled
    # Deliver quietly means the News Feed is enabled + OS notifications are disabled (so only AC notifications)
    # Turn OFF means the News Feed is disabled (so no notifications at all and no polling)
    if not newsFeedEnabled:
      return VALUE_NOTIF_TURN_OFF
    if not newsOSNotificationsEnabled:
      return VALUE_NOTIF_DELIVER_QUIETLY
    return VALUE_NOTIF_SEND_ALERTS

  proc setNotifSettingStatusNews*(self: Service, value: string) {.slot.} =
    var newsFeedEnabled = false
    var newsOSNotificationsEnabled = false
    # We need to convert the string value to the right setting values
    case value
    of VALUE_NOTIF_SEND_ALERTS:
      # Send alerts means the News Feed is enabled + OS notifications are enabled
      newsFeedEnabled = true
      newsOSNotificationsEnabled = true
    of VALUE_NOTIF_TURN_OFF:
      # Turn OFF means the News Feed is disabled + OS notifications are disabled
      newsFeedEnabled = false
      newsOSNotificationsEnabled = false
    of VALUE_NOTIF_DELIVER_QUIETLY:
      # Deliver quietly means the News Feed is enabled + OS notifications are disabled
      newsFeedEnabled = true
      newsOSNotificationsEnabled = false
    else:
      error "error: ", procName="setNotifSettingStatusNews", errDescription = "Unknown value: ", value
      return

    # toggleNewsFeedEnabled changes the value and calls the signals
    discard self.toggleNewsFeedEnabled(newsFeedEnabled, newsOSNotificationsEnabled)

  QtProperty[string] notifSettingStatusNews:
    read = getNotifSettingStatusNews
    write = setNotifSettingStatusNews
    notify = notifSettingStatusNewsChanged

  proc newsRSSEnabledChanged*(self: Service) {.signal.}
  proc getNewsRSSEnabled*(self: Service): bool {.slot.} =
    if self.initialized:
      return self.settings.newsRSSEnabled

    result = true #default value
    try:
      let response = status_newsfeed.rssEnabled()
      if(not response.error.isNil):
        raise newException(RpcException, response.error.message)
      result = response.result.getBool
    except Exception as e:
      let errDesription = e.msg
      error "reading news RSS setting error: ", errDesription

  proc setNewsRSSEnabled*(self: Service, value: bool) {.slot.} =
    try:
      let response = status_newsfeed.setRSSEnabled(value)
      if not response.error.isNil:
        raise newException(RpcException, response.error.message)

      self.settings.newsRSSEnabled = value
      self.newsRSSEnabledChanged()
    except Exception as e:
      error "error: ", procName="toggleNewsRSSEnabled", errName = e.name, errDesription = e.msg

  QtProperty[bool] newsRSSEnabled:
    read = getNewsRSSEnabled
    write = setNewsRSSEnabled
    notify = newsRSSEnabledChanged

  # BACKUP
  proc setBackupPath*(self: Service, value: string) {.slot.} =
    if self.settings.backupPath == value:
      return
    try:
      var formattedPath = value
      var pathToSaveInDB = value
      when defined(android):
        # If the user selected a SAF folder, persist the URI permission immediately.
        if value.len > 0 and value.startsWith("content://"):
          safTakePersistablePermission(value)
          pathToSaveInDB = DEFAULT_BACKUP_DIR  # On Android, we save the data dir in the DB
      else:
        formattedPath = singletonInstance.utils.fromPathUri(value)
        pathToSaveInDB = formattedPath

      # We save this path in the local setting as it is the chosen path by the user
      singletonInstance.localAccountSensitiveSettings.setLocalBackupChosenPath(formattedPath)

      # In the DB, we save the path where we will actually write the backups
      # For most OSes, it will be the exact same path, but for Android, it will be
      # the data dir as we need to use the SAF to write the file to the chosen folder
      if self.saveSetting(KEY_BACKUP_PATH, pathToSaveInDB):
        self.settings.backupPath = pathToSaveInDB
      else:
        raise newException(RpcException, "Failed to save backup path setting")
    except Exception as e:
      error "error: ", procName="setBackupPath", errName = e.name, errDesription = e.msg

  proc messagesBackupEnabledChanged*(self: Service) {.signal.}
  proc getMessagesBackupEnabled*(self: Service): bool {.slot.} =
    if self.initialized:
      return self.settings.messagesBackupEnabled

    try:
      let response = status_settings.messagesBackupEnabled()
      if not response.error.isNil:
        raise newException(RpcException, response.error.message)
      return response.result.getBool
    except Exception as e:
      let errDesription = e.msg
      error "reading messagesBackupEnabled setting error: ", errDesription
      return false

  proc setMessagesBackupEnabled*(self: Service, value: bool) {.slot.} =
    if self.settings.messagesBackupEnabled == value:
      return
    try:
      if self.saveSetting(KEY_MESSAGES_BACKUP_ENABLED, value):
        self.settings.messagesBackupEnabled = value
        self.messagesBackupEnabledChanged()
      else:
        raise newException(RpcException, "Failed to save messages backup enabled setting")
    except Exception as e:
      error "error: ", procName="setMessagesBackupEnabled", errName = e.name, errDesription = e.msg

  QtProperty[bool] messagesBackupEnabled:
    read = getMessagesBackupEnabled
    write = setMessagesBackupEnabled
    notify = messagesBackupEnabledChanged

  proc thirdpartyServicesEnabledChanged*(self: Service) {.signal.}

  proc getThirdpartyServicesEnabled*(self: Service): bool {.slot.} =
    try:
      let response = status_settings.thirdpartyServicesEnabled()
      if not response.error.isNil:
        raise newException(RpcException, response.error.message)
      return response.result.getBool
    except Exception as e:
      let errDesription = e.msg
      error "reading thirdpartyServicesEnabled setting error: ", errDesription

  proc setThirdpartyServicesEnabled*(self: Service, value: bool) {.slot.} =
    try:
      if self.saveSetting(KEY_THIRDPARTY_SERVICES_ENABLED, value):
        self.settings.thirdpartyServicesEnabled = value
        self.thirdpartyServicesEnabledChanged()
      else:
        raise newException(RpcException, "Failed to save ThirdpartyServicesEnabled setting")
    except Exception as e:
      error "error: ", procName="setThirdpartyServicesEnabled", errName = e.name, errDesription = e.msg

  QtProperty[bool] thirdpartyServicesEnabled:
    read = getThirdpartyServicesEnabled
    write = setThirdpartyServicesEnabled
    notify = thirdpartyServicesEnabledChanged

  proc delete*(self: Service) =
    self.QObject.delete

