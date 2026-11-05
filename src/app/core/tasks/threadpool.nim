import # status-desktop libs
  ./common, ./typed_handoff, app/global/feature_flags

featureGuard THREADPOOL_ENABLED:
  import # std libs
    std/cpuinfo

import # vendor libs
  json_serialization, json, chronicles, taskpools

export common, json_serialization, taskpools.isolate, taskpools.extract

logScope:
  topics = "task-threadpool"

type
  ThreadPool* = ref object
    pool: Taskpool
    tornDown: bool
    localReads: ptr Channel[ThreadSafeTaskArg]
    localReadWorker: Thread[ptr Channel[ThreadSafeTaskArg]]
  ThreadSafeTaskArg* = object
    tptr: common.Task
    payload: cstring

proc safe*[T: TaskArg](taskArg: T): ThreadSafeTaskArg =
  var
    strArgs = taskArg.encode()
    res = cast[cstring](allocShared(strArgs.len + 1))

  copyMem(res, strArgs.cstring, strArgs.len)
  res[strArgs.len] = '\0'
  ThreadSafeTaskArg(tptr: taskArg.tptr, payload: res)

proc toString*(input: ThreadSafeTaskArg): string =
  result = $(input.payload)
  deallocShared input.payload

proc teardown*(self: ThreadPool) =
  ## Taskpool.shutdown is not reentrant.
  if self.tornDown:
    return
  self.tornDown = true

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
  # stopped mid-flight). All workers are quiesced by this point, so no producer
  # can race the drain. Destroys them on the shutdown thread — see typed_handoff.
  drainHandoffs()

proc newThreadPool*(): ThreadPool =
  new(result)
  featureGuard THREADPOOL_ENABLED:
    var nthreads = countProcessors()
    result.pool = Taskpool.new(num_threads = nthreads)

proc runTask(safeTaskArg: ThreadSafeTaskArg) {.gcsafe, nimcall, raises: [].} =
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

proc start*[T: TaskArg](self: ThreadPool, arg: T) =
  featureGuard THREADPOOL_ENABLED:
    self.pool.spawn runTask(arg.safe())
  else:
    runTask(arg.safe())

proc runLocalReads(queue: ptr Channel[ThreadSafeTaskArg]) {.thread.} =
  while true:
    let task = queue[].recv()
    if task.tptr == nil:
      break
    runTask(task)

proc startLocalRead*[T: TaskArg](self: ThreadPool, arg: T) =
  ## Submit on the GUI thread, like start. Only local, read-only work belongs
  ## here: network waits must never occupy this worker.
  if self.tornDown:
    raise newException(ValueError, "Cannot submit a local read after threadpool teardown")
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
        raise
      self.localReads = queue
    self.localReads[].send(arg.safe())
  else:
    runTask(arg.safe())
