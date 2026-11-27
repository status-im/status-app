import std/[importutils, json, tables, sets, unittest, options, monotimes]
import uuids
from seaqt/qcoreapplication import QCoreApplication, processEvents, sendEvent
from seaqt/qtimer import start, isActive, timerId
from seaqt/qtimerevent import QTimerEvent, create
import std/[os, times]
import ./support/qt_app
import app/core/eventemitter
import app_service/service/message/service as messages
import app_service/service/chat/service as chats

ensureQtCoreApp()

privateAccess(messages.Service)

proc reserve(service: messages.Service, chatId, messageId: string): UUID =
  result = genUUID()
  service.inlineMessageRequests[result] = (chatId & ":" & messageId, chatId, messageId, false)

proc respond(service: messages.Service, requestId: UUID, chatId, messageId, threadId: string, error = "") =
  service.onAsyncGetMessageById($(%* {
    "requestId": $requestId, "messageId": messageId, "error": error,
    "message": {"id": messageId, "localChatId": chatId, "threadId": threadId}
  }))

suite "shared inline message reads":
  test "repeated consumers reuse the existing request and the completed value":
    let service = messages.newService(createEventEmitter(), nil, nil, nil, nil, nil, nil)
    let request = service.reserve("chat", "message")
    check not service.inlineMessageUnavailable("chat", "message")
    for i in 0 ..< 100:
      check service.inlineMessageThreadId("chat", "message") == ""
    check service.inlineMessageRequests.len == 1
    service.respond(request, "chat", "message", "thread")
    check service.inlineMessageRequests.len == 0
    check service.inlineMessageThreadId("chat", "message") == "thread"

  test "a newer observed message supersedes the pending reply, including an empty thread ID":
    for threadId in ["new-thread", ""]:
      let events = createEventEmitter()
      let service = messages.newService(events, nil, nil, nil, nil, nil, nil)
      service.init()
      let request = service.reserve("chat", "message")
      events.emit(SIGNAL_NEW_MESSAGE_RECEIVED, MessagesArgs(chatId: "chat",
        messages: @[MessageDto(id: "message", localChatId: "chat", threadId: threadId)]))
      service.respond(request, "chat", "message", "stale-thread")
      check service.inlineMessageThreadId("chat", "message") == threadId

  test "failed and mismatched replies release the request and back off":
    for mismatch in [false, true]:
      let service = messages.newService(createEventEmitter(), nil, nil, nil, nil, nil, nil)
      let request = service.reserve("chat", "message")
      service.respond(request, "chat", if mismatch: "other-message" else: "message", "wrong-thread",
        if mismatch: "" else: "temporary failure")
      check service.inlineMessageRequests.len == 0
      check service.inlineMessageThreads["chat:message"].retryAt.isSome
      check service.inlineMessageUnavailable("chat", "message")
      # A nil threadpool would expose an accidental immediate retry.
      check service.inlineMessageThreadId("chat", "message") == ""

  test "a completed read wakes consumers that reached the concurrency limit":
    let events = createEventEmitter()
    let service = messages.newService(events, nil, nil, nil, nil, nil, nil)
    var request: UUID
    for i in 0 ..< 16:
      request = service.reserve("busy", $i)
    check service.inlineMessageThreadId("waiting", "message") == ""
    check "waiting" in service.inlineMessageWaitingChats
    var awakened = false
    events.on(SIGNAL_INLINE_MESSAGE_DATA_CHANGED) do(e: Args):
      if chats.ChatArgs(e).chatId == "waiting": awakened = true
    service.respond(request, "busy", "15", "thread")
    check awakened
    check service.inlineMessageWaitingChats.len == 0
    check service.inlineMessageRequests.len == 15

  test "the shared timer wakes failed reads automatically and stops after recovery":
    let events = createEventEmitter()
    let service = messages.newService(events, nil, nil, nil, nil, nil, nil)
    defer: service.delete()
    let first = service.reserve("chat", "first")
    service.respond(first, "chat", "first", "", "temporary failure")
    let timerHandle = service.inlineMessageRetryTimer.h
    require service.inlineMessageRetryTimer.isActive()
    let second = service.reserve("chat", "second")
    service.respond(second, "chat", "second", "", "temporary failure")
    check service.inlineMessageRetryTimer.h == timerHandle
    # Shorten the deadlines, then exercise the real Qt timeout and event delivery.
    let deadline = getMonoTime() + initDuration(milliseconds = 20)
    service.inlineMessageThreads["chat:first"].retryAt = some(deadline)
    service.inlineMessageThreads["chat:second"].retryAt = some(deadline)
    service.inlineMessageRetryTimer.start(1)
    var notifications = 0
    events.on(SIGNAL_INLINE_MESSAGE_DATA_CHANGED) do(e: Args):
      if chats.ChatArgs(e).chatId == "chat": inc notifications
    let timeout = getMonoTime() + initDuration(seconds = 1)
    while notifications == 0 and getMonoTime() < timeout:
      QCoreApplication.processEvents()
      sleep(1)
    check notifications == 1
    check not service.inlineMessageThreads.hasKey("chat:first")
    check not service.inlineMessageThreads.hasKey("chat:second")
    check not service.inlineMessageRetryTimer.isActive()
    let retry = service.reserve("chat", "first")
    service.respond(retry, "chat", "first", "recovered")
    check service.inlineMessageThreadId("chat", "first") == "recovered"
    check not service.inlineMessageRetryTimer.isActive()

  test "recovery cancels a pending retry and deletion releases the shared timer":
    let events = createEventEmitter()
    let service = messages.newService(events, nil, nil, nil, nil, nil, nil)
    let failed = service.reserve("chat", "message")
    service.respond(failed, "chat", "message", "", "temporary failure")
    require service.inlineMessageRetryTimer.isActive()
    let recovered = service.reserve("chat", "message")
    service.respond(recovered, "chat", "message", "thread")
    check not service.inlineMessageRetryTimer.isActive()
    let other = service.reserve("chat", "other")
    service.respond(other, "chat", "other", "", "temporary failure")
    require service.inlineMessageRetryTimer.isActive()
    service.inlineMessageThreads["chat:other"].retryAt = some(getMonoTime())
    service.inlineMessageRetryTimer.start(1)
    var notifications = 0
    events.on(SIGNAL_INLINE_MESSAGE_DATA_CHANGED) do(e: Args): inc notifications
    service.delete()
    check service.inlineMessageRetryTimer.h.isNil
    sleep(5)
    QCoreApplication.processEvents()
    check notifications == 0

  test "completed results remain bounded while history is traversed":
    let service = messages.newService(createEventEmitter(), nil, nil, nil, nil, nil, nil)
    for i in 0 ..< InlineLinkCacheLimit:
      service.inlineMessageThreads["chat:" & $i] = ("chat", "thread", none(MonoTime), false)
    let request = service.reserve("chat", "new-message")
    service.respond(request, "chat", "new-message", "new-thread")
    check service.inlineMessageThreads.len == InlineLinkCacheLimit
    check not service.inlineMessageThreads.hasKey("chat:0")
    check service.inlineMessageThreadId("chat", "new-message") == "new-thread"

  test "deleted messages are unavailable and late reads cannot restore them":
    let events = createEventEmitter()
    let service = messages.newService(events, nil, nil, nil, nil, nil, nil)
    service.init()
    let request = service.reserve("chat", "message")
    events.emit(SIGNAL_MESSAGE_REMOVED, MessageRemovedArgs(chatId: "chat", messageId: "message"))
    check service.inlineMessageUnavailable("chat", "message")
    service.respond(request, "chat", "message", "thread")
    check service.inlineMessageUnavailable("chat", "message")
    check not service.inlineMessageThreads["chat:message"].retryAt.isSome

  test "deletion flags and recovered reads update availability":
    let events = createEventEmitter()
    let service = messages.newService(events, nil, nil, nil, nil, nil, nil)
    service.init()
    let request = service.reserve("chat", "message")
    service.onAsyncGetMessageById($(%* {
      "requestId": $request, "messageId": "message", "error": "",
      "message": {"id": "message", "localChatId": "chat", "deleted": true}
    }))
    check service.inlineMessageUnavailable("chat", "message")
    events.emit(SIGNAL_NEW_MESSAGE_RECEIVED, MessagesArgs(chatId: "chat",
      messages: @[MessageDto(id: "message", localChatId: "chat", deletedForMe: true)]))
    check service.inlineMessageUnavailable("chat", "message")
    events.emit(SIGNAL_NEW_MESSAGE_RECEIVED, MessagesArgs(chatId: "chat",
      messages: @[MessageDto(id: "message", localChatId: "chat")]))
    check not service.inlineMessageUnavailable("chat", "message")

  test "bulk deletion updates existing inline consumers":
    let events = createEventEmitter()
    let service = messages.newService(events, nil, nil, nil, nil, nil, nil)
    service.init()
    let request = service.reserve("chat", "message")
    service.respond(request, "chat", "message", "")
    check not service.inlineMessageUnavailable("chat", "message")
    events.emit(SIGNAL_MESSAGES_DELETED, MessagesDeletedArgs(deletedMessages: {"chat": @["message"]}.toTable))
    check service.inlineMessageUnavailable("chat", "message")

  test "missing threads are unavailable only after summaries settle":
    let service = messages.newService(createEventEmitter(), nil, nil, nil, nil, nil, nil)
    check not service.inlineThreadUnavailable("chat", "missing")
    service.chatThreadSummariesLoadingChats.incl("chat")
    check not service.inlineThreadUnavailable("chat", "missing")
    service.chatThreadSummariesLoadingChats.excl("chat")
    service.chatThreadSummariesLoadedChats.incl("chat")
    check service.inlineThreadUnavailable("chat", "missing")
    service.chatThreadsByParentIdByChat["chat"] = {
      "parent": ThreadDto(chatId: "chat", threadId: "found", parentMessageId: "parent")
    }.toTable
    check not service.inlineThreadUnavailable("chat", "found")

  test "failed summaries report unavailability without hiding known threads":
    let service = messages.newService(createEventEmitter(), nil, nil, nil, nil, nil, nil)
    defer: service.delete()
    service.onAsyncLoadChatThreadsForChats($(%* {
      "chatIds": ["chat"], "includeSummaries": true, "error": "read failed"
    }))
    check service.inlineThreadUnavailable("chat", "missing")
    service.chatThreadsByParentIdByChat["chat"] = {
      "parent": ThreadDto(chatId: "chat", threadId: "found", parentMessageId: "parent")
    }.toTable
    check not service.inlineThreadUnavailable("chat", "found")
    service.onAsyncLoadChatThreadsForChats($(%* {
      "chatIds": ["chat"], "includeSummaries": true,
      "threads": [{"chatId": "chat", "threadId": "missing", "parentMessageId": "other-parent"}]
    }))
    check not service.inlineThreadUnavailable("chat", "missing")
    check "chat:" notin service.inlineMessageThreads

  test "failed thread summaries reuse the shared retry timer and wake consumers":
    let events = createEventEmitter()
    let service = messages.newService(events, nil, nil, nil, nil, nil, nil)
    defer: service.delete()
    let read = service.reserve("chat", "message")
    service.respond(read, "chat", "message", "", "read failed")
    let timer = service.inlineMessageRetryTimer.h
    service.chatThreadSummariesLoadedChats.incl("chat")
    service.onAsyncLoadChatThreadsForChats($(%* {
      "chatIds": ["chat"], "includeSummaries": true, "error": "read failed"
    }))
    check service.inlineMessageRetryTimer.h == timer
    check service.inlineThreadUnavailable("chat", "thread")
    # A nil threadpool exposes retries that bypass the backoff.
    service.asyncLoadChatThreadSummaries("chat", notifyIfCached = false)
    check "chat" notin service.chatThreadSummariesLoadingChats
    var notifications = 0
    events.on(SIGNAL_INLINE_MESSAGE_DATA_CHANGED) do(e: Args):
      if chats.ChatArgs(e).chatId == "chat": inc notifications
    let expired = getMonoTime() - initDuration(seconds = 1)
    service.inlineMessageThreads["chat:message"].retryAt = some(expired)
    service.inlineMessageThreads["chat:"].retryAt = some(expired)
    let timeout = QTimerEvent.create(service.inlineMessageRetryTimer.timerId())
    discard QCoreApplication.sendEvent(service.inlineMessageRetryTimer, timeout)
    check notifications == 1
    check "chat:" notin service.inlineMessageThreads
    check "chat" notin service.chatThreadSummariesLoadedChats
    check not service.inlineThreadUnavailable("chat", "thread")
    check not service.inlineMessageRetryTimer.isActive()
    service.onAsyncLoadChatThreadsForChats($(%* {
      "chatIds": ["chat"], "includeSummaries": true,
      "threads": [{"chatId": "chat", "threadId": "thread", "parentMessageId": "parent"}]
    }))
    check service.getThreadById("chat", "thread").threadId == "thread"
    check not service.inlineThreadUnavailable("chat", "thread")
