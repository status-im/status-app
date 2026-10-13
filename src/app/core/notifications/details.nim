{.used.}

import json

include ../../../app_service/common/json_utils

type
  NotificationType* {.pure.} = enum
    UnknownNotification,
    TestNotification,
    NewContactRequest,
    AcceptedContactRequest,
    ContactRemoved,
    JoinCommunityRequest,
    MyRequestToJoinCommunityAccepted,
    MyRequestToJoinCommunityRejected,
    NewMessage,
    NewMessageWithPersonalMention,
    NewMessageWithGlobalMention,
    IdentityVerificationRequest,
    CommunityTokenPermissionCreated,
    CommunityTokenPermissionUpdated,
    CommunityTokenPermissionDeleted,
    CommunityTokenPermissionCreationFailed,
    CommunityTokenPermissionUpdateFailed,
    CommunityTokenPermissionDeletionFailed,
    CommunityMemberKicked,
    CommunityMemberBanned,
    CommunityMemberUnbanned,
    NewsFeedMessage,

  NotificationDetails* = object
    notificationType*: NotificationType # the default value is `UnknownNotification`
    sectionId*: string
    isCommunitySection*: bool
    sectionActive*: bool
    chatId*: string
    chatActive*: bool
    isOneToOne*: bool
    isGroupChat*: bool
    messageId*: string
    threadId*: string
    notificationId*: string

proc isEmpty*(self: NotificationDetails): bool =
  return self.notificationType == NotificationType.UnknownNotification

proc toNotificationDetails*(jsonObj: JsonNode): NotificationDetails =
  var notificationType: int
  if (not (jsonObj.getProp("notificationType", notificationType) and
    jsonObj.getProp("sectionId", result.sectionId) and
    jsonObj.getProp("isCommunitySection", result.isCommunitySection) and
    jsonObj.getProp("sectionActive", result.sectionActive) and
    jsonObj.getProp("chatId", result.chatId) and
    jsonObj.getProp("chatActive", result.chatActive) and
    jsonObj.getProp("isOneToOne", result.isOneToOne) and
    jsonObj.getProp("isGroupChat", result.isGroupChat) and
    jsonObj.getProp("messageId", result.messageId))):
    return NotificationDetails()

  result.notificationType = notificationType.NotificationType
  discard jsonObj.getProp("threadId", result.threadId)

proc toJsonNode*(self: NotificationDetails): JsonNode =
  result = %* {
    "notificationType": self.notificationType.int,
    "sectionId": self.sectionId,
    "isCommunitySection": self.isCommunitySection,
    "sectionActive": self.sectionActive,
    "chatId": self.chatId,
    "chatActive": self.chatActive,
    "isOneToOne": self.isOneToOne,
    "isGroupChat": self.isGroupChat,
    "messageId": self.messageId,
    "threadId": self.threadId
  }
