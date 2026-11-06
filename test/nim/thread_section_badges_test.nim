import std/[importutils, json, sets, tables, unittest]

import app/core/eventemitter
import app/core/signals/types
import app/global/[feature_flags, global_singleton]
import app/modules/main/io_interface as main_interface
import app/modules/main/controller as main_controller
import app/modules/main/chat_section/module as section_module
import app/modules/main/chat_section/controller as section_controller
import app/modules/main/chat_section/view as section_view
import app/modules/main/chat_section/model
import app_service/service/chat/service as chat_service
import app_service/service/chat/dto/chat
import app_service/service/community/service as community_service
import app_service/service/community/dto/community
import app_service/service/message/service as message_service
from seaqt/qcoreapplication import QCoreApplication, create

privateAccess(section_module.Module)
privateAccess(main_controller.Controller)
privateAccess(community_service.Service)
privateAccess(message_service.Service)

discard QCoreApplication.create()

type BadgeDelegate = ref object of main_interface.AccessInterface
  updates: seq[tuple[sectionId: string, unread: bool, mentions: int]]

method onNotificationsUpdated(self: BadgeDelegate, sectionId: string,
    sectionHasUnreadMessages: bool, sectionNotificationCount: int) =
  self.updates.add((sectionId, sectionHasUnreadMessages, sectionNotificationCount))

suite "backend section badges without chat UI":
  setup:
    check THREADS_ENABLED
    let events = createEventEmitter()
    let chats = chat_service.newService(events, nil, nil)
    let messages = message_service.newService(events, nil, chats, nil, nil, nil, nil)
    messages.init()
    let communities = community_service.newService(events, nil, chats, nil, messages)
    communities.communities["community"] = CommunityDto(id: "community")
    let delegate = BadgeDelegate()
    let mainController = main_controller.Controller(delegate: delegate, events: events, chatService: chats)
    mainController.init()
    let section = section_module.Module(delegate: delegate)
    section.controller = section_controller.newController(
      delegate = section, sectionId = "community", isCommunity = true, events = events,
      settingsService = nil, nodeConfigurationService = nil, contactService = nil,
      chatService = chats, communityService = communities, messageService = messages,
      mailserversService = nil, walletAccountService = nil, tokenService = nil,
      communityTokensService = nil, sharedUrlsService = nil, networkService = nil)
    events.on(SIGNAL_CHAT_THREADS_FOR_CHATS_LOADED) do(e: Args):
      let args = ChatThreadsForChatsLoadedArgs(e)
      section.onChatThreadsForChatsLoaded(args.threads, args.completedChatIds)

  teardown:
    chats.delete()

  test "snapshot updates unopened community and personal badges without metadata":
    chats.onAsyncSectionUnreadCounts($ %* {"response": {"sections": [
      {"sectionId": "personal", "unviewedMessagesCount": 2, "unviewedMentionsCount": 1},
      {"sectionId": "community", "unviewedMessagesCount": 3, "unviewedMentionsCount": 2}
    ]}})
    check ("community", true, 2) in delegate.updates
    check (singletonInstance.userProfile.getPubKey(), true, 1) in delegate.updates
    check not section.chatsLoaded
    check section.view.isNil
    check messages.chatThreadsByParentIdByChat.len == 0
    check section.controller.sectionUnreadMessagesAndMentionsCount() == (3, 2)
    check mainController.sectionUnreadMessagesAndMentionsCount("community") == (3, 2)
    check mainController.sectionUnreadMessagesAndMentionsCount(singletonInstance.userProfile.getPubKey()) == (2, 1)

  test "thread metadata cannot overwrite authoritative section totals":
    chats.onAsyncSectionUnreadCounts($ %* {"response": {"sections": [
      {"sectionId": "personal", "unviewedMessagesCount": 0, "unviewedMentionsCount": 0},
      {"sectionId": "community", "unviewedMessagesCount": 3, "unviewedMentionsCount": 2}
    ]}})
    let before = delegate.updates.len
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(chatId: "channel", threadId: "thread", parentMessageId: "root",
        followed: true, unviewedMessagesCount: 100, unviewedMentionsCount: 100)
    ]))
    check delegate.updates.len == before
    check section.controller.sectionUnreadMessagesAndMentionsCount() == (3, 2)

  test "loading an unopened section does not request thread metadata":
    chats.updateOrAddChat(ChatDto(id: "channel", communityId: "community", chatType: ChatType.CommunityChat))
    # A nil worker pool makes any unexpected eager thread fetch fail.
    section.view = section_view.newView(section)
    defer: section.view.delete()
    section.moduleLoaded = true
    section.load()
    check not section.chatsLoaded
    check section.view.chatsModel().rowCount(nil) == 0
    check messages.chatThreadListsLoadingChats.len == 0
    check messages.chatThreadListsLoadedChats.len == 0

  test "zero totals and removed communities clear existing badges":
    chats.onAsyncSectionUnreadCounts($ %* {"response": {"sections": [
      {"sectionId": "personal", "unviewedMessagesCount": 1, "unviewedMentionsCount": 0},
      {"sectionId": "community", "unviewedMessagesCount": 3, "unviewedMentionsCount": 2}
    ]}})
    delegate.updates.setLen(0)
    chats.onAsyncSectionUnreadCounts($ %* {"response": {"sections": [
      {"sectionId": "personal", "unviewedMessagesCount": 0, "unviewedMentionsCount": 0}
    ]}})
    check ("community", false, 0) in delegate.updates
    check (singletonInstance.userProfile.getPubKey(), false, 0) in delegate.updates
