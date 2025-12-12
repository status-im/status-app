import chronicles, json
import ../../backend/backend
import ../../backend/settings
import ../../statusq_bridge

logScope:
  topics = "android-push-notifications"

# Push notification token types (from protobuf.PushNotificationRegistration_TokenType)
const
  UNKNOWN_TOKEN_TYPE* = 0
  APN_TOKEN* = 1
  FIREBASE_TOKEN* = 2

# Global state - stores the FCM token until user logs in
var g_fcmToken: string = ""
var g_tokenRegistered: bool = false

# Global callback handlers - must use cdecl calling convention
proc onPushNotificationTokenReceived(token: cstring) {.cdecl, exportc.} =
  # Initialize Nim GC for foreign thread calls
  when declared(setupForeignThreadGc):
    setupForeignThreadGc()
  when declared(nimGC_setStackBottom):
    var locals {.volatile, noinit.}: pointer
    locals = addr(locals)
    nimGC_setStackBottom(locals)
  
  let tokenStr = $token  
  # Store the token globally - we'll register it after user logs in
  g_fcmToken = tokenStr
  g_tokenRegistered = false
  
  debug "FCM token received, will register after user login"

proc onPushNotificationReceived(encryptedMessage: cstring, chatId: cstring, publicKey: cstring) {.cdecl, exportc.} =
  # Initialize Nim GC for foreign thread calls
  when declared(setupForeignThreadGc):
    setupForeignThreadGc()
  when declared(nimGC_setStackBottom):
    var locals {.volatile, noinit.}: pointer
    locals = addr(locals)
    nimGC_setStackBottom(locals)
  
  debug "Push notification received", 
    encryptedMessage = $encryptedMessage, 
    chatId = $chatId, 
    publicKey = $publicKey
  
  # NOTE: In most cases, you don't need to process this manually!
  # 
  # The push notification serves as a WAKE-UP CALL:
  # 1. It wakes up the app (if backgrounded/closed)
  # 2. status-go connects to Waku automatically
  # 3. Waku delivers messages through normal flow
  # 4. status-go decrypts and generates local notifications
  #
  # The encrypted data here is for:
  # - Quick preview before Waku sync (future enhancement)
  # - Message prioritization
  # - Offline handling (future enhancement)
  #
  # For now, just logging is sufficient. status-go handles the rest!

proc registerPushNotificationToken*(): bool =
  ## Register the stored FCM token with status-go
  ## This should be called after user login when messenger is ready
  ## Returns true if registration was attempted, false if no token available
  
  if g_fcmToken.len == 0:
    debug "No FCM token available to register"
    return false
  
  if g_tokenRegistered:
    debug "FCM token already registered"
    return false
  
  debug "Registering FCM token with status-go (post-login)...", token=g_fcmToken
  
  try:
    # First, ensure messenger notifications are enabled
    # This is required for the push notification client to be initialized
    # TODO: This should be done by the user through the onboarding/settings
    debug "Enabling messenger notifications in settings..."
    let enableResponse = saveSettings("messenger-notifications-enabled?", true)
    if not enableResponse.error.isNil:
      error "Failed to enable messenger notifications", error=enableResponse.error
      return false
    debug "Messenger notifications enabled"
    
    # Now register with status-go using the proper backend API
    # Parameters:
    #   - deviceToken: FCM token from Firebase
    #   - apnTopic: empty string for Android (only used for iOS)
    #   - tokenType: FIREBASE_TOKEN (2) for Android
    debug "Registering FCM token with status-go..."
    let response = registerForPushNotifications(g_fcmToken, "", FIREBASE_TOKEN)
    
    debug "Successfully registered for push notifications", response=response
    g_tokenRegistered = true
    return true
  except Exception as e:
    error "Failed to register for push notifications", error=e.msg
    return false

proc requestNotificationPermission*() =
  ## Request notification permission (Android 13+ only)
  ## On Android 12 and below, this is a no-op
  ## Should be called before requesting FCM token
  debug "Requesting notification permission..."
  statusq_requestNotificationPermission()

proc hasNotificationPermission*(): bool =
  ## Check if notification permission is granted
  ## Returns true on Android 12- (permission not required)
  ## Returns actual permission status on Android 13+
  statusq_hasNotificationPermission()

proc initializeAndroidPushNotifications*() =
  ## Initialize push notifications on Android
  ## This should be called once during app startup
  debug "Initializing Android push notifications..."

  # Register our callbacks with StatusQ C++ layer
  statusq_initPushNotifications(
    onPushNotificationTokenReceived,
    onPushNotificationReceived
  )

  # Request notification permission (Android 13+ only)
  # This will show a system dialog on Android 13+
  # On Android 12 and below, this does nothing
  requestNotificationPermission()

  debug "Android push notifications initialized"

