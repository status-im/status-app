import nimqml

import local_account_settings
import local_account_sensitive_settings
import local_app_settings
import user_profile
import utils
import global_events
import loader_deactivator
import feature_flags
import app_lifecycle

export local_account_settings
export local_account_sensitive_settings
export local_app_settings
export user_profile
export utils
export global_events
export loader_deactivator
export feature_flags


# #########################################################
# Application Handle
# #########################################################
type
  ApplicationHandle* = object
    app: QGuiApplication

when defined(ios) or defined(android):
  proc c_exit(code: cint) {.importc: "_exit", header: "<unistd.h>".}

proc tryTerminateWithoutCascade*() =
  ## Mobile teardown policy: leave without running static destructors
  when defined(ios) or defined(android):
    c_exit(0)

proc quit*(self: ApplicationHandle) =
  markShuttingDown()
  if not self.app.isNil:
    self.app.quit()
  tryTerminateWithoutCascade()

proc exit*(self: ApplicationHandle) =
  markShuttingDown()
  if not self.app.isNil:
    self.app.exit()
  tryTerminateWithoutCascade()
# #########################################################


type
  GlobalSingleton = object
  # Don't export GlobalSingleton type.
  # Other global things like local/global settings will be added here.

var singletonInstance* = GlobalSingleton()

proc engine*(self: GlobalSingleton): QQmlApplicationEngine =
  var qmlEngine {.global.}: QQmlApplicationEngine
  if (qmlEngine.isNil):
    qmlEngine = newQQmlApplicationEngine()
  return qmlEngine

var qGuiApplicationInstance {.global.}: QGuiApplication

proc setApplication*(self: GlobalSingleton, app: QGuiApplication) =
  qGuiApplicationInstance = app

proc application*(self: GlobalSingleton): ApplicationHandle =
  ApplicationHandle(app: qGuiApplicationInstance)

# Names of the QML context properties the current app session set (see
# setSessionContextProperty()).
var sessionContextPropertyNames: seq[string]

proc setSessionContextProperty*(self: GlobalSingleton, name: string, value: QVariant) =
  ## A QML context property of the current app session (one login lifetime): the
  ## session's objects are deleted when it ends, so clearSessionContextProperties()
  ## unsets it first. Process-lifetime properties use the engine directly.
  if name notin sessionContextPropertyNames:
    sessionContextPropertyNames.add(name)
  self.engine.setRootContextProperty(name, value)

proc clearSessionContextProperties*(self: GlobalSingleton) =
  ## Unsets the context properties of the ended session before its objects are deleted:
  ## QML that outlives the session (the window) must not reach them. To QML they are
  ## undefined again, as before the session set them.
  let unset = newQVariant()
  for name in sessionContextPropertyNames:
    self.engine.setRootContextProperty(name, unset)
  sessionContextPropertyNames.setLen(0)
  unset.delete

proc localAccountSettings*(self: GlobalSingleton): LocalAccountSettings =
  var localAccountSettings {.global.}: LocalAccountSettings
  if (localAccountSettings.isNil):
    localAccountSettings = newLocalAccountSettings()
  return localAccountSettings

proc localAccountSensitiveSettings*(self: GlobalSingleton): LocalAccountSensitiveSettings =
  var localAccountSensitiveSettings {.global.}: LocalAccountSensitiveSettings
  if (localAccountSensitiveSettings.isNil):
    localAccountSensitiveSettings = newLocalAccountSensitiveSettings()
  return localAccountSensitiveSettings

proc localAppSettings*(self: GlobalSingleton): LocalAppSettings =
  var localAppSettings {.global.}: LocalAppSettings
  if (localAppSettings.isNil):
    localAppSettings = newLocalAppSettings("global")
  return localAppSettings

proc userProfile*(self: GlobalSingleton): UserProfile =
  var userProfile {.global.}: UserProfile
  if (userProfile.isNil):
    userProfile = newUserProfile(singletonInstance.localAccountSettings)
  return userProfile

proc utils*(self: GlobalSingleton): Utils =
  var utils {.global.}: Utils
  if (utils.isNil):
    utils = newUtils()
  return utils

proc globalEvents*(self: GlobalSingleton): GlobalEvents =
  var globalEvents {.global.}: GlobalEvents
  if (globalEvents.isNil):
    globalEvents = newGlobalEvents()
  return globalEvents

proc loaderDeactivator*(self: GlobalSingleton): LoaderDeactivator =
  var loaderDeactivator {.global.}: LoaderDeactivator
  if (loaderDeactivator.isNil):
    loaderDeactivator = newLoaderDeactivator()
  return loaderDeactivator

proc featureFlags*(self: GlobalSingleton): FeatureFlags =
  var featureFlags {.global.}: FeatureFlags
  if (featureFlags.isNil):
    featureFlags = newFeatureFlags()
  return featureFlags

proc delete*(self: GlobalSingleton) =
  self.engine.delete()
  self.localAccountSettings.delete()
  self.localAccountSensitiveSettings.delete()
  self.localAppSettings.delete()
  self.userProfile.delete()
  self.loaderDeactivator.delete()
  self.featureFlags.delete()
