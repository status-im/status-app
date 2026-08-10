import std/times

import nimqml, json, chronicles

import app/core/eventemitter
import app/core/tasks/threadpool
import app/global/log_cleanup
import constants
import ./async_tasks

logScope:
  topics = "advanced-app-service"

const SIGNAL_ADVANCED_LOGS_CLEANUP_FINISHED* = "advancedLogsCleanupFinished"

type AdvancedLogsCleanupFinishedArgs* = ref object of Args
  deletedCount*: int
  failedCount*: int
  error*: string

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    clearingOldLogs: bool

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, threadpool: ThreadPool): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.clearingOldLogs = false

  proc isClearingOldLogs*(self: Service): bool =
    return self.clearingOldLogs

  proc clearOldLogs*(self: Service): bool =
    if self.clearingOldLogs:
      return false

    self.clearingOldLogs = true
    let arg = ClearOldLogsTaskArg(
      tptr: clearOldLogsTask,
      vptr: cast[uint](self.vptr),
      slot: "onOldLogsCleanupFinished",
      logsDir: LOGDIR,
      dataDir: STATUSGODIR,
      processStartedAtUnix: logCleanupProcessStartedAt().toUnix)
    self.threadpool.start(arg)
    return true

  proc onOldLogsCleanupFinished*(self: Service, response: string) {.slot.} =
    var result = AdvancedLogsCleanupFinishedArgs()
    try:
      let responseObj = response.parseJson
      result.deletedCount = responseObj{"deletedCount"}.getInt()
      result.failedCount = responseObj{"failedCount"}.getInt()
      result.error = responseObj{"error"}.getStr()
    except Exception as e:
      result.error = e.msg

    self.clearingOldLogs = false
    self.events.emit(SIGNAL_ADVANCED_LOGS_CLEANUP_FINISHED, result)

  proc delete*(self: Service) =
    self.QObject.delete