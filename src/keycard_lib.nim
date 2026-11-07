## status-keycard-qt entry points. On Android the library (with the libcrypto and Qt Nfc it
## needs) is dlopen()ed on the first keycard call instead of being loaded at startup.

when not defined(android):
  import keycard_go
  export keycard_go

  proc isLoaded*(): bool = true

  proc ensureLoaded*() = discard

else:
  import std/[dynlib, locks]
  import chronicles

  type
    KeycardSignalCallback* = proc(signal: cstring): void {.cdecl, gcsafe, raises: [].}
    CallRPCFn = proc(params: cstring): cstring {.cdecl, gcsafe, raises: [].}
    SetCallbackFn = proc(callback: KeycardSignalCallback) {.cdecl, gcsafe, raises: [].}
    FreeFn = proc(p: pointer) {.cdecl, gcsafe, raises: [].}

  const LIB_NAME = "libstatus-keycard-qt.so"

  var
    loadLock: Lock
    callRPCFn: CallRPCFn
    freeFn: FreeFn
    signalCallback: KeycardSignalCallback

  initLock(loadLock)

  proc load(): bool {.gcsafe.} =
    {.cast(gcsafe).}:
      withLock loadLock:
        if callRPCFn != nil:
          return true
        let lib = loadLib(LIB_NAME)
        if lib == nil:
          error "failed to load keycard library", lib = LIB_NAME
          return false
        let setCallback = cast[SetCallbackFn](lib.symAddr("KeycardSetSignalEventCallback"))
        freeFn = cast[FreeFn](lib.symAddr("Free"))
        setCallback(signalCallback)
        callRPCFn = cast[CallRPCFn](lib.symAddr("KeycardCallRPC"))
        info "keycard library loaded"
        return true

  proc isLoaded*(): bool =
    {.cast(gcsafe).}:
      withLock loadLock:
        result = callRPCFn != nil

  # The library creates its NFC objects with the signal callback, so this must run on the
  # Qt main thread
  proc ensureLoaded*() =
    discard load()

  proc setSignalEventCallback*(callback: KeycardSignalCallback) =
    signalCallback = callback

  proc keycardCallRPC*(params: string): string =
    if not load():
      return """{"error":"keycard library not available"}"""
    {.cast(gcsafe).}:
      let funcOut = callRPCFn(params.cstring)
      defer: freeFn(funcOut)
      return $funcOut
