import nimqml, strutils, os

import constants

# Local App Settings keys:
const LAS_KEY_LANGUAGE* = "global/language"
const DEFAULT_LAS_KEY_LANGUAGE* = "en"
const LAS_KEY_GEOMETRY = "global/app_geometry"
const LAS_KEY_VISIBILITY = "global/app_visibility"
const LAS_KEY_SCROLL_VELOCITY = "global/scroll_velocity"
const LAS_KEY_SCROLL_DECELERATION = "global/scroll_deceleration"
const DEFAULT_SCROLL_VELOCITY = 0 # unset
const DEFAULT_SCROLL_DECELERATION = 0 # unset
const LAS_KEY_CUSTOM_MOUSE_SCROLLING_ENABLED = "global/custom_mouse_scroll_enabled"
const DEFAULT_CUSTOM_MOUSE_SCROLLING_ENABLED = false
const LAS_KEY_TRANSLATIONS_ENABLED = "global/translations_enabled"
const DEFAULT_LAS_KEY_TRANSLATIONS_ENABLED = true
const LAS_KEY_REFRESH_TOKEN_ENABLED = "global/refresh_token_enabled"
const LAS_KEY_METRICS_POPUP_SEEN = "global/metrics_popup_seen"
const DEFAULT_LAS_KEY_METRICS_POPUP_SEEN = false
const LS_KEY_SEEN_NETWORK_CHAINS = "global/seenNetworkChains"
const DEFAULT_SEEN_NETWORK_CHAINS = "[]"
const LAS_KEY_SELECTED_PROFILE_KEY_UID = "global/selected_profile_key_uid"

when constants.IS_MOBILE:
  const DEFAULT_VISIBILITY = 4 #maximized visibility, from qml
else:
  const DEFAULT_VISIBILITY = 2 #windowed visibility, from qml

QtObject:
  type LocalAppSettings* = ref object of QObject
    settings: QSettings

  proc setup(self: LocalAppSettings)
  proc delete*(self: LocalAppSettings)
  proc newLocalAppSettings*(fileName: string): LocalAppSettings =
    new(result, delete)
    result.setup
    let filePath = os.joinPath(DATADIR, "qt", fileName)
    result.settings = newQSettings(filePath, QSettingsFormat.IniFormat)

  proc setup(self: LocalAppSettings) =
    self.QObject.setup

  proc delete*(self: LocalAppSettings) =
    self.QObject.delete

  proc languageChanged*(self: LocalAppSettings) {.signal.}
  proc getLanguage*(self: LocalAppSettings): string {.slot.} =
    self.settings.value(LAS_KEY_LANGUAGE).stringVal
  proc setLanguage*(self: LocalAppSettings, value: string) {.slot.} =
    self.settings.setValue(LAS_KEY_LANGUAGE, newQVariant(value))
    self.languageChanged()

  QtProperty[string] language:
    read = getLanguage
    write = setLanguage
    notify = languageChanged


  proc geometryChanged*(self: LocalAppSettings) {.signal.}
  proc getGeometry*(self: LocalAppSettings): QVariant {.slot.} =
    self.settings.value(LAS_KEY_GEOMETRY)
  proc setGeometry*(self: LocalAppSettings, value: QVariant) {.slot.} =
    self.settings.setValue(LAS_KEY_GEOMETRY, newQVariant(value))
    self.geometryChanged()

  QtProperty[QVariant] geometry:
    read = getGeometry
    write = setGeometry
    notify = geometryChanged


  proc visibilityChanged*(self: LocalAppSettings) {.signal.}
  proc getVisibility*(self: LocalAppSettings): int {.slot.} =
    self.settings.value(LAS_KEY_VISIBILITY, newQVariant(DEFAULT_VISIBILITY)).intVal
  proc setVisibility*(self: LocalAppSettings, value: int) {.slot.} =
    self.settings.setValue(LAS_KEY_VISIBILITY, newQVariant(value))
    self.visibilityChanged()

  QtProperty[int] visibility:
    read = getVisibility
    write = setVisibility
    notify = visibilityChanged

  proc isCustomMouseScrollingEnabledChanged*(self: LocalAppSettings) {.signal.}
  proc getCustomMouseScrollingEnabled*(self: LocalAppSettings): bool {.slot.} =
    self.settings.value(LAS_KEY_CUSTOM_MOUSE_SCROLLING_ENABLED, newQVariant(DEFAULT_CUSTOM_MOUSE_SCROLLING_ENABLED)).boolVal
  proc setCustomMouseScrollingEnabled*(self: LocalAppSettings, value: bool) {.slot.} =
    self.settings.setValue(LAS_KEY_CUSTOM_MOUSE_SCROLLING_ENABLED, newQVariant(value))
    self.isCustomMouseScrollingEnabledChanged()

  QtProperty[bool] isCustomMouseScrollingEnabled:
    read = getCustomMouseScrollingEnabled
    write = setCustomMouseScrollingEnabled
    notify = isCustomMouseScrollingEnabledChanged

  proc scrollVelocityChanged*(self: LocalAppSettings) {.signal.}
  proc getScrollVelocity*(self: LocalAppSettings): int {.slot.} =
    self.settings.value(LAS_KEY_SCROLL_VELOCITY, newQVariant(DEFAULT_SCROLL_VELOCITY)).intVal
  proc setScrollVelocity*(self: LocalAppSettings, value: int) {.slot.} =
    self.settings.setValue(LAS_KEY_SCROLL_VELOCITY, newQVariant(value))
    self.scrollVelocityChanged()

  QtProperty[int] scrollVelocity:
    read = getScrollVelocity
    write = setScrollVelocity
    notify = scrollVelocityChanged

  proc scrollDecelerationChanged*(self: LocalAppSettings) {.signal.}
  proc getScrollDeceleration*(self: LocalAppSettings): int {.slot.} =
    self.settings.value(LAS_KEY_SCROLL_DECELERATION, newQVariant(DEFAULT_SCROLL_DECELERATION)).intVal
  proc setScrollDeceleration*(self: LocalAppSettings, value: int) {.slot.} =
    self.settings.setValue(LAS_KEY_SCROLL_DECELERATION, newQVariant(value))
    self.scrollDecelerationChanged()

  QtProperty[int] scrollDeceleration:
    read = getScrollDeceleration
    write = setScrollDeceleration
    notify = scrollDecelerationChanged

  proc getTestEnvironment*(self: LocalAppSettings): bool {.slot.} =
    return TEST_MODE_ENABLED

  QtProperty[bool] testEnvironment:
    read = getTestEnvironment

  proc displayMockedKeycardWindow*(self: LocalAppSettings): bool {.slot.} =
    return DISPLAY_MOCKED_KEYCARD_WINDOW

  proc refreshTokenEnabledChanged*(self: LocalAppSettings) {.signal.}
  proc getRefreshTokenEnabled*(self: LocalAppSettings): bool {.slot.} =
    self.settings.value(LAS_KEY_REFRESH_TOKEN_ENABLED, newQVariant(false)).boolVal
  proc setRefreshTokenEnabled*(self: LocalAppSettings, enabled: bool) {.slot.} =
    self.settings.setValue(LAS_KEY_REFRESH_TOKEN_ENABLED, newQVariant(enabled))
    self.refreshTokenEnabledChanged()

  QtProperty[bool] refreshTokenEnabled:
    read = getRefreshTokenEnabled
    write = setRefreshTokenEnabled
    notify = refreshTokenEnabledChanged

  proc translationsEnabledChanged*(self: LocalAppSettings) {.signal.}
  proc getTranslationsEnabled*(self: LocalAppSettings): bool {.slot.} =
    self.settings.value(LAS_KEY_TRANSLATIONS_ENABLED, newQVariant(DEFAULT_LAS_KEY_TRANSLATIONS_ENABLED)).boolVal
  proc setTranslationsEnabled*(self: LocalAppSettings, value: bool) {.slot.} =
    if value == self.getTranslationsEnabled:
      return
    self.settings.setValue(LAS_KEY_TRANSLATIONS_ENABLED, newQVariant(value))
    self.translationsEnabledChanged()

  QtProperty[bool] translationsEnabled:
    read = getTranslationsEnabled
    write = setTranslationsEnabled
    notify = translationsEnabledChanged

  proc removeKey*(self: LocalAppSettings, key: string) =
    if(self.settings.isNil):
      return

    self.settings.remove(key)

    case key:
      of LAS_KEY_LANGUAGE: self.languageChanged()
      of LAS_KEY_GEOMETRY: self.geometryChanged()
      of LAS_KEY_VISIBILITY: self.visibilityChanged()
      of LAS_KEY_SCROLL_VELOCITY: self.scrollVelocityChanged()
      of LAS_KEY_SCROLL_DECELERATION: self.scrollDecelerationChanged()
      of LAS_KEY_CUSTOM_MOUSE_SCROLLING_ENABLED: self.isCustomMouseScrollingEnabledChanged()
      of LAS_KEY_TRANSLATIONS_ENABLED: self.translationsEnabledChanged()

  proc getWalletConnectProjectID*(self: LocalAppSettings): string {.slot.} =
    return constants.WALLET_CONNECT_PROJECT_ID

  QtProperty[string] walletConnectProjectID:
    read = getWalletConnectProjectID


  proc refreshMetricsPopupSeen*(self: LocalAppSettings) {.signal.}
  proc getMetricsPopupSeen*(self: LocalAppSettings): bool {.slot.} =
    self.settings.value(LAS_KEY_METRICS_POPUP_SEEN, newQVariant(DEFAULT_LAS_KEY_METRICS_POPUP_SEEN)).boolVal
  proc setMetricsPopupSeen*(self: LocalAppSettings, enabled: bool) {.slot.} =
    self.settings.setValue(LAS_KEY_METRICS_POPUP_SEEN, newQVariant(enabled))
    self.refreshMetricsPopupSeen()

  QtProperty[bool] metricsPopupSeen:
    read = getMetricsPopupSeen
    write = setMetricsPopupSeen
    notify = refreshMetricsPopupSeen

  proc seenNetworkChainsChanged*(self: LocalAppSettings) {.signal.}

  proc getSeenNetworkChains*(self: LocalAppSettings): string {.slot.} =
    if self.settings.isNil:
      return DEFAULT_SEEN_NETWORK_CHAINS

    return self.settings.value(LS_KEY_SEEN_NETWORK_CHAINS, newQVariant(DEFAULT_SEEN_NETWORK_CHAINS)).stringVal

  proc setSeenNetworkChains*(self: LocalAppSettings, value: string) {.slot.} =
    if self.settings.isNil or self.getSeenNetworkChains() == value:
      return

    self.settings.setValue(LS_KEY_SEEN_NETWORK_CHAINS, newQVariant(value))
    self.seenNetworkChainsChanged()

  QtProperty[string] seenNetworkChains:
    read = getSeenNetworkChains
    write = setSeenNetworkChains
    notify = seenNetworkChainsChanged

  proc selectedProfileKeyUidChanged*(self: LocalAppSettings) {.signal.}
  proc getSelectedProfileKeyUid*(self: LocalAppSettings): string {.slot.} =
    self.settings.value(LAS_KEY_SELECTED_PROFILE_KEY_UID).stringVal
  proc setSelectedProfileKeyUid*(self: LocalAppSettings, value: string) {.slot.} =
    self.settings.setValue(LAS_KEY_SELECTED_PROFILE_KEY_UID, newQVariant(value))
    self.selectedProfileKeyUidChanged()

  QtProperty[string] selectedProfileKeyUid:
    read = getSelectedProfileKeyUid
    write = setSelectedProfileKeyUid
    notify = selectedProfileKeyUidChanged