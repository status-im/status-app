import json

const CuratedRunUnknown* = -1

type
  CuratedRefreshError* {.pure.} = enum
    None
    Partial
    Full

  CuratedRefreshReply* = object
    asked*: bool
    runId*: int

  CuratedDirectoryBackend* = object
    read*: proc()
    refresh*: proc(): CuratedRefreshReply
    stop*: proc()
    busyChanged*: proc(busy: bool)
    loaded*: proc(): int
    errorChanged*: proc(error: CuratedRefreshError)

  CuratedDirectory* = ref object
    backend: CuratedDirectoryBackend
    open: bool
    reading: bool
    readAgain: bool
    refreshing: bool
    empty: bool
    startedDuringRead: bool
    suspended: bool
    interrupted: bool
    busy: bool
    minAcceptedRunId: int
    highestRunId: int
    startedRunId: int
    finishedRunId: int
    directoryFailed: bool
    failed: bool
    outcomePending: bool
    error: CuratedRefreshError

proc toCuratedRefreshReply*(rpcResult: JsonNode): CuratedRefreshReply =
  result = CuratedRefreshReply(asked: true, runId: CuratedRunUnknown)
  if not rpcResult.isNil and rpcResult.kind == JInt:
    result.runId = rpcResult.getInt()

proc newCuratedDirectory*(backend: CuratedDirectoryBackend): CuratedDirectory =
  CuratedDirectory(backend: backend, empty: true, minAcceptedRunId: 1)

proc update(self: CuratedDirectory) =
  let busy = self.reading or self.refreshing
  if busy == self.busy:
    return
  self.busy = busy
  self.backend.busyChanged(busy)

proc requestRead(self: CuratedDirectory) =
  if self.reading:
    self.readAgain = true
    return
  self.reading = true
  self.backend.read()

proc setError(self: CuratedDirectory, error: CuratedRefreshError) =
  if error == self.error:
    return
  self.error = error
  self.backend.errorChanged(error)

proc judge(self: CuratedDirectory) =
  if self.reading:
    self.outcomePending = true
    return
  self.outcomePending = false
  if (self.directoryFailed and self.empty) or (self.failed and self.backend.loaded() == 0):
    self.setError(CuratedRefreshError.Full)
  elif self.directoryFailed or self.failed:
    self.setError(CuratedRefreshError.Partial)
  else:
    self.setError(CuratedRefreshError.None)

proc accepts(self: CuratedDirectory, runId: int): bool =
  if runId == CuratedRunUnknown:
    return true
  self.highestRunId = max(self.highestRunId, runId)
  runId >= self.minAcceptedRunId

proc start(self: CuratedDirectory) =
  self.requestRead()
  let reply = self.backend.refresh()
  let runId = if reply.asked: reply.runId else: 0
  self.refreshing = runId != 0
  if runId > 0:
    self.minAcceptedRunId = runId
    self.highestRunId = max(self.highestRunId, runId)
  else:
    self.minAcceptedRunId = high(int)
  if runId > 0 and runId == self.finishedRunId:
    self.refreshing = false
  elif self.refreshing:
    self.failed = false
    if runId == CuratedRunUnknown or runId != self.startedRunId:
      self.directoryFailed = false
    self.outcomePending = false
    self.update()
    self.setError(CuratedRefreshError.None)
  elif not reply.asked:
    self.failed = false
    self.directoryFailed = true
    self.judge()
  self.update()

proc halt(self: CuratedDirectory) =
  self.readAgain = false
  self.startedDuringRead = false
  self.refreshing = false
  self.minAcceptedRunId = self.highestRunId + 1
  self.backend.stop()
  self.update()

proc enter*(self: CuratedDirectory) =
  self.open = true
  if self.suspended:
    self.interrupted = true
  else:
    self.start()

proc leave*(self: CuratedDirectory) =
  self.open = false
  self.interrupted = false
  self.outcomePending = false
  self.halt()

proc suspend*(self: CuratedDirectory) =
  if self.suspended:
    return
  self.suspended = true
  if self.open:
    self.interrupted = self.refreshing
    self.halt()

proc resume*(self: CuratedDirectory) =
  if not self.suspended:
    return
  self.suspended = false
  if self.open and self.interrupted:
    self.start()
  self.interrupted = false

proc retry*(self: CuratedDirectory) =
  if self.open and not self.suspended and not self.refreshing:
    self.start()

proc refreshStarted*(self: CuratedDirectory, changed = false, directoryFailed = false, runId = CuratedRunUnknown) =
  if not self.accepts(runId):
    return
  if self.open and not self.suspended:
    self.startedRunId = runId
    self.refreshing = true
    self.failed = false
    self.directoryFailed = directoryFailed
    self.outcomePending = false
    self.update()
    self.setError(CuratedRefreshError.None)
    if changed:
      self.requestRead()
    elif self.reading:
      self.startedDuringRead = true
    elif self.empty:
      self.requestRead()
  self.update()

proc refreshFinished*(self: CuratedDirectory, failed = 0, cancelled = false, runId = CuratedRunUnknown) =
  if cancelled or not self.accepts(runId):
    return
  self.finishedRunId = runId
  if self.refreshing:
    self.refreshing = false
    self.failed = failed > 0
    self.judge()
  self.update()

proc readDone*(self: CuratedDirectory, entries = 0) =
  self.reading = false
  self.empty = entries == 0
  let again = self.readAgain or (self.startedDuringRead and self.empty)
  self.readAgain = false
  self.startedDuringRead = false
  if again:
    self.requestRead()
  elif self.outcomePending:
    self.judge()
  self.update()
