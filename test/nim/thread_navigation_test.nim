import std/[importutils, json, tables, sets, unittest]
import nimqml

import app/core/eventemitter
import app/modules/main/chat_section/chat_content/io_interface as chat_content_interface
import app/modules/main/chat_section/chat_content/messages/module as messages_module
import app_service/service/message/service as message_service
import app/global/feature_flags
import app/modules/main/chat_section/chat_content/messages/[controller, view]
import app/modules/shared_models/message_model
import app/modules/shared_models/message_item
import app_service/service/contacts/dto/contact_details
import app_service/service/chat/service as chat_service
import app_service/service/contacts/service as contact_service
import app_service/service/community/service as community_service
import app_service/service/message/message_cursor
import app_service/service/message/dto/message
import app_service/service/message/dto/thread

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
        name: "Thread title", parentMessageId: "parent-id", setActive: false,
        hasUnreadMessages: unreadCount > 0, notificationsCount: mentionsCount))

    check(delegate.opened.len == 3)

  test "creating a thread preserves the selected parent chat":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let delegate = MockDelegate()
    let module = messages_module.newModule(delegate, events, "section-id", "chat-id",
      true, nil, nil, nil, service, nil, nil)
    defer: module.delete()

    module.onThreadCreated("parent-id", @[ThreadDto(threadId: "parent-id",
      parentMessageId: "parent-id", name: "New thread",
      unviewedMessagesCount: 2, unviewedMentionsCount: 1)])

    check(delegate.opened == @[OpenedThread(threadId: "parent-id",
      name: "New thread", parentMessageId: "parent-id", setActive: false,
      hasUnreadMessages: true, notificationsCount: 1)])

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

  test "info thread snapshots settle empty lists and incremental updates preserve other rows":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let module = messages_module.newModule(MockDelegate(), events, "section-id", "chat-id",
      true, nil, nil, nil, service, nil, nil)
    defer: module.delete()
    privateAccess(view.View)
    module.view.setThreadsState(true, false)
    module.onChatThreadsLoaded(@[
      ThreadDto(threadId: "first", parentMessageId: "parent-first", name: "First"),
      ThreadDto(threadId: "second", parentMessageId: "parent-second", name: "Second")
    ], listLoaded = true)
    check(module.view.threadsModel().rowCount(nil) == 2)
    check(not module.view.threadsLoading)
    module.onChatThreadsLoaded(@[ThreadDto(threadId: "first", parentMessageId: "parent-first", name: "Updated")])
    check(module.view.threadsModel().rowCount(nil) == 2)
    module.view.setThreadsState(true, false)
    module.onChatThreadsLoaded(@[], listLoaded = true)
    check(module.view.threadsModel().rowCount(nil) == 0)
    check(not module.view.threadsLoading)
    module.view.setThreadsState(true, false)
    module.onChatThreadsLoadingFailed()
    check(module.view.threadsLoading)
    check(not module.view.threadsError)
    module.onChatThreadsLoadingFailed(summariesRequested = true)
    check(module.view.threadsError)
    check(not module.view.threadsLoading)

  test "bulk thread summaries resolve message and album parents":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let module = messages_module.newModule(MockDelegate(), events, "section-id", "chat-id",
      true, nil, nil, nil, service, nil, nil)
    defer: module.delete()
    let parent = createMessageItemFromDtos(MessageDto(id: "parent", clock: 1), "", ContactDetails(), false, "", "")
    let album = createMessageItemFromDtos(MessageDto(id: "album-parent", albumId: "album", clock: 2), "",
      ContactDetails(), false, "", "", albumMessageIds = @["album-parent", "album-child"])
    module.view.model().insertItemBasedOnClock(parent)
    module.view.model().insertItemBasedOnClock(album)
    module.onChatThreadsLoaded(@[
      ThreadDto(threadId: "first", parentMessageId: "parent", name: "First", messagesCount: 2),
      ThreadDto(threadId: "second", parentMessageId: "album-child", name: "Second", messagesCount: 3),
      ThreadDto(threadId: "third", parentMessageId: "not-loaded", name: "Third", messagesCount: 1)
    ], listLoaded = true)
    check(parent.hasThread)
    check(parent.threadSummary.threadId == "first")
    check(album.hasThread)
    check(album.threadSummary.threadId == "second")
    check(module.view.threadsModel().rowCount(nil) == 3)

  test "thread info models are lazy and are not built for thread conversations":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let parent = messages_module.newModule(MockDelegate(), events, "section-id", "chat-id",
      true, nil, nil, nil, service, nil, nil)
    let child = messages_module.newModule(MockDelegate(), events, "section-id", "chat-id",
      true, nil, nil, nil, service, nil, nil, threadId = "thread-id")
    defer:
      parent.delete()
      child.delete()
    check(not parent.view.hasThreadsModel())
    check(not child.view.hasThreadsModel())
    let threads = @[ThreadDto(threadId: "first", parentMessageId: "parent-first", name: "First")]
    parent.onChatThreadsLoaded(threads)
    child.onChatThreadsLoaded(threads, listLoaded = true)
    check(not parent.view.hasThreadsModel())
    check(not child.view.hasThreadsModel())
    check(child.view.threadsModel().isNil)
    parent.onChatThreadsLoaded(threads, listLoaded = true)
    check(parent.view.threadsModel().rowCount(nil) == 1)
    check(not child.view.hasThreadsModel())

  test "thread summary snapshots preserve concurrent creations and unread updates":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      service.init()
      service.chatThreadSummariesLoadingChats.incl("chat-id")
      events.emit(chat_service.SIGNAL_CHAT_THREADS_UPDATED,
        chat_service.ChatThreadsUpdatedArgs(threads: @[
          ThreadDto(chatId: "chat-id", threadId: "existing", parentMessageId: "parent-existing",
            name: "Updated", unviewedMessagesCount: 3),
          ThreadDto(chatId: "chat-id", threadId: "new", parentMessageId: "parent-new", name: "New")
        ]))
      var completed: seq[ThreadDto]
      events.on(message_service.SIGNAL_CHAT_THREADS_FOR_CHATS_LOADED) do(e: Args):
        let args = ChatThreadsForChatsLoadedArgs(e)
        if args.summariesLoaded:
          completed = args.threads
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["chat-id"], "includeSummaries": true,
        "threads": [{"chatId": "chat-id", "threadId": "existing",
          "parentMessageId": "parent-existing", "name": "Old", "messagesCount": 2}]
      }))
      check(completed.len == 2)
      let existing = service.getThreadForParentMessage("chat-id", "parent-existing")
      check(existing.name == "Updated")
      check(existing.unviewedMessagesCount == 3)
      check(existing.messagesCount == 2)
      check(service.chatHasThreadForParentMessage("chat-id", "parent-new"))
      check(not service.chatThreadSummariesPendingUpdates.hasKey("chat-id"))
      completed = @[]
      service.asyncLoadChatThreadSummaries("chat-id")
      check(completed.len == 2)

  test "history invalidation filters stale chats from lightweight batch responses":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    service.init()
    events.emit(chat_service.SIGNAL_CHAT_HISTORY_CLEARED, chat_service.ChatArgs(chatId: "cleared"))
    var completed: seq[string]
    events.on(message_service.SIGNAL_CHAT_THREADS_FOR_CHATS_LOADED) do(e: Args):
      completed = ChatThreadsForChatsLoadedArgs(e).completedChatIds
    service.onAsyncLoadChatThreadsForChats($(%* {
      "chatIds": ["cleared", "current"], "includeSummaries": false,
      "chatRevisions": {"cleared": 0, "current": 0},
      "threads": [
        {"chatId": "cleared", "threadId": "old", "parentMessageId": "old-parent"},
        {"chatId": "current", "threadId": "live", "parentMessageId": "live-parent"}
      ]
    }))
    check(not service.chatHasThreadForParentMessage("cleared", "old-parent"))
    check(service.chatHasThreadForParentMessage("current", "live-parent"))
    check(completed == @["current"])
    service.onAsyncLoadChatThreadsForChats($(%* {
      "chatIds": ["cleared"], "includeSummaries": false,
      "chatRevisions": {"cleared": 1},
      "threads": [{"chatId": "cleared", "threadId": "new", "parentMessageId": "new-parent"}]
    }))
    check(service.chatHasThreadForParentMessage("cleared", "new-parent"))

  test "thread summary cache replays live updates and invalidates with chat history":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      service.init()
      var completed: seq[ThreadDto]
      events.on(message_service.SIGNAL_CHAT_THREADS_FOR_CHATS_LOADED) do(e: Args):
        let args = ChatThreadsForChatsLoadedArgs(e)
        if args.summariesLoaded:
          completed = args.threads
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["chat-id"], "includeSummaries": true,
        "threads": [{"chatId": "chat-id", "threadId": "thread-id",
          "parentMessageId": "parent-id", "name": "First", "messagesCount": 2}]
      }))
      completed = @[]
      # With no threadpool, a cache miss would fail instead of issuing a new RPC.
      service.asyncLoadChatThreadSummaries("chat-id")
      require(completed.len == 1)
      check(completed[0].name == "First")
      events.emit(chat_service.SIGNAL_CHAT_THREADS_UPDATED,
        chat_service.ChatThreadsUpdatedArgs(threads: @[
          ThreadDto(chatId: "chat-id", threadId: "thread-id", parentMessageId: "parent-id",
            name: "Updated", unviewedMessagesCount: 3)
        ]))
      service.asyncLoadChatThreadSummaries("chat-id")
      require(completed.len == 1)
      check(completed[0].name == "Updated")
      check(completed[0].unviewedMessagesCount == 3)
      check(completed[0].messagesCount == 2)
      service.chatThreadSummariesLoadingChats.incl("pending-chat")
      service.asyncLoadChatThreadSummaries("pending-chat")
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["pending-chat"], "includeSummaries": true, "error": "Failed"
      }))
      check("pending-chat" notin service.chatThreadSummariesLoadingChats)
      events.emit(chat_service.SIGNAL_CHAT_HISTORY_CLEARED, chat_service.ChatArgs(chatId: "chat-id"))
      check("chat-id" notin service.chatThreadSummariesLoadedChats)
      check(not service.chatThreadsByParentIdByChat.hasKey("chat-id"))
      # A response started before invalidation must not restore the old cache.
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["chat-id"], "includeSummaries": true, "threads": []
      }))
      check("chat-id" notin service.chatThreadSummariesLoadedChats)
      check(not service.chatThreadsByParentIdByChat.hasKey("chat-id"))
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["chat-id"], "includeSummaries": true,
        "chatRevisions": {"chat-id": service.chatThreadsRevision.getOrDefault("chat-id")}, "threads": []
      }))
      service.asyncLoadChatThreadSummaries("chat-id")
      check(completed.len == 0)
      check("chat-id" in service.chatThreadSummariesLoadedChats)
