## Unit tests for the pure pending-fetch set.
## This is the coalescing/dedup core of the async batched fetch that replaces the
## synchronous GUI-thread token RPC: a miss enqueues a key, a burst of lookups for
## the same key collapses to one batch entry, a batch is drained atomically, and
## keys not returned by a batch feed the 0001 negative markers. No Qt/backend.

import unittest, sequtils, sets

import app_service/service/token/token_pending_fetch

suite "pending token fetch — enqueue and batching":
  test "the first enqueue of a key schedules; repeats within the same window dedup":
    var p = initPendingTokenFetch()
    check p.enqueue("1-0xaaa") == true   # newly pending -> caller schedules a batch
    check p.enqueue("1-0xaaa") == false  # already pending -> no second schedule
    check p.hasPending()

  test "a burst of lookups for the same key yields a single batch entry":
    var p = initPendingTokenFetch()
    for _ in 0 ..< 5:
      discard p.enqueue("1-0xbbb")
    let batch = p.takeBatch()
    check batch.keys == @["1-0xbbb"]
    check not p.hasPending()  # draining clears the pending set

  test "takeBatch returns every distinct pending key":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.enqueue("10-0xbbb")
    let batch = p.takeBatch()
    check batch.keys.toHashSet == ["1-0xaaa", "10-0xbbb"].toHashSet
    check not p.hasPending()

suite "pending token fetch — in-flight window":
  test "a key in flight does not re-enqueue while its batch is running":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.takeBatch()                 # 1-0xaaa is now in flight
    check p.enqueue("1-0xaaa") == false   # a repeat lookup mid-flight must not re-fetch
    check not p.hasPending()

  test "completing a batch releases its keys so a later miss can re-enqueue":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    let batch = p.takeBatch()
    check p.completeBatch(batch.id) == @["1-0xaaa"]  # batch done -> in-flight cleared
    check p.enqueue("1-0xaaa") == true     # a fresh miss of the same key is allowed again
    check p.hasPending()

  test "completing a batch releases only its own keys":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    let first = p.takeBatch()
    discard p.enqueue("10-0xbbb")
    let second = p.takeBatch()
    check first.id != second.id
    check p.completeBatch(first.id) == @["1-0xaaa"]
    check p.enqueue("10-0xbbb") == false   # still in flight with its own batch
    check p.completeBatch(second.id) == @["10-0xbbb"]

  test "a batch completing after a drain releases nothing":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    let first = p.takeBatch()
    discard p.enqueue("10-0xbbb")
    let second = p.takeBatch()
    check p.drainInFlight().toHashSet == ["1-0xaaa", "10-0xbbb"].toHashSet
    check p.completeBatch(second.id).len == 0
    check p.completeBatch(first.id).len == 0

  test "a drained key fetched again belongs to its new batch, not the old one":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    let stale = p.takeBatch()
    discard p.drainInFlight()
    discard p.enqueue("1-0xaaa")
    let fresh = p.takeBatch()
    check p.completeBatch(stale.id).len == 0
    check p.enqueue("1-0xaaa") == false    # still in flight with the fresh batch
    check p.completeBatch(fresh.id) == @["1-0xaaa"]

  test "draining the in-flight set releases every key but leaves pending keys queued":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.takeBatch()                  # 1-0xaaa in flight
    discard p.enqueue("10-0xbbb")          # queued for the NEXT batch
    discard p.drainInFlight()              # failure path: batch keys unknown
    check p.enqueue("1-0xaaa") == true     # released -> may re-enqueue
    check p.enqueue("10-0xbbb") == false   # still pending -> still dedups
    check p.takeBatch().keys.len == 2

suite "pending token fetch — negative-marker feed":
  test "keys requested but not returned by a batch are the ones to mark missing":
    let requested = @["1-0xaaa", "1-0xbbb", "10-0xccc"]
    let found = ["1-0xbbb"].toHashSet
    # Only 1-0xbbb resolved; the other two feed the 0001 negative cache.
    check missingFromBatch(requested, found) == @["1-0xaaa", "10-0xccc"]

  test "a fully-resolved batch leaves nothing to mark missing":
    let requested = @["1-0xaaa"]
    check missingFromBatch(requested, ["1-0xaaa"].toHashSet).len == 0

suite "pending token fetch — failed batch retries":
  const t0 = 1_000_000'i64

  proc failOnce(p: var PendingTokenFetch, key: string, nowMs = t0): seq[string] =
    discard p.enqueue(key)
    let batch = p.takeBatch()
    discard p.completeBatch(batch.id)
    return p.failBatch(batch.keys, nowMs)

  test "retry delays back off over three tries":
    check MissingTokenFetchRetryDelaysMs == [2000, 5000, 15000]

  test "each failure of a key waits the next, longer backoff":
    var p = initPendingTokenFetch()
    var now = t0
    for delayMs in MissingTokenFetchRetryDelaysMs:
      check p.failBatch(@["1-0xaaa"], now).len == 0
      check p.nextRetryInMs(now) == delayMs
      check not p.releaseDueRetries(now + delayMs - 1)
      now += delayMs
      check p.releaseDueRetries(now)
      check p.takeBatch().keys == @["1-0xaaa"]

  test "a key waiting for a retry stays pending and dedups lookups":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa")
    check p.enqueue("1-0xaaa") == false
    check not p.hasPending()
    check p.isAwaitingRetry("1-0xaaa")

  test "a due retry queues its key for the next batch exactly once":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa")
    check p.releaseDueRetries(t0 + 2000)
    check not p.isAwaitingRetry("1-0xaaa")
    check p.nextRetryInMs(t0 + 2000) == -1
    check not p.releaseDueRetries(t0 + 4000)   # already released
    check p.takeBatch().keys == @["1-0xaaa"]

  test "a batch failing just before an earlier one's retry still waits its full backoff":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa", t0)
    discard p.failOnce("10-0xbbb", t0 + 1900)
    check p.releaseDueRetries(t0 + 2000)
    check p.takeBatch().keys == @["1-0xaaa"]
    check p.isAwaitingRetry("10-0xbbb")
    check p.nextRetryInMs(t0 + 2000) == 1900
    check p.releaseDueRetries(t0 + 3900)
    check p.takeBatch().keys == @["10-0xbbb"]

  test "the next retry is the earliest one due across backoff tiers":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa", t0)
    check p.releaseDueRetries(t0 + 2000)
    discard p.completeBatch(p.takeBatch().id)
    discard p.failBatch(@["1-0xaaa"], t0 + 2000)   # second try: due at +5s
    discard p.failOnce("10-0xbbb", t0 + 3000)     # first try: due at +2s
    check p.nextRetryInMs(t0 + 3000) == 2000
    check p.releaseDueRetries(t0 + 5000)
    check p.takeBatch().keys == @["10-0xbbb"]
    check p.nextRetryInMs(t0 + 5000) == 2000
    check p.nextRetryInMs(t0 + 9000) == 0

  test "a key failing every retry gives up and stops being fetched":
    var p = initPendingTokenFetch()
    var now = t0
    for delayMs in MissingTokenFetchRetryDelaysMs:
      discard p.failBatch(@["1-0xaaa"], now)
      now += delayMs
      discard p.releaseDueRetries(now)
      discard p.completeBatch(p.takeBatch().id)
    check p.failBatch(@["1-0xaaa"], now) == @["1-0xaaa"]
    check not p.isAwaitingRetry("1-0xaaa")
    check p.nextRetryInMs(now) == -1
    check not p.hasPending()

  test "keys of one failed batch are retried together":
    var p = initPendingTokenFetch()
    discard p.failBatch(@["1-0xaaa", "10-0xbbb"], t0)
    check p.releaseDueRetries(t0 + 2000)
    check p.takeBatch().keys.toHashSet == ["1-0xaaa", "10-0xbbb"].toHashSet

  test "a settled key starts its next failure from the first backoff":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa")
    discard p.releaseDueRetries(t0 + 2000)
    discard p.completeBatch(p.takeBatch().id)
    p.settleKeys(@["1-0xaaa"])             # the retry answered
    discard p.failOnce("1-0xaaa", t0 + 3000)
    check p.nextRetryInMs(t0 + 3000) == 2000

  test "a retry skips keys that resolved or settled during the backoff":
    var p = initPendingTokenFetch()
    discard p.failBatch(@["1-0xaaa", "10-0xbbb"], t0)
    check p.releaseDueRetries(t0 + 2000, isSettled = proc(key: string): bool = key == "1-0xaaa")
    check p.takeBatch().keys == @["10-0xbbb"]

  test "a retry whose keys all settled during the backoff schedules nothing":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa")
    check not p.releaseDueRetries(t0 + 2000, isSettled = proc(key: string): bool = true)
    check not p.hasPending()
    check not p.isAwaitingRetry("1-0xaaa")
    discard p.failOnce("1-0xaaa", t0 + 3000)   # settled: its next failure restarts the backoff
    check p.nextRetryInMs(t0 + 3000) == 2000
