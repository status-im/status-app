# Declarations of methods exposed from StatusQ

type StatusQMessageHandler* = proc(messageType: cint, message: cstring, category: cstring,
  file: cstring, function: cstring, line: cint) {.cdecl.}

proc statusq_registerQmlTypes*() {.cdecl, importc.}
proc statusq_installMessageHandler*(cb: StatusQMessageHandler) {.cdecl, importc.}
proc statusq_setupNetworkAccessManagerFactory*(engine: pointer, tmpPath: cstring) {.cdecl, importc.}
proc statusq_initializeWebEngine*() {.cdecl, importc.}

proc statusq_osnotification_create*(): pointer {.cdecl, importc.}
proc statusq_osnotification_show_notification*(obj: pointer, title: cstring, message: cstring, identifier: cstring) {.cdecl, importc.}
proc statusq_osnotification_show_badge_notification*(obj: pointer, notificationsCount: cint) {.cdecl, importc.}
proc statusq_osnotification_delete*(obj: pointer) {.cdecl, importc.}

proc statusq_invoke_method_queued*(obj: pointer, meth: cstring, arg: cstring) {.cdecl, importc.}
