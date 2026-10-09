import std/[importutils, json, tables, unittest]

import app/core/eventemitter
import app/modules/main/chat_section/chat_content/io_interface as chat_content_interface
import app/modules/main/chat_section/chat_content/messages/module as messages_module
import app_service/service/message/service as message_service
import app/global/feature_flags
import app/modules/main/chat_section/chat_content/messages/[controller, view]
import app/modules/shared_models/message_model
import app_service/service/chat/service as chat_service
import app_service/service/contacts/service as contact_service
import app_service/service/community/service as community_service
import app_service/service/message/message_cursor
import app_service/service/message/dto/message

privateAccess(messages_module.Module)
privateAccess(message_service.Service)

type
  OpenedThread = object
    threadId, name, parentMessageId: string
    setActive, hasUnreadMessages: bool
    notificationsCount: int

  MockDelegate = ref object of chat_content_interface.AccessInterface
    opened: seq[OpenedThread]

method openThreadAsChat(self: MockDelegate, threadId, threadName, parentMessageId: string,
    setActive: bool = true, hasUnreadMessages: bool = false, notificationsCount: int = 0) =
  self.opened.add(OpenedThread(threadId: threadId, name: threadName,
    parentMessageId: parentMessageId, setActive: setActive,
    hasUnreadMessages: hasUnreadMessages, notificationsCount: notificationsCount))

suite "thread navigation":
  test "reopening an existing thread forwards current unread state":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let delegate = MockDelegate()
    let module = messages_module.newModule(delegate, events, "section-id", "chat-id",
      true, nil, nil, nil, service, nil, nil)
    defer: module.delete()

    for (unreadCount, mentionsCount) in [(1, 0), (2, 1), (0, 0)]:
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["chat-id"],
        "threads": [{
          "threadId": "thread-id",
          "chatId": "chat-id",
          "parentMessageId": "parent-id",
          "name": "Thread title",
          "unviewedMessagesCount": unreadCount,
          "unviewedMentionsCount": mentionsCount
        }]
      }))

      module.createThread("parent-id")
      check(delegate.opened[^1] == OpenedThread(threadId: "thread-id",
        name: "Thread title", parentMessageId: "parent-id", setActive: true,
        hasUnreadMessages: unreadCount > 0, notificationsCount: mentionsCount))

    check(delegate.opened.len == 3)

  test "empty and filtered final pages finish a pending message search":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    service.msgCursor["chat-id"] = initMessageCursor("", false, true)
    let module = messages_module.newModule(MockDelegate(), events, "section-id", "chat-id",
      true, nil, nil, nil, service, nil, nil)
    defer: module.delete()
    module.onFirstUnseenMessageLoaded("")
    module.switchToMessage("missing-id")
    module.view.setMessageSearchOngoing(true)

    module.newMessagesLoaded(@[], @[])

    check(module.controller.getSearchedMessageId() == "")
    check(not module.view.getMessageSearchOngoing())
    check(not module.view.isLoading())

    if THREADS_ENABLED:
      module.switchToMessage("missing-reply")
      module.view.setMessageSearchOngoing(true)
      module.newMessagesLoaded(@[MessageDto(id: "filtered-reply", threadId: "thread-id")], @[])
      check(module.controller.getSearchedMessageId() == "")
      check(not module.view.getMessageSearchOngoing())
      check(not module.view.isLoading())

  test "thread reply visibility follows the feature flag for loaded and added messages":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let contacts = contact_service.newService(events, nil, nil, nil)
    let chats = chat_service.newService(events, nil, contacts)
    let communities = community_service.newService(events, nil, chats, nil, service)
    let module = messages_module.newModule(MockDelegate(), events, "section-id", "chat-id",
      true, contacts, communities, chats, service, nil, nil)
    defer: module.delete()

    module.newMessagesLoaded(@[MessageDto(id: "loaded-reply", threadId: "thread-id", clock: 1)], @[])
    module.messagesAdded(@[MessageDto(id: "added-reply", threadId: "thread-id", clock: 2)])

    for id in ["loaded-reply", "added-reply"]:
      check((module.view.model().findIndexForMessageId(id) >= 0) == not THREADS_ENABLED)
