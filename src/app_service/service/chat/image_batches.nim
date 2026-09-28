import options

const IMAGES_PER_MESSAGE* = 6

type
  ImageBatch* = object
    token*: string
    imagePaths*: seq[string]
    withText*: bool

  ImageBatchQueue* = object
    ## Batches go out one at a time, in order. `inFlight` is the token of the
    ## batch waiting for its finished signal ("" when idle).
    pending*: seq[ImageBatch]
    inFlight*: string

proc imageBatches*(imagePaths: seq[string], tokenPrefix: string, perMessage = IMAGES_PER_MESSAGE,
    firstIndex = 0): seq[ImageBatch] =
  ## Chunks of at most `perMessage` images; only the first chunk carries the text.
  ## Tokens are `<tokenPrefix>-<n>`, numbered from `firstIndex`.
  result = @[]
  var start = 0
  while start < imagePaths.len:
    let stop = min(start + perMessage, imagePaths.len)
    result.add(ImageBatch(token: tokenPrefix & "-" & $(firstIndex + result.len),
      imagePaths: imagePaths[start ..< stop], withText: start == 0))
    start = stop

proc enqueueBatches*(queue: var ImageBatchQueue, batches: seq[ImageBatch]) =
  queue.pending.add(batches)

proc takeNextBatch*(queue: var ImageBatchQueue): Option[ImageBatch] =
  ## Marks the batch in flight BEFORE returning, so a finished signal emitted
  ## synchronously by the send still matches. None while a batch is in flight.
  if queue.inFlight != "" or queue.pending.len == 0:
    return none(ImageBatch)
  let batch = queue.pending[0]
  queue.pending.delete(0)
  queue.inFlight = batch.token
  result = some(batch)

proc finishBatch*(queue: var ImageBatchQueue, token: string): bool =
  ## True iff `token` is the batch in flight (success or failure alike); the
  ## queue is then free for the next dispatch.
  if queue.inFlight == "" or token != queue.inFlight:
    return false
  queue.inFlight = ""
  result = true
