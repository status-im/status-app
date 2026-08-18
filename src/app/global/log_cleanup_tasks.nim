import std/times

import chronicles

import app/core/tasks/threadpool
import ./log_cleanup

logScope:
  topics = "log-cleanup"

type StartupLogCleanupTaskArg = ref object of TaskArg
  logsDir: string
  dataDir: string
  processStartedAtUnix: int64
  maxFilesPerFamily: int

proc startupLogCleanupTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[StartupLogCleanupTaskArg](argEncoded)
  let result = cleanupLogFiles(
    arg.logsDir,
    arg.dataDir,
    fromUnix(arg.processStartedAtUnix),
    RemoveExpiredLogs,
    arg.maxFilesPerFamily
  )

  if result.failedCount > 0:
    warn "failed to remove some expired log files", deletedCount = result.deletedCount,
      failedCount = result.failedCount
  else:
    debug "removed expired log files", deletedCount = result.deletedCount

proc scheduleLogFamilyCleanup*(threadpool: ThreadPool, logsDir, dataDir: string, processStartedAt: Time,
  maxFilesPerFamily: int) =
  let arg = StartupLogCleanupTaskArg(
    tptr: startupLogCleanupTask,
    logsDir: logsDir,
    dataDir: dataDir,
    processStartedAtUnix: processStartedAt.toUnix,
    maxFilesPerFamily: maxFilesPerFamily
  )
  threadpool.start(arg)

proc scheduleStartupLogCleanup*(threadpool: ThreadPool, logsDir, dataDir: string, processStartedAt: Time) =
  # MaxLogFamilyMaxFiles is used on the app start, later updated to the user's per-family setting when DB is ready
  scheduleLogFamilyCleanup(threadpool, logsDir, dataDir, processStartedAt, MaxLogFamilyMaxFiles)