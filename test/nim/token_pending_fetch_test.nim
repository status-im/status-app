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
    check batch == @["1-0xbbb"]
    check not p.hasPending()  # draining clears the pending set

  test "takeBatch returns every distinct pending key":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.enqueue("10-0xbbb")
    let batch = p.takeBatch()
    check batch.toHashSet == ["1-0xaaa", "10-0xbbb"].toHashSet
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
    p.completeBatch(batch)                 # batch done -> in-flight cleared
    check p.enqueue("1-0xaaa") == true     # a fresh miss of the same key is allowed again
    check p.hasPending()

  test "draining the in-flight set releases every key but leaves pending keys queued":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.takeBatch()                  # 1-0xaaa in flight
    discard p.enqueue("10-0xbbb")          # queued for the NEXT batch
    discard p.drainInFlight()              # failure path: batch keys unknown
    check p.enqueue("1-0xaaa") == true     # released -> may re-enqueue
    check p.enqueue("10-0xbbb") == false   # still pending -> still dedups
    check p.takeBatch().len == 2

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
  proc failOnce(p: var PendingTokenFetch, key: string): tuple[retryTiers: seq[int], gaveUp: seq[string]] =
    discard p.enqueue(key)
    let batch = p.takeBatch()
    p.completeBatch(batch)
    return p.failBatch(batch)

  test "retry delays back off over three tries":
    check MissingTokenFetchRetryDelaysMs == [2000, 5000, 15000]

  test "each failure of a key waits on the next, longer retry tier":
    var p = initPendingTokenFetch()
    for tier in 0 ..< MissingTokenFetchRetryDelaysMs.len:
      let (retryTiers, gaveUp) = p.failBatch(@["1-0xaaa"])
      check retryTiers == @[tier]
      check gaveUp.len == 0
      check p.releaseRetries(tier)
      check p.takeBatch() == @["1-0xaaa"]

  test "a key waiting for a retry stays pending and dedups lookups":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa")
    check p.enqueue("1-0xaaa") == false
    check not p.hasPending()
    check p.isAwaitingRetry("1-0xaaa")

  test "a released tier queues its keys for the next batch exactly once":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa")
    check not p.releaseRetries(1)          # other tiers hold nothing
    check p.releaseRetries(0)
    check not p.isAwaitingRetry("1-0xaaa")
    check not p.releaseRetries(0)          # already released
    check p.takeBatch() == @["1-0xaaa"]

  test "a key failing every retry gives up and stops being fetched":
    var p = initPendingTokenFetch()
    for tier in 0 ..< MissingTokenFetchRetryDelaysMs.len:
      discard p.failBatch(@["1-0xaaa"])
      discard p.releaseRetries(tier)
      p.completeBatch(p.takeBatch())
    let (retryTiers, gaveUp) = p.failBatch(@["1-0xaaa"])
    check retryTiers.len == 0
    check gaveUp == @["1-0xaaa"]
    check not p.isAwaitingRetry("1-0xaaa")
    check not p.hasPending()

  test "keys of one failed batch share a tier; the tier is armed once":
    var p = initPendingTokenFetch()
    let (retryTiers, _) = p.failBatch(@["1-0xaaa", "10-0xbbb"])
    check retryTiers == @[0]
    check p.releaseRetries(0)
    check p.takeBatch().toHashSet == ["1-0xaaa", "10-0xbbb"].toHashSet

  test "a settled key starts its next failure from the first tier":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa")
    discard p.releaseRetries(0)
    p.completeBatch(p.takeBatch())
    p.settleKeys(@["1-0xaaa"])             # the retry answered
    let (retryTiers, _) = p.failOnce("1-0xaaa")
    check retryTiers == @[0]

  test "a retry skips keys that resolved or settled during the backoff":
    var p = initPendingTokenFetch()
    discard p.failBatch(@["1-0xaaa", "10-0xbbb"])
    check p.releaseRetries(0, isSettled = proc(key: string): bool = key == "1-0xaaa")
    check p.takeBatch() == @["10-0xbbb"]

  test "a tier whose keys all settled during the backoff schedules nothing":
    var p = initPendingTokenFetch()
    discard p.failOnce("1-0xaaa")
    check not p.releaseRetries(0, isSettled = proc(key: string): bool = true)
    check not p.hasPending()
    check not p.isAwaitingRetry("1-0xaaa")
    let (retryTiers, _) = p.failOnce("1-0xaaa")   # settled: its next failure restarts the backoff
    check retryTiers == @[0]
