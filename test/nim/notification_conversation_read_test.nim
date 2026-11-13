import std/[json, unittest]

import app/core/eventemitter
import app/core/signals/signals_manager
import app_service/common/activity_center
import app_service/service/message/service as message_service

suite "notification.conversation.read":
  setup:
    let events = createEventEmitter()
    let messages = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    messages.init()
    let manager = newSignalsManager(events)

    var marked: seq[MessagesMarkedAsReadArgs]
    events.on(SIGNAL_MESSAGES_MARKED_AS_READ) do(e: Args):
      marked.add(MessagesMarkedAsReadArgs(e))

    var acNotifications: JsonNode
    events.on(SIGNAL_PARSE_RAW_ACTIVITY_CENTER_NOTIFICATIONS) do(e: Args):
      acNotifications = RawActivityCenterNotificationsArgs(e).activityCenterNotifications

  test "a chat read from the tray is marked read like an in-app mark-all-read":
    manager.processSignal($(%* {
      "type": "notification.conversation.read",
      "event": {
        "chatId": "chat-id",
        "threadId": "",
        "response": {"jsonrpc": "2.0", "id": 1, "result": {
          "activityCenterNotifications": [{"id": "ac-id"}]
        }}
      }
    }))

    check marked.len == 1
    check marked[0].chatId == "chat-id"
    check marked[0].threadId == ""
    check marked[0].allMessagesMarked
    check acNotifications[0]["id"].getStr == "ac-id"

  test "a thread read from the tray is marked read for that thread only":
    manager.processSignal($(%* {
      "type": "notification.conversation.read",
      "event": {
        "chatId": "chat-id",
        "threadId": "thread-id",
        "response": {"jsonrpc": "2.0", "id": 1, "result": {}}
      }
    }))

    check marked.len == 1
    check marked[0].chatId == "chat-id"
    check marked[0].threadId == "thread-id"
    check marked[0].allMessagesMarked

  test "a signal without a chat id marks nothing":
    manager.processSignal("""{"type":"notification.conversation.read","event":{"response":{"result":{}}}}""")

    check marked.len == 0
