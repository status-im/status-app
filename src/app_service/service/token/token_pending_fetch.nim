## Pure pending-fetch set for the wallet token service.
##
## Replaces the synchronous GUI-thread `getTokensByKeys` RPC in getTokenByKey: a
## miss enqueues the key here and returns nil immediately; the service drains the
## set in a coalesced batch on a worker thread. This module holds only the
## dedup/coalescing bookkeeping so it can be unit-tested without a live Service or
## backend — no scheduling, threadpool, or IO here.

import sequtils, sets, tables

const MissingTokenFetchRetryDelaysMs* = [2000, 5000, 15000]
  ## Backoff before re-fetching the keys of a failed batch; past the last try they give up as missing.

type PendingTokenFetch* = object
  pending: HashSet[string]  ## keys awaiting the next batch fetch
  inFlight: Table[string, int] ## key -> id of the running batch it was handed to (dedup across the fetch window)
  lastBatchId: int
  awaitingRetry: Table[string, int64] ## key -> when its backoff ends (ms)
  failedAttempts: Table[string, int] ## failed fetches of a key since it last settled

proc initPendingTokenFetch*(): PendingTokenFetch =
  PendingTokenFetch(pending: initHashSet[string]())

proc isAwaitingRetry*(self: PendingTokenFetch, key: string): bool =
  self.awaitingRetry.hasKey(key)

proc enqueue*(self: var PendingTokenFetch, key: string): bool =
  ## Record a missing key. Returns true only when the key is newly pending — the
  ## caller uses that to schedule (debounce) a batch exactly once per burst. Keys
  ## already pending or already in flight dedup and return false.
  if key in self.pending or self.inFlight.hasKey(key) or self.isAwaitingRetry(key):
    return false
  self.pending.incl(key)
  return true

proc hasPending*(self: PendingTokenFetch): bool =
  self.pending.len > 0

proc takeBatch*(self: var PendingTokenFetch): tuple[id: int, keys: seq[string]] =
  ## Drain the pending keys into the in-flight set and return them as the batch to
  ## fetch. Draining is atomic from the GUI thread's view: after this the pending
  ## set is empty and the same keys will not be re-enqueued while in flight.
  inc self.lastBatchId
  result = (self.lastBatchId, toSeq(self.pending))
  for key in result.keys:
    self.inFlight[key] = result.id
  self.pending.clear()

proc completeBatch*(self: var PendingTokenFetch, batchId: int): seq[string] =
  ## Release the keys of a finished batch from the in-flight set and return them:
  ## only those still owned by this batch, so a batch drained meanwhile releases
  ## nothing. After this a fresh miss of the same key may enqueue again (the
  ## caches/markers updated by the completion normally make that unnecessary).
  for key, id in self.inFlight:
    if id == batchId:
      result.add(key)
  for key in result:
    self.inFlight.del(key)

proc drainInFlight*(self: var PendingTokenFetch): seq[string] =
  ## Release every in-flight key and return them. For the failure path where a
  ## batch's own key list is unknown (its envelope was undecodable): the batch
  ## cannot be released by completeBatch, so drain everything rather than leave
  ## its keys wedged as permanently in flight. A running batch drained with it
  ## releases nothing when it completes (see completeBatch), so its keys are
  ## retried once, not twice.
  result = toSeq(self.inFlight.keys)
  self.inFlight.clear()

proc failBatch*(self: var PendingTokenFetch, keys: seq[string], nowMs: int64): seq[string] =
  ## Park the (already released) keys of a failed batch until their next backoff
  ## ends. Returns the keys out of tries, which the caller settles as missing.
  for key in keys:
    let attempt = self.failedAttempts.getOrDefault(key) + 1
    if attempt > MissingTokenFetchRetryDelaysMs.len:
      self.failedAttempts.del(key)
      result.add(key)
      continue
    self.failedAttempts[key] = attempt
    self.awaitingRetry[key] = nowMs + MissingTokenFetchRetryDelaysMs[attempt - 1]

proc nextRetryInMs*(self: PendingTokenFetch, nowMs: int64): int =
  ## Time until the earliest backoff ends (0 when one is overdue), -1 when no key awaits a retry.
  result = -1
  for dueMs in self.awaitingRetry.values:
    let remainingMs = max(0, int(dueMs - nowMs))
    if result < 0 or remainingMs < result:
      result = remainingMs

proc releaseDueRetries*(self: var PendingTokenFetch, nowMs: int64,
    isSettled: proc(key: string): bool = nil): bool =
  ## Queue the keys whose backoff ended for the next batch, skipping those
  ## `isSettled` reports as cached or known-missing meanwhile. Returns true when
  ## any key was queued (the caller schedules the batch).
  var dueKeys: seq[string]
  for key, dueMs in self.awaitingRetry:
    if dueMs <= nowMs:
      dueKeys.add(key)
  for key in dueKeys:
    self.awaitingRetry.del(key)
    if not isSettled.isNil and isSettled(key):
      self.failedAttempts.del(key)
      continue
    self.pending.incl(key)
    result = true

proc settleKeys*(self: var PendingTokenFetch, keys: seq[string]) =
  ## The backend answered for these keys (found or missing): reset their retries.
  for key in keys:
    self.failedAttempts.del(key)

proc missingFromBatch*(requestedKeys: seq[string], foundKeys: HashSet[string]): seq[string] =
  ## The requested keys the backend did not return — these become negative
  ## markers so they cost no further RPC until a refresh. Order follows the request.
  var missing: seq[string]
  for key in requestedKeys:
    if key notin foundKeys:
      missing.add(key)
  return missing
