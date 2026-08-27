import nimqml, os
import app/global/qt_settings

import ../../constants

# Local Account Settings keys:
const LS_KEY_STORE_TO_KEYCHAIN* = "storeToKeychain"
const LS_KEY_FRESH_PROFILE* = "freshProfile"
const DEFAULT_STORE_TO_KEYCHAIN = "notNow"
const LS_KEY_STAY_LOGGED_IN* = "stayLoggedIn"
# Local Account Settings values:
const LS_VALUE_STORE* = "store"
const LS_VALUE_NOT_NOW* = "notNow"
const LS_VALUE_NEVER* = "never"

QtObject:
  type LocalAccountSettings* = ref object of QObject
    settingsFileDir: string
    currentFileName: string
    settings: QSettings

  proc setup(self: LocalAccountSettings, settingsFileDir: string)
  proc delete*(self: LocalAccountSettings)

  proc newLocalAccountSettings*(settingsFileDir = os.joinPath(DATADIR, "qt")):
    LocalAccountSettings =
    new(result, delete)
    result.setup(settingsFileDir)

  proc setFileName*(self: LocalAccountSettings, fileName: string) =
    let
      currentFilePath = os.joinPath(self.settingsFileDir, self.currentFileName)
      newFilePath = os.joinPath(self.settingsFileDir, fileName)
    try:
      if self.currentFileName.len > 0 and currentFilePath != newFilePath:
        moveFile(currentFilePath, newFilePath)
    except OSError:
      discard
    self.currentFileName = fileName
    self.settings = newQSettings(newFilePath, QSettingsFormat.IniFormat)

  proc storeToKeychainValueChanged*(self: LocalAccountSettings) {.signal.}

  proc stayLoggedInChanged*(self: LocalAccountSettings) {.signal.}

  proc removeKey*(self: LocalAccountSettings, key: string) =
    if self.settings.isNil:
      return
    self.settings.remove(key)
    if key == LS_KEY_STORE_TO_KEYCHAIN:
      self.storeToKeychainValueChanged()
    elif key == LS_KEY_STAY_LOGGED_IN:
      self.stayLoggedInChanged()

  proc getStoreToKeychainValue*(self: LocalAccountSettings): string {.slot.} =
    if self.settings.isNil or TEST_MODE_ENABLED:
      return DEFAULT_STORE_TO_KEYCHAIN

    self.settings.value(LS_KEY_STORE_TO_KEYCHAIN).stringVal

  proc setStoreToKeychainValue*(self: LocalAccountSettings, value: string) {.slot.} =
    if(self.settings.isNil):
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

  # "Stay logged in" preference (per profile — this settings file is per account).
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

  proc setup(self: LocalAccountSettings, settingsFileDir: string) =
    self.QObject.setup
    self.settingsFileDir = settingsFileDir

  proc delete*(self: LocalAccountSettings) =
    self.QObject.delete