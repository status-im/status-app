## LocalAccountSettings: the fresh-profile flag is written once at profile
## creation and read back from the per-account ini across restarts.

import unittest, os, nimqml
import app/global/local_account_settings

suite "LocalAccountSettings fresh profile":

  let dir = getTempDir() / "local_account_settings_test"

  setup:
    removeDir(dir)
    createDir(dir)

  teardown:
    removeDir(dir)

  test "no key reads as an established profile":
    let s = newLocalAccountSettings(dir)
    s.setFileName("alice")
    check not s.isFreshProfile()

  test "no file bound reads as an established profile":
    let s = newLocalAccountSettings(dir)
    check not s.isFreshProfile()

  test "markProfileFresh is visible immediately and after reopening the file":
    block:
      let s = newLocalAccountSettings(dir)
      s.setFileName("alice")
      s.markProfileFresh()
      check s.isFreshProfile()

    block:
      let s = newLocalAccountSettings(dir)
      s.setFileName("alice")
      check s.isFreshProfile()

  test "flag is per account file":
    block:
      let s = newLocalAccountSettings(dir)
      s.setFileName("alice")
      s.markProfileFresh()

    let other = newLocalAccountSettings(dir)
    other.setFileName("bob")
    check not other.isFreshProfile()

suite "LocalAccountSettings detach on logout":

  let dir = getTempDir() / "local_account_settings_detach_test"

  setup:
    removeDir(dir)
    createDir(dir)

  teardown:
    removeDir(dir)

  test "logging out of A and into B keeps A's file and gives B its own":
    let s = newLocalAccountSettings(dir)
    s.setFileName("alice")
    s.markProfileFresh()
    s.setStoreToKeychainValue(LS_VALUE_STORE)

    s.detach()  # flushes alice's pending writes
    check fileExists(dir / "alice")
    check not s.isFreshProfile()

    s.setFileName("bob")
    check fileExists(dir / "alice")
    check not s.isFreshProfile()
    check s.getStoreToKeychainValue() != LS_VALUE_STORE

    s.detach()
    s.setFileName("alice")
    check s.isFreshProfile()
    check s.getStoreToKeychainValue() == LS_VALUE_STORE

  test "renaming the bound account still moves its file":
    let s = newLocalAccountSettings(dir)
    s.setFileName("alice")
    s.markProfileFresh()
    s.setFileName("alice2")
    check not fileExists(dir / "alice")
    check s.isFreshProfile()
