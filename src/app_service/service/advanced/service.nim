import std/[times, os, strutils]

import nimqml, json, chronicles

import app/core/eventemitter
import app/core/signals/types
import app/core/tasks/threadpool
import app/global/log_cleanup
import backend/storage_stats as status_storage_stats
import constants
import ./async_tasks

logScope:
  topics = "advanced-app-service"

const SIGNAL_ADVANCED_LOGS_CLEANUP_FINISHED* = "advancedLogsCleanupFinished"
const SIGNAL_ADVANCED_LOGS_SIZE_UPDATED* = "advancedLogsSizeUpdated"
const SIGNAL_STORAGE_STATS_PROGRESS* = "storageStatsProgress"
const SIGNAL_STORAGE_STATS_FINISHED* = "storageStatsFinished"

## The snapshot goes into LOGDIR so the existing "collect logs" flow bundles it.
## Milliseconds in the name keep two collections in the same second apart.
const STORAGE_STATS_FILE_PREFIX = "storage-stats-"
const STORAGE_STATS_FILE_SUFFIX = ".json"
const STORAGE_STATS_FILE_TIME_FORMAT = "yyyyMMdd-HHmmss'-'fff"

## Result error meaning "aborted by Stop()", not a failure worth showing.
## Mirrors storagestats.ErrCancelled in status-go.
const STORAGE_STATS_CANCELLED = "cancelled"

type AdvancedLogsCleanupFinishedArgs* = ref object of Args
  deletedCount*: int
  failedCount*: int
  error*: string

type StorageStatsProgressArgs* = ref object of Args
  step*: int
  total*: int

type StorageStatsFinishedArgs* = ref object of Args
  ## `data` is the profile as pretty-printed JSON: parsed by the preview, copied
  ## by the user, and written to `snapshotPath`. That path is empty if the file
  ## could not be written, which is not a collection failure.
  data*: string
  snapshotPath*: string
  error*: string

## backend/core wraps a failed RPC into a multi-line
## "status-go error [methodName:..., code:..., message:... ]" string; only the
## message belongs in the UI.
proc rpcErrorMessage(raw: string): string =
  const marker = "message:"
  let start = raw.find(marker)
  if start < 0:
    return raw.strip()

  var message = raw[start + marker.len .. ^1].strip()
  if message.endsWith("]"):
    message = message[0 ..< message.high].strip()
  return message

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    clearingOldLogs: bool
    refreshingLogsSize: bool
    logsFolderSizeBytesCached: float
    collectingStorageStats: bool
    storageStatsRequestId: string
    # Kept for the session: the settings view is built by a Loader and loses its
    # own state on navigation, and re-collecting costs minutes of table scans.
    lastStorageStats: StorageStatsFinishedArgs
    lastStorageStatsCollectedAt: int64

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, threadpool: ThreadPool): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.clearingOldLogs = false
    result.collectingStorageStats = false

  proc isClearingOldLogs*(self: Service): bool =
    return self.clearingOldLogs

  proc logsFolderSizeBytes*(self: Service): float =
    return self.logsFolderSizeBytesCached

  proc refreshLogsFolderSize*(self: Service) =
    if self.refreshingLogsSize:
      return

    self.refreshingLogsSize = true
    let arg = LogsSizeTaskArg(
      tptr: computeLogsSizeTask,
      vptr: cast[uint](self.vptr),
      slot: "onLogsSizeComputed",
      logsDir: LOGDIR,
      dataDir: STATUSGODIR)
    self.threadpool.start(arg)

  proc onLogsSizeComputed*(self: Service, response: string) {.slot.} =
    self.refreshingLogsSize = false
    try:
      let responseObj = response.parseJson
      self.logsFolderSizeBytesCached = responseObj{"sizeBytes"}.getBiggestInt().float
    except Exception as e:
      error "failed to parse logs size response", error = e.msg
    self.events.emit(SIGNAL_ADVANCED_LOGS_SIZE_UPDATED, Args())

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

  proc cleanupLogFamilies*(self: Service, maxFilesPerFamily: int) =
    let arg = LogFamilyCleanupTaskArg(
      tptr: logFamilyCleanupTask,
      vptr: cast[uint](self.vptr),
      slot: "onLogFamilyCleanupFinished",
      logsDir: LOGDIR,
      dataDir: STATUSGODIR,
      processStartedAtUnix: logCleanupProcessStartedAt().toUnix,
      maxFilesPerFamily: maxFilesPerFamily)
    self.threadpool.start(arg)

  proc onLogFamilyCleanupFinished*(self: Service, response: string) {.slot.} =
    self.refreshLogsFolderSize()

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
    self.refreshLogsFolderSize()

  proc isCollectingStorageStats*(self: Service): bool =
    return self.collectingStorageStats

  proc getLastStorageStats*(self: Service): StorageStatsFinishedArgs =
    return self.lastStorageStats

  ## Seconds since the cached profile was collected, or -1 when there is none.
  ## An age, not a timestamp: the artifact must carry no absolute dates.
  proc lastStorageStatsAgeSeconds*(self: Service): int =
    if self.lastStorageStats.isNil:
      return -1
    return int(getTime().toUnix - self.lastStorageStatsCollectedAt)

  ## Returns the path written, or "" on failure.
  proc writeStorageStatsSnapshot(self: Service, content: string): string =
    if content.len == 0:
      return ""
    try:
      let path = LOGDIR / (STORAGE_STATS_FILE_PREFIX &
        now().format(STORAGE_STATS_FILE_TIME_FORMAT) & STORAGE_STATS_FILE_SUFFIX)
      createDir(LOGDIR)
      writeFile(path, content)
      return path
    except Exception as e:
      error "failed to write the storage stats snapshot", error = e.msg
      return ""

  proc finishStorageStats(self: Service, args: StorageStatsFinishedArgs) =
    self.collectingStorageStats = false
    self.storageStatsRequestId = ""
    if args.data.len > 0:
      self.lastStorageStats = args
      self.lastStorageStatsCollectedAt = getTime().toUnix
    self.events.emit(SIGNAL_STORAGE_STATS_FINISHED, args)

  ## Starts a collection in status-go; false if one is already running. The
  ## result arrives through the signals below, never from this call.
  proc collectStorageStats*(self: Service): bool =
    if self.collectingStorageStats:
      return false

    self.collectingStorageStats = true
    try:
      # callPrivateRPC raises on backend errors instead of returning them, so
      # every failure lands in the except branch below.
      let requestId = status_storage_stats.collect().result.getStr()
      if requestId.len == 0:
        self.finishStorageStats(StorageStatsFinishedArgs(
          error: "status-go did not return a request id"))
        return false
      # Signals are delivered on this thread, so no progress event can arrive
      # before the id is assigned.
      self.storageStatsRequestId = requestId
    except Exception as e:
      error "failed to start collecting storage stats", error = e.msg
      self.finishStorageStats(StorageStatsFinishedArgs(error: rpcErrorMessage(e.msg)))
      return false

    return true

  proc init*(self: Service) =
    self.events.on(SignalType.StorageStatsProgress.event) do(e: Args):
      let signal = StorageStatsProgressSignal(e)
      if signal.requestId != self.storageStatsRequestId:
        return
      self.events.emit(SIGNAL_STORAGE_STATS_PROGRESS,
        StorageStatsProgressArgs(step: signal.step, total: signal.total))

    self.events.on(SignalType.StorageStatsResult.event) do(e: Args):
      let signal = StorageStatsResultSignal(e)
      if signal.requestId != self.storageStatsRequestId:
        return

      var args = StorageStatsFinishedArgs(error: signal.error)
      if args.error == STORAGE_STATS_CANCELLED:
        args.error = ""
      elif signal.error.len == 0:
        if not signal.data.isNil and signal.data.kind != JNull:
          # Pretty-printed once; the preview, the clipboard and the file share it.
          args.data = signal.data.pretty()
        args.snapshotPath = self.writeStorageStatsSnapshot(args.data)
      self.finishStorageStats(args)

  proc delete*(self: Service) =
    self.QObject.delete