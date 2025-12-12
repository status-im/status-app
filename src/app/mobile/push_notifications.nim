import chronicles, json
import ../../backend/backend
import ../../backend/settings
import ../../statusq_bridge

logScope:
  topics = "mobile-push-notifications"

# Push notification token types (from protobuf.PushNotificationRegistration_TokenType)
const
  UNKNOWN_TOKEN_TYPE* = 0
  APN_TOKEN* = 1
  FIREBASE_TOKEN* = 2

# Global state - stores the push token until user logs in
var g_pushToken: string = ""
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
  g_pushToken = tokenStr
  g_tokenRegistered = false
  
  when defined(android):
    debug "FCM token received, will register after user login", token=tokenStr
  elif defined(ios):
    debug "APNS token received, will register after user login", token=tokenStr
  else:
    debug "Push token received, will register after user login", token=tokenStr

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
  ## Register the stored push token with status-go
  ## This should be called after user login when messenger is ready
  ## Returns true if registration was attempted, false if no token available
  
  if g_pushToken.len == 0:
    debug "No push token available to register"
    return false
  
  if g_tokenRegistered:
    debug "Push token already registered"
    return false
  
  when defined(android):
    debug "Registering FCM token with status-go (post-login)...", token=g_pushToken
  elif defined(ios):
    debug "Registering APNS token with status-go (post-login)...", token=g_pushToken
  else:
    debug "Registering push token with status-go (post-login)...", token=g_pushToken
  
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
    #   - deviceToken: Push token (FCM for Android, APNS for iOS)
    #   - apnTopic: empty string for Android, bundle ID for iOS
    #   - tokenType: FIREBASE_TOKEN (2) for Android, APN_TOKEN (1) for iOS
    when defined(android):
      debug "Registering FCM token with status-go...", tokenType="FIREBASE_TOKEN(2)"
      let response = registerForPushNotifications(g_pushToken, "", FIREBASE_TOKEN)
    elif defined(ios):
      # Bundle ID for new status-desktop iOS app
      let apnTopic = "im.status.ethereum"
      info "Registering APNS token with status-go", 
        token=g_pushToken, 
        apnTopic=apnTopic, 
        tokenType="APN_TOKEN(1)"
      let response = registerForPushNotifications(g_pushToken, apnTopic, APN_TOKEN)
    else:
      error "Unsupported platform for push notifications"
      return false
    
    # Log the full response for debugging
    info "Push notification registration response", 
      response=response,
      hasError=(not response.error.isNil)
    
    if not response.error.isNil:
      error "Push notification registration failed", error=response.error
      return false
    
    debug "Successfully registered for push notifications"
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

proc initializeMobilePushNotifications*() =
  ## Initialize push notifications on mobile (Android/iOS)
  ## This should be called once during app startup
  when defined(android):
    debug "Initializing Android push notifications..."
  elif defined(ios):
    debug "Initializing iOS push notifications..."
  else:
    debug "Initializing mobile push notifications..."

  # Register our callbacks with StatusQ C++ layer
  statusq_initPushNotifications(
    onPushNotificationTokenReceived,
    onPushNotificationReceived
  )

  when defined(android):
    # Request notification permission
    # Android 13+: Shows system dialog
    # Android 12-: No-op (permission granted by default)
    requestNotificationPermission()
    debug "Android push notifications initialized"
  elif defined(ios):
    # iOS: Permission and registration handled by QIOSApplicationDelegate category
    # in statusappdelegate_ios.mm via didFinishLaunchingWithOptions override
    debug "iOS push notifications initialized - registration handled by app delegate category"
  else:
    requestNotificationPermission()
    debug "Mobile push notifications initialized"

# Deprecated: Use initializeMobilePushNotifications instead
proc initializeAndroidPushNotifications*() =
  initializeMobilePushNotifications()

