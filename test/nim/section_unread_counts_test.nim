import std/[importutils, json, tables, unittest]
import app/core/eventemitter
import app/core/signals/[types, signals_manager, signal_type_scan]
import app_service/service/chat/service as chat_service
import app_service/service/message/service as message_service
import backend/response_type
from seaqt/qcoreapplication import QCoreApplication, create
from seaqt/qtimer import isActive, stop

privateAccess(chat_service.Service)

discard QCoreApplication.create()

proc snapshot(personalUnread = 2, communityUnread = 5, mentions = 1): string =
  $ %* {"response": {"sections": [
    {"sectionId": "personal", "unviewedMessagesCount": personalUnread, "unviewedMentionsCount": mentions},
    {"sectionId": "community", "unviewedMessagesCount": communityUnread, "unviewedMentionsCount": mentions}
  ]}, "error": ""}

suite "section unread count snapshots":
  setup:
    let events = createEventEmitter()
    let service = chat_service.newService(events, nil, nil)
    var updates: seq[SectionUnreadCountsUpdatedArgs]
    var failures: seq[string]
    events.on(SIGNAL_SECTION_UNREAD_COUNTS_UPDATED) do(args: Args):
      updates.add(SectionUnreadCountsUpdatedArgs(args))
    events.on(SIGNAL_SECTION_UNREAD_COUNTS_FAILED) do(args: Args):
      failures.add(SectionUnreadCountsFailedArgs(args).error)

  teardown:
    service.delete()

  test "counts load without chat or thread caches":
    service.onAsyncSectionUnreadCounts(snapshot())
    check service.chats.len == 0
    check service.getSectionUnreadCounts("community") ==
      SectionUnreadCounts(unviewedMessagesCount: 5, unviewedMentionsCount: 1)
    check service.getSectionUnreadCounts("personal").unviewedMessagesCount == 2
    check service.getSectionUnreadCounts("unknown") == SectionUnreadCounts()
    check updates.len == 1
    check failures.len == 0

  test "complete replacements clear zero and removed sections":
    service.onAsyncSectionUnreadCounts(snapshot())
    service.onAsyncSectionUnreadCounts($ %* {"response": {"sections": [
      {"sectionId": "personal", "unviewedMessagesCount": 0, "unviewedMentionsCount": 0}
    ]}})
    check service.getSectionUnreadCounts("community") == SectionUnreadCounts()
    check service.sectionUnreadCounts.len == 1
    check updates[^1].counts["community"] == SectionUnreadCounts()
    check updates[^1].counts["personal"] == SectionUnreadCounts()

  test "invalid snapshots preserve all last successful totals and report failure":
    service.onAsyncSectionUnreadCounts(snapshot())
    let expected = service.sectionUnreadCounts
    for bad in [
      "not json",
      $ %* {"error": "backend unavailable"},
      $ %* {"response": nil},
      $ %* {"response": {"sections": {}}},
      $ %* {"response": {"sections": []}},
      $ %* {"response": {"sections": [{"sectionId": "personal", "unviewedMessagesCount": -1, "unviewedMentionsCount": 0}]}},
      $ %* {"response": {"sections": [{"sectionId": "personal", "unviewedMessagesCount": 1.5, "unviewedMentionsCount": 0}]}},
      $ %* {"response": {"sections": [{"sectionId": "personal", "unviewedMessagesCount": 1}]}},
      $ %* {"response": {"sections": [
        {"sectionId": "personal", "unviewedMessagesCount": 0, "unviewedMentionsCount": 0},
        {"sectionId": "personal", "unviewedMessagesCount": 1, "unviewedMentionsCount": 0}
      ]}}
    ]:
      service.sectionCountsInFlight = true
      service.onAsyncSectionUnreadCounts(bad)
      check not service.sectionCountsInFlight
      check service.sectionUnreadCounts == expected
      check failures[^1].len > 0
    check failures.len == 9
    check updates.len == 1
    service.requestSectionUnreadCounts()
    check service.sectionCountsTimer.isActive

  test "bursts coalesce and in-flight invalidations schedule exactly one followup":
    for i in 0 ..< 20:
      service.requestSectionUnreadCounts()
    check service.sectionCountsTimer.isActive
    check service.sectionCountsRefreshPending
    service.sectionCountsTimer.stop()
    service.sectionCountsRefreshPending = false
    service.sectionCountsInFlight = true
    for i in 0 ..< 20:
      service.requestSectionUnreadCounts()
    check not service.sectionCountsTimer.isActive
    check service.sectionCountsRefreshPending
    service.onAsyncSectionUnreadCounts(snapshot())
    check service.sectionCountsTimer.isActive
    check not service.sectionCountsInFlight
    service.sectionCountsTimer.stop()
    service.sectionCountsRefreshPending = false
    service.sectionCountsInFlight = true
    service.onAsyncSectionUnreadCounts(snapshot(communityUnread = 8))
    check not service.sectionCountsTimer.isActive
    check service.getSectionUnreadCounts("community").unviewedMessagesCount == 8
    check updates.len == 2

  test "an invalidated failed request still schedules a followup":
    service.sectionCountsInFlight = true
    service.requestSectionUnreadCounts()
    service.onAsyncSectionUnreadCounts($ %* {"error": "busy"})
    check failures == @["busy"]
    check service.sectionCountsTimer.isActive
    check not service.sectionCountsInFlight

  test "backend invalidation and message response flag survive signal decoding":
    let manager = newSignalsManager(events)
    defer: manager.delete()
    check isKnownSignalType("section.unread_counts.changed")
    manager.processSignal("""{"type":"section.unread_counts.changed","event":null}""")
    check service.sectionCountsTimer.isActive
    service.sectionCountsTimer.stop()
    service.sectionCountsRefreshPending = false
    manager.processSignal("""{"type":"messages.new","event":{"sectionUnreadCountsChanged":true}}""")
    check service.sectionCountsTimer.isActive
    service.sectionCountsTimer.stop()
    service.sectionCountsRefreshPending = false
    manager.processSignal("""{"type":"messages.new","event":{}}""")
    check not service.sectionCountsTimer.isActive

  test "local RPC response flags invalidate but unrelated results do not":
    service.handleSectionUnreadCountsResponse(%* {"sectionUnreadCountsChanged": false})
    check not service.sectionCountsTimer.isActive
    service.parseChatResponseAndEmit(RpcResponse[JsonNode](result: %* {"sectionUnreadCountsChanged": true}))
    check service.sectionCountsTimer.isActive

  test "thread mutation completions preserve unread invalidations":
    let messages = message_service.newService(events, nil, service, nil, nil, nil, nil)
    defer: messages.delete()
    let response = %* {
      "chatId": "chat", "threadId": "thread", "parentMessageId": "root",
      "threads": [{"chatId": "chat", "threadId": "thread", "parentMessageId": "root",
        "name": "Thread", "followed": true, "deleted": true}],
      "error": "", "sectionUnreadCountsChanged": true
    }
    for finish in [message_service.onAsyncEditThread, message_service.onAsyncSetThreadFollowed,
        message_service.onAsyncDeleteThread, message_service.onAsyncCreateThread]:
      finish(messages, $response)
      check service.sectionCountsTimer.isActive
      service.sectionCountsTimer.stop()
      service.sectionCountsRefreshPending = false
