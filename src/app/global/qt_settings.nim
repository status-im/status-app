## Thin wrapper around seaqt QSettings exposing the same public API that
## the three caller modules (local_account_settings, local_account_sensitive_settings,
## local_app_settings) previously obtained from dotherside_ext.
##
## Callers only need to add:
##   import app/global/qt_settings
## The public types QSettings / QSettingsFormat and all procs are identical.

import nimqml  # for nimqml QVariant + the .seaqt / newQVariant(seaqt) bridges

# Import seaqt QSettings impl under a module alias so all seaqt QSettings procs
# (create, value, setValue, remove, beginGroup, endGroup) are called via sqset.X.
# This avoids any name clash between seaqt's QSettings type and our own wrapper below.
import seaqt/QtCore/gen_qsettings as sqset

type
  QSettingsFormat* {.pure.} = enum
    ## Mirrors Qt::QSettings::Format (the two values callers actually use).
    NativeFormat = 0
    IniFormat = 1

  QSettings* = ref object
    ## Wrapper around a seaqt-backed QSettings instance.
    ## The inner seaqt QSettings is a move-only value with automatic =destroy.
    inner: sqset.QSettings

proc newQSettings*(fileName: string,
    format: QSettingsFormat = QSettingsFormat.NativeFormat): QSettings =
  new(result)
  result.inner = sqset.QSettings.create(fileName, cint(format.int))

proc value*(self: QSettings, key: string,
    defaultValue: nimqml.QVariant = newQVariant()): nimqml.QVariant =
  ## Returns the setting value for key, or defaultValue when absent.
  let seaqtDefault = defaultValue.seaqt   # nimqml QVariant → seaqt QVariant (borrowed)
  let seaqtResult  = sqset.value(self.inner, key, seaqtDefault)
  newQVariant(seaqtResult)                # seaqt QVariant → nimqml QVariant (cloned)

proc setValue*(self: QSettings, key: string, value: nimqml.QVariant) =
  ## Stores value under key.
  sqset.setValue(self.inner, key, value.seaqt)

proc remove*(self: QSettings, key: string) =
  sqset.remove(self.inner, key)

proc beginGroup*(self: QSettings, group: string) =
  sqset.beginGroup(self.inner, group)

proc endGroup*(self: QSettings) =
  sqset.endGroup(self.inner)

proc delete*(self: QSettings) =
  ## API-compatibility shim. Flush pending writes immediately — the C++ ~QSettings would
  ## sync on destruction, but the inner value is only freed later via =destroy (at GC).
  sqset.sync(self.inner)
