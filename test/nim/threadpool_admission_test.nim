## ThreadPool admission control for in-process logout: a closed pool drops new tasks,
## submitted tasks are stamped with the session generation, and `isIdle` lets the
## owner wait for running tasks without blocking in `teardown`.

import unittest, os, std/atomics
import app/core/tasks/threadpool
import app/core/signal_handler

type
  CountTaskArg = ref object of TaskArg
    holdMs: int

var ran: Atomic[int]
var lastGeneration: Atomic[uint64]
var release: Atomic[bool]

proc countTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[CountTaskArg](argEncoded)
  lastGeneration.store(arg.generation)
  while arg.holdMs > 0 and not release.load():
    sleep(1)
  discard ran.fetchAdd(1)

proc waitUntil(cond: proc(): bool): bool =
  for _ in 0 ..< 2000:
    if cond():
      return true
    sleep(1)
  cond()

suite "ThreadPool admission":

  setup:
    ran.store(0)
    release.store(false)

  test "tasks carry the session generation they were submitted in":
    let pool = newThreadPool()
    let generation = advanceSessionGeneration()
    pool.start(CountTaskArg(tptr: countTask))
    check waitUntil(proc(): bool = ran.load() == 1)
    check lastGeneration.load() == generation
    pool.teardown()

  test "a closed pool drops new tasks":
    let pool = newThreadPool()
    pool.close()
    check pool.isClosed()
    pool.start(CountTaskArg(tptr: countTask))
    sleep(20)
    check ran.load() == 0
    check pool.isIdle()
    pool.teardown()

  test "isIdle stays false while a task runs, teardown is immediate once idle":
    let pool = newThreadPool()
    pool.start(CountTaskArg(tptr: countTask, holdMs: 1))
    check waitUntil(proc(): bool = pool.inFlightCount() == 1)
    pool.close()
    sleep(20)
    check not pool.isIdle()

    release.store(true)
    check waitUntil(proc(): bool = pool.isIdle())
    pool.teardown()
    check ran.load() == 1

  test "start after teardown is dropped":
    let pool = newThreadPool()
    pool.teardown()
    pool.start(CountTaskArg(tptr: countTask))
    sleep(20)
    check ran.load() == 0
    check pool.isIdle()
