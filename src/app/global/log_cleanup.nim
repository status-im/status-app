import std/[locks, os, strutils, times]

const LogRetentionDays* = 14

type
  LogCleanupMode* = enum
    ClearClosedLogs,
    RemoveExpiredLogs

  LogCleanupResult* = object
    deletedCount*: int
    failedCount*: int
    skippedCount*: int

var cleanupLock: Lock
var logCleanupStartedAt = getTime()

initLock(cleanupLock)

proc initializeLogCleanup*(processStartedAt: Time) =
  logCleanupStartedAt = processStartedAt

proc logCleanupProcessStartedAt*(): Time =
  logCleanupStartedAt

proc isDataLogFile(path: string): bool =
  path.toLowerAscii().endsWith(".log")

proc shouldRemove(fileTime, processStartedAt, currentTime: Time,
    mode: LogCleanupMode): bool =
  if fileTime >= processStartedAt:
    return false

  return mode == ClearClosedLogs or
    fileTime < currentTime - initDuration(days = LogRetentionDays)

proc cleanupFile(path: string, processStartedAt, currentTime: Time,
    mode: LogCleanupMode, result: var LogCleanupResult) =
  try:
    let fileInfo = getFileInfo(path, followSymlink = false)
    if fileInfo.kind != pcFile:
      inc result.skippedCount
      return

    if not shouldRemove(fileInfo.lastWriteTime, processStartedAt, currentTime, mode):
      inc result.skippedCount
      return

    if tryRemoveFile(path):
      inc result.deletedCount
    elif fileExists(path):
      inc result.failedCount
  except OSError:
    if fileExists(path):
      inc result.failedCount

proc cleanupDataDirectory(directory: string, processStartedAt, currentTime: Time,
    mode: LogCleanupMode, result: var LogCleanupResult) =
  if not dirExists(directory):
    return

  try:
    for kind, path in walkDir(directory):
      case kind
      of pcFile:
        if isDataLogFile(path):
          cleanupFile(path, processStartedAt, currentTime, mode, result)
      of pcDir:
        cleanupDataDirectory(path, processStartedAt, currentTime, mode, result)
      else:
        discard
  except OSError:
    inc result.failedCount

proc cleanupLogFiles*(logsDir, dataDir: string, processStartedAt, currentTime: Time,
    mode: LogCleanupMode): LogCleanupResult =
  acquire(cleanupLock)
  defer:
    release(cleanupLock)

  if dirExists(logsDir):
    try:
      for kind, path in walkDir(logsDir):
        if kind == pcFile:
          cleanupFile(path, processStartedAt, currentTime, mode, result)
    except OSError:
      inc result.failedCount

  cleanupDataDirectory(dataDir, processStartedAt, currentTime, mode, result)