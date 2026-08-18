import std/[json, times]

import chronicles

import app/core/tasks/[qt, threadpool]
import app/global/log_cleanup

logScope:
  topics = "advanced-app-service"

type ClearOldLogsTaskArg* = ref object of QObjectTaskArg
  logsDir*: string
  dataDir*: string
  processStartedAtUnix*: int64

proc clearOldLogsTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ClearOldLogsTaskArg](argEncoded)
  try:
    let result = cleanupLogFiles(
      arg.logsDir,
      arg.dataDir,
      fromUnix(arg.processStartedAtUnix),
      ClearClosedLogs)
    arg.finish(%* {
      "deletedCount": result.deletedCount,
      "failedCount": result.failedCount,
      "error": "",
    })
  except Exception as e:
    error "failed to clear old log files", error = e.msg
    arg.finish(%* {
      "deletedCount": 0,
      "failedCount": 0,
      "error": e.msg,
    })

type LogsSizeTaskArg* = ref object of QObjectTaskArg
  logsDir*: string
  dataDir*: string

proc computeLogsSizeTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[LogsSizeTaskArg](argEncoded)
  try:
    arg.finish(%* {
      "sizeBytes": logsTotalSizeBytes(arg.logsDir, arg.dataDir),
    })
  except Exception as e:
    error "failed to compute logs size", error = e.msg
    arg.finish(%* {
      "sizeBytes": 0,
    })

type LogFamilyCleanupTaskArg* = ref object of QObjectTaskArg
  logsDir*: string
  dataDir*: string
  processStartedAtUnix*: int64
  maxFilesPerFamily*: int

proc logFamilyCleanupTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[LogFamilyCleanupTaskArg](argEncoded)
  try:
    let result = cleanupLogFiles(
      arg.logsDir,
      arg.dataDir,
      fromUnix(arg.processStartedAtUnix),
      RemoveExpiredLogs,
      arg.maxFilesPerFamily)
    arg.finish(%* {
      "deletedCount": result.deletedCount,
      "failedCount": result.failedCount,
      "error": "",
    })
  except Exception as e:
    error "failed to apply log family cap", error = e.msg
    arg.finish(%* {
      "deletedCount": 0,
      "failedCount": 0,
      "error": e.msg,
    })