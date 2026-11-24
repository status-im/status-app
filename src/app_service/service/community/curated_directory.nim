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
    newCommunitiesDotChanged*: proc(shown: bool)

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
    enteredSuspended: bool
    busy: bool
    runId: int
    minAcceptedRunId: int
    highestRunId: int
    startedRunId: int
    finishedRunId: int
    directoryFailed: bool
    failed: bool
    readFailed: bool
    finishes: int
    outcomePending: bool
    error: CuratedRefreshError
    loadedAtLeave: int
    snapshotPending: bool
    dotPending: bool
    dot: bool

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
  if not self.open:
    return
  if (self.directoryFailed and self.empty) or ((self.failed or self.readFailed) and self.backend.loaded() == 0):
    self.setError(CuratedRefreshError.Full)
  elif self.directoryFailed or self.failed or self.readFailed:
    self.setError(CuratedRefreshError.Partial)
  else:
    self.setError(CuratedRefreshError.None)

proc setDot(self: CuratedDirectory, shown: bool) =
  if shown == self.dot:
    return
  self.dot = shown
  self.backend.newCommunitiesDotChanged(shown)

proc checkDot(self: CuratedDirectory) =
  if self.reading:
    return
  self.dotPending = false
  if not self.open and self.backend.loaded() > self.loadedAtLeave:
    self.setDot(true)

proc concludeClosed(self: CuratedDirectory) =
  if self.open:
    return
  self.dotPending = true
  self.checkDot()

proc accepts(self: CuratedDirectory, runId: int): bool =
  if runId == CuratedRunUnknown:
    return true
  self.highestRunId = max(self.highestRunId, runId)
  runId >= self.minAcceptedRunId

proc start(self: CuratedDirectory) =
  self.requestRead()
  let finishesBefore = self.finishes
  let reply = self.backend.refresh()
  let runId = if reply.asked: reply.runId else: 0
  self.runId = runId
  self.refreshing = runId != 0
  if runId > 0:
    self.minAcceptedRunId = runId
    self.highestRunId = max(self.highestRunId, runId)
  elif runId == 0:
    self.minAcceptedRunId = high(int)
  let finishedDuringCall = runId == CuratedRunUnknown and self.finishes != finishesBefore
  if (runId > 0 and runId == self.finishedRunId) or finishedDuringCall:
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
  let wasRefreshing = self.refreshing
  self.refreshing = false
  self.minAcceptedRunId = self.highestRunId + 1
  if wasRefreshing:
    self.backend.stop()
  self.update()

proc enter*(self: CuratedDirectory) =
  self.open = true
  self.outcomePending = false
  self.dotPending = false
  self.setDot(false)
  self.snapshotPending = false
  if self.suspended:
    self.enteredSuspended = true
  elif self.refreshing:
    self.requestRead()
  else:
    self.start()

proc leave*(self: CuratedDirectory) =
  self.open = false
  self.snapshotPending = self.reading
  if not self.reading:
    self.loadedAtLeave = self.backend.loaded()
  self.enteredSuspended = false
  self.outcomePending = false

proc suspend*(self: CuratedDirectory) =
  if self.suspended:
    return
  self.suspended = true
  self.interrupted = self.refreshing
  self.halt()

proc resume*(self: CuratedDirectory) =
  if not self.suspended:
    return
  self.suspended = false
  if self.interrupted or (self.open and self.enteredSuspended):
    self.start()
  self.interrupted = false
  self.enteredSuspended = false

proc retry*(self: CuratedDirectory) =
  if self.open and not self.suspended and not self.refreshing:
    self.start()

proc refreshStarted*(self: CuratedDirectory, changed = false, directoryFailed = false, runId = CuratedRunUnknown) =
  if not self.accepts(runId):
    return
  if not self.suspended and (self.open or self.refreshing):
    if runId != CuratedRunUnknown:
      self.runId = runId
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
  if self.suspended and self.interrupted and not cancelled and (runId == CuratedRunUnknown or runId == self.runId):
    self.interrupted = false
    self.failed = failed > 0
    self.judge()
    self.concludeClosed()
    return
  if not self.accepts(runId):
    return
  if cancelled:
    if runId != CuratedRunUnknown and self.refreshing:
      self.refreshing = false
      self.update()
    return
  self.finishedRunId = runId
  inc self.finishes
  if self.refreshing:
    self.refreshing = false
    self.failed = failed > 0
    self.judge()
    self.concludeClosed()
  self.update()

proc readDone*(self: CuratedDirectory, entries = 0, failed = false) =
  self.reading = false
  self.readFailed = failed
  if not failed:
    self.empty = entries == 0
  let again = self.readAgain or (not failed and self.startedDuringRead and self.empty)
  self.readAgain = false
  self.startedDuringRead = false
  if self.snapshotPending and not self.open:
    self.snapshotPending = false
    self.loadedAtLeave = self.backend.loaded()
  if again:
    self.requestRead()
  elif self.outcomePending or (failed and self.open and not self.suspended and not self.refreshing):
    self.judge()
  if self.dotPending:
    self.checkDot()
  self.update()
