## Unit tests for the routing of message-service responses and signals into the
## dense model. The model under test is a stub that records every call and
## drives a real `DenseStore`, so the rules are checked both by the calls they
## make and by the row counts and loadedness they end up producing — without
## nimqml, which cannot be linked in a host test.

import std/strutils
import unittest

import app/modules/shared_models/dense_message_store
import app/modules/shared_models/dense_message_routing

# ------------------------------------------------------------------ harness

type
  TestItem = object
    id: string
    clock: int64

  StubModel = ref object
    store: DenseStore
    calls: seq[string]

proc item(id: string, clock: int64): TestItem =
  TestItem(id: id, clock: clock)

## A page as status-go returns it: newest-first, `items[i]` has rank `firstRank - i`.
proc pageOfRanks(firstRank, lastRank: int): seq[TestItem] =
  for rank in countdown(firstRank, lastRank):
    result.add(item("m" & $rank, rank.int64))

proc newStubModel(totalCount = 0): StubModel =
  result = StubModel(store: newDenseStore(), calls: @[])
  result.store.reset(totalCount)

proc rows(items: seq[TestItem]): seq[LoadedRow] =
  for it in items:
    result.add(LoadedRow(id: it.id, clock: it.clock))

proc totalCount(self: StubModel): int =
  self.store.totalCount

proc newestLoadedClock(self: StubModel): int64 =
  self.store.newestLoadedClock

proc setTotalCount(self: StubModel, totalCount: int) =
  self.calls.add("setTotalCount(" & $totalCount & ")")
  self.store.setTotalCount(totalCount)

proc applyPage(self: StubModel, items: seq[TestItem], firstRank: int, totalCount: int) =
  self.calls.add("applyPage(" & $items.len & "," & $firstRank & "," & $totalCount & ")")
  self.store.applyPage(items.rows, firstRank, totalCount)

proc addLiveMessages(self: StubModel, items: seq[TestItem], totalCount: int) =
  self.calls.add("addLiveMessages(" & $items.len & "," & $totalCount & ")")
  self.store.appendLive(items.rows, totalCount)

proc addBackfilledMessage(self: StubModel, it: TestItem, totalCount: int) =
  self.calls.add("addBackfilledMessage(" & it.id & "," & $totalCount & ")")
  self.store.insertBackfilled(LoadedRow(id: it.id, clock: it.clock), totalCount)

proc messageDeleted(self: StubModel, messageId: string, clock: int64, totalCount: int) =
  self.calls.add("messageDeleted(" & messageId & "," & $clock & "," & $totalCount & ")")
  self.store.removeMessage(messageId, clock, totalCount)

proc resetToChat(self: StubModel, totalCount: int) =
  self.calls.add("resetToChat(" & $totalCount & ")")
  self.store.reset(totalCount)

proc loadedIds(self: StubModel): seq[string] =
  for index in 0 ..< self.store.rowCount:
    if self.store.isLoaded(index):
      result.add(self.store.rowAt(index).id)

proc called(self: StubModel, prefix: string): bool =
  for call in self.calls:
    if call.startsWith(prefix):
      return true

# --------------------------------------------------------------------- tests

suite "page routing":
  test "a page is placed at its rank and the count is applied with it":
    let model = newStubModel(100)
    model.applyMessagePage(pageOfRanks(59, 40), 59, 100)
    check(model.calls == @["applyPage(20,59,100)"])
    check(model.totalCount == 100)
    # rank 59 is model index 40 in a 100-row chat
    check(model.loadedIds.len == 20)
    check(model.store.isLoaded(40))
    check(model.store.rowAt(40).id == "m59")
    check(model.store.isLoaded(59))
    check(model.store.rowAt(59).id == "m40")
    check(not model.store.isLoaded(39))

  test "a page grows the model when the chat grew under it":
    let model = newStubModel(100)
    model.applyMessagePage(pageOfRanks(109, 100), 109, 110)
    check(model.totalCount == 110)
    check(model.store.isLoaded(0))
    check(model.store.rowAt(0).id == "m109")

  test "an empty page applies only its count, never rank 0":
    let model = newStubModel(100)
    model.applyMessagePage(newSeq[TestItem](), RANK_NOT_APPLICABLE, 120)
    check(model.calls == @["setTotalCount(120)"])
    check(not model.called("applyPage"))
    check(model.totalCount == 120)
    check(model.loadedIds.len == 0)

  test "a rank past the end of the chat is not a page at the oldest end":
    # `chatMessagesAtRank` past the end answers with messages: [], firstRank: -1
    # and the true count; treating -1 as rank 0 would stamp the page onto the
    # oldest rows of the chat
    let model = newStubModel(100)
    model.applyMessagePage(pageOfRanks(9, 0), RANK_NOT_APPLICABLE, 100)
    check(not model.called("applyPage"))
    check(model.loadedIds.len == 0)

  test "a page without a count leaves the count alone":
    let model = newStubModel(100)
    model.applyMessagePage(pageOfRanks(9, 0), 9, COUNT_UNKNOWN)
    check(model.calls == @["applyPage(10,9,-1)"])
    check(model.totalCount == 100)
    check(model.loadedIds.len == 10)

  test "a short page around an anchor near the oldest end lands at rank 0":
    let model = newStubModel(100)
    # anchor at rank 5 with limit 40: status-go does not backfill, so the page
    # is short and starts at the oldest row
    model.applyMessagePage(pageOfRanks(25, 0), 25, 100)
    check(model.totalCount == 100)
    check(model.store.isLoaded(99))
    check(model.store.rowAt(99).id == "m0")

  test "a page of exactly one row":
    let model = newStubModel(3)
    model.applyMessagePage(@[item("only", 7)], 1, 3)
    check(model.store.isLoaded(1))
    check(model.store.rowAt(1).id == "only")

suite "incoming message routing":
  test "a message newer than everything loaded is live":
    let model = newStubModel(10)
    model.applyMessagePage(pageOfRanks(9, 5), 9, 10)
    model.applyIncomingMessages(@[item("new", 100)], model.newestLoadedClock, 11)
    check(model.called("addLiveMessages(1,-1)"))
    check(not model.called("addBackfilledMessage"))
    check(model.totalCount == 11)
    check(model.store.rowAt(0).id == "new")

  test "a message older than the newest loaded row is a backfill":
    let model = newStubModel(10)
    model.applyMessagePage(pageOfRanks(9, 5), 9, 10)
    model.applyIncomingMessages(@[item("old", 2)], model.newestLoadedClock, 11)
    check(model.called("addBackfilledMessage(old,-1)"))
    check(not model.called("addLiveMessages"))
    check(model.totalCount == 11)
    check(model.store.rowAt(0).id == "m9")

  test "a mixed batch is split and counted once":
    let model = newStubModel(10)
    model.applyMessagePage(pageOfRanks(9, 5), 9, 10)
    model.applyIncomingMessages(@[item("new", 100), item("old", 2)], model.newestLoadedClock, 12)
    check(model.called("addLiveMessages(1,-1)"))
    check(model.called("addBackfilledMessage(old,-1)"))
    check(model.calls[^1] == "setTotalCount(12)")
    check(model.totalCount == 12)

  test "everything is live while the model knows of no message":
    let model = newStubModel(0)
    model.applyIncomingMessages(@[item("a", 1), item("b", 2)], NO_CLOCK, 2)
    check(model.called("addLiveMessages(2,-1)"))
    check(model.totalCount == 2)

  test "a batch without a count still inserts":
    let model = newStubModel(0)
    model.applyIncomingMessages(@[item("a", 1)], NO_CLOCK, COUNT_UNKNOWN)
    check(model.totalCount == 1)

  test "an empty batch is only its count":
    let model = newStubModel(5)
    model.applyIncomingMessages(newSeq[TestItem](), NO_CLOCK, 5)
    check(model.calls == @["setTotalCount(5)"])

suite "deletion routing":
  test "a loaded row is removed and the row count shrinks":
    let model = newStubModel(10)
    model.applyMessagePage(pageOfRanks(9, 0), 9, 10)
    model.applyMessageRemoval("m5", 5)
    check(model.called("messageDeleted(m5,5,-1)"))
    check(model.totalCount == 9)
    check("m5" notin model.loadedIds)

  test "a deletion inside a hole shrinks the hole by its clock":
    let model = newStubModel(10)
    # load the newest 3 and the oldest 3; ranks 3..6 are a hole
    model.applyMessagePage(pageOfRanks(9, 7), 9, 10)
    model.applyMessagePage(pageOfRanks(2, 0), 2, 10)
    check(model.loadedIds.len == 6)
    model.applyMessageRemoval("m5", 5)
    check(model.totalCount == 9)
    check(model.loadedIds.len == 6)

  test "a removal carries no count of its own":
    # the batch count describes the state after every removal in it, so it must
    # not be applied once per removal
    let model = newStubModel(10)
    model.applyMessagePage(pageOfRanks(9, 0), 9, 10)
    model.applyMessageRemoval("m5", 5)
    model.applyMessageRemoval("m6", 6)
    check(model.calls[^2] == "messageDeleted(m5,5,-1)")
    check(model.calls[^1] == "messageDeleted(m6,6,-1)")
    check(model.totalCount == 8)
    model.applyChatMessageCount(8)
    check(model.totalCount == 8)

  test "an empty message id is not a deletion":
    let model = newStubModel(10)
    model.applyMessageRemoval("", 5)
    check(model.calls.len == 0)
    check(model.totalCount == 10)

suite "count routing":
  test "a count grows and shrinks the row count":
    let model = newStubModel(10)
    model.applyChatMessageCount(14)
    check(model.totalCount == 14)
    model.applyChatMessageCount(4)
    check(model.totalCount == 4)

  test "a cleared chat is count 0, which is not unknown":
    let model = newStubModel(10)
    model.applyChatMessageCount(0)
    check(model.calls == @["setTotalCount(0)"])
    check(model.totalCount == 0)

  test "an unknown count is not applied at all":
    let model = newStubModel(10)
    model.applyChatMessageCount(COUNT_UNKNOWN)
    check(model.calls.len == 0)
    check(model.totalCount == 10)

  test "a chat switch resets to the new chat's count":
    let model = newStubModel(10)
    model.applyMessagePage(pageOfRanks(9, 0), 9, 10)
    model.applyChatReset(3)
    check(model.called("resetToChat(3)"))
    check(model.totalCount == 3)
    check(model.loadedIds.len == 0)

  test "a chat switch with an unknown count resets to empty":
    let model = newStubModel(10)
    model.applyChatReset(COUNT_UNKNOWN)
    check(model.called("resetToChat(0)"))
    check(model.totalCount == 0)

suite "per-chat fan-out":
  setup:
    let mine = newStubModel(10)
    let router = newDenseChatRouter("chat-a", mine)

  test "a page for another chat is dropped":
    router.onMessagePageLoaded("chat-b", pageOfRanks(9, 0), 9, 50)
    check(mine.calls.len == 0)
    check(mine.totalCount == 10)
    router.onMessagePageLoaded("chat-a", pageOfRanks(9, 0), 9, 10)
    check(mine.called("applyPage"))

  test "a count for another chat is dropped":
    router.onChatMessageCount("chat-b", 99)
    check(mine.totalCount == 10)
    router.onChatMessageCount("chat-a", 12)
    check(mine.totalCount == 12)

  test "a deletion for another chat is dropped":
    router.onMessagePageLoaded("chat-a", pageOfRanks(9, 0), 9, 10)
    router.onMessageRemoved("chat-b", "m5", 5)
    check(mine.totalCount == 10)
    router.onMessageRemoved("chat-a", "m5", 5)
    check(mine.totalCount == 9)

  test "incoming messages for another chat are dropped":
    router.onIncomingMessages("chat-b", @[item("x", 100)], 11)
    check(mine.calls.len == 0)
    router.onIncomingMessages("chat-a", @[item("x", 100)], 11)
    check(mine.totalCount == 11)

  test "a router without a chat id handles nothing":
    let orphan = newDenseChatRouter("", newStubModel(10))
    check(not orphan.handles(""))
    check(not orphan.handles("chat-a"))

  test "an anchor rank converts to a model index, and -1 stays -1":
    router.onChatMessageCount("chat-a", 100)
    check(router.anchorIndex(99) == 0)
    check(router.anchorIndex(0) == 99)
    check(router.anchorIndex(RANK_NOT_APPLICABLE) == -1)
    check(router.anchorIndex(100) == -1)

suite "the existing pager against the enriched response":
  test "paging from the newest end backwards fills the model":
    let model = newStubModel(0)
    # first page: the newest 20 of 100
    model.applyChatReset(100)
    model.applyMessagePage(pageOfRanks(99, 80), 99, 100)
    check(model.totalCount == 100)
    check(model.loadedIds.len == 20)
    # second page continues where the cursor left off
    model.applyMessagePage(pageOfRanks(79, 60), 79, 100)
    check(model.totalCount == 100)
    check(model.loadedIds.len == 40)
    check(model.store.isLoaded(0))
    check(model.store.isLoaded(39))
    check(not model.store.isLoaded(40))

  test "a page that arrives after the chat grew re-anchors instead of duplicating":
    let model = newStubModel(0)
    model.applyChatReset(100)
    model.applyMessagePage(pageOfRanks(99, 80), 99, 100)
    # two live messages, then a page whose ranks moved up by two
    model.applyIncomingMessages(@[item("live2", 200), item("live1", 199)],
      model.newestLoadedClock, 102)
    check(model.totalCount == 102)
    model.applyMessagePage(pageOfRanks(99, 80), 99, 102)
    check(model.totalCount == 102)
    var seen = 0
    for id in model.loadedIds:
      if id == "m99":
        seen += 1
    check(seen == 1)

  test "the last page of a short chat":
    let model = newStubModel(0)
    model.applyChatReset(3)
    model.applyMessagePage(pageOfRanks(2, 0), 2, 3)
    check(model.loadedIds == @["m2", "m1", "m0"])
    # the pager asks once more and gets an empty page
    model.applyMessagePage(newSeq[TestItem](), RANK_NOT_APPLICABLE, 3)
    check(model.loadedIds == @["m2", "m1", "m0"])
