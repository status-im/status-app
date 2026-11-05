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

  test "revisioned mute and unmute events update only the matching thread":
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root", name: "Thread"),
      ThreadDto(threadId: "sibling", chatId: "chat", parentMessageId: "other", name: "Other"),
    ]))
    for revision, muted in [true, false]:
      events.emit(SignalType.Message.event, MessageSignal(threads: @[
        ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
          name: "Thread", muted: muted, muteRevision: (revision + 1).int64),
      ]))
      service.onAsyncThreadMute($ %* {"chatId": "chat", "threadId": "thread", "error": ""})
      check service.getThreadById("chat", "thread").muted == muted
      check not service.getThreadById("chat", "sibling").muted
      check updates[^1].threads[0].muted == muted

  test "delayed expiration and snapshots cannot undo a newer mute":
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
        name: "Thread", muted: true, muteTill: 1793900000000'i64, muteRevision: 2),
    ]))
    for revision in [1'i64, 0'i64]:
      events.emit(SignalType.Message.event, MessageSignal(threads: @[
        ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
          name: "Updated name", muted: false, muteRevision: revision),
      ]))
      let thread = service.getThreadById("chat", "thread")
      check thread.muted
      check thread.muteTill == 1793900000000'i64
      check thread.muteRevision == 2
      check thread.name == "Updated name"
      check updates[^1].threads[0].muted

  test "older preferences cannot restore counters computed before a mute change":
    for muted in [true, false]:
      events.emit(SignalType.Message.event, MessageSignal(threads: @[
        ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
          muted: muted, muteRevision: 10, unviewedMessagesCount: 5, unviewedMentionsCount: 1),
      ]))
      for revision in [9'i64, 0'i64]:
        events.emit(SignalType.Message.event, MessageSignal(threads: @[
          ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
            muted: not muted, muteRevision: revision,
            unviewedMessagesCount: 6, unviewedMentionsCount: 5),
        ]))
        check service.getThreadById("chat", "thread").muted == muted
        check service.getThreadById("chat", "thread").unviewedMentionsCount == 1
        check updates[^1].threads[0].unviewedMentionsCount == 1
      # Normal message updates with the same preference must still refresh counts.
      events.emit(SignalType.Message.event, MessageSignal(threads: @[
        ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
          muted: muted, unviewedMessagesCount: 7, unviewedMentionsCount: 2),
      ]))
      check service.getThreadById("chat", "thread").unviewedMentionsCount == 2

  test "late mute completion cannot overwrite an expiration event":
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root",
        muted: false, muteRevision: 3),
    ]))
    service.onAsyncThreadMute($ %* {
      "chatId": "chat", "threadId": "thread", "error": "",
      "muted": true, "muteTill": "0001-01-01T00:00:00Z",
    })
    check not service.getThreadById("chat", "thread").muted
    check updates.len == 1

  test "failed mute completion leaves cached state unchanged":
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(threadId: "thread", chatId: "chat", parentMessageId: "root", muted: true),
    ]))
    service.onAsyncThreadMute($ %* {"chatId": "chat", "threadId": "thread", "error": "RPC failure"})
    check service.getThreadById("chat", "thread").muted
    check updates.len == 1
