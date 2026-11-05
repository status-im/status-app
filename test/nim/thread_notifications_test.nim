import std/[importutils, json, tables, unittest]
import nimqml

import app/core/eventemitter
import app/core/notifications/details
import app/global/global_singleton
import app/modules/main/chat_section/module as section_module
import app/modules/main/chat_section/controller as section_controller
import app/modules/main/chat_section/view as section_view
import app_service/service/chat/service as chat_service
import app_service/service/chat/dto/chat
import app_service/service/contacts/service as contact_service
import app_service/service/community/service as community_service
import app_service/service/message/service as message_service
import app_service/service/message/dto/message

privateAccess(section_module.Module)
privateAccess(chat_service.Service)

QtObject:
  type NotificationReceiver = ref object of QObject
    threadIds: seq[string]
    notificationTypes: seq[int]

  proc delete(self: NotificationReceiver)

  proc newNotificationReceiver(): NotificationReceiver =
    new(result, delete)
    result.QObject.setup

  proc delete(self: NotificationReceiver) =
    self.QObject.delete

  proc onNotification(self: NotificationReceiver, title: string, message: string, sectionId: string,
      isCommunitySection: bool, isSectionActive: bool, chatId: string, isChatActive: bool, messageId: string,
      threadId: string, notificationType: int, isOneToOne: bool, isGroupChat: bool) {.slot.} =
    self.threadIds.add(threadId)
    self.notificationTypes.add(notificationType)

suite "thread desktop notifications":
  test "mute suppresses ordinary messages but preserves mentions and replies":
    let events = createEventEmitter()
    let messages = message_service.newService(events, nil, nil, nil, nil, nil, nil)
    let contacts = contact_service.newService(events, nil, nil, nil)
    let chats = chat_service.newService(events, nil, contacts)
    let communities = community_service.newService(events, nil, chats, nil, messages)
    chats.chats["parent"] = ChatDto(id: "parent", chatType: ChatType.OneToOne)
    let section = section_module.Module(messageService: messages)
    section.controller = section_controller.newController(section, "section", false, events,
      nil, nil, contacts, chats, communities, messages, nil, nil, nil, nil, nil, nil)
    section.view = section_view.newView(section)
    section.viewVariant = newQVariant(section.view)
    defer: section.delete()
    let receiver = newNotificationReceiver()
    defer: receiver.delete()
    discard QObject.connect(singletonInstance.globalEvents, showMessageNotification, receiver, onNotification)

    for muted in [true, false]:
      messages.onAsyncLoadChatThreadsForChats($(%* {
        "chatIds": ["parent"], "threads": [{"chatId": "parent", "threadId": "muted-thread",
          "parentMessageId": "root", "muted": muted}]
      }))
      receiver.threadIds = @[]
      receiver.notificationTypes = @[]
      for threadId in ["muted-thread", "sibling", ""]:
        for kind in ["ordinary", "mention", "reply", "reply-to-other", "global-mention"]:
          let myPK = singletonInstance.userProfile.getPubKey()
          receiver.threadIds = @[]
          receiver.notificationTypes = @[]
          let mentions = case kind:
            of "mention": @[myPK]
            of "global-mention": @[EVERYONE_MENTION]
            else: newSeq[string]()
          section.onNewMessagesReceived("different-section", "parent", "parent", ChatType.OneToOne,
            1, 1, 1, MessageDto(id: "message", `from`: "sender", threadId: threadId,
              parsedText: newJArray(), mentions: mentions,
              responseTo: (if kind in ["reply", "reply-to-other"]: "quoted" else: ""),
              quotedMessage: QuotedMessage(`from`: (if kind == "reply": myPK else: "other"))))
          let suppressed = THREADS_ENABLED and muted and threadId == "muted-thread" and
            kind in ["ordinary", "reply-to-other"]
          check receiver.threadIds == (if suppressed: newSeq[string]() else: @[threadId])
          if not suppressed:
            let expectedType = case kind:
              of "mention": NotificationType.NewMessageWithPersonalMention
              of "global-mention": NotificationType.NewMessageWithGlobalMention
              else: NotificationType.NewMessage
            check receiver.notificationTypes == @[expectedType.int]
