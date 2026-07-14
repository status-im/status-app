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

suite "pending token fetch — negative-marker feed":
  test "keys requested but not returned by a batch are the ones to mark missing":
    let requested = @["1-0xaaa", "1-0xbbb", "10-0xccc"]
    let found = ["1-0xbbb"].toHashSet
    # Only 1-0xbbb resolved; the other two feed the 0001 negative cache.
    check missingFromBatch(requested, found) == @["1-0xaaa", "10-0xccc"]

  test "a fully-resolved batch leaves nothing to mark missing":
    let requested = @["1-0xaaa"]
    check missingFromBatch(requested, ["1-0xaaa"].toHashSet).len == 0
