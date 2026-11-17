## Per-profile settings file `qt/<keyUid>`. Replaces the legacy `qt/<display name>` and
## `qt/<public key>` files, each merged into it once.

import nimqml, os, json, chronicles
import app/global/qt_settings
import app/global/local_app_settings

import ../../constants

const LS_KEY_STORE_TO_KEYCHAIN* = "storeToKeychain"
const LS_KEY_FRESH_PROFILE* = "freshProfile"
const DEFAULT_STORE_TO_KEYCHAIN = "notNow"
const LS_KEY_STAY_LOGGED_IN* = "stayLoggedIn"
const LS_VALUE_STORE* = "store"
const LS_VALUE_NOT_NOW* = "notNow"
const LS_VALUE_NEVER* = "never"

# Legacy file merge markers
const LS_KEY_DISPLAY_NAME_FILE_MERGED* = "migration/displayNameFileMerged"
const LS_KEY_PUBLIC_KEY_FILE_MERGED* = "migration/publicKeyFileMerged"
const LS_KEY_PUBLIC_KEY_FILE_STALE* = "migration/publicKeyFileStale"

const LSS_KEY_CHAT_SPLIT_VIEW* = "chatSplitView"
const LSS_KEY_WALLET_SPLIT_VIEW* = "walletSplitView"
const LSS_KEY_PROFILE_SPLIT_VIEW* = "profileSplitView"
const LSS_KEY_IS_COMMUNITY_PERMISSIONS_ENABLED* = "isExperimentalCommunityPermissionsEnabled"
const DEFAULT_IS_COMMUNITY_PERMISSIONS_ENABLED = false
const LSS_KEY_IS_COMMUNITY_TOKENS_ENABLED* = "isExperimentalCommunityTokensEnabled"
const DEFAULT_IS_COMMUNITY_TOKENS_ENABLED = false
const LSS_KEY_ENS_COMMUNITY_PERMISSIONS_ENABLED* = "ensCommunityPermissionsEnabled"
const DEFAULT_COMMUNITY_PERMISSIONS_ENABLED = false
const LSS_KEY_IS_BROWSER_ENABLED* = "isExperimentalBrowserEnabled"
const DEFAULT_IS_BROWSER_ENABLED = true
const LSS_KEY_EXPAND_USERS_LIST* = "expandUsersList"
const DEFAULT_EXPAND_USERS_LIST = true
const DEFAULT_IS_MULTI_NETWORK_ENABLED = false
const LSS_KEY_NEVER_ASK_ABOUT_UNFURLING_AGAIN* = "neverAskAboutUnfurlingAgain"
const DEFAULT_NEVER_ASK_ABOUT_UNFURLING_AGAIN = false
const LSS_KEY_HIDE_CHANNEL_SUGGESTIONS* = "hideChannelSuggestions"
const DEFAULT_HIDE_CHANNEL_SUGGESTIONS = false
const DEFAULT_HIDE_SIGN_PHRASE_MODAL = false
const LSS_KEY_QUITE_ON_CLOSE* = "quitOnClose"
const DEFAULT_QUITE_ON_CLOSE = false
const LSS_KEY_SHOW_DELETE_MESSAGE_WARNING* = "showDeleteMessageWarning"
const DEFAULT_SHOW_DELETE_MESSAGE_WARNING = true
const LSS_KEY_SHOW_DELETE_THREAD_WARNING* = "showDeleteThreadWarning"
const DEFAULT_SHOW_DELETE_THREAD_WARNING = true
const LSS_KEY_ACTIVE_SECTION* = "activeSection"
const DEFAULT_ACTIVE_SECTION = ""
const LAST_SECTION_CHAT = "LastSectionChat"
const LAST_SECTION_THREAD = "LastSectionThread"
const THREAD_PRESENTATION_SELECTED_CHAT* = "selectedChat"
const THREAD_PRESENTATION_SIDE_PANEL* = "sidePanel"
const DEFAULT_ACTIVE_CHAT = ""
const DEFAULT_SHOW_BROWSER_SELECTOR = true
const LSS_KEY_OPEN_LINKS_IN_STATUS* = "openLinksInStatus"
const DEFAULT_OPEN_LINKS_IN_STATUS = true
const LSS_KEY_SHOULD_SHOW_FAVORITES_BAR* = "shouldShowFavoritesBar"
const DEFAULT_SHOULD_SHOW_FAVORITES_BAR = not IS_MOBILE
const LSS_KEY_BROWSER_HOMEPAGE* = "browserHomepage"
const DEFAULT_BROWSER_HOMEPAGE = ""
const LSS_KEY_SHOULD_SHOW_BROWSER_SEARCH_ENGINE* = "shouldShowBrowserSearchEngine"
const DEFAULT_SHOULD_SHOW_BROWSER_SEARCH_ENGINE = 1 #browserSearchEngineDuckDuckGo from SearchEnginesConfig.qml
const LSS_KEY_CUSTOM_SEARCH_ENGINE_URL* = "customSearchEngineUrl"
const DEFAULT_CUSTOM_SEARCH_ENGINE_URL = ""
const LSS_KEY_USE_BROWSER_ETHEREUM_EXPLORER* = "useBrowserEthereumExplorer"
const DEFAULT_USE_BROWSER_ETHEREUM_EXPLORER = 1 #browserEthereumExplorerEtherscan from qml
const LSS_KEY_AUTO_LOAD_IMAGES* = "autoLoadImages"
const DEFAULT_AUTO_LOAD_IMAGES = true
const LSS_KEY_JAVA_SCRIPT_ENABLED* = "javaScriptEnabled"
const DEFAULT_JAVA_SCRIPT_ENABLED = true
const LSS_KEY_ERROR_PAGE_ENABLED* = "errorPageEnabled"
const DEFAULT_ERROR_PAGE_ENABLED = true
const LSS_KEY_PLUGINS_ENABLED* = "pluginsEnabled"
const DEFAULT_PLUGINS_ENABLED = true
const LSS_KEY_AUTO_LOAD_ICONS_FOR_PAGE* = "autoLoadIconsForPage"
const DEFAULT_AUTO_LOAD_ICONS_FOR_PAGE = true
const LSS_KEY_TOUCH_ICONS_ENABLED* = "touchIconsEnabled"
const DEFAULT_TOUCH_ICONS_ENABLED = true
const LSS_KEY_WEB_RTC_PUBLIC_INTERFACES_ONLY* = "webRTCPublicInterfacesOnly"
const DEFAULT_WEB_RTC_PUBLIC_INTERFACES_ONLY = true
const LSS_KEY_DEV_TOOLS_ENABLED* = "devToolsEnabled"
const DEFAULT_DEV_TOOLS_ENABLED = false
const LSS_KEY_PDF_VIEWER_ENABLED* = "pdfViewerEnabled"
const DEFAULT_PDF_VIEWER_ENABLED = true
const LSS_KEY_STICKERS_ENS_ROPSTEN* = "stickersEnsRopsten"
const DEFAULT_STICKERS_ENS_ROPSTEN = false
const LSS_KEY_USER_DECLINED_BACKUP_BANNER* = "userDeclinedBackupBanner"
const DEFAULT_USER_DECLINED_BACKUP_BANNER = false
const LSS_KEY_GIF_UNFURLING_ENABLED* = "gifUnfurlingEnabled"
const DEFAULT_GIF_UNFURLING_ENABLED* = false
const LSS_KEY_COPY_MESSAGE_LINKS_ENABLED* = "copyMessageLinksEnabled"
const DEFAULT_COPY_MESSAGE_LINKS_ENABLED* = false
const LS_KEY_LOCAL_BACKUP_CHOSEN_PATH* = "localBackupChosenPath"

logScope:
  topics = "local-account-settings"

type SectionThreadRecord* = object
  threadId*: string
  parentChatId*: string
  presentation*: string

proc parseLastSectionThread*(serialized: string): SectionThreadRecord =
  if serialized.len == 0:
    return

  try:
    let value = serialized.parseJson()
    if value.kind != JObject:
      raise newException(ValueError, "thread record is not an object")
    result.threadId = value{"threadId"}.getStr()
    result.parentChatId = value{"parentChatId"}.getStr()
    result.presentation = value{"presentation"}.getStr()
    if result.threadId.len == 0 or result.parentChatId.len == 0 or
        result.presentation notin [THREAD_PRESENTATION_SELECTED_CHAT, THREAD_PRESENTATION_SIDE_PANEL]:
      raise newException(ValueError, "thread record is incomplete")
  except CatchableError as e:
    warn "ignoring malformed last section thread record", msg=e.msg
    result = SectionThreadRecord()

proc openIniFile(path: string): QSettings =
  newQSettings(path, QSettingsFormat.IniFormat)

proc copyIfMissing(target, source: QSettings, sourceKey: string, targetKey = sourceKey) =
  if source.contains(sourceKey) and not target.contains(targetKey):
    target.setValue(targetKey, source.value(sourceKey))

type ProfileName* = tuple[keyUid, displayName: string]

proc isSameFile(a, b: string): bool =
  ## The file system decides, e.g. case-insensitively on macOS and Windows.
  try:
    fileExists(a) and fileExists(b) and sameFile(a, b)
  except OSError:
    true # unknown: assume shared, so nothing is deleted

proc isPlainFileName(name: string): bool =
  # Names from before status-go validated them may hold path separators.
  name.len > 0 and name == extractFilename(name) and name notin [".", ".."]

proc removeLegacyFile(path: string) =
  try:
    removeFile(path)
  except OSError as e:
    warn "failed to remove a merged legacy settings file", path, msg = e.msg

QtObject:
  type LocalAccountSettings* = ref object of QObject
    settingsFileDir: string
    keyUid: string
    settings: QSettings

  proc setup(self: LocalAccountSettings, settingsFileDir: string)
  proc delete*(self: LocalAccountSettings)
  proc notifyAll(self: LocalAccountSettings)

  proc newLocalAccountSettings*(settingsFileDir = os.joinPath(DATADIR, "qt")):
    LocalAccountSettings =
    new(result, delete)
    result.setup(settingsFileDir)

  proc flush*(self: LocalAccountSettings) =
    if not self.settings.isNil:
      self.settings.sync()

  proc releaseSettings(self: LocalAccountSettings) =
    # Flush before dropping the reference: the QSettings itself is freed later.
    self.flush()
    self.settings = nil

  proc filePath(self: LocalAccountSettings, fileName: string): string =
    os.joinPath(self.settingsFileDir, fileName)

  proc isFileMerged(self: LocalAccountSettings, keyUid: string, marker: string): bool =
    let path = self.filePath(keyUid)
    fileExists(path) and openIniFile(path).contains(marker)

  proc commitMarker(self: LocalAccountSettings, marker: string): bool =
    self.settings.setValue(marker, newQVariant(true))
    self.settings.sync()
    result = self.settings.status() == QSettingsStatus.NoError
    if not result:
      self.settings.remove(marker)
      warn "failed to write the merged legacy settings", keyUid = self.keyUid, marker

  proc removeUnusedDisplayNameFile(self: LocalAccountSettings, displayName: string,
      otherProfiles: seq[ProfileName]) =
    ## Unless a profile sharing it hasn't merged it yet, or it is the app file.
    if not isPlainFileName(displayName):
      return
    let legacyPath = self.filePath(displayName)
    if not fileExists(legacyPath) or
        isSameFile(legacyPath, self.filePath(APP_SETTINGS_FILE_NAME)):
      return
    for other in otherProfiles:
      if isSameFile(legacyPath, self.filePath(other.displayName)) and
          not self.isFileMerged(other.keyUid, LS_KEY_DISPLAY_NAME_FILE_MERGED):
        return
    removeLegacyFile(legacyPath)

  proc mergeLegacyDisplayNameFile(self: LocalAccountSettings, displayName: string,
      otherProfiles: seq[ProfileName]) =
    ## Profiles whose names map to the same file share it: each takes all of its keys, as
    ## before the upgrade, and it is removed once all of them merged it. Removed files are
    ## not restored for an older build.
    if self.settings.contains(LS_KEY_DISPLAY_NAME_FILE_MERGED):
      return

    let legacyPath = self.filePath(displayName)
    var hasLegacyFile = false
    if isPlainFileName(displayName) and fileExists(legacyPath):
      let ownPath = self.filePath(self.keyUid)
      try:
        hasLegacyFile = not (fileExists(ownPath) and sameFile(legacyPath, ownPath))
      except OSError:
        return # retried on the next bind
    if hasLegacyFile:
      let legacy = openIniFile(legacyPath)
      if legacy.status() != QSettingsStatus.NoError:
        warn "failed to read the legacy display-name settings", keyUid = self.keyUid
        return
      self.settings.copyIfMissing(legacy, LS_KEY_STORE_TO_KEYCHAIN)
      self.settings.copyIfMissing(legacy, LS_KEY_FRESH_PROFILE)
      self.settings.copyIfMissing(legacy, LS_KEY_STAY_LOGGED_IN & "/" & self.keyUid,
        LS_KEY_STAY_LOGGED_IN)

    if self.commitMarker(LS_KEY_DISPLAY_NAME_FILE_MERGED) and hasLegacyFile:
      self.removeUnusedDisplayNameFile(displayName, otherProfiles)

  proc bindAccount*(self: LocalAccountSettings, keyUid: string, displayName = "",
      otherProfiles: seq[ProfileName] = @[]) =
    ## Binds `qt/<keyUid>` and merges the legacy `qt/<displayName>` file into it. Without a
    ## name nothing is merged yet. `otherProfiles`: every other local profile.
    if keyUid.len == 0 or (keyUid == self.keyUid and not self.settings.isNil):
      return

    self.releaseSettings()
    self.keyUid = keyUid
    self.settings = openIniFile(self.filePath(keyUid))
    if displayName.len > 0:
      self.mergeLegacyDisplayNameFile(displayName, otherProfiles)
    self.notifyAll()

  proc markNewOnDevice*(self: LocalAccountSettings) =
    ## Legacy files of its name or public key belong to another or a deleted profile.
    if self.settings.isNil:
      return
    self.settings.setValue(LS_KEY_PUBLIC_KEY_FILE_STALE, newQVariant(true))
    if not self.commitMarker(LS_KEY_DISPLAY_NAME_FILE_MERGED):
      self.settings.remove(LS_KEY_PUBLIC_KEY_FILE_STALE)

  proc mergeLegacyPublicKeyFile*(self: LocalAccountSettings, publicKey: string) =
    ## Post-login (the public key is unknown before). On failure, retried on the next login.
    if self.settings.isNil or publicKey.len == 0 or
        self.settings.contains(LS_KEY_PUBLIC_KEY_FILE_MERGED):
      return

    let legacyPath = self.filePath(publicKey)
    let hasLegacyFile = fileExists(legacyPath)
    let stale = self.settings.contains(LS_KEY_PUBLIC_KEY_FILE_STALE)
    if hasLegacyFile and not stale:
      let legacy = openIniFile(legacyPath)
      if legacy.status() != QSettingsStatus.NoError:
        warn "failed to read the legacy public-key settings", keyUid = self.keyUid
        return
      for key in legacy.allKeys():
        self.settings.copyIfMissing(legacy, key)

    if self.commitMarker(LS_KEY_PUBLIC_KEY_FILE_MERGED) and hasLegacyFile:
      removeLegacyFile(legacyPath)
      if not stale:
        self.notifyAll()

  proc detach*(self: LocalAccountSettings) =
    ## For a profile being created or deleted; logout keeps the binding.
    self.releaseSettings()
    self.keyUid = ""
    self.notifyAll()

  proc removeAccount*(self: LocalAccountSettings, keyUid: string, displayName: string,
      otherProfiles: seq[ProfileName]) =
    ## An unmerged legacy public-key file stays: the public key is unknown before login.
    if keyUid.len == 0:
      return
    if keyUid == self.keyUid:
      self.detach()
    let path = self.filePath(keyUid)
    try:
      removeFile(path)
    except OSError as e:
      warn "failed to remove the profile's settings file", keyUid, msg = e.msg
    self.removeUnusedDisplayNameFile(displayName, otherProfiles)

  proc storeToKeychainValueChanged*(self: LocalAccountSettings) {.signal.}

  proc getStoreToKeychainValue*(self: LocalAccountSettings): string {.slot.} =
    if self.settings.isNil or TEST_MODE_ENABLED:
      return DEFAULT_STORE_TO_KEYCHAIN

    self.settings.value(LS_KEY_STORE_TO_KEYCHAIN).stringVal

  proc setStoreToKeychainValue*(self: LocalAccountSettings, value: string) {.slot.} =
    if self.settings.isNil:
      return

    self.settings.setValue(LS_KEY_STORE_TO_KEYCHAIN, newQVariant(value))
    self.storeToKeychainValueChanged()

  QtProperty[string] storeToKeychainValue:
    read = getStoreToKeychainValue
    write = setStoreToKeychainValue
    notify = storeToKeychainValueChanged

  proc freshProfileChanged*(self: LocalAccountSettings) {.signal.}

  # A profile created in this install with a generated seed phrase; absent for every other origin.
  proc isFreshProfile*(self: LocalAccountSettings): bool {.slot.} =
    if self.settings.isNil:
      return false
    self.settings.value(LS_KEY_FRESH_PROFILE, newQVariant(false)).boolVal

  # Nim-only on purpose: the origin is decided once at profile creation, never from the UI.
  proc markProfileFresh*(self: LocalAccountSettings) =
    if self.settings.isNil:
      return
    self.settings.setValue(LS_KEY_FRESH_PROFILE, newQVariant(true))
    self.freshProfileChanged()

  QtProperty[bool] freshProfile:
    read = isFreshProfile
    notify = freshProfileChanged

  proc stayLoggedInChanged*(self: LocalAccountSettings) {.signal.}

  # "Stay logged in" preference of the bound profile.
  # Deliberately NOT the source of truth for the startup auto-login decision (that is the
  # presence of the credential in secure storage, checkable pre-login); this flag governs
  # whether the credential gets (re-)stored after an explicit login — it survives logout
  # by design. Default false: existing users are opted out; new users opt in via the
  # onboarding checkbox. Always false in TEST_MODE so e2e runs can never auto-login.
  proc getStayLoggedIn*(self: LocalAccountSettings): bool {.slot.} =
    if self.settings.isNil or TEST_MODE_ENABLED:
      return false
    self.settings.value(LS_KEY_STAY_LOGGED_IN).boolVal

  proc setStayLoggedIn*(self: LocalAccountSettings, value: bool) {.slot.} =
    if self.settings.isNil:
      return
    self.settings.setValue(LS_KEY_STAY_LOGGED_IN, newQVariant(value))
    self.stayLoggedInChanged()

  QtProperty[bool] stayLoggedIn:
    read = getStayLoggedIn
    write = setStayLoggedIn
    notify = stayLoggedInChanged

  # float type must be exposed through QVariant property.
  proc getSettingsPropQVariant(self: LocalAccountSettings, prop: string, default: QVariant): QVariant =
    result = if(self.settings.isNil): default else: self.settings.value(prop, default)

  proc getSettingsPropString(self: LocalAccountSettings, prop: string, default: QVariant): string =
    result = if(self.settings.isNil): default.stringVal else: self.settings.value(prop, default).stringVal

  proc getSettingsPropInt(self: LocalAccountSettings, prop: string, default: QVariant): int =
    result = if(self.settings.isNil): default.intVal else: self.settings.value(prop, default).intVal

  proc getSettingsPropBool(self: LocalAccountSettings, prop: string, default: QVariant): bool =
    result = if(self.settings.isNil): default.boolVal else: self.settings.value(prop, default).boolVal

  template getSettingsProp[T](self: LocalAccountSettings, prop: string, default: QVariant): untyped =
    # This doesn't work in case of QVariant, such properties will be handled in a common way.
    when T is string:
      result = getSettingsPropString(self, prop, default)
    when T is int:
      result = getSettingsPropInt(self, prop, default)
    when T is bool:
      result = getSettingsPropBool(self, prop, default)

  template getSettingsGroupProp[T](self: LocalAccountSettings, group: string, prop: string, default: QVariant): untyped =
    # This doesn't work in case of QVariant, such properties will be handled in a common way.
    if(self.settings.isNil):
      return

    self.settings.beginGroup(group);
    getSettingsProp[T](self, prop, default)
    self.settings.endGroup();
  

  template setSettingsProp(self: LocalAccountSettings, prop: string, value: QVariant, signal: untyped) =
    if(self.settings.isNil):
      return

    self.settings.setValue(prop, value)
    signal

  template setSettingsGroupProp(self: LocalAccountSettings, group: string, key: string, value: QVariant) =
    if(self.settings.isNil):
      return

    self.settings.beginGroup(group)
    self.settings.setValue(key, value)
    self.settings.endGroup()

  proc removeSettingsGroupKey(self: LocalAccountSettings, group: string, key: string) =
    if(self.settings.isNil):
      return

    self.settings.beginGroup(group)
    self.settings.remove(key)
    self.settings.endGroup()

  proc getSectionLastOpenChat*(self: LocalAccountSettings, sectionId: string): string =
    getSettingsGroupProp[string](self, LAST_SECTION_CHAT, sectionId, newQVariant(DEFAULT_ACTIVE_CHAT))

  proc setSectionLastOpenChat*(self: LocalAccountSettings, sectionId: string, value: string) =
    self.setSettingsGroupProp(LAST_SECTION_CHAT, sectionId, newQVariant(value))
    if not self.settings.isNil:
       self.settings.sync()

  proc getSectionLastOpenThread*(self: LocalAccountSettings, sectionId: string): string =
    getSettingsGroupProp[string](self, LAST_SECTION_THREAD, sectionId, newQVariant(""))

  proc setSectionLastOpenThread*(self: LocalAccountSettings, sectionId: string,
      threadId: string, parentChatId: string, presentation: string) =
    if threadId.len == 0 or parentChatId.len == 0 or
        presentation notin [THREAD_PRESENTATION_SELECTED_CHAT, THREAD_PRESENTATION_SIDE_PANEL]:
      error "refusing invalid last section thread record", sectionId, threadId, parentChatId, presentation
      return
    self.setSettingsGroupProp(LAST_SECTION_THREAD, sectionId, newQVariant($(%*{
      "threadId": threadId,
      "parentChatId": parentChatId,
      "presentation": presentation,
    })))
    if not self.settings.isNil:
       self.settings.sync()

  proc removeSectionLastOpenThread*(self: LocalAccountSettings, sectionId: string) =
    self.removeSettingsGroupKey(LAST_SECTION_THREAD, sectionId)
    if not self.settings.isNil:
       self.settings.sync()
    
  proc removeSectionChatRecord*(self: LocalAccountSettings, sectionId: string) =
    self.removeSettingsGroupKey(LAST_SECTION_CHAT, sectionId)
    self.removeSectionLastOpenThread(sectionId)

  proc chatSplitViewChanged*(self: LocalAccountSettings) {.signal.}
  proc getChatSplitView*(self: LocalAccountSettings): QVariant {.slot.} =
    getSettingsPropQVariant(self, LSS_KEY_CHAT_SPLIT_VIEW, newQVariant())
  proc setChatSplitView*(self: LocalAccountSettings, value: QVariant) {.slot.} =
    setSettingsProp(self, LSS_KEY_CHAT_SPLIT_VIEW, value):
      self.chatSplitViewChanged()

  QtProperty[QVariant] chatSplitView:
    read = getChatSplitView
    write = setChatSplitView
    notify = chatSplitViewChanged


  proc walletSplitViewChanged*(self: LocalAccountSettings) {.signal.}
  proc getWalletSplitView*(self: LocalAccountSettings): QVariant {.slot.} =
    getSettingsPropQVariant(self, LSS_KEY_WALLET_SPLIT_VIEW, newQVariant())
  proc setWalletSplitView*(self: LocalAccountSettings, value: QVariant) {.slot.} =
    setSettingsProp(self, LSS_KEY_WALLET_SPLIT_VIEW, value):
      self.walletSplitViewChanged()

  QtProperty[QVariant] walletSplitView:
    read = getWalletSplitView
    write = setWalletSplitView
    notify = walletSplitViewChanged


  proc profileSplitViewChanged*(self: LocalAccountSettings) {.signal.}
  proc getProfileSplitView*(self: LocalAccountSettings): QVariant {.slot.} =
    getSettingsPropQVariant(self, LSS_KEY_PROFILE_SPLIT_VIEW, newQVariant())
  proc setProfileSplitView*(self: LocalAccountSettings, value: QVariant) {.slot.} =
    setSettingsProp(self, LSS_KEY_PROFILE_SPLIT_VIEW, value):
      self.profileSplitViewChanged()

  QtProperty[QVariant] profileSplitView:
    read = getProfileSplitView
    write = setProfileSplitView
    notify = profileSplitViewChanged

  proc isBrowserEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getIsBrowserEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_IS_BROWSER_ENABLED, newQVariant(DEFAULT_IS_BROWSER_ENABLED))
  proc setIsBrowserEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_IS_BROWSER_ENABLED, newQVariant(value)):
      self.isBrowserEnabledChanged()

  QtProperty[bool] isBrowserEnabled:
    read = getIsBrowserEnabled
    write = setIsBrowserEnabled
    notify = isBrowserEnabledChanged

  proc ensCommunityPermissionsEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getEnsCommunityPermissionsEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_ENS_COMMUNITY_PERMISSIONS_ENABLED, newQVariant(DEFAULT_COMMUNITY_PERMISSIONS_ENABLED))
  proc setEnsCommunityPermissionsEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_ENS_COMMUNITY_PERMISSIONS_ENABLED, newQVariant(value)):
      self.ensCommunityPermissionsEnabledChanged()

  QtProperty[bool] ensCommunityPermissionsEnabled:
    read = getEnsCommunityPermissionsEnabled
    write = setEnsCommunityPermissionsEnabled
    notify = ensCommunityPermissionsEnabledChanged

  proc expandUsersListChanged*(self: LocalAccountSettings) {.signal.}
  proc getExpandUsersList*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_EXPAND_USERS_LIST, newQVariant(DEFAULT_EXPAND_USERS_LIST))
  proc setExpandUsersList*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_EXPAND_USERS_LIST, newQVariant(value)):
      self.expandUsersListChanged()

  QtProperty[bool] expandUsersList:
    read = getExpandUsersList
    write = setExpandUsersList
    notify = expandUsersListChanged

  proc neverAskAboutUnfurlingAgainChanged*(self: LocalAccountSettings) {.signal.}
  proc getNeverAskAboutUnfurlingAgain*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_NEVER_ASK_ABOUT_UNFURLING_AGAIN, newQVariant(DEFAULT_NEVER_ASK_ABOUT_UNFURLING_AGAIN))
  proc setNeverAskAboutUnfurlingAgain*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_NEVER_ASK_ABOUT_UNFURLING_AGAIN, newQVariant(value)):
      self.neverAskAboutUnfurlingAgainChanged()

  QtProperty[bool] neverAskAboutUnfurlingAgain:
    read = getNeverAskAboutUnfurlingAgain
    write = setNeverAskAboutUnfurlingAgain
    notify = neverAskAboutUnfurlingAgainChanged


  proc hideChannelSuggestionsChanged*(self: LocalAccountSettings) {.signal.}
  proc getHideChannelSuggestions*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_HIDE_CHANNEL_SUGGESTIONS, newQVariant(DEFAULT_HIDE_CHANNEL_SUGGESTIONS))
  proc setHideChannelSuggestions*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_HIDE_CHANNEL_SUGGESTIONS, newQVariant(value)):
      self.hideChannelSuggestionsChanged()

  QtProperty[bool] hideChannelSuggestions:
    read = getHideChannelSuggestions
    write = setHideChannelSuggestions
    notify = hideChannelSuggestionsChanged


  proc quitOnCloseChanged*(self: LocalAccountSettings) {.signal.}
  proc getQuitOnClose*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_QUITE_ON_CLOSE, newQVariant(DEFAULT_QUITE_ON_CLOSE))
  proc setQuitOnClose*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_QUITE_ON_CLOSE, newQVariant(value)):
      self.quitOnCloseChanged()

  QtProperty[bool] quitOnClose:
    read = getQuitOnClose
    write = setQuitOnClose
    notify = quitOnCloseChanged


  proc showDeleteMessageWarningChanged*(self: LocalAccountSettings) {.signal.}
  proc getShowDeleteMessageWarning*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_SHOW_DELETE_MESSAGE_WARNING, newQVariant(DEFAULT_SHOW_DELETE_MESSAGE_WARNING))
  proc setShowDeleteMessageWarning*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_SHOW_DELETE_MESSAGE_WARNING, newQVariant(value)):
      self.showDeleteMessageWarningChanged()

  QtProperty[bool] showDeleteMessageWarning:
    read = getShowDeleteMessageWarning
    write = setShowDeleteMessageWarning
    notify = showDeleteMessageWarningChanged

  proc showDeleteThreadWarningChanged*(self: LocalAccountSettings) {.signal.}
  proc getShowDeleteThreadWarning*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_SHOW_DELETE_THREAD_WARNING, newQVariant(DEFAULT_SHOW_DELETE_THREAD_WARNING))
  proc setShowDeleteThreadWarning*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_SHOW_DELETE_THREAD_WARNING, newQVariant(value)):
      self.showDeleteThreadWarningChanged()

  QtProperty[bool] showDeleteThreadWarning:
    read = getShowDeleteThreadWarning
    write = setShowDeleteThreadWarning
    notify = showDeleteThreadWarningChanged

  proc activeSectionChanged*(self: LocalAccountSettings) {.signal.}
  proc getActiveSection*(self: LocalAccountSettings): string {.slot.} =
    getSettingsProp[string](self, LSS_KEY_ACTIVE_SECTION, newQVariant(DEFAULT_ACTIVE_SECTION))
  proc setActiveSection*(self: LocalAccountSettings, value: string) {.slot.} =
    setSettingsProp(self, LSS_KEY_ACTIVE_SECTION, newQVariant(value)):
      self.activeSectionChanged()

  QtProperty[string] activeSection:
    read = getActiveSection
    write = setActiveSection
    notify = activeSectionChanged

  proc openLinksInStatusChanged*(self: LocalAccountSettings) {.signal.}
  proc getOpenLinksInStatus*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_OPEN_LINKS_IN_STATUS, newQVariant(DEFAULT_OPEN_LINKS_IN_STATUS))
  proc setOpenLinksInStatus*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_OPEN_LINKS_IN_STATUS, newQVariant(value)):
      self.openLinksInStatusChanged()

  QtProperty[bool] openLinksInStatus:
    read = getOpenLinksInStatus
    write = setOpenLinksInStatus
    notify = openLinksInStatusChanged


  proc shouldShowFavoritesBarChanged*(self: LocalAccountSettings) {.signal.}
  proc getShouldShowFavoritesBar*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_SHOULD_SHOW_FAVORITES_BAR, newQVariant(DEFAULT_SHOULD_SHOW_FAVORITES_BAR))
  proc setShouldShowFavoritesBar*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_SHOULD_SHOW_FAVORITES_BAR, newQVariant(value)):
      self.shouldShowFavoritesBarChanged()

  QtProperty[bool] shouldShowFavoritesBar:
    read = getShouldShowFavoritesBar
    write = setShouldShowFavoritesBar
    notify = shouldShowFavoritesBarChanged


  proc browserHomepageChanged*(self: LocalAccountSettings) {.signal.}
  proc getBrowserHomepage*(self: LocalAccountSettings): string {.slot.} =
    getSettingsProp[string](self, LSS_KEY_BROWSER_HOMEPAGE, newQVariant(DEFAULT_BROWSER_HOMEPAGE))
  proc setBrowserHomepage*(self: LocalAccountSettings, value: string) {.slot.} =
    setSettingsProp(self, LSS_KEY_BROWSER_HOMEPAGE, newQVariant(value)):
      self.browserHomepageChanged()

  QtProperty[string] browserHomepage:
    read = getBrowserHomepage
    write = setBrowserHomepage
    notify = browserHomepageChanged


  proc selectedBrowserSearchEngineIdChanged*(self: LocalAccountSettings) {.signal.}
  proc getSelectedBrowserSearchEngineId*(self: LocalAccountSettings): int {.slot.} =
    getSettingsProp[int](self, LSS_KEY_SHOULD_SHOW_BROWSER_SEARCH_ENGINE, newQVariant(DEFAULT_SHOULD_SHOW_BROWSER_SEARCH_ENGINE))
  proc setSelectedBrowserSearchEngineId*(self: LocalAccountSettings, value: int) {.slot.} =
    setSettingsProp(self, LSS_KEY_SHOULD_SHOW_BROWSER_SEARCH_ENGINE, newQVariant(value)):
      self.selectedBrowserSearchEngineIdChanged()

  QtProperty[int] selectedBrowserSearchEngineId:
    read = getSelectedBrowserSearchEngineId
    write = setSelectedBrowserSearchEngineId
    notify = selectedBrowserSearchEngineIdChanged


  proc customSearchEngineUrlChanged*(self: LocalAccountSettings) {.signal.}
  proc getCustomSearchEngineUrl*(self: LocalAccountSettings): string {.slot.} =
    getSettingsProp[string](self, LSS_KEY_CUSTOM_SEARCH_ENGINE_URL, newQVariant(DEFAULT_CUSTOM_SEARCH_ENGINE_URL))
  proc setCustomSearchEngineUrl*(self: LocalAccountSettings, value: string) {.slot.} =
    setSettingsProp(self, LSS_KEY_CUSTOM_SEARCH_ENGINE_URL, newQVariant(value)):
      self.customSearchEngineUrlChanged()

  QtProperty[string] customSearchEngineUrl:
    read = getCustomSearchEngineUrl
    write = setCustomSearchEngineUrl
    notify = customSearchEngineUrlChanged


  proc useBrowserEthereumExplorerChanged*(self: LocalAccountSettings) {.signal.}
  proc getUseBrowserEthereumExplorer*(self: LocalAccountSettings): int {.slot.} =
    getSettingsProp[int](self, LSS_KEY_USE_BROWSER_ETHEREUM_EXPLORER, newQVariant(DEFAULT_USE_BROWSER_ETHEREUM_EXPLORER))
  proc setUseBrowserEthereumExplorer*(self: LocalAccountSettings, value: int) {.slot.} =
    setSettingsProp(self, LSS_KEY_USE_BROWSER_ETHEREUM_EXPLORER, newQVariant(value)):
      self.useBrowserEthereumExplorerChanged()

  QtProperty[int] useBrowserEthereumExplorer:
    read = getUseBrowserEthereumExplorer
    write = setUseBrowserEthereumExplorer
    notify = useBrowserEthereumExplorerChanged


  proc autoLoadImagesChanged*(self: LocalAccountSettings) {.signal.}
  proc getAutoLoadImages*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_AUTO_LOAD_IMAGES, newQVariant(DEFAULT_AUTO_LOAD_IMAGES))
  proc setAutoLoadImages*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_AUTO_LOAD_IMAGES, newQVariant(value)):
      self.autoLoadImagesChanged()

  QtProperty[bool] autoLoadImages:
    read = getAutoLoadImages
    write = setAutoLoadImages
    notify = autoLoadImagesChanged


  proc javaScriptEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getJavaScriptEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_JAVA_SCRIPT_ENABLED, newQVariant(DEFAULT_JAVA_SCRIPT_ENABLED))
  proc setJavaScriptEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_JAVA_SCRIPT_ENABLED, newQVariant(value)):
      self.javaScriptEnabledChanged()

  QtProperty[bool] javaScriptEnabled:
    read = getJavaScriptEnabled
    write = setJavaScriptEnabled
    notify = javaScriptEnabledChanged


  proc errorPageEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getErrorPageEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_ERROR_PAGE_ENABLED, newQVariant(DEFAULT_ERROR_PAGE_ENABLED))
  proc setErrorPageEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_ERROR_PAGE_ENABLED, newQVariant(value)):
      self.errorPageEnabledChanged()

  QtProperty[bool] errorPageEnabled:
    read = getErrorPageEnabled
    write = setErrorPageEnabled
    notify = errorPageEnabledChanged


  proc pluginsEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getPluginsEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_PLUGINS_ENABLED, newQVariant(DEFAULT_PLUGINS_ENABLED))
  proc setPluginsEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_PLUGINS_ENABLED, newQVariant(value)):
      self.pluginsEnabledChanged()

  QtProperty[bool] pluginsEnabled:
    read = getPluginsEnabled
    write = setPluginsEnabled
    notify = pluginsEnabledChanged

  proc autoLoadIconsForPageChanged*(self: LocalAccountSettings) {.signal.}
  proc getAutoLoadIconsForPage*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_AUTO_LOAD_ICONS_FOR_PAGE, newQVariant(DEFAULT_AUTO_LOAD_ICONS_FOR_PAGE))
  proc setAutoLoadIconsForPage*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_AUTO_LOAD_ICONS_FOR_PAGE, newQVariant(value)):
      self.autoLoadIconsForPageChanged()

  QtProperty[bool] autoLoadIconsForPage:
    read = getAutoLoadIconsForPage
    write = setAutoLoadIconsForPage
    notify = autoLoadIconsForPageChanged


  proc touchIconsEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getTouchIconsEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_TOUCH_ICONS_ENABLED, newQVariant(DEFAULT_TOUCH_ICONS_ENABLED))
  proc setTouchIconsEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_TOUCH_ICONS_ENABLED, newQVariant(value)):
      self.touchIconsEnabledChanged()

  QtProperty[bool] touchIconsEnabled:
    read = getTouchIconsEnabled
    write = setTouchIconsEnabled
    notify = touchIconsEnabledChanged


  proc webRTCPublicInterfacesOnlyChanged*(self: LocalAccountSettings) {.signal.}
  proc getWebRTCPublicInterfacesOnly*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_WEB_RTC_PUBLIC_INTERFACES_ONLY, newQVariant(DEFAULT_WEB_RTC_PUBLIC_INTERFACES_ONLY))
  proc setWebRTCPublicInterfacesOnly*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_WEB_RTC_PUBLIC_INTERFACES_ONLY, newQVariant(value)):
      self.webRTCPublicInterfacesOnlyChanged()

  QtProperty[bool] webRTCPublicInterfacesOnly:
    read = getWebRTCPublicInterfacesOnly
    write = setWebRTCPublicInterfacesOnly
    notify = webRTCPublicInterfacesOnlyChanged


  proc devToolsEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getDevToolsEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_DEV_TOOLS_ENABLED, newQVariant(DEFAULT_DEV_TOOLS_ENABLED))
  proc setDevToolsEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_DEV_TOOLS_ENABLED, newQVariant(value)):
      self.devToolsEnabledChanged()

  QtProperty[bool] devToolsEnabled:
    read = getDevToolsEnabled
    write = setDevToolsEnabled
    notify = devToolsEnabledChanged


  proc pdfViewerEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getPdfViewerEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_PDF_VIEWER_ENABLED, newQVariant(DEFAULT_PDF_VIEWER_ENABLED))
  proc setPdfViewerEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_PDF_VIEWER_ENABLED, newQVariant(value)):
      self.pdfViewerEnabledChanged()

  QtProperty[bool] pdfViewerEnabled:
    read = getPdfViewerEnabled
    write = setPdfViewerEnabled
    notify = pdfViewerEnabledChanged


  proc stickersEnsRopstenChanged*(self: LocalAccountSettings) {.signal.}
  proc getStickersEnsRopsten*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_STICKERS_ENS_ROPSTEN, newQVariant(DEFAULT_STICKERS_ENS_ROPSTEN))
  proc setStickersEnsRopsten*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_STICKERS_ENS_ROPSTEN, newQVariant(value)):
      self.stickersEnsRopstenChanged()

  QtProperty[bool] stickersEnsRopsten:
    read = getStickersEnsRopsten
    write = setStickersEnsRopsten
    notify = stickersEnsRopstenChanged

  proc userDeclinedBackupBannerChanged*(self: LocalAccountSettings) {.signal.}
  proc getUserDeclinedBackupBanner*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_USER_DECLINED_BACKUP_BANNER, newQVariant(DEFAULT_USER_DECLINED_BACKUP_BANNER))
  proc setUserDeclinedBackupBanner*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_USER_DECLINED_BACKUP_BANNER, newQVariant(value)):
      self.userDeclinedBackupBannerChanged()

  QtProperty[bool] userDeclinedBackupBanner:
    read = getUserDeclinedBackupBanner
    write = setUserDeclinedBackupBanner
    notify = userDeclinedBackupBannerChanged

  proc gifUnfurlingEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getGifUnfurlingEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_GIF_UNFURLING_ENABLED, newQVariant(DEFAULT_GIF_UNFURLING_ENABLED))
  proc setGifUnfurlingEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_GIF_UNFURLING_ENABLED, newQVariant(value)):
      self.gifUnfurlingEnabledChanged()

  QtProperty[bool] gifUnfurlingEnabled:
    read = getGifUnfurlingEnabled
    write = setGifUnfurlingEnabled
    notify = gifUnfurlingEnabledChanged

  proc copyMessageLinksEnabledChanged*(self: LocalAccountSettings) {.signal.}
  proc getCopyMessageLinksEnabled*(self: LocalAccountSettings): bool {.slot.} =
    getSettingsProp[bool](self, LSS_KEY_COPY_MESSAGE_LINKS_ENABLED, newQVariant(DEFAULT_COPY_MESSAGE_LINKS_ENABLED))
  proc setCopyMessageLinksEnabled*(self: LocalAccountSettings, value: bool) {.slot.} =
    setSettingsProp(self, LSS_KEY_COPY_MESSAGE_LINKS_ENABLED, newQVariant(value)):
      self.copyMessageLinksEnabledChanged()

  QtProperty[bool] copyMessageLinksEnabled:
    read = getCopyMessageLinksEnabled
    write = setCopyMessageLinksEnabled
    notify = copyMessageLinksEnabledChanged

  proc localBackupChosenPathChanged*(self: LocalAccountSettings) {.signal.}

  proc getLocalBackupChosenPathSetting*(self: LocalAccountSettings): string =
    if self.settings.isNil or TEST_MODE_ENABLED:
      return ""

    return self.settings.value(LS_KEY_LOCAL_BACKUP_CHOSEN_PATH).stringVal

  proc getLocalBackupChosenPath*(self: LocalAccountSettings): string {.slot.} =
    let setting = self.getLocalBackupChosenPathSetting()
    if setting == "":
      when defined(android):
        # Return an empty string to make it clear to users that without permissisons we cannot access any path
        return ""
      return DEFAULT_BACKUP_DIR

    return setting

  # Not a slot
  # We need to call this from setBackupPath in settings/service.nim
  proc setLocalBackupChosenPath*(self: LocalAccountSettings, value: string) =
    if self.settings.isNil:
      return

    self.settings.setValue(LS_KEY_LOCAL_BACKUP_CHOSEN_PATH, newQVariant(value))
    self.localBackupChosenPathChanged()

  QtProperty[string] localBackupChosenPath:
    read = getLocalBackupChosenPath
    notify = localBackupChosenPathChanged

  proc removeKey*(self: LocalAccountSettings, key: string) =
    if(self.settings.isNil):
      return

    self.settings.remove(key)

    case key:
      of LS_KEY_STORE_TO_KEYCHAIN: self.storeToKeychainValueChanged()
      of LS_KEY_FRESH_PROFILE: self.freshProfileChanged()
      of LS_KEY_STAY_LOGGED_IN: self.stayLoggedInChanged()
      of LSS_KEY_CHAT_SPLIT_VIEW: self.chatSplitViewChanged()
      of LSS_KEY_WALLET_SPLIT_VIEW: self.walletSplitViewChanged()
      of LSS_KEY_PROFILE_SPLIT_VIEW: self.profileSplitViewChanged()
      of LSS_KEY_ENS_COMMUNITY_PERMISSIONS_ENABLED: self.ensCommunityPermissionsEnabledChanged()
      of LSS_KEY_IS_BROWSER_ENABLED: self.isBrowserEnabledChanged()
      of LSS_KEY_EXPAND_USERS_LIST: self.expandUsersListChanged()
      of LSS_KEY_NEVER_ASK_ABOUT_UNFURLING_AGAIN: self.neverAskAboutUnfurlingAgainChanged()
      of LSS_KEY_HIDE_CHANNEL_SUGGESTIONS: self.hideChannelSuggestionsChanged()
      of LSS_KEY_QUITE_ON_CLOSE: self.quitOnCloseChanged()
      of LSS_KEY_SHOW_DELETE_MESSAGE_WARNING: self.showDeleteMessageWarningChanged()
      of LSS_KEY_SHOW_DELETE_THREAD_WARNING: self.showDeleteThreadWarningChanged()
      of LSS_KEY_ACTIVE_SECTION: self.activeSectionChanged()
      of LSS_KEY_OPEN_LINKS_IN_STATUS: self.openLinksInStatusChanged()
      of LSS_KEY_SHOULD_SHOW_FAVORITES_BAR: self.shouldShowFavoritesBarChanged()
      of LSS_KEY_BROWSER_HOMEPAGE: self.browserHomepageChanged()
      of LSS_KEY_SHOULD_SHOW_BROWSER_SEARCH_ENGINE: self.selectedBrowserSearchEngineIdChanged()
      of LSS_KEY_CUSTOM_SEARCH_ENGINE_URL: self.customSearchEngineUrlChanged()
      of LSS_KEY_USE_BROWSER_ETHEREUM_EXPLORER: self.useBrowserEthereumExplorerChanged()
      of LSS_KEY_AUTO_LOAD_IMAGES: self.autoLoadImagesChanged()
      of LSS_KEY_JAVA_SCRIPT_ENABLED: self.javaScriptEnabledChanged()
      of LSS_KEY_ERROR_PAGE_ENABLED: self.errorPageEnabledChanged()
      of LSS_KEY_PLUGINS_ENABLED: self.pluginsEnabledChanged()
      of LSS_KEY_AUTO_LOAD_ICONS_FOR_PAGE: self.autoLoadIconsForPageChanged()
      of LSS_KEY_TOUCH_ICONS_ENABLED: self.touchIconsEnabledChanged()
      of LSS_KEY_WEB_RTC_PUBLIC_INTERFACES_ONLY: self.webRTCPublicInterfacesOnlyChanged()
      of LSS_KEY_DEV_TOOLS_ENABLED: self.devToolsEnabledChanged()
      of LSS_KEY_PDF_VIEWER_ENABLED: self.pdfViewerEnabledChanged()
      of LSS_KEY_STICKERS_ENS_ROPSTEN: self.stickersEnsRopstenChanged()
      of LSS_KEY_USER_DECLINED_BACKUP_BANNER: self.userDeclinedBackupBannerChanged()
      of LSS_KEY_GIF_UNFURLING_ENABLED: self.gifUnfurlingEnabledChanged()
      of LSS_KEY_COPY_MESSAGE_LINKS_ENABLED: self.copyMessageLinksEnabledChanged()

  proc notifyAll(self: LocalAccountSettings) =
    self.storeToKeychainValueChanged()
    self.freshProfileChanged()
    self.stayLoggedInChanged()
    self.chatSplitViewChanged()
    self.walletSplitViewChanged()
    self.profileSplitViewChanged()
    self.isBrowserEnabledChanged()
    self.ensCommunityPermissionsEnabledChanged()
    self.expandUsersListChanged()
    self.neverAskAboutUnfurlingAgainChanged()
    self.hideChannelSuggestionsChanged()
    self.quitOnCloseChanged()
    self.showDeleteMessageWarningChanged()
    self.showDeleteThreadWarningChanged()
    self.activeSectionChanged()
    self.openLinksInStatusChanged()
    self.shouldShowFavoritesBarChanged()
    self.browserHomepageChanged()
    self.selectedBrowserSearchEngineIdChanged()
    self.customSearchEngineUrlChanged()
    self.useBrowserEthereumExplorerChanged()
    self.autoLoadImagesChanged()
    self.javaScriptEnabledChanged()
    self.errorPageEnabledChanged()
    self.pluginsEnabledChanged()
    self.autoLoadIconsForPageChanged()
    self.touchIconsEnabledChanged()
    self.webRTCPublicInterfacesOnlyChanged()
    self.devToolsEnabledChanged()
    self.pdfViewerEnabledChanged()
    self.stickersEnsRopstenChanged()
    self.userDeclinedBackupBannerChanged()
    self.gifUnfurlingEnabledChanged()
    self.copyMessageLinksEnabledChanged()
    self.localBackupChosenPathChanged()

  proc setup(self: LocalAccountSettings, settingsFileDir: string) =
    self.QObject.setup
    self.settingsFileDir = settingsFileDir

  proc delete*(self: LocalAccountSettings) =
    self.QObject.delete
