## LocalAccountSettings: the per-profile settings file `qt/<keyUid>`, its binding, and the
## one-time merge of the two legacy files (`qt/<display name>`, `qt/<public key>`).

import unittest, os, strutils, nimqml
from std/tempfiles import createTempDir
import app/global/local_account_settings
import app/global/local_app_settings
import app/global/qt_settings

const
  aliceUid = "0xa11ce"
  bobUid = "0xb0b"
  alicePubKey = "0x04a11ce"

proc writeIni(path: string, values: openArray[(string, QVariant)]) =
  let file = newQSettings(path, QSettingsFormat.IniFormat)
  for (key, value) in values:
    file.setValue(key, value)
  file.sync()

proc readIni(path: string, key: string): QVariant =
  newQSettings(path, QSettingsFormat.IniFormat).value(key)

proc hasIniKey(path: string, key: string): bool =
  newQSettings(path, QSettingsFormat.IniFormat).contains(key)

suite "Last section thread record":
  test "parses a selected thread record":
    let record = parseLastSectionThread(
      """{"threadId":"thread-1","parentChatId":"chat-1","presentation":"selectedChat"}""")

    check record.threadId == "thread-1"
    check record.parentChatId == "chat-1"
    check record.presentation == THREAD_PRESENTATION_SELECTED_CHAT

  test "parses a side panel thread record":
    let record = parseLastSectionThread(
      """{"threadId":"thread-1","parentChatId":"chat-1","presentation":"sidePanel"}""")

    check record.threadId == "thread-1"
    check record.parentChatId == "chat-1"
    check record.presentation == THREAD_PRESENTATION_SIDE_PANEL

  test "rejects incomplete and malformed records":
    for value in [
      "",
      """{"threadId":"thread-1","parentChatId":"chat-1"}""",
      """{"threadId":"","parentChatId":"chat-1","presentation":"sidePanel"}""",
      """{"threadId":"thread-1","parentChatId":"chat-1","presentation":"other"}""",
      "not-json",
    ]:
      let record = parseLastSectionThread(value)
      check record.threadId == ""
      check record.parentChatId == ""
      check record.presentation == ""

suite "LocalAccountSettings binding":
  var dir: string

  setup:
    dir = createTempDir("local_account_settings_bind_", "")

  teardown:
    removeDir(dir)

  test "nothing bound serves defaults and ignores writes":
    let s = newLocalAccountSettings(dir)
    check not s.isFreshProfile()
    check s.getExpandUsersList()
    s.setExpandUsersList(false)
    check s.getExpandUsersList()

  test "the profile's file is named by its keyUid and survives reopening":
    block:
      let s = newLocalAccountSettings(dir)
      s.bindAccount(aliceUid)
      s.markProfileFresh()
      s.setExpandUsersList(false)
      s.flush()
    check fileExists(dir / aliceUid)

    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    check s.isFreshProfile()
    check not s.getExpandUsersList()

  test "binding another profile serves that profile's values":
    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    s.markProfileFresh()
    s.setStoreToKeychainValue(LS_VALUE_STORE)

    s.bindAccount(bobUid)
    check not s.isFreshProfile()
    check s.getStoreToKeychainValue() != LS_VALUE_STORE

    s.bindAccount(aliceUid)
    check s.isFreshProfile()
    check s.getStoreToKeychainValue() == LS_VALUE_STORE

  test "binding the bound profile again keeps it":
    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    s.setExpandUsersList(false)
    s.bindAccount(aliceUid)
    check not s.getExpandUsersList()

  test "flush keeps the profile bound (logout)":
    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    s.setExpandUsersList(false)
    s.flush()
    check not s.getExpandUsersList()
    check not readIni(dir / aliceUid, LSS_KEY_EXPAND_USERS_LIST).boolVal

  test "detach serves defaults until a profile is bound (new profile)":
    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    s.setExpandUsersList(false)
    s.detach()
    check s.getExpandUsersList()

    s.bindAccount(aliceUid)
    check not s.getExpandUsersList()

suite "LocalAccountSettings display-name file merge":
  var dir: string

  setup:
    dir = createTempDir("local_account_settings_name_", "")

  teardown:
    removeDir(dir)

  test "ports the profile's keys and removes the file":
    writeIni(dir / "Alice", {
      LS_KEY_STORE_TO_KEYCHAIN: newQVariant(LS_VALUE_STORE),
      LS_KEY_FRESH_PROFILE: newQVariant(true),
      LS_KEY_STAY_LOGGED_IN & "/" & aliceUid: newQVariant(true),
      LS_KEY_STAY_LOGGED_IN & "/" & bobUid: newQVariant(false),
    })

    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid, "Alice")

    check s.isFreshProfile()
    check readIni(dir / aliceUid, LS_KEY_STORE_TO_KEYCHAIN).stringVal == LS_VALUE_STORE
    check readIni(dir / aliceUid, LS_KEY_STAY_LOGGED_IN).boolVal
    check not hasIniKey(dir / aliceUid, LS_KEY_STAY_LOGGED_IN & "/" & bobUid)
    check hasIniKey(dir / aliceUid, LS_KEY_DISPLAY_NAME_FILE_MERGED)
    check not fileExists(dir / "Alice")

  test "each profile of a shared name takes the file's keys; it stays until all merged":
    writeIni(dir / "Sam", {
      LS_KEY_STORE_TO_KEYCHAIN: newQVariant(LS_VALUE_STORE),
      LS_KEY_STAY_LOGGED_IN & "/" & aliceUid: newQVariant(true),
      LS_KEY_STAY_LOGGED_IN & "/" & bobUid: newQVariant(false),
    })

    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid, "Sam", @[(bobUid, "Sam")])
    check s.getStoreToKeychainValue() == LS_VALUE_STORE
    check readIni(dir / aliceUid, LS_KEY_STAY_LOGGED_IN).boolVal
    check fileExists(dir / "Sam")

    s.bindAccount(bobUid, "Sam", @[(aliceUid, "Sam")])
    check s.getStoreToKeychainValue() == LS_VALUE_STORE
    check not readIni(dir / bobUid, LS_KEY_STAY_LOGGED_IN).boolVal
    check not fileExists(dir / "Sam")

  test "a profile new on this device takes nothing from a file of its name":
    writeIni(dir / "Alice", {LS_KEY_STORE_TO_KEYCHAIN: newQVariant(LS_VALUE_STORE)})

    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    s.markNewOnDevice()
    s.bindAccount(bobUid)
    s.bindAccount(aliceUid, "Alice")
    check not hasIniKey(dir / aliceUid, LS_KEY_STORE_TO_KEYCHAIN)
    check hasIniKey(dir / aliceUid, LS_KEY_DISPLAY_NAME_FILE_MERGED)
    check fileExists(dir / "Alice")

  test "merges once and never overwrites the profile's own values":
    writeIni(dir / aliceUid, {LS_KEY_STORE_TO_KEYCHAIN: newQVariant(LS_VALUE_NEVER)})
    writeIni(dir / "Alice", {LS_KEY_STORE_TO_KEYCHAIN: newQVariant(LS_VALUE_STORE)})

    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid, "Alice")
    check readIni(dir / aliceUid, LS_KEY_STORE_TO_KEYCHAIN).stringVal == LS_VALUE_NEVER

    writeIni(dir / "Alice", {LS_KEY_FRESH_PROFILE: newQVariant(true)})
    s.bindAccount(bobUid)
    s.bindAccount(aliceUid, "Alice")
    check not s.isFreshProfile()
    check fileExists(dir / "Alice")

  test "a marker that failed to save is not kept for a later save":
    writeIni(dir / "Alice", {LS_KEY_STORE_TO_KEYCHAIN: newQVariant(LS_VALUE_STORE)})
    let s = newLocalAccountSettings(dir)
    setFilePermissions(dir, {fpUserRead, fpUserExec})
    s.bindAccount(aliceUid, "Alice")
    setFilePermissions(dir, {fpUserRead, fpUserWrite, fpUserExec})
    s.setExpandUsersList(false)
    check not hasIniKey(dir / aliceUid, LS_KEY_DISPLAY_NAME_FILE_MERGED)
    check fileExists(dir / "Alice")

  test "a missing file still marks the merge done":
    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid, "Alice")
    check hasIniKey(dir / aliceUid, LS_KEY_DISPLAY_NAME_FILE_MERGED)

  test "never removes the app settings file a profile named \"global\" shared":
    writeIni(dir / APP_SETTINGS_FILE_NAME, {LS_KEY_FRESH_PROFILE: newQVariant(true)})

    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid, APP_SETTINGS_FILE_NAME)
    check s.isFreshProfile()
    check fileExists(dir / APP_SETTINGS_FILE_NAME)

  test "never removes the app settings file through a case variant of its name":
    writeIni(dir / APP_SETTINGS_FILE_NAME, {LS_KEY_FRESH_PROFILE: newQVariant(true)})

    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid, "Global")
    check fileExists(dir / APP_SETTINGS_FILE_NAME)

  test "names the file system maps to one file share it":
    writeIni(dir / "Sam", {LS_KEY_STAY_LOGGED_IN & "/" & bobUid: newQVariant(true)})
    if not fileExists(dir / "sam"):
      skip() # case-sensitive file system: "sam" is another file
    else:
      let s = newLocalAccountSettings(dir)
      s.bindAccount(aliceUid, "Sam", @[(bobUid, "sam")])
      check fileExists(dir / "Sam")

      s.bindAccount(bobUid, "sam", @[(aliceUid, "Sam")])
      check readIni(dir / bobUid, LS_KEY_STAY_LOGGED_IN).boolVal
      check not fileExists(dir / "Sam")

  test "a name the file system maps to the profile's own file is not a legacy file":
    writeIni(dir / aliceUid, {LS_KEY_FRESH_PROFILE: newQVariant(true)})
    if not fileExists(dir / aliceUid.toUpperAscii()):
      skip() # case-sensitive file system: another file
    else:
      let s = newLocalAccountSettings(dir)
      s.bindAccount(aliceUid, aliceUid.toUpperAscii())
      check fileExists(dir / aliceUid)
      check s.isFreshProfile()

  test "never reads a file outside the settings directory":
    writeIni(dir / "outside", {LS_KEY_FRESH_PROFILE: newQVariant(true)})
    let settingsDir = dir / "qt"
    createDir(settingsDir)
    let s = newLocalAccountSettings(settingsDir)
    s.bindAccount(aliceUid, "../outside")
    check not s.isFreshProfile()
    check hasIniKey(settingsDir / aliceUid, LS_KEY_DISPLAY_NAME_FILE_MERGED)
    check fileExists(dir / "outside")

suite "LocalAccountSettings public-key file merge":
  var dir: string

  setup:
    dir = createTempDir("local_account_settings_pubkey_", "")

  teardown:
    removeDir(dir)

  test "moves every key, groups included, and removes the file":
    writeIni(dir / alicePubKey, {
      LSS_KEY_EXPAND_USERS_LIST: newQVariant(false),
      LSS_KEY_ACTIVE_SECTION: newQVariant("wallet"),
      "LastSectionChat/community-1": newQVariant("chat-1"),
    })

    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    s.mergeLegacyPublicKeyFile(alicePubKey)

    check not s.getExpandUsersList()
    check s.getActiveSection() == "wallet"
    check s.getSectionLastOpenChat("community-1") == "chat-1"
    check hasIniKey(dir / aliceUid, LS_KEY_PUBLIC_KEY_FILE_MERGED)
    check not fileExists(dir / alicePubKey)

  test "keeps the values already in the profile's file":
    writeIni(dir / alicePubKey, {
      LSS_KEY_ACTIVE_SECTION: newQVariant("wallet"),
      LSS_KEY_EXPAND_USERS_LIST: newQVariant(false),
    })

    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    s.setActiveSection("chat")
    s.mergeLegacyPublicKeyFile(alicePubKey)

    check s.getActiveSection() == "chat"
    check not s.getExpandUsersList()

  test "merges once":
    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    s.mergeLegacyPublicKeyFile(alicePubKey)
    check hasIniKey(dir / aliceUid, LS_KEY_PUBLIC_KEY_FILE_MERGED)

    writeIni(dir / alicePubKey, {LSS_KEY_ACTIVE_SECTION: newQVariant("wallet")})
    s.mergeLegacyPublicKeyFile(alicePubKey)
    check s.getActiveSection() == ""
    check fileExists(dir / alicePubKey)

  test "a profile new on this device removes the file without taking its values":
    writeIni(dir / alicePubKey, {LSS_KEY_ACTIVE_SECTION: newQVariant("wallet")})
    let s = newLocalAccountSettings(dir)
    s.bindAccount(aliceUid)
    s.markNewOnDevice()
    s.mergeLegacyPublicKeyFile(alicePubKey)
    check s.getActiveSection() == ""
    check hasIniKey(dir / aliceUid, LS_KEY_PUBLIC_KEY_FILE_MERGED)
    check not fileExists(dir / alicePubKey)

  test "does nothing while no profile is bound":
    writeIni(dir / alicePubKey, {LSS_KEY_ACTIVE_SECTION: newQVariant("wallet")})
    let s = newLocalAccountSettings(dir)
    s.mergeLegacyPublicKeyFile(alicePubKey)
    check fileExists(dir / alicePubKey)
