## B1: Cross-thread refcount stress test for CowSeq.
##
## The whole point of CowSeq in this PR is to cross the service<->UI thread
## boundary safely.  The refcount must therefore tolerate concurrent
## inc/dec from multiple threads without dropping refs (use-after-free) or
## holding them too long (leak).
##
## This test spawns N consumer threads that repeatedly copy and destroy
## snapshots of a single producer-side CowSeq.  At the end the producer's
## refcount must be exactly 1 (only the producer holds it).
##
## Build with `--threads:on -d:testing`.

{.define: testing.}

import unittest
import app/core/cow_seq

const NumConsumers = 8
const IterationsPerConsumer = 5_000

type ConsumerArg = ref object
  snapshot: CowSeq[int]

proc consumerLoop(arg: ConsumerArg) {.thread.} =
  for _ in 0 ..< IterationsPerConsumer:
    var copy = arg.snapshot  # =copy: refCount.fetchAdd
    doAssert copy.len == 1000
    # copy is destroyed at end of loop iteration: refCount.fetchSub

suite "CowSeq - thread safety":
  test "B1: concurrent copy/destroy from many threads keeps refcount sane":
    var data = newSeq[int](1000)
    for i in 0 ..< 1000:
      data[i] = i
    var producer = toCowSeq(data)

    var threads: array[NumConsumers, Thread[ConsumerArg]]
    var args: array[NumConsumers, ConsumerArg]
    for i in 0 ..< NumConsumers:
      args[i] = ConsumerArg(snapshot: producer)
      createThread(threads[i], consumerLoop, args[i])

    for i in 0 ..< NumConsumers:
      joinThread(threads[i])

    # Tear down the per-thread args so their CoW refs go away.
    for i in 0 ..< NumConsumers:
      args[i] = nil

    GC_fullCollect()

    # Producer is the only remaining holder.  If any consumer destructor
    # had raced and dropped a ref incorrectly, this would be < 1 (and
    # producer would be dangling).  Over-increment would leave it > 1.
    check producer.getRefCount == 1
    check producer.len == 1000
