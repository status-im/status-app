## Unit tests for the decode-and-release step of the async missing-tokens batch.
##
## This is the slot-side half of the batched fetch: the worker's envelope comes
## back as a string, and whatever the outcome the batch's keys must leave the
## in-flight set — a key stuck in flight can never re-enqueue, so the token
## wedges (stops resolving) for the rest of the session. No Qt/backend.

import unittest

import app_service/service/token/token_missing_fetch
import app_service/service/token/token_pending_fetch

suite "missing-tokens batch — decoded envelope":
  test "a clean envelope yields its keys and releases them from the in-flight set":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.takeBatch()                 # 1-0xaaa is now in flight
    let response = """{"requestedKeys":["1-0xaaa"],"tokens":[],"error":""}"""
    let (env, decodeError) = decodeAndCompleteBatch(p, response)
    check decodeError.len == 0
    check env.requestedKeys == @["1-0xaaa"]
    check env.error.len == 0
    check p.enqueue("1-0xaaa") == true    # released -> a fresh miss may re-enqueue

  test "a backend-error envelope still releases the batch's keys":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.takeBatch()
    let response = """{"requestedKeys":["1-0xaaa"],"tokens":[],"error":"boom"}"""
    let (env, decodeError) = decodeAndCompleteBatch(p, response)
    check decodeError.len == 0
    check env.error == "boom"
    check p.enqueue("1-0xaaa") == true    # transient failure -> retry allowed

suite "missing-tokens batch — undecodable envelope":
  test "a raised decode still releases the in-flight keys instead of wedging them":
    var p = initPendingTokenFetch()
    discard p.enqueue("1-0xaaa")
    discard p.takeBatch()                 # 1-0xaaa is now in flight
    let (env, decodeError) = decodeAndCompleteBatch(p, "not json at all")
    check decodeError.len > 0
    check env.requestedKeys.len == 0
    # The batch's keys are unknown when the envelope itself is undecodable, so
    # everything in flight must be released — otherwise these keys stay "in
    # flight" forever and can never be fetched again this session.
    check p.enqueue("1-0xaaa") == true

  test "an empty response (drained handoff) releases the in-flight keys too":
    var p = initPendingTokenFetch()
    discard p.enqueue("10-0xbbb")
    discard p.takeBatch()
    let (_, decodeError) = decodeAndCompleteBatch(p, "")
    check decodeError.len > 0
    check p.enqueue("10-0xbbb") == true
