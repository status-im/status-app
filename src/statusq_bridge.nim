# Declarations of methods exposed from StatusQ

proc statusq_registerQmlTypes*() {.cdecl, importc.}

when defined(android) or defined(ios):
  # Push notification callback types (cross-platform)
  type
    PushNotificationTokenCallback* = proc(token: cstring) {.cdecl.}
    PushNotificationReceivedCallback* = proc(encryptedMessage: cstring, chatId: cstring, publicKey: cstring) {.cdecl.}
  
  # Mobile push notification initialization (Android + iOS)
  proc statusq_initPushNotifications*(
    tokenCallback: PushNotificationTokenCallback,
    receivedCallback: PushNotificationReceivedCallback
  ) {.cdecl, importc.}
  
  # Notification permission management
  # Android: Required on Android 13+, no-op on Android 12-
  # iOS: Always required, shows system dialog
  proc statusq_requestNotificationPermission*() {.cdecl, importc.}
  proc statusq_hasNotificationPermission*(): bool {.cdecl, importc.}
