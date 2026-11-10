import std/[importutils, json, tables, unittest]

import app/core/eventemitter
import app_service/service/message/service as message_service
import app_service/service/message/message_cursor

privateAccess(message_service.Service)

# A chat with a page of its history in flight, and every SIGNAL_MESSAGES_LOADED
# it answers with.
proc chatWithPageInFlight(answers: ref seq[MessagesLoadedArgs]): message_service.Service =
  let events = createEventEmitter()
  events.on(SIGNAL_MESSAGES_LOADED) do(e: Args):
    answers[].add(MessagesLoadedArgs(e))

  result = message_service.newService(events, nil, nil, nil, nil, nil, nil)
  result.msgCursor["chat-id"] = initMessageCursor("cursor-1", pending = true, mostRecent = false)

suite "message history paging":
  # The view waits for every request to be answered: a failed page must still
  # reach the chat that asked, and must not leave the request pending for ever.
  test "a failed page is answered for its chat and can be asked again":
    let answers = new seq[MessagesLoadedArgs]
    let service = chatWithPageInFlight(answers)

    service.onAsyncLoadMoreMessagesForChat($(%* {
      "chatId": "chat-id",
      "threadId": "",
      "error": "boom"
    }))

    check(answers[].len == 1)
    check(answers[][0].chatId == "chat-id")
    check(answers[][0].messages.len == 0)

    let cursor = service.msgCursor["chat-id"]
    check(not cursor.isPending())
    check(cursor.isFetchable())
    check(cursor.getValue() == "cursor-1")
    check(not cursor.isMostRecent())

  test "a loaded page moves the cursor on":
    let answers = new seq[MessagesLoadedArgs]
    let service = chatWithPageInFlight(answers)

    service.onAsyncLoadMoreMessagesForChat($(%* {
      "chatId": "chat-id",
      "threadId": "",
      "messages": [],
      "messagesCursor": "cursor-2",
      "reactions": []
    }))

    check(answers[].len == 1)
    check(answers[][0].chatId == "chat-id")

    let cursor = service.msgCursor["chat-id"]
    check(not cursor.isPending())
    check(cursor.getValue() == "cursor-2")
    check(not cursor.isMostRecent())

suite "pinned messages cursor after leave":
  test "resetting the message cursor allows pinned messages to be fetched again":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    const chatId = "0xcommunity-general"
    service.msgCursor[chatId] = initMessageCursor("msg-cursor", pending = false, mostRecent = true)
    service.pinnedMsgCursor[chatId] = initMessageCursor("pin-cursor", pending = false, mostRecent = true)

    service.resetMessageCursor(chatId)

    check not service.msgCursor.hasKey(chatId)
    check not service.pinnedMsgCursor.hasKey(chatId)

  test "resetting the message cursor drops a stale pinned cursor even when message cursor is absent":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    const chatId = "0xcommunity-general"
    service.pinnedMsgCursor[chatId] = initMessageCursor("pin-cursor", pending = false, mostRecent = true)

    service.resetMessageCursor(chatId)

    check not service.pinnedMsgCursor.hasKey(chatId)

