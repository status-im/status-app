import nimqml, tables, json, sequtils

import ./io_interface, ./view, ./controller, ./token_data_item
import ../io_interface as delegate_interface
import ./item as notification_item
import ../../shared_models/message_model
import ../../shared_models/message_item_qobject as msg_item_qobj
import ../../../global/global_singleton
import ../../../global/app_sections_config as conf
import ../../../core/eventemitter
import app_service/service/activity_center/service as activity_center_service
import app_service/service/contacts/service as contacts_service
import app_service/service/message/service as message_service
import app_service/service/chat/service as chat_service
import app_service/service/community/service as community_service
import app_service/service/devices/service as devices_service
import app_service/service/general/service as general_service

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool
    unreadCount: int

proc newModule*(
    delegate: delegate_interface.AccessInterface,
    events: EventEmitter,
    activityCenterService: activity_center_service.Service,
    contactsService: contacts_service.Service,
    messageService: message_service.Service,
    chatService: chat_service.Service,
    communityService: community_service.Service,
    devicesService: devices_service.Service,
    generalService: general_service.Service,
    ): Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(
    result,
    events,
    activityCenterService,
    contactsService,
    messageService,
    chatService,
    communityService,
    devicesService,
    generalService,
  )
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("activityCenterModule", self.viewVariant)
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method unreadActivityCenterNotificationsCount*(self: Module): int =
  self.controller.unreadActivityCenterNotificationsCount()

method unreadActivityCenterNotificationsCountFromView*(self: Module): int =
  self.view.unreadCount()

method hasUnseenActivityCenterNotifications*(self: Module): bool =
  self.controller.hasUnseenActivityCenterNotifications()

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.activityCenterDidLoad()
  self.view.setUnreadCount(self.unreadActivityCenterNotificationsCount())
  self.view.setHasUnseen(self.hasUnseenActivityCenterNotifications())

method hasMoreToShow*(self: Module): bool =
  self.controller.hasMoreToShow()

method onNotificationsCountMayHaveChanged*(self: Module) =
  self.view.setUnreadCount(self.unreadActivityCenterNotificationsCount())
  self.delegate.onActivityNotificationsUpdated()

method onUnseenChanged*(self: Module, hasUnseen: bool) =
  self.view.setHasUnseen(hasUnseen)

proc createMessageItemFromDto(self: Module, message: MessageDto, communityId: string, albumMessages: seq[MessageDto]): MessageItem =
  let contactDetails = self.controller.getContactDetails(message.`from`)
  let communityChats = self.controller.getCommunityById(communityId).chats

  var quotedMessageAuthorDetails = ContactDetails()
  if message.quotedMessage.`from` != "":
    if(message.`from` == message.quotedMessage.`from`):
      quotedMessageAuthorDetails = contactDetails
    else:
      quotedMessageAuthorDetails = self.controller.getContactDetails(message.quotedMessage.`from`)

  var albumImages: seq[string]
  var albumMessageIds: seq[string]
  if message.albumId != "":
    for msg in albumMessages:
      albumImages.add(msg.image)
      albumMessageIds.add(msg.id)

  let messageItem = message_model.createMessageItemFromDtos(
    message,
    communityId,
    contactDetails,
    contactDetails.isCurrentUser,
    renderedMessageText = self.controller.getRenderedText(message.parsedText, communityChats),
    clearText = self.controller.replacePubKeysWithDisplayNames(message.text),
    albumImages,
    albumMessageIds,
    deletedByContactDetails = ContactDetails(),
    quotedMessageAuthorDetails,
    quotedRenderedMessageText = self.controller.getRenderedText(message.quotedMessage.parsedText, communityChats),
  )
  return msg_item_qobj.newMessageItem(messageItem)

method convertToItems*(
    self: Module,
    activityCenterNotifications: seq[ActivityCenterNotificationDto]
    ): seq[notification_item.Item] =
  result = activityCenterNotifications.map(
    proc(notification: ActivityCenterNotificationDto): notification_item.Item =
      var messageItem: MessageItem
      var repliedMessageItem: MessageItem
      # default section id is `Chat` section
      let sectionId = if notification.communityId.len > 0:
          notification.communityId
        else:
          singletonInstance.userProfile.getPubKey()

      if (notification.message.id != ""):
        let communityId = sectionId
        # If there is a message in the Notification, transfer it to a MessageItem (QObject)
        messageItem = self.createMessageItemFromDto(notification.message, communityId, notification.albumMessages)

        if (notification.notificationType == ActivityCenterNotificationType.Reply and notification.message.responseTo != ""):
          repliedMessageItem = self.createMessageItemFromDto(notification.replyMessage, communityId, @[])

        if (notification.notificationType == ActivityCenterNotificationType.ContactVerification):
          repliedMessageItem = self.createMessageItemFromDto(notification.replyMessage, communityId, @[])

      var tokenDataItem = token_data_item.newTokenDataItem(
          notification.tokenData.chainId,
          notification.tokenData.txHash,
          notification.tokenData.walletAddress,
          notification.tokenData.isFirst,
          notification.tokenData.communiyId,
          notification.tokenData.amount,
          notification.tokenData.name,
          notification.tokenData.symbol,
          notification.tokenData.imageUrl,
          notification.tokenData.tokenType
      )

      let chatDetails = self.controller.getChatDetails(notification.chatId)

      return notification_item.initItem(
        notification.id,
        notification.chatId,
        notification.communityId,
        notification.membershipStatus,
        sectionId,
        notification.name,
        notification.newsTitle,
        notification.newsDescription,
        notification.newsContent,
        notification.newsImageUrl,
        notification.newsLink,
        notification.newsLinkLabel,
        notification.author,
        notification.notificationType,
        notification.timestamp,
        notification.read,
        notification.dismissed,
        notification.accepted,
        messageItem,
        repliedMessageItem,
        chatDetails.chatType,
        tokenDataItem,
        notification.installationId,
      )
    )

method fetchActivityCenterNotifications*(self: Module) =
  self.controller.asyncActivityNotificationLoad()

method markAllActivityCenterNotificationsRead*(self: Module): string =
  self.controller.markAllActivityCenterNotificationsRead()

method markAllActivityCenterNotificationsReadDone*(self: Module) =
  self.view.markAllActivityCenterNotificationsReadDone()

method markActivityCenterNotificationRead*(self: Module, notificationId: string) =
  self.controller.markActivityCenterNotificationRead(notificationId)

method markActivityCenterNotificationReadDone*(self: Module, notificationIds: seq[string]) =
  for notificationId in notificationIds:
    self.view.markActivityCenterNotificationReadDone(notificationId)

method markAsSeenActivityCenterNotifications*(self: Module) =
  self.controller.markAsSeenActivityCenterNotifications()

method addActivityCenterNotifications*(self: Module, activityCenterNotifications: seq[ActivityCenterNotificationDto], initialLoad: bool) =
  if not initialLoad:
    for notif in activityCenterNotifications:
      if notif.notificationType == ActivityCenterNotificationTypeNews:
        # Show an AC or OS notification for News Feed notifications
        singletonInstance.globalEvents.showNewsMessageNotification(
          notif.id,
          notif.newsTitle,
        )
  self.view.addActivityCenterNotifications(self.convertToItems(activityCenterNotifications))
  self.view.hasUnseenActivityCenterNotificationsChanged()

method resetActivityCenterNotifications*(self: Module, activityCenterNotifications: seq[ActivityCenterNotificationDto]) =
  self.view.resetActivityCenterNotifications(self.convertToItems(activityCenterNotifications))

method markActivityCenterNotificationUnread*(self: Module, notificationId: string) =
  self.controller.markActivityCenterNotificationUnread(notificationId)

method acceptActivityCenterNotification*(self: Module, notificationId: string) =
  self.controller.acceptActivityCenterNotification(notificationId)

method dismissActivityCenterNotification*(self: Module, notificationId: string) =
  self.controller.dismissActivityCenterNotification(notificationId)

method acceptActivityCenterNotificationDone*(self: Module, notificationId: string) =
  self.view.acceptActivityCenterNotificationDone(notificationId)

method dismissActivityCenterNotificationDone*(self: Module, notificationId: string) =
  self.view.dismissActivityCenterNotificationDone(notificationId)

method markActivityCenterNotificationUnreadDone*(self: Module, notificationIds: seq[string]) =
  for notificationId in notificationIds:
    self.view.markActivityCenterNotificationUnreadDone(notificationId)

method removeActivityCenterNotifications*(self: Module, notificationIds: seq[string]) =
  self.view.removeActivityCenterNotifications(notificationIds)

method switchTo*(self: Module, sectionId, chatId, messageId: string) =
  self.controller.switchTo(sectionId, chatId, messageId)

method getDetails*(self: Module, sectionId: string, chatId: string): string =
  var jsonObject = newJObject()
  if sectionId == singletonInstance.userProfile.getPubKey():
    jsonObject["sType"] = %* ChatSectionType.Personal
    jsonObject["sName"] = %* conf.CHAT_SECTION_NAME
    jsonObject["sImage"] = %* ""
    jsonObject["sColor"] = %* ""
  else:
    # Community
    let community {.cursor.} = self.controller.getCommunityById(sectionId)
    jsonObject["sType"] = %* ChatSectionType.Community
    jsonObject["sName"] = %* community.name
    jsonObject["sImage"] = %* community.images.thumbnail
    jsonObject["sColor"] = %* community.color

  let c = self.controller.getChatDetails(chatId)
  
  var chatName = c.name
  var chatImage = c.icon
  if c.chatType == ChatType.OneToOne:
    (chatName, chatImage, _) = self.controller.getOneToOneChatNameAndImage(c.id)

  jsonObject["cName"] = %* chatName
  jsonObject["cImage"] = %* chatImage
  jsonObject["cColor"] = %* c.color
  jsonObject["cEmoji"] = %* c.emoji
  return $jsonObject

method getChatDetailsAsJson*(self: Module, chatId: string): string =
  let chatDto = self.controller.getChatDetails(chatId)
  var jsonObject = newJObject()
  jsonObject["name"] = %* chatDto.name
  jsonObject["icon"] = %* chatDto.icon
  jsonObject["color"] = %* chatDto.color
  jsonObject["emoji"] = %* chatDto.emoji
  return $jsonObject

method setActiveNotificationGroup*(self: Module, group: int) =
  self.controller.setActiveNotificationGroup(ActivityCenterGroup(group))

method getActiveNotificationGroup*(self: Module): int =
  return self.controller.getActiveNotificationGroup().int

method setActivityCenterReadType*(self: Module, readType: int) =
  self.controller.setActivityCenterReadType(ActivityCenterReadType(readType))

method getActivityCenterReadType*(self: Module): int =
  return self.controller.getActivityCenterReadType().int

method setActivityGroupCounters*(self: Module, counters: Table[ActivityCenterGroup, int]) =
  self.view.setActivityGroupCounters(counters)

method enableInstallationAndSync*(self: Module, installationId: string) =
  self.controller.enableInstallationAndSync(installationId)
