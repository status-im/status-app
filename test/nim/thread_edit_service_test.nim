import std/[json, unittest]
import app/core/eventemitter
import app/core/signals/types
import app_service/service/message/service as message_service
import app_service/service/activity_center/service as activity_service

suite "thread edit metadata handling":
  setup:
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    service.init()
    var updates: seq[ChatThreadsForChatsLoadedArgs]
    var completions: seq[ThreadEditFinishedArgs]
    events.on(SIGNAL_CHAT_THREADS_FOR_CHATS_LOADED) do(args: Args):
      updates.add(ChatThreadsForChatsLoadedArgs(args))
    events.on(SIGNAL_THREAD_EDIT_FINISHED) do(args: Args):
      completions.add(ThreadEditFinishedArgs(args))

  test "thread lookup borrows cached storage across subsequent lookups":
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "first", chatId: "chat", parentMessageId: "first-root",
        name: "First thread", participantsPreviewIds: @["creator", "member"],
        lastMessage: ThreadLastMessageDto(text: "First reply")),
      ThreadDto(threadId: "second", chatId: "chat", parentMessageId: "second-root",
        name: "Second thread"),
    ]))
    let first {.cursor.} = service.getThreadById("chat", "first")
    let second {.cursor.} = service.getThreadById("chat", "second")
    check second.name == "Second thread"
    check first.threadId == "first"
    check first.name == "First thread"
    check first.participantsPreviewIds == @["creator", "member"]
    check first.lastMessage.text == "First reply"
    let copied = first
    check copied.name == "First thread"
    check copied.participantsPreviewIds == @["creator", "member"]

  test "missing chat and thread lookups return an empty DTO":
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
        name: "Existing thread"),
    ]))
    check service.getThreadById("missing-chat", "thread") == ThreadDto()
    check service.getThreadById("chat", "missing-thread") == ThreadDto()
    check service.getThreadById("", "") == ThreadDto()
    check service.getThreadById("chat", "thread").name == "Existing thread"

  test "local rename preserves cached summary and emits keyed completion":
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root", name: "Old",
        creatorId: "creator", messagesCount: 3, unviewedMessagesCount: 2,
        participantsCount: 2, participantsPreviewIds: @["creator", "member"],
        lastMessage: ThreadLastMessageDto(text: "Unchanged reply")),
    ]))
    service.onAsyncEditThread($ %* {
      "chatId": "chat", "threadId": "thread", "requestId": "request",
      "error": "",
      "threads": [{
        "chatId": "chat", "threadId": "thread", "parentMessageId": "root",
        "name": "Renamed", "unviewedMessagesCount": 2,
      }],
    })
    let cached = service.getThreadById("chat", "thread")
    check cached.name == "Renamed"
    check cached.creatorId == "creator"
    check cached.messagesCount == 3
    check cached.participantsPreviewIds == @["creator", "member"]
    check cached.lastMessage.text == "Unchanged reply"
    check cached.unviewedMessagesCount == 2
    check updates.len == 2
    check updates[^1].threads[0].name == "Renamed"
    check completions.len == 1
    check completions[0].chatId == "chat"
    check completions[0].threadId == "thread"
    check completions[0].requestId == "request"
    check completions[0].error == ""

  test "metadata-only remote rename updates zero-reply thread without save completion":
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
        name: "Remote", creatorId: "creator"),
    ]))
    check service.getThreadById("chat", "thread").name == "Remote"
    check updates.len == 1
    check updates[0].threads[0].messagesCount == 0
    check completions.len == 0

  test "RPC error is surfaced without metadata update":
    service.onAsyncEditThread($ %* {
      "chatId": "chat", "threadId": "thread", "requestId": "failed-request",
      "error": "edit-thread: invalid name",
    })
    check updates.len == 0
    check completions.len == 1
    check completions[0].requestId == "failed-request"
    check completions[0].error == "edit-thread: invalid name"

  test "missing or wrong edited thread metadata is not treated as success":
    for threads in [newJArray(), %* [{
      "chatId": "different-chat", "threadId": "thread", "name": "Wrong",
    }]]:
      service.onAsyncEditThread($ %* {
        "chatId": "chat", "threadId": "thread", "requestId": "malformed",
        "error": "", "threads": threads,
      })
      check completions[^1].error.len > 0
    check updates.len == 0
    check completions.len == 2

  test "missing threads and incomplete thread metadata are explicit failures":
    service.onAsyncEditThread($ %* {
      "chatId": "chat", "threadId": "thread", "requestId": "missing",
      "error": "",
    })
    service.onAsyncEditThread($ %* {
      "chatId": "chat", "threadId": "thread", "requestId": "incomplete",
      "error": "", "threads": [{"chatId": "chat", "threadId": "thread"}],
    })
    check completions.len == 2
    check completions[0].error.len > 0
    check completions[1].error.len > 0
    check updates.len == 0

  test "deletion clears summaries and survives stale metadata and snapshots":
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root", name: "Thread",
        messagesCount: 3, unviewedMessagesCount: 2, participantsCount: 2,
        participantsPreviewIds: @["creator"], lastMessage: ThreadLastMessageDto(text: "Private reply")),
    ]))
    var deletedCompletions: seq[ThreadDeleteFinishedArgs]
    events.on(SIGNAL_THREAD_DELETE_FINISHED) do(args: Args):
      deletedCompletions.add(ThreadDeleteFinishedArgs(args))
    service.onAsyncDeleteThread($ %* {
      "chatId": "chat", "threadId": "thread", "requestId": "delete-request", "error": "",
      "threads": [{"chatId": "chat", "threadId": "thread", "parentMessageId": "root",
        "deleted": true, "deletedBy": "admin", "deletedClock": 20, "deletedAt": 18}],
    })
    check deletedCompletions.len == 1
    check deletedCompletions[0].error == ""
    check deletedCompletions[0].requestId == "delete-request"
    var cached = service.getThreadById("chat", "thread")
    check cached.deleted
    check cached.deletedBy == "admin"
    check cached.messagesCount == 0
    check cached.participantsPreviewIds.len == 0
    check cached.lastMessage.text == ""
    check cached.unviewedMessagesCount == 0
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
        name: "Old metadata", messagesCount: 3),
    ]))
    check service.getThreadById("chat", "thread").deleted
    service.onAsyncLoadChatThreadsForChats($ %* {
      "chatIds": ["chat"], "threads": [], "includeSummaries": true,
      "chatRevisions": [0], "error": "",
    })
    cached = service.getThreadById("chat", "thread")
    check cached.deleted
    check cached.deletedAt == 18
    check cached.messagesCount == 0

  test "failed or malformed deletion never changes the cached thread":
    var errors: seq[string]
    events.on(SIGNAL_THREAD_DELETE_FINISHED) do(args: Args):
      errors.add(ThreadDeleteFinishedArgs(args).error)
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root", name: "Thread"),
    ]))
    for reply in [
      %* {"chatId": "chat", "threadId": "thread", "requestId": "denied", "error": "permission denied"},
      %* {"chatId": "chat", "threadId": "thread", "requestId": "missing", "error": "", "threads": []},
      %* {"chatId": "chat", "threadId": "thread", "requestId": "active", "error": "",
        "threads": [{"chatId": "chat", "threadId": "thread", "parentMessageId": "root", "deleted": false}]},
    ]:
      service.onAsyncDeleteThread($reply)
      check not service.getThreadById("chat", "thread").deleted
    check errors.len == 3
    for error in errors:
      check error.len > 0

  test "deletion removes loaded activity notifications and filters late updates":
    let activity = activity_service.newService(events, nil, nil)
    activity.init()
    var received: seq[string]
    var removed: seq[string]
    events.on(activity_service.SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_RECEIVED) do(args: Args):
      for notification in ActivityCenterNotificationsArgs(args).activityCenterNotifications:
        received.add(notification.id)
    events.on(activity_service.SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_REMOVED) do(args: Args):
      removed.add(ActivityCenterNotificationIdsArgs(args).notificationIds)
    let notification = ActivityCenterNotificationDto(id: "notification", chatId: "chat", threadId: "thread",
      notificationType: ActivityCenterNotificationType.Mention)
    events.emit(SignalType.Message.event, MessageSignal(activityCenterNotifications: @[notification]))
    check received == @["notification"]
    events.emit(SIGNAL_CHAT_THREADS_FOR_CHATS_LOADED, ChatThreadsForChatsLoadedArgs(threads: @[
      ThreadDto(chatId: "chat", threadId: "thread", parentMessageId: "root", deleted: true)]))
    check removed == @["notification"]
    events.emit(SignalType.Message.event, MessageSignal(activityCenterNotifications: @[notification]))
    check received == @["notification"]
