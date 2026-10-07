import std/[json, unittest]
import app/core/eventemitter
import app/core/signals/types
import app_service/service/message/service as message_service

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
