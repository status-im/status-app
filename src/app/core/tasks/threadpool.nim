import # std libs
  std/atomics

import # status-desktop libs
  ./common, ./typed_handoff, app/global/feature_flags, app/core/signal_handler

featureGuard THREADPOOL_ENABLED:
  import # std libs
    std/cpuinfo

import # vendor libs
  json_serialization, json, chronicles, taskpools

export common, json_serialization, taskpools.isolate, taskpools.extract

logScope:
  topics = "task-threadpool"

type
  InFlightCount = object
    ## Tasks submitted and not finished yet, shared with the workers. Owns its memory,
    ## so ThreadPoolObj keeps the default destructor (a custom one would stop its
    ## fields from being destroyed).
    count: ptr Atomic[int]
    releasable: bool # set once no worker can touch the count anymore

  ThreadPoolObj* = object
    pool: Taskpool
    tornDown: bool
    localReads: ptr Channel[ThreadSafeTaskArg]
    localReadWorker: Thread[ptr Channel[ThreadSafeTaskArg]]
    closed: Atomic[bool]
    inFlight: InFlightCount
  ThreadPool* = ref ThreadPoolObj
  ThreadSafeTaskArg* = object
    tptr: common.Task
    payload: cstring
    inFlight: ptr Atomic[int]

proc `=destroy`(self: InFlightCount) =
  # Without a teardown workers may still run and update the count: leak it then.
  if self.releasable and not self.count.isNil:
    freeShared(self.count)

proc `=copy`(dest: var InFlightCount, src: InFlightCount) {.error.}

proc safe[T: TaskArg](taskArg: T, inFlight: ptr Atomic[int]): ThreadSafeTaskArg =
  var
    strArgs = taskArg.encode()
    res = cast[cstring](allocShared(strArgs.len + 1))

  copyMem(res, strArgs.cstring, strArgs.len)
  res[strArgs.len] = '\0'
  ThreadSafeTaskArg(tptr: taskArg.tptr, payload: res, inFlight: inFlight)

proc toString*(input: ThreadSafeTaskArg): string =
  result = $(input.payload)
  deallocShared input.payload

proc teardown*(self: ThreadPool) =
  ## Blocks until every task has finished, then stops the workers. Must run on the
  ## thread that created the pool. Taskpool.shutdown is not reentrant.
  ##
  ## To end a session without blocking the GUI: `advanceSessionGeneration` (so late
  ## completions are dropped), `close`, poll `isIdle`, then `teardown`, which then
  ## returns at once and sweeps the typed handoffs whose delivery was dropped. Only
  ## then start the next session's pool: the sweep is global.
  if self.tornDown:
    return
  self.tornDown = true
  self.closed.store(true)

  featureGuard THREADPOOL_ENABLED:
    self.pool.syncAll()
    self.pool.shutdown()
    if self.localReads != nil:
      self.localReads[].send(ThreadSafeTaskArg())
      joinThread(self.localReadWorker)
      self.localReads[].close()
      deallocShared(self.localReads)
      self.localReads = nil
  # Sweep any typed completions parked by workers whose GUI slot never ran (loop
  # stopped mid-flight, or delivery dropped as stale). All workers have stopped by
  # this point, so no producer can race the drain. Destroys them on the shutdown
  # thread — see typed_handoff.
  drainHandoffs()
  self.inFlight.releasable = true

proc close*(self: ThreadPool) =
  ## Stops accepting tasks: later `start` calls are logged and dropped. Tasks already
  ## submitted keep running.
  self.closed.store(true)

proc isClosed*(self: ThreadPool): bool =
  self.closed.load()

proc inFlightCount*(self: ThreadPool): int =
  self.inFlight.count[].load()

proc isIdle*(self: ThreadPool): bool =
  ## No submitted task is still running, so `teardown` returns without waiting.
  self.inFlightCount() == 0

proc newThreadPool*(numThreads = 0): ThreadPool =
  ## `numThreads` 0 means one per processor.
  new(result)
  result.inFlight = InFlightCount(count: createShared(Atomic[int]))
  featureGuard THREADPOOL_ENABLED:
    let nthreads = if numThreads > 0: numThreads else: countProcessors()
    result.pool = Taskpool.new(num_threads = nthreads)

proc runTask(safeTaskArg: ThreadSafeTaskArg) {.gcsafe, nimcall, raises: [].} =
  defer: discard safeTaskArg.inFlight[].fetchSub(1)
  let taskArg = safeTaskArg.toString()
  var parsed: JsonNode

  try:
    parsed = parseJson(taskArg)
  except Exception as e:
    error "[threadpool task thread] parsing task arg", error=e.msg
    return

  let messageType = parsed{"$type"}.getStr

  if defined(production):
    debug "[threadpool task thread] initiating task", messageType=messageType,
      threadid=getThreadId()
  else:
    debug "[threadpool task thread] initiating task", messageType=messageType,
      threadid=getThreadId(), task=taskArg

  try:
    safeTaskArg.tptr(taskArg)
  except Exception as e:
    error "[threadpool task thread] exception", error=e.msg

proc logDroppedTask(taskType: string) =
  # Kept out of the generic `start`: chronicles would resolve its stream at every
  # instantiation site.
  warn "dropping a task submitted to a closed thread pool", taskType

proc admit[T: TaskArg](self: ThreadPool, arg: T): bool =
  ## Stamps an admitted task with the session generation and counts it in flight.
  if self.closed.load():
    logDroppedTask($T)
    return false
  arg.sessionGeneration = currentSessionGeneration()
  discard self.inFlight.count[].fetchAdd(1)
  true

proc start*[T: TaskArg](self: ThreadPool, arg: T) =
  if not self.admit(arg):
    return
  featureGuard THREADPOOL_ENABLED:
    self.pool.spawn runTask(arg.safe(self.inFlight.count))
  else:
    runTask(arg.safe(self.inFlight.count))

proc runLocalReads(queue: ptr Channel[ThreadSafeTaskArg]) {.thread.} =
  while true:
    let task = queue[].recv()
    if task.tptr == nil:
      break
    runTask(task)

proc startLocalRead*[T: TaskArg](self: ThreadPool, arg: T) =
  ## Submit on the GUI thread, like start. Only local, read-only work belongs
  ## here: network waits must never occupy this worker. Admission, the session
  ## generation and the in-flight count are the same as for `start`.
  if not self.admit(arg):
    return
  featureGuard THREADPOOL_ENABLED:
    if self.localReads == nil:
      # A separate Taskpool would overwrite the submitting thread's taskpools
      # workerContext. Use a native worker and FIFO instead.
      let queue = cast[ptr Channel[ThreadSafeTaskArg]](
        allocShared0(sizeof(Channel[ThreadSafeTaskArg])))
      queue[].open()
      try:
        createThread(self.localReadWorker, runLocalReads, queue)
      except:
        queue[].close()
        deallocShared(queue)
        discard self.inFlight.count[].fetchSub(1)
        raise
      self.localReads = queue
    self.localReads[].send(arg.safe(self.inFlight.count))
  else:
    runTask(arg.safe(self.inFlight.count))
