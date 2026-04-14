import nimqml, json, sequtils, chronicles, strutils, strutils, stint, sugar, tables, json_serialization

import ../../../app/core/eventemitter
import ../../../app/core/[main]
import ../../../app/core/tasks/[qt, threadpool]

import web3/eth_api_types, web3/conversions, stew/byteutils, nimcrypto

import ../../../backend/backend
import ../../../backend/response_type
import ./dto/notification

import ../../common/activity_center
import ../message/service
import ../message/dto/seen_unseen_messages
import ../chat/service as chat_service

export notification

include async_tasks

logScope:
  topics = "activity-center-service"

type
  ActivityCenterNotificationsArgs* = ref object of Args
    activityCenterNotifications*: seq[ActivityCenterNotificationDto]

  ActivityCenterNotificationIdsArgs* = ref object of Args
    notificationIds*: seq[string]

  ActivityCenterNotificationIdArgs* = ref object of Args
    notificationId*: string

  ActivityCenterNotificationHasUnseen* = ref object of Args
    hasUnseen*: bool

# Signals which may be emitted by this service:
const SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_LOADED* = "activityCenterNotificationsLoaded"
const SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_RECEIVED* = "activityCenterNotificationsReceived"
const SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_COUNT_MAY_HAVE_CHANGED* = "activityCenterNotificationsCountMayChanged"
const SIGNAL_ACTIVITY_CENTER_UNSEEN_UPDATED* = "activityCenterNotificationsHasUnseenUpdated"
const SIGNAL_ACTIVITY_CENTER_MARK_NOTIFICATIONS_AS_READ* = "activityCenterMarkNotificationsAsRead"
const SIGNAL_ACTIVITY_CENTER_MARK_NOTIFICATIONS_AS_UNREAD* = "activityCenterMarkNotificationsAsUnread"
const SIGNAL_ACTIVITY_CENTER_MARK_ALL_NOTIFICATIONS_AS_READ* = "activityCenterMarkAllNotificationsAsRead"
const SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_REMOVED* = "activityCenterNotificationsRemoved"
const SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_ACCEPTED* = "activityCenterNotificationsAccepted"
const SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_DISMISSED* = "activityCenterNotificationsDismissed"

const DEFAULT_LIMIT = 20

# NOTE: temporary disable Transactions and System and we don't count All group
const ACTIVITY_GROUPS = @[
  ActivityCenterGroup.Mentions,
  ActivityCenterGroup.Replies,
  ActivityCenterGroup.Membership,
  ActivityCenterGroup.Admin,
  ActivityCenterGroup.ContactRequests,
  ActivityCenterGroup.IdentityVerification,
  ActivityCenterGroup.System,
  ActivityCenterGroup.News
]

QtObject:
  type Service* = ref object of QObject
    threadpool: ThreadPool
    events: EventEmitter
    cursor*: string
    activeGroup: ActivityCenterGroup
    readType: ActivityCenterReadType
    chatService: chat_service.Service

  # Forward declaration
  proc asyncActivityNotificationLoad*(self: Service)

  proc delete*(self: Service)
  proc newService*(
      events: EventEmitter,
      threadpool: ThreadPool,
      chatService: chat_service.Service,
      ): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.cursor = ""
    result.activeGroup = ActivityCenterGroup.All
    result.readType = ActivityCenterReadType.All
    result.chatService = chatService

  proc handleNewNotificationsLoaded(self: Service, activityCenterNotifications: seq[ActivityCenterNotificationDto]) =
    # For now status-go notify about every notification update regardless active group so we need filter manually on the desktop side
    let groupTypes = activityCenterNotificationTypesByGroup(self.activeGroup)
    let filteredNotifications = filter(activityCenterNotifications, proc(notification: ActivityCenterNotificationDto): bool =
      return (self.readType == ActivityCenterReadType.All or not notification.read) and groupTypes.contains(notification.notificationType.int)
    )
    let removedNotifications = filter(activityCenterNotifications, proc(notification: ActivityCenterNotificationDto): bool =
      return notification.deleted
    )

    if (filteredNotifications.len > 0):
      self.events.emit(
        SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_RECEIVED,
        ActivityCenterNotificationsArgs(activityCenterNotifications: filteredNotifications)
      )

    if (removedNotifications.len > 0):
      var notificationIds: seq[string] = removedNotifications.map(notification => notification.id)
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_REMOVED, ActivityCenterNotificationIdsArgs(notificationIds: notificationIds))
    # NOTE: this signal must fire even we have no new notifications to show
    self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_COUNT_MAY_HAVE_CHANGED, Args())

  proc init*(self: Service) =
    self.events.on(SignalType.Message.event) do(e: Args):
      let receivedData = MessageSignal(e)
      if (receivedData.activityCenterNotifications.len > 0):
        self.handleNewNotificationsLoaded(receivedData.activityCenterNotifications)

    self.events.on(SIGNAL_PARSE_RAW_ACTIVITY_CENTER_NOTIFICATIONS) do(e: Args):
      let raw = RawActivityCenterNotificationsArgs(e)
      if raw.activityCenterNotifications.len > 0:
        var activityCenterNotifications: seq[ActivityCenterNotificationDto] = @[]
        for notificationJson in raw.activityCenterNotifications:
          activityCenterNotifications.add(notificationJson.toActivityCenterNotificationDto)
        self.handleNewNotificationsLoaded(activityCenterNotifications)

  proc setActiveNotificationGroup*(self: Service, group: ActivityCenterGroup) =
    self.activeGroup = group

  proc getActiveNotificationGroup*(self: Service): ActivityCenterGroup =
    return self.activeGroup

  proc setActivityCenterReadType*(self: Service, readType: ActivityCenterReadType) =
    self.readType = readType

  proc getActivityCenterReadType*(self: Service): ActivityCenterReadType =
    return self.readType

  proc resetCursor*(self: Service) =
    self.cursor = ""

  proc hasMoreToShow*(self: Service): bool =
    return self.cursor != ""

  proc parseActivityCenterState*(self: Service, response: RpcResponse) =
    var activityCenterState: JsonNode = newJObject()
    if response.result.getProp("activityCenterState", activityCenterState):
      let hasSeen = activityCenterState["hasSeen"].getBool
      self.events.emit(SIGNAL_ACTIVITY_CENTER_UNSEEN_UPDATED, ActivityCenterNotificationHasUnseen(hasUnseen: not hasSeen))

  proc asyncActivityNotificationLoad*(self: Service) =
    let arg = AsyncActivityNotificationLoadTaskArg(
      tptr: asyncActivityNotificationLoadTask,
      vptr: cast[uint](self.vptr),
      slot: "asyncActivityNotificationLoaded",
      cursor: self.cursor,
      limit: DEFAULT_LIMIT,
      group: self.activeGroup,
      readType: self.readType
    )
    self.threadpool.start(arg)

  proc getActivityCenterNotifications*(self: Service): seq[ActivityCenterNotificationDto] =
    try:
      let activityTypes = activityCenterNotificationTypesByGroup(self.activeGroup)
      let response = backend.activityCenterNotifications(
        backend.ActivityCenterNotificationsRequest(
          cursor: self.cursor,
          limit: DEFAULT_LIMIT,
          activityTypes: activityTypes,
          readType: self.readType.int
        )
      )

      let activityCenterNotificationsTuple = parseActivityCenterNotifications(response.result)

      self.cursor = activityCenterNotificationsTuple[0];
      result = activityCenterNotificationsTuple[1]

    except Exception as e:
      error "Error getting activity center notifications", msg = e.msg

  proc getActivityCenterNotificationsCounters(self: Service, activityTypes: seq[int], readType: ActivityCenterReadType): Table[int, int] =
    try:
      let response = backend.activityCenterNotificationsCount(
        backend.ActivityCenterCountRequest(
          activityTypes: activityTypes,
          readType: readType.int,
        )
      )
      var counters = initTable[int, int]()
      if response.result.kind != JNull:
        for activityType in activityTypes:
          if response.result.contains($activityType):
            counters[activityType] = response.result[$activityType].getInt
      return counters
    except Exception as e:
      error "Error getting unread activity center notifications count", msg = e.msg

  proc getActivityGroupCounters*(self: Service): Table[ActivityCenterGroup, int] =
    let allActivityTypes = activityCenterNotificationTypesByGroup(ActivityCenterGroup.All)
    let counters = self.getActivityCenterNotificationsCounters(allActivityTypes, self.readType)
    var groupCounters = initTable[ActivityCenterGroup, int]()
    for group in ACTIVITY_GROUPS:
      var groupTotal = 0
      for activityType in activityCenterNotificationTypesByGroup(group):
        groupTotal = groupTotal + counters.getOrDefault(activityType, 0)
      groupCounters[group] = groupTotal
    return groupCounters

  proc getUnreadActivityCenterNotificationsCount*(self: Service): int =
    let activityTypes = activityCenterNotificationTypesByGroup(ActivityCenterGroup.All)
    let counters = self.getActivityCenterNotificationsCounters(activityTypes, ActivityCenterReadType.Unread)
    var total = 0
    for activityType in activityTypes:
      total = total + counters.getOrDefault(activityType, 0)
    return total

  proc getHasUnseenActivityCenterNotifications*(self: Service): bool =
    try:
      let response = backend.hasUnseenActivityCenterNotifications()

      if response.result.kind != JNull:
        return response.result.getBool
    except Exception as e:
      error "Error getting unseen activity center notifications", msg = e.msg

  proc markActivityCenterNotificationRead*(self: Service, notificationId: string) =
    try:
      let notificationIds = @[notificationId]
      let response = backend.markActivityCenterNotificationsRead(notificationIds)

      var seenAndUnseenMessagesBatch: JsonNode = newJObject()
      discard response.result.getProp("seenAndUnseenMessages", seenAndUnseenMessagesBatch)

      if seenAndUnseenMessagesBatch.len > 0:
        for seenAndUnseenMessagesRaw in seenAndUnseenMessagesBatch:
          let seenAndUnseenMessages = seenAndUnseenMessagesRaw.toSeenUnseenMessagesDto()

          let data = MessagesMarkedAsReadArgs(
            chatId: seenAndUnseenMessages.chatId,
            allMessagesMarked: false,
            messagesIds: notificationIds,
            messagesCount: seenAndUnseenMessages.count,
            messagesWithMentionsCount: seenAndUnseenMessages.countWithMentions)
          self.events.emit(SIGNAL_MESSAGES_MARKED_AS_READ, data)

      self.parseActivityCenterState(response)
      self.events.emit(SIGNAL_ACTIVITY_CENTER_MARK_NOTIFICATIONS_AS_READ, ActivityCenterNotificationIdsArgs(notificationIds: notificationIds))
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_COUNT_MAY_HAVE_CHANGED, Args())
    except Exception as e:
      error "Error marking as read", msg = e.msg

  proc markActivityCenterNotificationUnread*(self: Service, notificationId: string) =
    try:
      let notificationIds = @[notificationId]
      let response =  backend.markActivityCenterNotificationsUnread(notificationIds)
      if response.error != nil:
        raise newException(RpcException, response.error.message)

      self.parseActivityCenterState(response)
      self.events.emit(SIGNAL_ACTIVITY_CENTER_MARK_NOTIFICATIONS_AS_UNREAD, ActivityCenterNotificationIdsArgs(notificationIds: notificationIds))
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_COUNT_MAY_HAVE_CHANGED, Args())
    except Exception as e:
      error "Error marking as unread", msg = e.msg

  proc markAllActivityCenterNotificationsRead*(self: Service) =
    try:
      let response = backend.markAllActivityCenterNotificationsRead()

      var seenAndUnseenMessagesBatch: JsonNode = newJObject()
      discard response.result.getProp("seenAndUnseenMessages", seenAndUnseenMessagesBatch)

      if seenAndUnseenMessagesBatch.len > 0:
        for seenAndUnseenMessagesRaw in seenAndUnseenMessagesBatch:
          let seenAndUnseenMessages = seenAndUnseenMessagesRaw.toSeenUnseenMessagesDto()

          let data = MessagesMarkedAsReadArgs(chatId: seenAndUnseenMessages.chatId, allMessagesMarked: true)
          self.events.emit(SIGNAL_MESSAGES_MARKED_AS_READ, data)

      self.parseActivityCenterState(response)
      self.events.emit(SIGNAL_ACTIVITY_CENTER_MARK_ALL_NOTIFICATIONS_AS_READ, Args())
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_COUNT_MAY_HAVE_CHANGED, Args())
    except Exception as e:
      error "Error marking all as read", msg = e.msg

  proc markAsSeenActivityCenterNotifications*(self: Service) =
    try:
      discard backend.markAsSeenActivityCenterNotifications()
    except Exception as e:
      error "Error marking as seen", msg = e.msg

  proc asyncActivityNotificationLoaded*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if responseObj{"error"}.kind != JNull and responseObj{"error"}.getStr != "":
        raise newException(CatchableError, responseObj{"error"}.getStr)

      if responseObj["activityNotifications"].kind != JNull:
        let activityCenterNotificationsTuple = parseActivityCenterNotifications(responseObj["activityNotifications"])

        self.cursor = activityCenterNotificationsTuple[0]

        self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_LOADED,
          ActivityCenterNotificationsArgs(activityCenterNotifications: activityCenterNotificationsTuple[1]))
    except Exception as e:
      error "Error loading activity notification async", msg = e.msg


  proc deleteActivityCenterNotifications*(self: Service, notificationIds: seq[string]): string =
    try:
      let response = backend.deleteActivityCenterNotifications(notificationIds)
      if response.error != nil:
        raise newException(RpcException, response.error.message)

      self.parseActivityCenterState(response)
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_REMOVED, ActivityCenterNotificationIdsArgs(notificationIds: notificationIds))
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_COUNT_MAY_HAVE_CHANGED, Args())
    except Exception as e:
      error "Error deleting notifications", msg = e.msg
      result = e.msg

  proc getNotificationForTypeAndCommunityId*(self: Service, notificationType: ActivityCenterNotificationType, communityId: string): ActivityCenterNotificationDto =
    let acNotifications = self.getActivityCenterNotifications()
    for acNotification in acNotifications:
      if acNotification.notificationType == notificationType and acNotification.communityId == communityId:
        return acNotification

  proc acceptActivityCenterNotification*(self: Service, notificationId: string) =
    try:
      let notificationIds = @[notificationId]
      let response = backend.acceptActivityCenterNotifications(notificationIds)
      if response.error != nil:
        raise newException(RpcException, response.error.message)

      if response.result.kind != JNull:
        if response.result.contains("chats"):
          for jsonChat in response.result["chats"]:
            var chat = toChatDto(jsonChat)
            self.chatService.updateOrAddChat(chat)
            self.events.emit(SIGNAL_CHAT_UPDATE, ChatUpdateArgs(chats: @[chat]))

      self.parseActivityCenterState(response)
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_ACCEPTED, ActivityCenterNotificationIdArgs(notificationId: notificationId))
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_COUNT_MAY_HAVE_CHANGED, Args())
    except Exception as e:
      error "Error accepting activity center notification", msg = e.msg

  proc dismissActivityCenterNotification*(self: Service, notificationId: string) =
    try:
      let notificationIds = @[notificationId]
      let response = backend.dismissActivityCenterNotifications(notificationIds)
      if response.error != nil:
        raise newException(RpcException, response.error.message)

      self.parseActivityCenterState(response)
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_DISMISSED, ActivityCenterNotificationIdArgs(notificationId: notificationId))
      self.events.emit(SIGNAL_ACTIVITY_CENTER_NOTIFICATIONS_COUNT_MAY_HAVE_CHANGED, Args())
    except Exception as e:
      error "Error dismissing activity center notification", msg = e.msg

  proc delete*(self: Service) =
    self.QObject.delete

