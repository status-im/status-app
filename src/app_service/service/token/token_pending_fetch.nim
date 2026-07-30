## Pure pending-fetch set for the wallet token service.
##
## Replaces the synchronous GUI-thread `getTokensByKeys` RPC in getTokenByKey: a
## miss enqueues the key here and returns nil immediately; the service drains the
## set in a coalesced batch on a worker thread. This module holds only the
## dedup/coalescing bookkeeping so it can be unit-tested without a live Service or
## backend — no scheduling, threadpool, or IO here.

import sequtils, sets

type PendingTokenFetch* = object
  pending: HashSet[string]  ## keys awaiting the next batch fetch
  inFlight: HashSet[string] ## keys handed to a batch already running (dedup across the fetch window)

proc initPendingTokenFetch*(): PendingTokenFetch =
  PendingTokenFetch(pending: initHashSet[string](), inFlight: initHashSet[string]())

proc enqueue*(self: var PendingTokenFetch, key: string): bool =
  ## Record a missing key. Returns true only when the key is newly pending — the
  ## caller uses that to schedule (debounce) a batch exactly once per burst. Keys
  ## already pending or already in flight dedup and return false.
  if key in self.pending or key in self.inFlight:
    return false
  self.pending.incl(key)
  return true

proc hasPending*(self: PendingTokenFetch): bool =
  self.pending.len > 0

proc takeBatch*(self: var PendingTokenFetch): seq[string] =
  ## Drain the pending keys into the in-flight set and return them as the batch to
  ## fetch. Draining is atomic from the GUI thread's view: after this the pending
  ## set is empty and the same keys will not be re-enqueued while in flight.
  let batch = toSeq(self.pending)
  for key in batch:
    self.inFlight.incl(key)
  self.pending.clear()
  return batch

proc completeBatch*(self: var PendingTokenFetch, keys: seq[string]) =
  ## Release the keys of a finished batch from the in-flight set. After this a
  ## fresh miss of the same key may enqueue again (the caches/markers updated by
  ## the completion normally make that unnecessary).
  for key in keys:
    self.inFlight.excl(key)

proc drainInFlight*(self: var PendingTokenFetch) =
  ## Release every in-flight key. For the failure path where a batch's own key
  ## list is unknown (its envelope was undecodable): the batch cannot be
  ## released by completeBatch, so drain everything rather than leave its keys
  ## wedged as permanently in flight. Over-releasing a concurrently running
  ## batch is benign — worst case one duplicate fetch of its keys.
  self.inFlight.clear()

proc missingFromBatch*(requestedKeys: seq[string], foundKeys: HashSet[string]): seq[string] =
  ## The requested keys the backend did not return — these become negative
  ## markers so they cost no further RPC until a refresh. Order follows the request.
  var missing: seq[string]
  for key in requestedKeys:
    if key notin foundKeys:
      missing.add(key)
  return missing
