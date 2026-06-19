## DOtherSide wrapper for status-desktop.
##
## The binding layer migrated from the status-im `nimqml` fork to `nimqml-seaqt`.
## nimqml-seaqt provides the standard QObject/QML machinery (backed by seaqt's
## `notherside`, `nos_*` symbols). DOtherSide is kept building as a *utility*
## static library (`vendor/DOtherSide`) and this module declares the subset of its
## `dos_*` C API we still use plus the thin high-level procs/types on top — ported
## verbatim from the old fork's `dotherside.nim` + `status/*` + `qsettings/qtimer`
## modules.
##
## DOtherSide's `dos_*` and notherside's `nos_*` C symbols don't overlap, so the
## two coexist in one binary. We never call DOtherSide's app/QObject-creation
## entry points (nimqml-seaqt creates those), only its leaf utility functions, so
## its heavy machinery stays dormant. The QObject pointers handed to `dos_*` come
## from nimqml-seaqt QObjects (real `QObject*` via the `vptr` accessors added to
## nimqml-seaqt for this migration).
## 
## TODO: remove this and migrate to seaqt APIs or StatusQ

import nimqml

# DOtherSide library name. `--dynlibOverrideAll` (config.nims, macOS/Linux) makes
# these statically linked against libDOtherSideStatic.a; on Windows the DLL loads.
const dynLibName =
  when defined(windows): "DOtherSide.dll"
  elif defined(macosx): "libDOtherSide.dylib"
  else: "libDOtherSide.so.0.(9|8)"

type
  DosMessageHandler* = proc(messageType: cint, message: cstring, category: cstring,
    file: cstring, function: cstring, line: cint) {.cdecl.}

  QSettingsFormat* {.pure.} = enum
    NativeFormat = 0
    IniFormat

  # Custom QObjects (real QObjects created by DOtherSide; adopted as nimqml-seaqt
  # QObject subtypes so `newQVariant` works on them).
  SingleInstance* = ref object of QObject
  StatusEvent* = ref object of QObject
  StatusOSNotification* = ref object of QObject

  # Qt classes nimqml-seaqt does not provide.
  QSettings* = ref object of QObject
  QTimer* = ref object of QObject
  QNetworkAccessManagerFactory* = ref object of RootObj
    vptr: pointer

# --- DOtherSide C API (only what status still uses) --------------------------
# QObject pointers are passed as raw `pointer` (a real C++ `QObject*`).
proc dos_chararray_delete(str: cstring) {.cdecl, dynlib: dynLibName, importc.}

proc dos_signal(vptr: pointer, signal: cstring, slot: cstring) {.cdecl, dynlib: dynLibName, importc.}

proc dos_plain_text(htmlString: cstring): cstring {.cdecl, dynlib: dynLibName, importc.}
proc dos_escape_html(input: cstring): cstring {.cdecl, dynlib: dynLibName, importc.}
proc dos_save_byte_image_to_file(imagePath: cstring): cstring {.cdecl, dynlib: dynLibName, importc.}

proc dos_app_is_active(engine: pointer): bool {.cdecl, dynlib: dynLibName, importc.}
proc dos_app_make_it_active(engine: pointer) {.cdecl, dynlib: dynLibName, importc.}

proc dos_add_self_signed_certificate(content: cstring) {.cdecl, dynlib: dynLibName, importc.}
proc dos_installMessageHandler(handler: DosMessageHandler) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qguiapplication_enable_hdpi(uiScaleFilePath: cstring) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qtwebview_initialize() {.cdecl, dynlib: dynLibName, importc.}
proc dos_qguiapplication_try_enable_threaded_renderer() {.cdecl, dynlib: dynLibName, importc.}
proc dos_qguiapplication_installEventFilter(filter: pointer) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qguiapplication_exit() {.cdecl, dynlib: dynLibName, importc.}
proc dos_qguiapplication_icon(filename: cstring) {.cdecl, dynlib: dynLibName, importc.}

proc dos_qqmlnetworkaccessmanagerfactory_create(tmpPath: cstring): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_qqmlapplicationengine_setNetworkAccessManagerFactory(engine: pointer, factory: pointer) {.cdecl, dynlib: dynLibName, importc.}

proc dos_osnotification_create(): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_osnotification_show_notification(vptr: pointer, title, message, identifier: cstring) {.cdecl, dynlib: dynLibName, importc.}
proc dos_osnotification_show_badge_notification(vptr: pointer, notificationsCount: int) {.cdecl, dynlib: dynLibName, importc.}
proc dos_osnotification_delete(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}

proc dos_event_create_urlSchemeEvent(): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_event_delete(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}
proc dos_event_set_urlSchemeEvent_instance(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}

proc dos_singleinstance_create(uniqueName: cstring, eventStr: cstring): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_singleinstance_isfirst(vptr: pointer): bool {.cdecl, dynlib: dynLibName, importc.}
proc dos_singleinstance_delete(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}

proc dos_qsettings_create(fileName: cstring, format: int): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_qsettings_value(vptr: pointer, key: cstring, defaultValue: pointer): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_qsettings_set_value(vptr: pointer, key: cstring, value: pointer) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qsettings_remove(vptr: pointer, key: cstring) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qsettings_delete(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qsettings_begin_group(vptr: pointer, group: cstring) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qsettings_end_group(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}

proc dos_qtimer_create(): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_qtimer_delete(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qtimer_set_interval(vptr: pointer, interval: int) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qtimer_interval(vptr: pointer): int {.cdecl, dynlib: dynLibName, importc.}
proc dos_qtimer_start(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qtimer_stop(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qtimer_set_single_shot(vptr: pointer, singleShot: bool) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qtimer_is_single_shot(vptr: pointer): bool {.cdecl, dynlib: dynLibName, importc.}
proc dos_qtimer_is_active(vptr: pointer): bool {.cdecl, dynlib: dynLibName, importc.}

# --- High-level API (ported verbatim from the old nimqml fork) ---------------

proc signal_handler*(receiver: pointer, signal: cstring, slot: cstring) =
  if not receiver.isNil:
    dos_signal(receiver, signal, slot)

proc plain_text*(htmlString: string): string =
  let s = dos_plain_text(htmlString.cstring)
  defer: dos_chararray_delete(s)
  result = $s

proc escape_html*(input: string): string =
  let s = dos_escape_html(input.cstring)
  defer: dos_chararray_delete(s)
  result = $s

proc save_byte_image_to_file*(imagePath: string): string =
  let s = dos_save_byte_image_to_file(imagePath.cstring)
  defer: dos_chararray_delete(s)
  result = $s

proc app_isActive*(engine: QQmlApplicationEngine): bool =
  dos_app_is_active(engine.vptr)

proc app_makeItActive*(engine: QQmlApplicationEngine) =
  dos_app_make_it_active(engine.vptr)

# QGuiApplication extras
proc installSelfSignedCertificate*(certificate: string) =
  dos_add_self_signed_certificate(certificate.cstring)

proc installMessageHandler*(handler: DosMessageHandler) =
  dos_installMessageHandler(handler)

proc enableHDPI*(uiScaleFilePath: string) =
  dos_qguiapplication_enable_hdpi(uiScaleFilePath.cstring)

proc initializeWebView*() =
  dos_qtwebview_initialize()

proc tryEnableThreadedRenderer*() =
  dos_qguiapplication_try_enable_threaded_renderer()


# nimqml-seaqt wraps `quit` but not `exit`/`icon`. DOtherSide's impls act on the
# global qApp (== the seaqt-created application), so they are safe here.
proc exit*(self: QGuiApplication) =
  dos_qguiapplication_exit()

proc icon*(application: QGuiApplication, filename: string) =
  dos_qguiapplication_icon(filename.cstring)

# QNetworkAccessManagerFactory (custom disk-cache factory)
proc delete*(self: QNetworkAccessManagerFactory)

proc newQNetworkAccessManagerFactory*(tmpPath: string): QNetworkAccessManagerFactory =
  new(result, delete)
  result.vptr = dos_qqmlnetworkaccessmanagerfactory_create(tmpPath.cstring)

proc delete*(self: QNetworkAccessManagerFactory) =
  self.vptr = nil

proc setNetworkAccessManagerFactory*(self: QQmlApplicationEngine,
    factory: QNetworkAccessManagerFactory) =
  dos_qqmlapplicationengine_setNetworkAccessManagerFactory(self.vptr, factory.vptr)

# OSNotification
proc delete*(self: StatusOSNotification)

proc newStatusOSNotification*(): StatusOSNotification =
  new(result, delete)
  result.vptr = dos_osnotification_create()

proc delete*(self: StatusOSNotification) =
  dos_osnotification_delete(self.vptr)
  self.vptr = nil

proc showNotification*(self: StatusOSNotification, title: string, message: string,
    identifier: string) =
  dos_osnotification_show_notification(self.vptr, title.cstring, message.cstring,
    identifier.cstring)

proc showIconBadgeNotification*(self: StatusOSNotification, notificationsCount: int) =
  dos_osnotification_show_badge_notification(self.vptr, notificationsCount)

# UrlSchemeEvent (deep links)
proc delete*(self: StatusEvent)

proc newStatusUrlSchemeEventObject*(): StatusEvent =
  new(result, delete)
  result.vptr = dos_event_create_urlSchemeEvent()

proc delete*(self: StatusEvent) =
  dos_event_delete(self.vptr)
  self.vptr = nil

proc setInstance*(self: StatusEvent) =
  dos_event_set_urlSchemeEvent_instance(self.vptr)

proc installEventFilter*(application: QGuiApplication, event: StatusEvent) =
  dos_qguiapplication_installEventFilter(event.vptr)

# SingleInstance
proc delete*(self: SingleInstance)

proc newSingleInstance*(uniqueName: string, eventStr: string): SingleInstance =
  new(result, delete)
  result.vptr = dos_singleinstance_create(uniqueName.cstring, eventStr.cstring)

proc delete*(self: SingleInstance) =
  if self.vptr.isNil:
    return
  dos_singleinstance_delete(self.vptr)
  self.vptr = nil

proc secondInstance*(self: SingleInstance): bool =
  not dos_singleinstance_isfirst(self.vptr)

# QSettings
proc delete*(self: QSettings)

proc newQSettings*(fileName: string,
    format: QSettingsFormat = QSettingsFormat.NativeFormat): QSettings =
  new(result, delete)
  result.vptr = dos_qsettings_create(fileName.cstring, format.int)

proc delete*(self: QSettings) =
  dos_qsettings_delete(self.vptr)
  self.vptr = nil

proc value*(self: QSettings, key: string, defaultValue: QVariant = newQVariant()): QVariant =
  newQVariantTakingPtr(dos_qsettings_value(self.vptr, key.cstring, defaultValue.vptr))

proc setValue*(self: QSettings, key: string, value: QVariant) =
  dos_qsettings_set_value(self.vptr, key.cstring, value.vptr)

proc remove*(self: QSettings, key: string) =
  dos_qsettings_remove(self.vptr, key.cstring)

proc beginGroup*(self: QSettings, group: string) =
  dos_qsettings_begin_group(self.vptr, group.cstring)

proc endGroup*(self: QSettings) =
  dos_qsettings_end_group(self.vptr)

# QTimer
proc delete*(self: QTimer)

proc newQTimer*(): QTimer =
  new(result, delete)
  result.vptr = dos_qtimer_create()

proc delete*(self: QTimer) =
  dos_qtimer_delete(self.vptr)
  self.vptr = nil

proc setInterval*(self: QTimer, interval: int) =
  dos_qtimer_set_interval(self.vptr, interval)

proc interval*(self: QTimer): int =
  dos_qtimer_interval(self.vptr)

proc start*(self: QTimer) =
  dos_qtimer_start(self.vptr)

proc stop*(self: QTimer) =
  dos_qtimer_stop(self.vptr)

proc setSingleShot*(self: QTimer, singleShot: bool) =
  dos_qtimer_set_single_shot(self.vptr, singleShot)

proc isSingleShot*(self: QTimer): bool =
  dos_qtimer_is_single_shot(self.vptr)

proc isActive*(self: QTimer): bool =
  dos_qtimer_is_active(self.vptr)
