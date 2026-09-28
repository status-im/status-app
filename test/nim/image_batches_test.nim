import unittest, sequtils, options

import app_service/service/chat/image_batches

proc paths(n: int): seq[string] =
  result = @[]
  for i in 0 ..< n: result.add("/img/" & $i & ".png")

suite "image batches - chunking":
  test "splits into messages of IMAGES_PER_MESSAGE with the text on the first one":
    let batches = imageBatches(paths(13), "t")
    check(batches.mapIt(it.imagePaths.len) == @[6, 6, 1])
    check(batches.mapIt(it.withText) == @[true, false, false])
    check(batches.mapIt(it.token) == @["t-0", "t-1", "t-2"])
    check(batches[0].imagePaths[0] == "/img/0.png" and batches[2].imagePaths[0] == "/img/12.png")

  test "up to IMAGES_PER_MESSAGE images stay a single message":
    let batches = imageBatches(paths(IMAGES_PER_MESSAGE), "t")
    check(batches.len == 1)
    check(batches[0].withText)
    check(batches[0].imagePaths.len == IMAGES_PER_MESSAGE)

  test "no images means no batches":
    check(imageBatches(@[], "t").len == 0)

  test "token numbering continues from firstIndex":
    check(imageBatches(paths(7), "t", firstIndex = 3).mapIt(it.token) == @["t-3", "t-4"])

  test "custom per-message size":
    check(imageBatches(paths(5), "t", perMessage = 2).mapIt(it.imagePaths.len) == @[2, 2, 1])

suite "image batches - sequential dispatch":
  test "one batch in flight at a time, advancing per finished token":
    var queue: ImageBatchQueue
    enqueueBatches(queue, imageBatches(paths(13), "t"))

    let first = takeNextBatch(queue)
    check(first.isSome and first.get().token == "t-0")
    check(takeNextBatch(queue).isNone)   # t-0 still in flight

    check(finishBatch(queue, "t-0"))
    let second = takeNextBatch(queue)
    check(second.isSome and second.get().token == "t-1")
    check(finishBatch(queue, "t-1"))
    let third = takeNextBatch(queue)
    check(third.isSome and third.get().token == "t-2")
    check(finishBatch(queue, "t-2"))
    check(takeNextBatch(queue).isNone)
    check(queue.pending.len == 0 and queue.inFlight == "")

  test "finished signals for other tokens do not advance the queue":
    var queue: ImageBatchQueue
    enqueueBatches(queue, imageBatches(paths(7), "t"))
    discard takeNextBatch(queue)
    check(not finishBatch(queue, "other"))
    check(not finishBatch(queue, "t-1"))   # not dispatched yet
    check(not finishBatch(queue, "t"))     # send token, not a batch token
    check(takeNextBatch(queue).isNone)
    check(finishBatch(queue, "t-0"))
    check(not finishBatch(queue, "t-0"))   # already finished

  test "a failed batch does not stall the remaining ones":
    # The chat service emits the finished signal on failure too, so the
    # queue only ever sees "finished"; the next batch goes out regardless.
    var queue: ImageBatchQueue
    enqueueBatches(queue, imageBatches(paths(13), "t"))
    var dispatched: seq[string] = @[]
    while true:
      let next = takeNextBatch(queue)
      if next.isNone: break
      dispatched.add(next.get().token)
      check(finishBatch(queue, next.get().token))   # failure or success alike
    check(dispatched == @["t-0", "t-1", "t-2"])

  test "a synchronous finished signal still matches right after dispatch":
    var queue: ImageBatchQueue
    enqueueBatches(queue, imageBatches(paths(1), "t"))
    let batch = takeNextBatch(queue)
    check(batch.isSome)
    check(queue.inFlight == batch.get().token)
    check(finishBatch(queue, batch.get().token))

  test "a second send queues behind the first in order":
    var queue: ImageBatchQueue
    enqueueBatches(queue, imageBatches(paths(7), "a"))
    enqueueBatches(queue, imageBatches(paths(2), "b"))
    var order: seq[string] = @[]
    while true:
      let next = takeNextBatch(queue)
      if next.isNone: break
      order.add(next.get().token)
      discard finishBatch(queue, next.get().token)
    check(order == @["a-0", "a-1", "b-0"])

  test "idle queue yields nothing":
    var queue: ImageBatchQueue
    check(takeNextBatch(queue).isNone)
    check(not finishBatch(queue, "t-0"))
