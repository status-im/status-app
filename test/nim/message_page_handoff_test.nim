## Issue 0017: a message page must be ASSEMBLED off the GUI thread and only
## CLAIMED on it.
##
## Pure Nim on purpose — `message_window` and `typed_handoff` are both free of
## nimqml and of the message DTOs, so the whole worker -> GUI crossing is
## runnable here. What the production tasks add on top (the RPC calls, and the
## DTO decode the slot deliberately keeps) is compile-checked, not run.
##
## Build with: nim c -r --mm:orc --threads:on (the registry moves a ref graph
## between threads, which refc's per-thread heaps cannot do).

import std/json
import std/typedthreads
import unittest

import app/core/tasks/typed_handoff
import app_service/service/message/message_window

proc reactionsFor(rows: int): JsonNode =
  result = newJArray()
  for i in 0 ..< rows:
    if i mod 2 == 0:
      result.add(%*{"id": "0xr" & $i, "messageId": "0xm" & $i, "emojiId": 1})

proc rpcResult(rows: int, firstRank = 8000, totalCount = 12000): JsonNode =
  var messages = newJArray()
  for i in 0 ..< rows:
    messages.add(%*{
      "id": "0xm" & $i,
      "text": "row " & $i,
      "clock": 1700000000000 + i,
      "parsedText": %[%*{"type": "paragraph",
                         "children": %[%*{"type": "text", "literal": "row " & $i}]}],
    })
  %*{
    "messages": messages,
    "reactions": reactionsFor(rows),
    "cursor": "cursor-" & $rows,
    "totalCount": totalCount,
    "firstRank": firstRank,
    "anchorRank": -1,
  }


# --- the worker half ----------------------------------------------------------

type PageSpec = tuple[rows: int, outHandle: ptr TaskHandle, outThreadId: ptr int]

# `outThreadId` is read from the OS, not from the payload: the payload's own
# stamp is what is under test, so believing it here would make the assertion
# tautological.
proc workerBuildPage(spec: PageSpec) {.thread.} =
  spec.outThreadId[] = getThreadId()
  spec.outHandle[] = parkHandoff(
    buildWindowPayload("chat-1", rpcResult(spec.rows)))

proc workerBuildError(spec: PageSpec) {.thread.} =
  spec.outThreadId[] = getThreadId()
  var payload = newErrorPagePayload("chat-1", "fetch blew up")
  payload.requestedRank = 42
  spec.outHandle[] = parkHandoff(payload)

proc runOnWorker(fn: proc(s: PageSpec) {.thread, nimcall.}, rows: int):
    tuple[payload: MessagePagePayload, workerThreadId: int] =
  var handle: TaskHandle
  var threadId: int
  var th: Thread[PageSpec]
  createThread(th, fn, (rows: rows, outHandle: addr handle, outThreadId: addr threadId))
  joinThread(th)
  (claimHandoff[MessagePagePayload](handle), threadId)

suite "a page is assembled off the claiming thread":
  test "the payload records the thread that built it, not the one that claims it":
    let (payload, workerThreadId) = runOnWorker(workerBuildPage, 30)
    check not payload.isNil
    check payload.builtOnThreadId == workerThreadId
    check payload.builtOnThreadId != getThreadId()

  test "an error payload crosses the same way, on the same transport":
    let (payload, workerThreadId) = runOnWorker(workerBuildError, 0)
    check not payload.isNil
    check payload.meta.error == "fetch blew up"
    check payload.meta.chatId == "chat-1"
    check payload.requestedRank == 42
    check payload.builtOnThreadId == workerThreadId
    check payload.builtOnThreadId != getThreadId()

  test "the claiming thread finds the page intact and readable":
    let (payload, _) = runOnWorker(workerBuildPage, 30)
    check payload.meta.chatId == "chat-1"
    check payload.meta.cursor == "cursor-30"
    check payload.meta.totalCount == 12000
    check payload.meta.firstRank == 8000
    check payload.meta.anchorRank == RANK_NOT_APPLICABLE
    check payload.meta.error == ""
    check payload.messages.kind == JArray
    check payload.messages.len == 30
    check payload.reactions.len == 15
    # the whole graph survives the crossing, not just its head
    check payload.messages[0]["id"].getStr == "0xm0"
    check payload.messages[29]["parsedText"][0]["children"][0]["literal"].getStr == "row 29"

  test "nothing is left parked once the page has been claimed":
    let (payload, _) = runOnWorker(workerBuildPage, 5)
    check not payload.isNil
    check pendingHandoffs() == 0

  test "a page dropped at shutdown claims as nil rather than a stale page":
    var handle: TaskHandle
    var threadId: int
    var th: Thread[PageSpec]
    createThread(th, workerBuildPage, (rows: 5, outHandle: addr handle, outThreadId: addr threadId))
    joinThread(th)
    drainHandoffs()
    check claimHandoff[MessagePagePayload](handle).isNil

suite "payload shapes":
  test "a fresh payload is empty, unranked and count-less, never zeroed":
    let payload = initMessagePagePayload("chat-1")
    check payload.meta.chatId == "chat-1"
    check payload.meta.totalCount == COUNT_UNKNOWN
    check payload.meta.firstRank == RANK_NOT_APPLICABLE
    check payload.meta.anchorRank == RANK_NOT_APPLICABLE
    check payload.requestedRank == RANK_NOT_APPLICABLE
    check payload.messageId == ""
    check payload.messages.kind == JArray
    check payload.messages.len == 0
    check payload.reactions.kind == JArray
    check payload.reactions.len == 0

  test "an error payload carries the chat so the slot can still address it":
    let payload = newErrorPagePayload("chat-7", "boom")
    check payload.meta.chatId == "chat-7"
    check payload.meta.error == "boom"
    check payload.messages.len == 0
    check payload.reactions.len == 0

  test "the arrays are the ones the rpc returned, not copies re-encoded":
    let rpc = rpcResult(3)
    let payload = buildWindowPayload("chat-1", rpc)
    check payload.messages == rpc["messages"]
    check payload.reactions == rpc["reactions"]

  test "a response with no messages field yields an empty page, not a nil array":
    let payload = buildWindowPayload("chat-1", %*{"cursor": "c"})
    check payload.messages.kind == JArray
    check payload.messages.len == 0
    check payload.reactions.kind == JArray
    check payload.reactions.len == 0
    check payload.meta.cursor == "c"
    check payload.meta.totalCount == COUNT_UNKNOWN
    check payload.meta.firstRank == RANK_NOT_APPLICABLE

  test "a non-object rpc result is a page-shaped error, not a crash":
    let payload = buildWindowPayload("chat-1", newJArray())
    check payload.messages.len == 0
    check payload.meta.firstRank == RANK_NOT_APPLICABLE
    check payload.meta.totalCount == COUNT_UNKNOWN

  test "the page size the view chunks by is the page size the pager asks for":
    # The whole point of moving MESSAGES_PER_PAGE next to the wire shapes: one
    # number, and an escalated page can never exceed what status-go accepts.
    check MESSAGES_PER_PAGE > 0
    check MESSAGES_PER_PAGE <= MESSAGES_PER_PAGE_MAX
    check MESSAGES_PER_PAGE_MAX <= MAX_MESSAGES_WINDOW_LIMIT
    check clampWindowLimit(MESSAGES_PER_PAGE) == MESSAGES_PER_PAGE
