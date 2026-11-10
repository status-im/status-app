import std/[importutils, json, os, tables, sets, tempfiles, unittest]
import nimqml

import app/core/eventemitter
import app/global/app_signals
import app/modules/main/app_search/io_interface as search_interface
import app/modules/main/app_search/controller as search_controller
import app/modules/main/app_search/module as search_module
import app/modules/main/app_search/view
import app/modules/main/app_search/models/location_menu_sub_model
import app/modules/main/app_search/models/[location_menu_model, location_menu_item, location_menu_sub_item]
import app_service/service/message/service as message_service
import app_service/service/message/dto/[message, thread]
import app_service/service/chat/service as chat_service
import app_service/service/chat/dto/chat

import app/global/feature_flags
import app/global/global_singleton
import app/global/qt_settings
import app/modules/main/chat_section/module as section_module
import app/modules/main/chat_section/controller as section_controller
import app/modules/main/chat_section/view as section_view
import app/modules/main/chat_section/item as chat_item
import app/modules/main/chat_section/model as section_model
import app/modules/main/chat_section/chat_content/io_interface as content_interface

privateAccess(search_controller.Controller)
privateAccess(search_module.Module)
privateAccess(view.View)
privateAccess(message_service.Service)
privateAccess(chat_service.Service)
privateAccess(LocalAccountSensitiveSettings)

type SearchDelegate = ref object of search_interface.AccessInterface
  completions: seq[seq[MessageDto]]

method onSearchMessagesDone(self: SearchDelegate, messages: seq[MessageDto]) =
  self.completions.add(messages)

suite "thread content search":
  test "global search keeps the active parent and thread without scanning other chats":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let chats = chat_service.newService(events, nil, nil)
      chats.chats["parent"] = ChatDto(id: "parent", communityId: "section")
      let module = search_module.newModule(nil, events, nil, chats, nil, service)
      defer: module.delete()
      let section = location_menu_item.initItem("section", "Community", "", "")
      section.setSubItems(@[location_menu_sub_item.initSubItem("parent", "general", "", "", "", false, false, 0, 0)])
      module.view.locationMenuModel().setItems(@[section])
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["parent"], "threads": [{"chatId": "parent", "threadId": "thread",
          "parentMessageId": "root", "name": "Thread"}]
      }))
      module.onActiveChatChange("section", "parent", "thread")
      let activeScope = module.getSearchLocationObject().parseJson
      check activeScope["subLocation"]["value"].getStr == "parent"
      check activeScope["thread"]["value"].getStr == "thread"
      check activeScope["thread"]["text"].getStr == "Thread"
      check service.getThreadById("", "thread").threadId == ""
      check service.getThreadById("other-parent", "thread").threadId == ""

      let parentScope = module.getSearchLocationObject("parent").parseJson
      check parentScope["thread"].getStr == ""
      let explicitScope = module.getSearchLocationObject("parent", "thread").parseJson
      check explicitScope["thread"]["value"].getStr == "thread"

      module.onActiveChatChange("section", "parent", "uncached-thread")
      let uncachedScope = module.getSearchLocationObject().parseJson
      check uncachedScope["subLocation"]["value"].getStr == "parent"
      check uncachedScope["thread"]["value"].getStr == "uncached-thread"
      module.onActiveChatChange("section", "parent")
      check module.controller.activeThreadId() == ""
      check module.getSearchLocationObject().parseJson["thread"].getStr == ""
    else:
      skip()

  test "only the current request may replace search results":
    let events = createEventEmitter()
    let delegate = SearchDelegate()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let controller = search_controller.newController(delegate, events, nil, nil, nil, service)
    controller.init()
    controller.searchRequestId = "current"

    for requestId in ["old", "", "current"]:
      service.onAsyncSearchMessages($(%* {
        "requestId": requestId,
        "messages": {"messages": []},
        "error": ""
      }))
    check delegate.completions.len == 1

    controller.setSearchLocation("section", "parent", "thread")
    check controller.searchThreadId() == "thread"
    events.emit(SIGNAL_SEARCH_MESSAGES_LOADED, SearchMessagesArgs(requestId: "current"))
    check delegate.completions.len == 1

    controller.searchRequestId = "next"
    controller.invalidateSearch()
    events.emit(SIGNAL_SEARCH_MESSAGES_LOADED, SearchMessagesArgs(requestId: "next"))
    check delegate.completions.len == 1

  test "resetting a location clears its thread scope":
    let controller = search_controller.newController(nil, nil, nil, nil, nil, nil)
    controller.setSearchLocation("section", "parent", "thread")
    controller.setSearchLocation("section", "parent")
    check controller.searchThreadId() == ""
    check controller.searchSubLocation() == "parent"
    controller.setSearchLocation("", "")
    check controller.searchLocation() == ""
    check controller.searchSubLocation() == ""

  test "clearing results preserves the clicked result's thread destination":
    let events = createEventEmitter()
    let module = search_module.newModule(nil, events, nil, nil, nil, nil)
    defer: module.delete()
    var destination: ActiveSectionChatArgs
    events.on(SIGNAL_MAKE_SECTION_CHAT_ACTIVE) do(e: Args):
      destination = ActiveSectionChatArgs(e)
    module.controller.addResultItemDetails("message", "section", "parent", "message", "thread")
    module.searchMessages("")
    module.resultItemClicked("message")
    check not destination.isNil
    check destination.sectionId == "section"
    check destination.chatId == "parent"
    check destination.threadId == "thread"
    check destination.messageId == "message"

  test "thread menu ignores other chats and late completions":
    let module = search_module.newModule(nil, nil, nil, nil, nil, nil)
    defer: module.delete()
    module.threadLocationChatId = "parent"
    module.view.setThreadLocationsState(true, false)
    module.onThreadLocationsLoaded(@[ThreadDto(chatId: "old", threadId: "old")], @["old"])
    check module.view.threadLocationsLoading
    check module.view.threadLocationMenuModel().count() == 0

    module.onThreadLocationsLoaded(@[
      ThreadDto(chatId: "parent", threadId: "one", name: "First"),
      ThreadDto(chatId: "other", threadId: "two", name: "Other")
    ], @["parent", "other"])
    check not module.view.threadLocationsLoading
    check module.view.threadLocationMenuModel().count() == 1
    module.onThreadLocationsFailed("old")
    check not module.view.threadLocationsError
    module.onThreadLocationsFailed("parent")
    check module.view.threadLocationsError
    module.onThreadLocationsLoaded(@[], @["parent"])
    check not module.view.threadLocationsError
    check module.view.threadLocationMenuModel().count() == 0

  test "channel submenu availability follows completed thread lists":
    let module = search_module.newModule(nil, nil, nil, nil, nil, nil)
    defer: module.delete()
    let section = location_menu_item.initItem("section", "Community", "", "")
    let parent = location_menu_sub_item.initSubItem("parent", "general", "", "", "", false, false, 0, 0)
    let empty = location_menu_sub_item.initSubItem("empty", "empty", "", "", "", false, false, 0, 0)
    section.setSubItems(@[parent, empty])
    module.view.locationMenuModel().setItems(@[section])
    check section.subItems.chatIds() == @["parent", "empty"]
    module.onThreadLocationsLoaded(@[ThreadDto(chatId: "parent", threadId: "one")], @["parent", "empty"])
    check parent.hasThreads
    check not empty.hasThreads
    module.onThreadLocationsLoaded(@[], @["other"])
    check parent.hasThreads
    module.onThreadLocationsLoaded(@[], @["parent"])
    check not parent.hasThreads

  test "summary and lightweight completion orders both settle thread locations":
    for summariesFirst in [false, true]:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let module = search_module.newModule(nil, events, nil, nil, nil, service)
      defer: module.delete()
      module.controller.init()
      let section = location_menu_item.initItem("section", "Community", "", "")
      let parent = location_menu_sub_item.initSubItem("parent", "general", "", "", "", false, false, 0, 0)
      section.setSubItems(@[parent])
      module.view.locationMenuModel().setItems(@[section])
      module.threadLocationChatId = "parent"
      module.view.setThreadLocationsState(true, false)
      service.chatThreadListsLoadingChats.incl("parent")
      service.chatThreadSummariesLoadingChats.incl("parent")
      for includeSummaries in (if summariesFirst: @[true, false] else: @[false, true]):
        service.onAsyncLoadChatThreadsForChats($(%* {
          "chatIds": ["parent"], "includeSummaries": includeSummaries,
          "threads": [{"chatId": "parent", "threadId": "thread", "parentMessageId": "root", "name": "Thread"}]
        }))
        check not module.view.threadLocationsLoading
        check parent.hasThreads
        check module.view.threadLocationMenuModel().count() == 1

  test "entering a section requests only its chats using the shared cache":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      service.chatThreadListsLoadedChats.incl("parent")
      service.chatThreadListsLoadedChats.incl("other")
      let module = search_module.newModule(nil, events, nil, nil, nil, service)
      defer: module.delete()
      let section = location_menu_item.initItem("section", "Community", "", "")
      section.setSubItems(@[location_menu_sub_item.initSubItem("parent", "general", "", "", "", false, false, 0, 0)])
      let other = location_menu_item.initItem("other-section", "Other", "", "")
      other.setSubItems(@[location_menu_sub_item.initSubItem("other", "other", "", "", "", false, false, 0, 0)])
      module.view.locationMenuModel().setItems(@[section, other])
      var completed: seq[seq[string]]
      events.on(SIGNAL_CHAT_THREADS_FOR_CHATS_LOADED) do(e: Args):
        completed.add(ChatThreadsForChatsLoadedArgs(e).completedChatIds)
      check completed.len == 0
      module.prepareThreadLocationsForSection("missing")
      check completed.len == 0
      module.prepareThreadLocationsForSection("section")
      check completed == @[@["parent"]]
      module.prepareThreadLocationsForSection("other-section")
      check completed == @[@["parent"], @["other"]]
    else:
      skip()

privateAccess(section_module.Module)
privateAccess(chat_item.ChatItem)

type
  ContentStub = ref object of content_interface.AccessInterface
    scrolledTo: seq[string]
    renamedTo: seq[string]
  SectionHarness = ref object of section_module.Module
    activated: seq[string]
    panelClosed: bool
    refreshes: seq[string]

method requestThreadLinkRefresh(self: SectionHarness, chatId: string) =
  self.refreshes.add(chatId)

method scrollToMessage(self: ContentStub, messageId: string) =
  self.scrolledTo.add(messageId)

method onThreadRenamed(self: ContentStub, newName: string) =
  self.renamedTo.add(newName)

method delete(self: ContentStub) = discard
method onNotificationsUpdated(self: ContentStub, hasUnreadMessages: bool, notificationsCount: int) = discard

method setActiveItem(self: SectionHarness, itemId: string) =
  self.activated.add(itemId)

method closeThreadPanel(self: SectionHarness) =
  self.panelClosed = true

proc newSectionHarness(service: message_service.Service, events: EventEmitter): SectionHarness =
  result = SectionHarness(messageService: service)
  result.events = events
  result.controller = section_controller.newController(result, "section", false, events,
    nil, nil, nil, nil, nil, service, nil, nil, nil, nil, nil, nil)
  result.view = section_view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.threadChatIds = initHashSet[string]()
  result.chatContentModules = initOrderedTable[string, content_interface.AccessInterface]()
  result.view.chatsModel().setData(@[chat_item.ChatItem(id: "parent", name: "Parent", canView: true,
    categoryOpened: true)])

suite "thread search result navigation":
  test "thread rows inherit persisted mute state and preserve mention markers on updates":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let section = newSectionHarness(service, events)
    defer: section.delete()
    section.chatsLoaded = true
    var thread = ThreadDto(chatId: "parent", threadId: "thread", parentMessageId: "root",
      name: "Thread", muted: true, unviewedMessagesCount: 3)
    section.onChatThreadsForChatsLoaded(@[thread], @["parent"])
    let item = section.view.chatsModel().getItemById("thread")
    require(not item.isNil)
    check(item.muted)
    check(item.notificationsCount == 0)
    thread.unviewedMentionsCount = 1
    section.onChatThreadsForChatsLoaded(@[thread], @[])
    check(item.muted)
    check(item.notificationsCount == 1)
    thread.muted = false
    section.onChatThreadsForChatsLoaded(@[thread], @[])
    check(not item.muted)
    # The sidebar mute icon must target the thread API, not its parent's chat API.
    service.threadMutePending.incl(("parent", "thread"))
    section.unmuteChat("thread")
    check(service.threadMuteQueued[("parent", "thread")] == 7)

  test "an uncached result survives a cached list and opens on an incremental update":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      section.chatsLoaded = true
      section.controller.init()
      service.init()
      let content = ContentStub()
      section.chatContentModules["thread"] = content

      let settings = singletonInstance.localAccountSensitiveSettings
      let previousSettings = settings.settings
      let settingsDir = createTempDir("thread-search-", "")
      let settingsFile = settingsDir / "settings.ini"
      settings.settings = newQSettings(settingsFile, QSettingsFormat.IniFormat)
      defer:
        settings.settings.delete()
        settings.settings = previousSettings
        removeFile(settingsFile)
        removeDir(settingsDir)
      settings.setSectionLastOpenThread("section", "saved-thread", "parent", THREAD_PRESENTATION_SELECTED_CHAT)
      let savedThread = settings.getSectionLastOpenThread("section")

      # This list is already loaded, so opening the result synchronously replays it.
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["parent"], "threads": []
      }))
      check section.openCommunityChatAndScrollToMessage("parent", "target", "thread")
      check section.pendingThreadId == "thread"
      check section.pendingThreadMessageId == "target"
      check settings.getSectionLastOpenThread("section") == savedThread
      check section.activated == @["parent"]

      events.emit(chat_service.SIGNAL_CHAT_THREADS_UPDATED, chat_service.ChatThreadsUpdatedArgs(threads: @[
        ThreadDto(chatId: "parent", threadId: "other-thread", parentMessageId: "other-root", name: "Other")
      ]))
      check section.pendingThreadMessageId == "target"
      check content.scrolledTo.len == 0

      events.emit(chat_service.SIGNAL_CHAT_THREADS_UPDATED, chat_service.ChatThreadsUpdatedArgs(threads: @[
        ThreadDto(chatId: "parent", threadId: "thread", parentMessageId: "root", name: "Thread")
      ]))
      check section.activated == @["parent", "thread"]
      check section.panelClosed
      check content.scrolledTo == @["target"]
      check section.pendingThreadId == ""
      check section.pendingThreadMessageId == ""
      check settings.getSectionLastOpenThread("section") == savedThread
    else:
      skip()

  test "archiving retains selected and panel threads and cached opening respects archive state":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let section = newSectionHarness(service, events)
    defer: section.delete()
    section.chatsLoaded = true
    let content = ContentStub()
    section.chatContentModules["thread"] = content
    section.onChatThreadsForChatsLoaded(@[
      ThreadDto(chatId: "parent", threadId: "thread", parentMessageId: "root",
        name: "Thread", archived: true)], @[])
    let row = section.view.chatsModel().getItemById("thread")
    require not row.isNil
    check row.archived
    section.view.setOpenThread("thread", "Thread", "parent")
    section.pendingThreadId = "saved-thread"
    section.pendingThreadParentChatId = "parent"
    for archived in [false, true, true, false]:
      section.onChatThreadsForChatsLoaded(@[
        ThreadDto(chatId: "parent", threadId: "thread", parentMessageId: "root",
          name: "Thread", archived: archived)], @[])
      check row.archived == archived
      check section.view.chatsModel().getItemById("thread") == row
      check section.view.chatsModel().rowCount() == 2
      check section.view.getOpenThreadId() == "thread"
      check section.chatContentModules["thread"] == content
      check section.isChatThread("thread")
      check section.activated.len == 0
      check not section.panelClosed
      check section.pendingThreadId == "saved-thread"
    service.onAsyncLoadChatThreadsForChats($(%* {
      "chatIds": ["parent"], "threads": [{"chatId": "parent", "threadId": "cached",
        "parentMessageId": "cached-root", "name": "Archived", "archived": true}]
    }))
    section.openThreadAsChat("parent", "cached", "Archived", "cached-root")
    check section.view.chatsModel().getItemById("cached").archived
    section.openThreadAsChat("parent", "cached", "Archived", "cached-root")
    check section.view.chatsModel().rowCount() == 3
    check section.view.chatsModel().getItemById("cached").archived

  test "a newer parent or cached thread result cancels deferred navigation":
    if THREADS_ENABLED:
      for nextThreadId in ["", "cached-thread"]:
        let events = createEventEmitter()
        let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
        let section = newSectionHarness(service, events)
        defer: section.delete()
        let parentContent = ContentStub()
        let cachedContent = ContentStub()
        let pendingContent = ContentStub()
        section.chatContentModules["parent"] = parentContent
        section.chatContentModules["cached-thread"] = cachedContent
        section.chatContentModules["pending-thread"] = pendingContent
        check section.openCommunityChatAndScrollToMessage("parent", "old-target", "pending-thread")
        section.chatsLoaded = true
        service.onAsyncLoadChatThreadsForChats($(%* {
          "chatIds": ["parent"], "threads": [{"chatId": "parent", "threadId": "cached-thread",
            "parentMessageId": "cached-root", "name": "Cached"}]
        }))
        check section.openCommunityChatAndScrollToMessage("parent", "new-target", nextThreadId)
        check section.pendingThreadMessageId == ""
        let activated = section.activated
        section.onChatThreadsForChatsLoaded(@[
          ThreadDto(chatId: "parent", threadId: "pending-thread", parentMessageId: "pending-root", name: "Pending")
        ], @["parent"])
        check section.activated == activated
        check pendingContent.scrolledTo.len == 0
        if nextThreadId.len == 0:
          check parentContent.scrolledTo == @["new-target"]
        else:
          check cachedContent.scrolledTo == @["new-target"]
    else:
      skip()

  test "a destination without pending message navigation preserves saved thread restoration":
    let events = createEventEmitter()
    let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let section = newSectionHarness(service, events)
    defer: section.delete()
    section.pendingThreadId = "saved-thread"
    section.pendingThreadParentChatId = "parent"
    section.chatContentModules["parent"] = ContentStub()
    check section.openCommunityChatAndScrollToMessage("parent", "target")
    check section.pendingThreadId == "saved-thread"
    check section.pendingThreadParentChatId == "parent"

  test "a result waits for section and thread metadata before scrolling":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      let content = ContentStub()
      section.chatContentModules["thread"] = content
      let thread = ThreadDto(chatId: "parent", threadId: "thread", parentMessageId: "root", name: "Thread")

      check section.openCommunityChatAndScrollToMessage("parent", "target", "thread")
      check section.activated == @["parent"]
      section.onChatThreadsForChatsLoaded(@[thread], @["parent"])
      check content.scrolledTo.len == 0
      check section.pendingThreadMessageId == "target"

      section.chatsLoaded = true
      section.onChatThreadsForChatsLoaded(@[thread], @["unrelated"])
      check content.scrolledTo.len == 0
      check content.renamedTo.len == 0
      section.onChatThreadsForChatsLoaded(@[thread], @["parent"])
      check content.renamedTo == @["Thread"]
      check section.activated == @["parent", "thread"]
      check section.panelClosed
      check content.scrolledTo == @["target"]
      check section.pendingThreadMessageId == ""
    else:
      skip()

  test "leaving a section cancels pending result navigation":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      check section.openCommunityChatAndScrollToMessage("parent", "target", "thread")
      section.onActiveSectionChange("another-section")
      check section.pendingThreadId == ""
      check section.pendingThreadMessageId == ""
    else:
      skip()

  test "a failed thread load cancels the pending result without changing chat":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      check section.openCommunityChatAndScrollToMessage("parent", "target", "thread")
      section.onChatThreadsLoadingFailed("unrelated")
      check section.pendingThreadMessageId == "target"
      section.onChatThreadsLoadingFailed("parent")
      check section.pendingThreadId == ""
      check section.activated == @["parent"]
    else:
      skip()

  test "an unavailable parent never becomes a thread destination":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      section.chatsLoaded = true
      check not section.openCommunityChatAndScrollToMessage("missing-parent", "target", "thread")
      check section.activated.len == 0
    else:
      skip()

suite "thread link navigation":
  test "a thread link waits for metadata without a message target":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      let content = ContentStub()
      section.chatContentModules["thread"] = content
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      check section.pendingThreadNavigation
      check section.pendingThreadMessageId == ""
      section.chatsLoaded = true
      section.onChatThreadsForChatsLoaded(@[ThreadDto(chatId: "parent", threadId: "thread",
        parentMessageId: "root", name: "Thread")], @["parent"])
      check section.activated == @["parent", "thread"]
      check section.panelClosed
      check content.scrolledTo.len == 0
      check not section.pendingThreadNavigation
    else:
      skip()

  test "leaving a section cancels a pending thread link":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      section.onActiveSectionChange("elsewhere")
      check section.pendingThreadId == ""
      check not section.pendingThreadNavigation
    else:
      skip()

  test "failed metadata loading cancels a pending thread link":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      section.onChatThreadsLoadingFailed("parent")
      check section.pendingThreadId == ""
      check not section.pendingThreadNavigation
    else:
      skip()

  test "a thread link rejects a missing or inaccessible parent":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      section.chatsLoaded = true
      check not section.openCommunityChatAndScrollToMessage("missing", "", "thread")
      section.view.chatsModel().getItemById("parent").canView = false
      check not section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      check section.activated.len == 0
    else:
      skip()

  test "a missing thread refreshes once before reporting unavailable":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      check section.openCommunityChatAndScrollToMessage("parent", "", "missing-thread")
      section.chatsLoaded = true
      section.onChatThreadsForChatsLoaded(@[], @["parent"])
      check section.pendingThreadNavigation
      check section.refreshes == @["parent"]
      section.onChatThreadsForChatsLoaded(@[], @["parent"])
      check section.refreshes == @["parent"]
      check section.pendingThreadNavigation
      var failures = 0
      events.on(SIGNAL_THREAD_LINK_FAILED) do(e: Args):
        inc failures
      section.onChatThreadsForChatsLoaded(@[], @["parent"], summariesLoaded = true)
      check section.pendingThreadId == ""
      check not section.pendingThreadNavigation
      check section.activated == @["parent"]
      check failures == 1
      section.onChatThreadsForChatsLoaded(@[], @["parent"], summariesLoaded = true)
      check failures == 1
    else:
      skip()

  test "a cached thread link opens without scrolling to an empty message":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      section.chatsLoaded = true
      let content = ContentStub()
      section.chatContentModules["thread"] = content
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["parent"], "threads": [{"chatId": "parent", "threadId": "thread",
          "parentMessageId": "root", "name": "Thread"}]
      }))
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      check section.activated[^1] == "thread"
      check section.panelClosed
      check content.scrolledTo.len == 0
    else:
      skip()

  test "a stale thread row cannot resolve a link absent from the completed list":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      section.chatsLoaded = true
      section.view.chatsModel().appendItem(chat_item.ChatItem(id: "thread", isThread: true,
        parentChatId: "parent", canView: true))
      section.onChatThreadsForChatsLoaded(@[], @["parent"])
      check section.pendingThreadRefreshRequested
      section.onChatThreadsForChatsLoaded(@[], @["parent"], summariesLoaded = true)
      check section.activated == @["parent"]
      check not section.pendingThreadNavigation
    else:
      skip()

  test "a thread row from another parent cannot resolve the link":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      section.chatsLoaded = true
      section.view.chatsModel().appendItem(chat_item.ChatItem(id: "thread", isThread: true,
        parentChatId: "another-parent", canView: true))
      check not section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      check section.activated.len == 0
    else:
      skip()

  test "a cached miss can resolve from refreshed summaries":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      section.chatsLoaded = true
      section.controller.init()
      service.init()
      let content = ContentStub()
      section.chatContentModules["thread"] = content
      service.onAsyncLoadChatThreadsForChats($(%* {"chatIds": ["parent"], "threads": []}))
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      check section.refreshes == @["parent"]
      check section.pendingThreadRefreshRequested
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["parent"], "includeSummaries": true,
        "threads": [{"chatId": "parent", "threadId": "thread", "parentMessageId": "root", "name": "Thread"}]
      }))
      check section.activated == @["parent", "thread"]
      check not section.pendingThreadNavigation
      check content.scrolledTo.len == 0
    else:
      skip()

  test "a stale lightweight failure cannot cancel an awaited summary refresh":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      section.chatsLoaded = true
      section.onChatThreadsForChatsLoaded(@[], @["parent"])
      section.onChatThreadsLoadingFailed("parent")
      check section.pendingThreadNavigation
      var failures = 0
      events.on(SIGNAL_THREAD_LINK_FAILED) do(e: Args):
        inc failures
      section.onChatThreadsLoadingFailed("parent", summariesRequested = true)
      check not section.pendingThreadNavigation
      check failures == 1
    else:
      skip()

  test "clearing parent history invalidates navigation before a late response":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      section.controller.init()
      service.init()
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      var failures = 0
      events.on(SIGNAL_THREAD_LINK_FAILED) do(e: Args):
        inc failures
      events.emit(chat_service.SIGNAL_CHAT_HISTORY_CLEARED, ChatArgs(chatId: "parent"))
      check not section.pendingThreadNavigation
      check failures == 1
      section.chatsLoaded = true
      service.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["parent"], "threads": [{"chatId": "parent", "threadId": "thread",
          "parentMessageId": "root", "name": "Thread"}]
      }))
      check section.activated == @["parent"]
      check failures == 1
    else:
      skip()

  test "selecting another conversation cancels the pending link before model loading":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      section.activeItemSet("another-thread")
      check not section.pendingThreadNavigation
      section.chatsLoaded = true
      section.onChatThreadsForChatsLoaded(@[ThreadDto(chatId: "parent", threadId: "thread",
        parentMessageId: "root", name: "Thread")], @["parent"], summariesLoaded = true)
      check section.activated == @["parent"]
      check not section.panelClosed
    else:
      skip()

  test "opening another thread panel prevents late navigation from stealing focus":
    if THREADS_ENABLED:
      let events = createEventEmitter()
      let service = message_service.newService(events, nil, nil, nil, nil, nil, nil)
      let section = newSectionHarness(service, events)
      defer: section.delete()
      let settings = singletonInstance.localAccountSensitiveSettings
      let previousSettings = settings.settings
      let settingsDir = createTempDir("thread-link-", "")
      let settingsFile = settingsDir / "settings.ini"
      settings.settings = newQSettings(settingsFile, QSettingsFormat.IniFormat)
      defer:
        settings.settings.delete()
        settings.settings = previousSettings
        removeFile(settingsFile)
        removeDir(settingsDir)
      section.view.chatsModel().appendItem(chat_item.ChatItem(id: "other", isThread: true,
        parentChatId: "parent", canView: true))
      section.chatContentModules["other"] = ContentStub()
      check section.openCommunityChatAndScrollToMessage("parent", "", "thread")
      section.openThreadPanel("other", "Other", "parent")
      check not section.pendingThreadNavigation
      section.chatsLoaded = true
      section.onChatThreadsForChatsLoaded(@[ThreadDto(chatId: "parent", threadId: "thread",
        parentMessageId: "root", name: "Thread")], @["parent"], summariesLoaded = true)
      check section.view.getOpenThreadId() == "other"
      check section.activated == @["parent"]
      check not section.panelClosed
    else:
      skip()
