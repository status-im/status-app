import std/[os, times, unittest]

import app/core/tasks/threadpool
import app/global/log_cleanup
import app/global/log_cleanup_tasks

proc removeTree(path: string) =
  if not dirExists(path):
    return

  for kind, child in walkDir(path):
    case kind
    of pcDir:
      removeTree(child)
    else:
      removeFile(child)
  removeDir(path)

proc writeLog(path: string, modifiedAt: Time) =
  createDir(parentDir(path))
  writeFile(path, "log")
  setLastModificationTime(path, modifiedAt)

suite "log cleanup":
  var tempDir: string
  var logsDir: string
  var dataDir: string

  setup:
    tempDir = getTempDir() / ("status-log-cleanup-" & $getCurrentProcessId() & "-" & $epochTime())
    logsDir = tempDir / "logs"
    dataDir = tempDir / "data"
    createDir(logsDir)
    createDir(dataDir)

  teardown:
    removeTree(tempDir)

  test "clear closed logs removes logs and preserves active files":
    let processStartedAt = getTime()
    let closedTime = processStartedAt - initDuration(hours = 1)
    let activeTime = processStartedAt + initDuration(seconds = 1)
    let closedAppLog = logsDir / "app-old.log"
    let closedArchive = logsDir / "app-old.log.gz"
    let activeAppLog = logsDir / "app-current.log"
    let closedDataLog = dataDir / "geth.log"
    let nestedClosedDataLog = dataDir / "keycard" / "keycard.log"
    let activeDataLog = dataDir / "pre_login.log"
    let dataFile = dataDir / "node-config.json"

    writeLog(closedAppLog, closedTime)
    writeLog(closedArchive, closedTime)
    writeLog(activeAppLog, activeTime)
    writeLog(closedDataLog, closedTime)
    writeLog(nestedClosedDataLog, closedTime)
    writeLog(activeDataLog, activeTime)
    writeFile(dataFile, "config")

    let result = cleanupLogFiles(logsDir, dataDir, processStartedAt, processStartedAt,
      ClearClosedLogs)

    check result.deletedCount == 4
    check result.failedCount == 0
    check not fileExists(closedAppLog)
    check not fileExists(closedArchive)
    check not fileExists(closedDataLog)
    check not fileExists(nestedClosedDataLog)
    check fileExists(activeAppLog)
    check fileExists(activeDataLog)
    check fileExists(dataFile)

  test "retention removes only closed logs older than two weeks":
    let processStartedAt = getTime()
    let expiredTime = processStartedAt - initDuration(days = LogRetentionDays + 1)
    let recentTime = processStartedAt - initDuration(days = LogRetentionDays - 1)
    let activeTime = processStartedAt + initDuration(seconds = 1)
    let expiredAppLog = logsDir / "app-expired.log"
    let recentAppLog = logsDir / "app-recent.log"
    let expiredDataLog = dataDir / "geth.log"
    let recentDataLog = dataDir / "nested" / "keycard.log"
    let activeDataLog = dataDir / "pre_login.log"

    writeLog(expiredAppLog, expiredTime)
    writeLog(recentAppLog, recentTime)
    writeLog(expiredDataLog, expiredTime)
    writeLog(recentDataLog, recentTime)
    writeLog(activeDataLog, activeTime)

    let result = cleanupLogFiles(logsDir, dataDir, processStartedAt, processStartedAt,
      RemoveExpiredLogs)

    check result.deletedCount == 2
    check result.failedCount == 0
    check not fileExists(expiredAppLog)
    check not fileExists(expiredDataLog)
    check fileExists(recentAppLog)
    check fileExists(recentDataLog)
    check fileExists(activeDataLog)

  test "missing log directories are ignored":
    let currentTime = getTime()
    let missingLogsDir = tempDir / "missing-logs"
    let missingDataDir = tempDir / "missing-data"
    let result = cleanupLogFiles(missingLogsDir, missingDataDir, currentTime, currentTime, ClearClosedLogs)

    check result.deletedCount == 0
    check result.failedCount == 0

  test "startup retention runs on the shared thread pool":
    let processStartedAt = getTime()
    let expiredLog = logsDir / "app-expired.log"
    writeLog(expiredLog, processStartedAt - initDuration(days = LogRetentionDays + 1))
    let threadpool = newThreadPool()

    scheduleStartupLogCleanup(threadpool, logsDir, dataDir, processStartedAt)
    threadpool.teardown()

    check not fileExists(expiredLog)