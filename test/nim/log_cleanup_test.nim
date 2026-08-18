import std/[os, strutils, times, unittest]

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

proc countLogs(dir, prefix: string): int =
  for kind, path in walkDir(dir):
    if kind == pcFile and extractFilename(path).startsWith(prefix):
      inc result

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

  test "log family derivation":
    check logFamily("app_20260814_083321.log") == "app"
    check logFamily("app_20260815_121212.log") == "app"
    check logFamily("pre_login.log") == "pre_login"
    check logFamily("pre_login-2026-08-14T11-08-48Z.log") == "pre_login"
    check logFamily("pre_login-2026-08-14T11-08-48.123.log") == "pre_login"
    check logFamily("0x4d..2f40.log") == "0x4d..2f40"
    check logFamily("0x4d..2f40-2026-08-14T13-37-56Z.log") == "0x4d..2f40"
    check logFamily("0x4d..2f40-2026-08-14T13-37-56.000.log") == "0x4d..2f40"
    check logFamily("api-2026-08-14T13-37-56.000.log.gz") == "api"
    check logFamily("geth-2026-08-14T13-37-56Z.log") == "geth"
    check logFamily("keycard.log") == "keycard"
    check logFamily("some_random.log") == "some_random"
    # not a session timestamp: stays its own family
    check logFamily("backup-2026-08-14.log") == "backup-2026-08-14"

  test "canonical log name detection":
    # live-file names a writer keeps open
    check isCanonicalLogName("pre_login.log")
    check isCanonicalLogName("0x4d..2f40.log")
    check isCanonicalLogName("keycard.log")
    check isCanonicalLogName("some_random.log")
    # archives and per-start client logs are not canonical
    check not isCanonicalLogName("pre_login-2026-08-14T11-08-48Z.log")
    check not isCanonicalLogName("0x4d..2f40-2026-08-14T13-37-56.000.log")
    check not isCanonicalLogName("api-2026-08-14T13-37-56.000.log.gz")
    check not isCanonicalLogName("app_20260814_083321.log")
    # only status-go's own live files can be held by an out-of-process writer
    check isStatusGoOwnedCanonicalLogName("pre_login.log")
    check isStatusGoOwnedCanonicalLogName("0x4d..2f40.log")
    check isStatusGoOwnedCanonicalLogName("api.log")
    check isStatusGoOwnedCanonicalLogName("geth.log")
    check not isStatusGoOwnedCanonicalLogName("keycard.log")
    check not isStatusGoOwnedCanonicalLogName("some_random.log")
    check not isStatusGoOwnedCanonicalLogName("pre_login-2026-08-14T11-08-48Z.log")
    check not isStatusGoOwnedCanonicalLogName("app_20260814_083321.log")

  test "clear closed logs removes closed files and preserves active ones":
    let processStartedAt = getTime()
    let closedTime = processStartedAt - initDuration(hours = 1)
    let activeTime = processStartedAt + initDuration(seconds = 1)
    let closedAppLog = logsDir / "app_20260101_000000.log"
    let closedArchive = logsDir / "pre_login-2026-08-14T11-08-48Z.log"
    let closedArchiveGz = logsDir / "api-2026-08-14T13-37-56.000.log.gz"
    let activeAppLog = logsDir / "app_20260102_000000.log"
    let closedDataArchive = dataDir / "0x4d..2f40-2026-08-14T13-37-56.000.log"
    # in-process status-go (desktop/iOS): mtime is a valid liveness test, so
    # closed canonical files are deletable and active ones are kept
    let closedCanonicalLog = dataDir / "geth.log"
    let closedNestedLog = dataDir / "keycard" / "keycard.log"
    let activeCanonicalLog = dataDir / "pre_login.log"
    let dataFile = dataDir / "node-config.json"

    writeLog(closedAppLog, closedTime)
    writeLog(closedArchive, closedTime)
    writeLog(closedArchiveGz, closedTime)
    writeLog(activeAppLog, activeTime)
    writeLog(closedDataArchive, closedTime)
    writeLog(closedCanonicalLog, closedTime)
    writeLog(closedNestedLog, closedTime)
    writeLog(activeCanonicalLog, activeTime)
    writeFile(dataFile, "config")

    let result = cleanupLogFiles(logsDir, dataDir, processStartedAt, ClearClosedLogs,
      protectStatusGoCanonical = false)

    check result.deletedCount == 6
    check result.failedCount == 0
    check not fileExists(closedAppLog)
    check not fileExists(closedArchive)
    check not fileExists(closedArchiveGz)
    check not fileExists(closedDataArchive)
    check not fileExists(closedCanonicalLog)
    check not fileExists(closedNestedLog)
    check fileExists(activeAppLog)
    check fileExists(activeCanonicalLog)
    check fileExists(dataFile)

  test "clear closed logs protects status-go canonical files when out of process":
    # Android: the status-go service outlives the UI process, so its canonical
    # files may be live even with an old mtime. UI-owned files (keycard.log)
    # still follow the mtime test.
    let processStartedAt = getTime()
    let closedTime = processStartedAt - initDuration(hours = 1)
    let statusGoLiveLog = dataDir / "pre_login.log"
    let statusGoProfileLog = dataDir / "0x4d..2f40.log"
    let statusGoArchive = dataDir / "pre_login-2026-08-14T11-08-48Z.log"
    let uiOwnedLog = dataDir / "keycard" / "keycard.log"

    writeLog(statusGoLiveLog, closedTime)
    writeLog(statusGoProfileLog, closedTime)
    writeLog(statusGoArchive, closedTime)
    writeLog(uiOwnedLog, closedTime)

    let result = cleanupLogFiles(logsDir, dataDir, processStartedAt, ClearClosedLogs,
      protectStatusGoCanonical = true)

    check result.deletedCount == 2
    check fileExists(statusGoLiveLog)
    check fileExists(statusGoProfileLog)
    # archives are closed by definition (status-go renamed them)
    check not fileExists(statusGoArchive)
    check not fileExists(uiOwnedLog)

  test "retention keeps the newest files per family":
    let processStartedAt = getTime()
    let activeTime = processStartedAt + initDuration(seconds = 1)

    # 5 closed app logs, newest first should survive with cap 3
    for i in 1 .. 5:
      writeLog(logsDir / ("app_2026081" & $i & "_083321.log"),
        processStartedAt - initDuration(days = 10 - i))

    # another family should not be affected by the app family's overflow
    writeLog(logsDir / "pre_login-2026-08-14T11-08-48Z.log",
      processStartedAt - initDuration(days = 9))
    writeLog(logsDir / "pre_login-2026-08-15T11-08-48Z.log",
      processStartedAt - initDuration(days = 8))

    # active file is kept and does not count against the cap
    writeLog(logsDir / "app_20260816_083321.log", activeTime)

    let result = cleanupLogFiles(logsDir, dataDir, processStartedAt,
      RemoveExpiredLogs, maxFilesPerFamily = 3)

    check result.deletedCount == 2
    check result.failedCount == 0
    # oldest two app logs removed
    check not fileExists(logsDir / "app_20260811_083321.log")
    check not fileExists(logsDir / "app_20260812_083321.log")
    check fileExists(logsDir / "app_20260813_083321.log")
    check fileExists(logsDir / "app_20260814_083321.log")
    check fileExists(logsDir / "app_20260815_083321.log")
    check fileExists(logsDir / "pre_login-2026-08-14T11-08-48Z.log")
    check fileExists(logsDir / "pre_login-2026-08-15T11-08-48Z.log")
    check fileExists(logsDir / "app_20260816_083321.log")

  test "retention counts family members across both directories":
    let processStartedAt = getTime()

    writeLog(logsDir / "pre_login-2026-08-15T11-08-48Z.log",
      processStartedAt - initDuration(days = 1))
    writeLog(dataDir / "pre_login-2026-08-14T11-08-48Z.log",
      processStartedAt - initDuration(days = 2))
    writeLog(dataDir / "pre_login-2026-08-13T11-08-48Z.log",
      processStartedAt - initDuration(days = 3))

    let result = cleanupLogFiles(logsDir, dataDir, processStartedAt,
      RemoveExpiredLogs, maxFilesPerFamily = 2)

    check result.deletedCount == 1
    check fileExists(logsDir / "pre_login-2026-08-15T11-08-48Z.log")
    check fileExists(dataDir / "pre_login-2026-08-14T11-08-48Z.log")
    check not fileExists(dataDir / "pre_login-2026-08-13T11-08-48Z.log")

  test "retention clamps the cap to the allowed range":
    let processStartedAt = getTime()
    writeLog(logsDir / "app_20260814_083321.log",
      processStartedAt - initDuration(days = 1))
    writeLog(logsDir / "app_20260815_083321.log",
      processStartedAt - initDuration(days = 2))

    let result = cleanupLogFiles(logsDir, dataDir, processStartedAt,
      RemoveExpiredLogs, maxFilesPerFamily = 0)

    # cap 0 clamps to 1: newest survives
    check result.deletedCount == 1
    check fileExists(logsDir / "app_20260814_083321.log")
    check not fileExists(logsDir / "app_20260815_083321.log")

  test "missing log directories are ignored":
    let currentTime = getTime()
    let missingLogsDir = tempDir / "missing-logs"
    let missingDataDir = tempDir / "missing-data"
    let result = cleanupLogFiles(missingLogsDir, missingDataDir, currentTime, ClearClosedLogs)

    check result.deletedCount == 0
    check result.failedCount == 0

  test "migration moves closed logs from data dir into logs dir":
    let processStartedAt = getTime()
    let closedTime = processStartedAt - initDuration(hours = 1)
    let activeTime = processStartedAt + initDuration(seconds = 1)

    writeLog(dataDir / "pre_login.log", closedTime)
    writeLog(dataDir / "pre_login-2026-08-14T11-08-48Z.log", closedTime)
    writeLog(dataDir / "keycard" / "keycard.log", closedTime)
    writeLog(dataDir / "0x4d..2f40.log", activeTime) # active: stays
    writeLog(logsDir / "pre_login-2026-08-14T11-08-48Z.log", closedTime) # collision
    writeFile(dataDir / "node-config.json", "config")

    let result = migrateLegacyLogFiles(dataDir, logsDir, processStartedAt,
      migrateStatusGoCanonicalNames = true)

    check result.movedCount == 3
    check result.failedCount == 0
    # canonical files are moved under a timestamped archive name so they can't
    # collide with the new live file at the destination
    check not fileExists(logsDir / "pre_login.log")
    check not fileExists(logsDir / "keycard.log")
    check not fileExists(dataDir / "pre_login.log")
    check not fileExists(dataDir / "keycard" / "keycard.log")
    check countLogs(logsDir, "keycard-") == 1
    # the archive rename must keep the file in its original retention family
    for kind, path in walkDir(logsDir):
      if kind == pcFile and extractFilename(path).startsWith("keycard-"):
        check logFamily(path) == "keycard"
    # the canonical pre_login.log and the colliding archive both got fresh
    # archive names next to the pre-existing one
    check countLogs(logsDir, "pre_login-") == 3
    check not fileExists(dataDir / "pre_login-2026-08-14T11-08-48Z.log")
    # active file untouched
    check fileExists(dataDir / "0x4d..2f40.log")
    check fileExists(dataDir / "node-config.json")

  test "migration leaves status-go canonical names in place when not permitted":
    # On Android the status-go service may still be writing pre_login.log /
    # 0x….log even though this (UI) process just started. UI-owned canonical
    # files (keycard.log) are still migrated.
    let processStartedAt = getTime()
    let closedTime = processStartedAt - initDuration(hours = 1)

    writeLog(dataDir / "pre_login.log", closedTime)
    writeLog(dataDir / "0x4d..2f40.log", closedTime)
    writeLog(dataDir / "pre_login-2026-08-14T11-08-48Z.log", closedTime)
    writeLog(dataDir / "keycard" / "keycard.log", closedTime)

    let result = migrateLegacyLogFiles(dataDir, logsDir, processStartedAt,
      migrateStatusGoCanonicalNames = false)

    check result.movedCount == 2
    check fileExists(dataDir / "pre_login.log")
    check fileExists(dataDir / "0x4d..2f40.log")
    check fileExists(logsDir / "pre_login-2026-08-14T11-08-48Z.log")
    check not fileExists(dataDir / "keycard" / "keycard.log")
    check countLogs(logsDir, "keycard-") == 1

  test "migration preserves modification times":
    let processStartedAt = getTime()
    let closedTime = processStartedAt - initDuration(hours = 5)
    writeLog(dataDir / "pre_login-2026-08-14T11-08-48Z.log", closedTime)

    discard migrateLegacyLogFiles(dataDir, logsDir, processStartedAt,
      migrateStatusGoCanonicalNames = true)

    let movedInfo = getFileInfo(logsDir / "pre_login-2026-08-14T11-08-48Z.log")
    check abs(inSeconds(movedInfo.lastWriteTime - closedTime)) <= 1

  test "logs total size covers both directories":
    let processStartedAt = getTime()
    writeLog(logsDir / "app_20260814_083321.log", processStartedAt)
    writeLog(dataDir / "pre_login.log", processStartedAt)
    writeFile(dataDir / "node-config.json", "not counted")

    check logsTotalSizeBytes(logsDir, dataDir) == 2 * len("log")

  test "startup cleanup task runs on the shared thread pool":
    let processStartedAt = getTime()
    writeLog(logsDir / "app_20260814_083321.log",
      processStartedAt - initDuration(days = 1))
    writeLog(logsDir / "app_20260815_083321.log",
      processStartedAt - initDuration(days = 2))
    let threadpool = newThreadPool()

    scheduleLogFamilyCleanup(threadpool, logsDir, dataDir, processStartedAt,
      maxFilesPerFamily = 1)
    threadpool.teardown()

    check fileExists(logsDir / "app_20260814_083321.log")
    check not fileExists(logsDir / "app_20260815_083321.log")
