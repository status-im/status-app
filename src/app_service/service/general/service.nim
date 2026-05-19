import nimqml, os, json, chronicles

import backend/general as status_general
import app/core/eventemitter
import app/core/tasks/[qt, threadpool]
import ../../../constants as app_constants
import ../../common/types
import status_go
import app/global/global_singleton

from app_service/service/activity_center/service import SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_RECEIVED, ActivityCenterNotificationsArgs
from app_service/service/activity_center/dto/notification import parseActivityCenterNotifications

import ../accounts/dto/accounts

include async_tasks


logScope:
  topics = "general-app-service"

include ../../common/async_tasks

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    timeoutInMilliseconds: int
    messengerStartScheduled: bool

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, threadpool: ThreadPool): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool

  proc init*(self: Service) =
    if not dirExists(app_constants.ROOTKEYSTOREDIR):
      createDir(app_constants.ROOTKEYSTOREDIR)

  proc startMessenger*(self: Service) =
    if self.messengerStartScheduled:
      return
    self.messengerStartScheduled = true
    let arg = AsyncStartMessengerTaskArg(
      tptr: asyncStartMessengerTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncStartMessengerDone",
    )
    self.threadpool.start(arg)

  proc onAsyncStartMessengerDone(self: Service, response: string) {.slot.} =
    var startError = ""
    try:
      let rpcResponseObj = response.parseJson

      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      let responseResult = rpcResponseObj{"response"}
      if not responseResult.isNil and responseResult.kind == JObject and
          responseResult.contains("activityCenterNotifications"):
        let notifications = JsonNode(%{"notifications": responseResult["activityCenterNotifications"]})
        let activityCenterNotificationsTuple = parseActivityCenterNotifications(notifications)
        self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_RECEIVED,
          ActivityCenterNotificationsArgs(activityCenterNotifications: activityCenterNotificationsTuple[1]))
    except Exception as e:
      startError = e.msg
      error "error:", procName="startMessenger", errName = e.name, errDesription = startError
    self.events.emit(SIGNAL_MESSENGER_STARTED, MessengerStartedArgs(error: startError))

  proc logout*(self: Service) =
    discard status_general.logout()

  proc getPasswordStrengthScore*(self: Service, password, userName: string): int =
    try:
      let response = status_general.getPasswordStrengthScore(password, @[userName])
      if(response.result.contains("error")):
        let errMsg = response.result["error"].getStr()
        error "error: ", methodName="getPasswordStrengthScore", errDesription = errMsg
        return

      return response.result["score"].getInt()
    except Exception as e:
      error "error: ", methodName="getPasswordStrengthScore", errName = e.name, errDesription = e.msg

  proc asyncImportLocalBackupFile*(self: Service, filePath: string) =
    let formattedFilePath = singletonInstance.utils.fromPathUri(filePath)
    let arg = AsyncImportLocalBackupFileTaskArg(
      tptr: asyncImportLocalBackupFileTask,
      vptr: cast[uint](self.vptr),
      slot: "onImportLocalBackupFileDone",
      filePath: formattedFilePath
    )
    self.threadpool.start(arg)

  proc onImportLocalBackupFileDone(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson

      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      let responseObj = rpcResponseObj["response"].getStr.parseJson

      if (responseObj{"error"}.kind != JNull and responseObj{"error"}.getStr != ""):
        raise newException(CatchableError, responseObj["error"].getStr)

      self.events.emit(SIGNAL_LOCAL_BACKUP_IMPORT_COMPLETED, LocalBackupImportArg(error: ""))
    except Exception as e:
      error "error:", procName="asyncImportLocalBackupFile", errName = e.name, errDesription = e.msg
      self.events.emit(SIGNAL_LOCAL_BACKUP_IMPORT_COMPLETED, LocalBackupImportArg(error: e.msg))

  proc connectionChange*(self: Service, connectionType: string, isExpensive: bool) =
    when defined(android):
      # Connectivity is driven natively by StatusGoService on Android — see
      # mobile/android/qt6/.../ipc/StatusGoService.java. This QML path is a no-op.
      return
    try:
      let response = status_go.connectionChange($(%* {"type": connectionType, "expensive": isExpensive}))
      let rpcResponseObj = response.parseJson
      if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
          raise newException(CatchableError, rpcResponseObj{"error"}.getStr)
    except Exception as e:
      error "error:", procName="connectionChange", errName = e.name, errDesription = e.msg

  proc delete*(self: Service) =
    self.QObject.delete

