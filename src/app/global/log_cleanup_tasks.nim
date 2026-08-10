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

proc startupLogCleanupTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[StartupLogCleanupTaskArg](argEncoded)
  let result = cleanupLogFiles(
    arg.logsDir,
    arg.dataDir,
    fromUnix(arg.processStartedAtUnix),
    getTime(),
    RemoveExpiredLogs)

  if result.failedCount > 0:
    warn "failed to remove some expired log files", deletedCount = result.deletedCount,
      failedCount = result.failedCount
  else:
    debug "removed expired log files", deletedCount = result.deletedCount

proc scheduleStartupLogCleanup*(threadpool: ThreadPool, logsDir, dataDir: string,
    processStartedAt: Time) =
  let arg = StartupLogCleanupTaskArg(
    tptr: startupLogCleanupTask,
    logsDir: logsDir,
    dataDir: dataDir,
    processStartedAtUnix: processStartedAt.toUnix)
  threadpool.start(arg)