# Declarations of methods exposed from StatusQ

type StatusQMessageHandler* = proc(messageType: cint, message: cstring, category: cstring,
  file: cstring, function: cstring, line: cint) {.cdecl.}

proc statusq_registerQmlTypes*() {.cdecl, importc.}
proc statusq_installMessageHandler*(cb: StatusQMessageHandler) {.cdecl, importc.}
proc statusq_setupNetworkAccessManagerFactory*(engine: pointer, tmpPath: cstring) {.cdecl, importc.}
proc statusq_initializeWebEngine*() {.cdecl, importc.}
