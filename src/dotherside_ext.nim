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

  # Custom QObjects (real QObjects created by DOtherSide; adopted as nimqml-seaqt
  # QObject subtypes so `newQVariant` works on them).
  StatusEvent* = ref object of QObject
  StatusOSNotification* = ref object of QObject

  QNetworkAccessManagerFactory* = ref object of RootObj
    vptr: pointer

# --- DOtherSide C API (only what status still uses) --------------------------
# QObject pointers are passed as raw `pointer` (a real C++ `QObject*`).

proc dos_signal(vptr: pointer, signal: cstring, slot: cstring) {.cdecl, dynlib: dynLibName, importc.}

proc dos_qtwebview_initialize() {.cdecl, dynlib: dynLibName, importc.}

proc dos_installMessageHandler(handler: DosMessageHandler) {.cdecl, dynlib: dynLibName, importc.}
proc dos_qguiapplication_installEventFilter(filter: pointer) {.cdecl, dynlib: dynLibName, importc.}

proc dos_qqmlnetworkaccessmanagerfactory_create(tmpPath: cstring): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_qqmlapplicationengine_setNetworkAccessManagerFactory(engine: pointer, factory: pointer) {.cdecl, dynlib: dynLibName, importc.}

proc dos_osnotification_create(): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_osnotification_show_notification(vptr: pointer, title, message, identifier: cstring) {.cdecl, dynlib: dynLibName, importc.}
proc dos_osnotification_show_badge_notification(vptr: pointer, notificationsCount: int) {.cdecl, dynlib: dynLibName, importc.}
proc dos_osnotification_delete(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}

proc dos_event_create_urlSchemeEvent(): pointer {.cdecl, dynlib: dynLibName, importc.}
proc dos_event_delete(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}
proc dos_event_set_urlSchemeEvent_instance(vptr: pointer) {.cdecl, dynlib: dynLibName, importc.}

# --- High-level API (ported verbatim from the old nimqml fork) ---------------

proc signal_handler*(receiver: pointer, signal: cstring, slot: cstring) =
  if not receiver.isNil:
    dos_signal(receiver, signal, slot)

proc initializeWebView*() =
  ## QtWebView FFI fallback: header <QtWebView/QtWebView> not found in build env.
  dos_qtwebview_initialize()

proc installMessageHandler*(handler: DosMessageHandler) =
  dos_installMessageHandler(handler)

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
