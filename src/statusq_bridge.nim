# Declarations of methods exposed from StatusQ

proc statusq_registerQmlTypes*() {.cdecl, importc.}

when defined(android):
  # Push notification callback types
  type
    PushNotificationTokenCallback* = proc(token: cstring) {.cdecl.}
    PushNotificationReceivedCallback* = proc(encryptedMessage: cstring, chatId: cstring, publicKey: cstring) {.cdecl.}
  
  # Android push notification initialization
  proc statusq_initPushNotifications*(
    tokenCallback: PushNotificationTokenCallback,
    receivedCallback: PushNotificationReceivedCallback
  ) {.cdecl, importc.}
  
  # Android notification permission (Android 13+)
  proc statusq_requestNotificationPermission*() {.cdecl, importc.}
  proc statusq_hasNotificationPermission*(): bool {.cdecl, importc.}
