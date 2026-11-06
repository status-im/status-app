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
  test "mute suppresses messages and mentions, preserves other conversations, and unmute restores them":
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
        for mentions in [newSeq[string](), @[singletonInstance.userProfile.getPubKey()]]:
          section.onNewMessagesReceived("different-section", "parent", "parent", ChatType.OneToOne,
            1, 1, 1, MessageDto(id: "message", `from`: "sender", threadId: threadId,
              parsedText: newJArray(), mentions: mentions))

      let expectedThreads = if THREADS_ENABLED and muted: @["sibling", "sibling", "", ""]
                            else: @["muted-thread", "muted-thread", "sibling", "sibling", "", ""]
      check receiver.threadIds == expectedThreads
      for i, notificationType in receiver.notificationTypes:
        check notificationType == (if i mod 2 == 0: NotificationType.NewMessage.int
                                   else: NotificationType.NewMessageWithPersonalMention.int)
