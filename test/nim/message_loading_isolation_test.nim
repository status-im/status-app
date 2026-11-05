import std/[atomics, importutils, monotimes, os, strutils, tempfiles, times, unittest]
import nimqml
import taskpools
import app/core/tasks/[qt, threadpool]
from seaqt/qcoreapplication import QCoreApplication, create, processEvents

privateAccess(ThreadPool)

type
  BlockingTaskArg = ref object of TaskArg
  LocalReadTaskArg = ref object of QObjectTaskArg
    path: string
    sequence: int

var
  blockersStarted: Atomic[int]
  releaseBlockers: Atomic[bool]
  readsFinished: Atomic[int]
  readsCorrect: Atomic[bool]

QtObject:
  type Receiver = ref object of QObject
    order: seq[int]
    completionThread: int

  proc delete(self: Receiver)

  proc newReceiver(): Receiver =
    new(result, delete)
    result.QObject.setup

  proc delete(self: Receiver) =
    self.QObject.delete

  proc onRead*(self: Receiver, response: string) {.slot.} =
    self.order.add(parseInt(response))
    self.completionThread = getThreadId()

discard QCoreApplication.create()

proc blockedIO(encoded: string) {.gcsafe, nimcall.} =
  discard blockersStarted.fetchAdd(1)
  while not releaseBlockers.load():
    sleep(1)

proc localRead(encoded: string) {.gcsafe, nimcall.} =
  let arg = decode[LocalReadTaskArg](encoded)
  if readFile(arg.path) != "already on this device" or
      readsFinished.load() != arg.sequence:
    readsCorrect.store(false)
  discard readsFinished.fetchAdd(1)
  arg.finish($arg.sequence)

proc waitFor(counter: var Atomic[int], target: int): bool =
  let deadline = getMonoTime() + initDuration(seconds = 2)
  while counter.load() < target and getMonoTime() < deadline:
    sleep(1)
  counter.load() == target

suite "local message read isolation":
  test "local reads complete in FIFO order while every general worker is blocked":
    let path = createTempDir("status-message-reads-", "") / "messages"
    writeFile(path, "already on this device")
    # Worker zero is the GUI/submitting thread and must not help execute tasks.
    let pool = ThreadPool(pool: Taskpool.new(num_threads = 3))
    blockersStarted.store(0)
    releaseBlockers.store(false)
    readsFinished.store(0)
    readsCorrect.store(true)
    try:
      for i in 1 .. 2:
        pool.start(BlockingTaskArg(tptr: blockedIO))
        require waitFor(blockersStarted, i)

      for i in 0 ..< 20:
        pool.startLocalRead(LocalReadTaskArg(tptr: localRead, path: path, sequence: i))

      check waitFor(readsFinished, 20)
      check readsCorrect.load()
      check not releaseBlockers.load()
    finally:
      releaseBlockers.store(true)
      pool.teardown()
      removeFile(path)
      removeDir(parentDir(path))

  test "teardown drains accepted local reads and can be repeated":
    let path = createTempDir("status-message-drain-", "") / "messages"
    writeFile(path, "already on this device")
    let pool = ThreadPool(pool: Taskpool.new(num_threads = 2))
    readsFinished.store(0)
    readsCorrect.store(true)
    try:
      for i in 0 ..< 20:
        pool.startLocalRead(LocalReadTaskArg(tptr: localRead, path: path, sequence: i))
      pool.teardown()
      pool.teardown()
      check readsFinished.load() == 20
      check readsCorrect.load()
      expect ValueError:
        pool.startLocalRead(LocalReadTaskArg(tptr: localRead, path: path))
    finally:
      pool.teardown()
      removeFile(path)
      removeDir(parentDir(path))

  test "local read completion reaches its QObject on the GUI thread":
    let path = createTempDir("status-message-completion-", "") / "messages"
    writeFile(path, "already on this device")
    let pool = ThreadPool(pool: Taskpool.new(num_threads = 2))
    let receiver = newReceiver()
    readsFinished.store(0)
    readsCorrect.store(true)
    try:
      pool.startLocalRead(LocalReadTaskArg(tptr: localRead, path: path,
        vptr: cast[uint](receiver.vptr), slot: "onRead"))
      require waitFor(readsFinished, 1)
      check receiver.order.len == 0
      let deadline = getMonoTime() + initDuration(seconds = 2)
      while receiver.order.len == 0 and getMonoTime() < deadline:
        QCoreApplication.processEvents()
        sleep(1)
      check receiver.order == @[0]
      check receiver.completionThread == getThreadId()
      check readsCorrect.load()
    finally:
      pool.teardown()
      receiver.delete()
      removeFile(path)
      removeDir(parentDir(path))

  test "teardown without any local reads does not create a worker":
    let pool = ThreadPool(pool: Taskpool.new(num_threads = 2))
    check pool.localReads == nil
    pool.teardown()
    pool.teardown()
