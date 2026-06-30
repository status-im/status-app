## Test for the seaqt-backed QSettings wrapper (app/global/qt_settings).
##
## Exercises round-trip read/write of string and int values via nimqml QVariant
## bridges:  nimqml QVariant  →  .seaqt  (borrowed seaqt QVariant)  →  stored
##           seaqt QVariant   →  newQVariant(...)  (cloned nimqml QVariant)  →  read back

import unittest, os, nimqml
import app/global/qt_settings

suite "seaqt QSettings wrapper":

  let tmpFile = getTempDir() / "qsettings_test_seaqt.ini"

  setup:
    # Remove stale file from previous run
    if fileExists(tmpFile):
      removeFile(tmpFile)

  teardown:
    if fileExists(tmpFile):
      removeFile(tmpFile)

  test "round-trip string value via IniFormat":
    block:
      let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
      s.setValue("greeting", newQVariant("hello seaqt"))

    block:
      let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
      let v = s.value("greeting")
      check v.stringVal == "hello seaqt"

  test "round-trip int value via IniFormat":
    block:
      let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
      s.setValue("answer", newQVariant(42))

    block:
      let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
      let v = s.value("answer")
      check v.intVal == 42

  test "value with defaultValue returned when key absent":
    let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
    let v = s.value("nonexistent", newQVariant("default"))
    check v.stringVal == "default"

  test "remove deletes a previously stored key":
    block:
      let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
      s.setValue("temp", newQVariant("to be removed"))

    block:
      let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
      s.remove("temp")

    block:
      let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
      let v = s.value("temp", newQVariant("gone"))
      check v.stringVal == "gone"

  test "beginGroup / endGroup scopes key lookup":
    block:
      let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
      s.beginGroup("mygroup")
      s.setValue("key", newQVariant("grouped"))
      s.endGroup()

    block:
      let s = newQSettings(tmpFile, QSettingsFormat.IniFormat)
      s.beginGroup("mygroup")
      let v = s.value("key")
      s.endGroup()
      check v.stringVal == "grouped"
