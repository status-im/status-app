import std/[importutils, json, sets, tables, unittest]

import app/core/eventemitter
import app/core/signals/types
import app/global/feature_flags
import app/modules/main/io_interface as main_interface
import app/modules/main/chat_section/module as section_module
import app/modules/main/chat_section/controller as section_controller
import app/modules/main/chat_section/view as section_view
import app/modules/main/chat_section/model
import app_service/service/chat/service as chat_service
import app_service/service/chat/dto/chat
import app_service/service/community/service as community_service
import app_service/service/community/dto/community
import app_service/service/message/service as message_service

privateAccess(section_module.Module)
privateAccess(community_service.Service)
privateAccess(message_service.Service)

type BadgeDelegate = ref object of main_interface.AccessInterface
  updates: seq[tuple[sectionId: string, unread: bool, mentions: int]]

method onNotificationsUpdated(self: BadgeDelegate, sectionId: string,
    sectionHasUnreadMessages: bool, sectionNotificationCount: int) =
  self.updates.add((sectionId, sectionHasUnreadMessages, sectionNotificationCount))

suite "thread section badges without chat UI":
  setup:
    check THREADS_ENABLED
    let events = createEventEmitter()
    let chats = chat_service.newService(events, nil, nil)
    chats.updateOrAddChat(ChatDto(id: "channel", communityId: "community", chatType: ChatType.CommunityChat))
    chats.updateOrAddChat(ChatDto(id: "other-channel", communityId: "other", chatType: ChatType.CommunityChat))
    chats.updateOrAddChat(ChatDto(id: "personal", chatType: ChatType.OneToOne, active: true))
    let messages = message_service.newService(events, nil, chats, nil, nil, nil, nil)
    messages.init()
    let communities = community_service.newService(events, nil, chats, nil, messages)
    communities.communities["community"] = CommunityDto(id: "community")
    let delegate = BadgeDelegate()
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

  test "persisted metadata refreshes unopened section without constructing rows":
    messages.onAsyncLoadChatThreadsForChats($ %* {
      "chatIds": ["channel", "other-channel"], "chatRevisions": {"channel": 0, "other-channel": 0},
      "error": "", "includeSummaries": false,
      "threads": [
        {"chatId": "channel", "threadId": "followed", "parentMessageId": "followed",
          "followed": true, "unviewedMessagesCount": 3, "unviewedMentionsCount": 2},
        {"chatId": "channel", "threadId": "unfollowed", "parentMessageId": "unfollowed",
          "followed": false, "unviewedMessagesCount": 8, "unviewedMentionsCount": 8},
        {"chatId": "channel", "threadId": "archived", "parentMessageId": "archived",
          "followed": true, "archived": true, "unviewedMessagesCount": 8, "unviewedMentionsCount": 8},
        {"chatId": "channel", "threadId": "deleted", "parentMessageId": "deleted",
          "followed": true, "deleted": true, "unviewedMessagesCount": 8, "unviewedMentionsCount": 8},
        {"chatId": "other-channel", "threadId": "other", "parentMessageId": "other",
          "followed": true, "unviewedMessagesCount": 9, "unviewedMentionsCount": 9}
      ]
    })
    check delegate.updates == @[("community", true, 2)]
    check not section.chatsLoaded
    check section.view.isNil

    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(chatId: "channel", threadId: "followed", parentMessageId: "followed",
        followed: false, unviewedMessagesCount: 3, unviewedMentionsCount: 2)
    ]))
    check delegate.updates[^1] == ("community", false, 0)
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(chatId: "channel", threadId: "followed", parentMessageId: "followed",
        followed: true, unviewedMessagesCount: 1)
    ]))
    check delegate.updates[^1] == ("community", true, 0)
    events.emit(SignalType.Message.event, MessageSignal(threads: @[
      ThreadDto(chatId: "channel", threadId: "followed", parentMessageId: "followed", followed: true)
    ]))
    check delegate.updates[^1] == ("community", false, 0)

  test "unrelated and unknown chats do not refresh this section":
    section.onChatThreadsForChatsLoaded(@[
      ThreadDto(chatId: "other-channel"), ThreadDto(chatId: "personal"), ThreadDto(chatId: "unknown")
    ], @["other-channel", "personal", "unknown"])
    check delegate.updates.len == 0
    section.onChatThreadsForChatsLoaded(@[], @["channel"])
    check delegate.updates == @[("community", false, 0)]

  test "section metadata loading is independent of model rows and reuses loaded chats":
    messages.chatThreadListsLoadedChats.incl("channel")
    var completed: seq[string]
    events.on(SIGNAL_CHAT_THREADS_FOR_CHATS_LOADED) do(e: Args):
      completed.add(ChatThreadsForChatsLoadedArgs(e).completedChatIds)
    section.view = section_view.newView(section)
    defer: section.view.delete()
    section.moduleLoaded = true
    section.load()
    check completed == @["channel"]
    check not section.chatsLoaded
    check section.view.chatsModel().rowCount(nil) == 0

  test "muted sections and chats suppress plain unread but retain mentions":
    for muteSection in [false, true]:
      communities.communities["community"].muted = muteSection
      chats.updateOrAddChat(ChatDto(id: "channel", communityId: "community",
        chatType: ChatType.CommunityChat, muted: not muteSection))
      for mentions in [0, 1]:
        events.emit(SignalType.Message.event, MessageSignal(threads: @[
          ThreadDto(chatId: "channel", threadId: "thread", parentMessageId: "thread",
            followed: true, unviewedMessagesCount: 3, unviewedMentionsCount: mentions)
        ]))
        check delegate.updates[^1] == ("community", mentions > 0, mentions)
