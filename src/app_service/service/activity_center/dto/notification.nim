{.used.}

import json, std/strformat, strutils, stint, json_serialization
import ../../message/dto/message
import ../../contacts/dto/contacts
import token_data

include ../../../common/json_utils
include ../../../common/utils

type ActivityCenterNotificationType* {.pure.}= enum
  NoType = 0,
  NewOneToOne = 1,
  NewPrivateGroupChat = 2,
  Mention = 3,
  Reply = 4,
  ContactRequest = 5,
  CommunityInvitation = 6,
  CommunityRequest = 7,
  CommunityMembershipRequest = 8,
  CommunityKicked = 9,
  ContactVerification = 10
  ContactRemoved = 11
  NewKeypairAddedToPairedDevice = 12
  OwnerTokenReceived = 13
  OwnershipReceived = 14
  OwnershipLost = 15
  SetSignerFailed = 16
  SetSignerDeclined = 17
  ShareAccounts = 18
  CommunityTokenReceived = 19
  FirstCommunityTokenReceived = 20
  CommunityBanned = 21
  CommunityUnbanned = 22
  NewInstallationReceived = 23
  NewInstallationCreated = 24
  BackupSyncingFetching = 25 # Deprecated
  BackupSyncingSuccess = 26 # Deprecated
  BackupSyncingPartialFailure = 27 # Deprecated
  BackupSyncingFailure = 28 # Deprecated
  ActivityCenterNotificationTypeNews = 29

type ActivityCenterGroup* {.pure.}= enum
  All = 0,
  Mentions = 1,
  Replies = 2,
  Membership = 3,
  Admin = 4,
  ContactRequests = 5,
  IdentityVerification = 6,
  Transactions = 7,
  System = 8
  News = 9

type ActivityCenterReadType* {.pure.}= enum
  Read = 1,
  Unread = 2
  All = 3

type ActivityCenterMembershipStatus* {.pure.}= enum
  Idle = 0,
  Pending = 1,
  Accepted = 2,
  Declined = 3,
  AcceptedPending = 4,
  DeclinedPending = 5,

type ActivityCenterNotificationDto* = ref object of RootObj
  id*: string # ID is the id of the chat, for public chats it is the name e.g. status, for one-to-one is the hex encoded public key and for group chats is a random uuid appended with the hex encoded pk of the creator of the chat
  chatId*: string
  communityId*: string
  membershipStatus*: ActivityCenterMembershipStatus
  name*: string
  newsTitle*: string
  newsDescription*: string
  newsContent*: string
  newsImageUrl*: string
  newsLink*: string
  newsLinkLabel*: string
  author*: string
  installationId*: string
  notificationType*: ActivityCenterNotificationType
  message*: MessageDto
  replyMessage*: MessageDto
  albumMessages*: seq[MessageDto]
  timestamp*: int64
  read*: bool
  dismissed*: bool
  deleted*: bool
  accepted*: bool
  tokenData*: TokenDataDto

proc `$`*(self: ActivityCenterNotificationDto): string =
  result = fmt"""ActivityCenterNotificationDto(
    id: {$self.id},
    chatId: {self.chatId},
    communityId: {self.communityId},
    name: {self.name},
    newsTitle: {self.newsTitle},
    newsDescription: {self.newsDescription},
    newsContent: {self.newsContent},
    newsImageUrl: {self.newsImageUrl},
    newsLink: {self.newsLink},
    newsLinkLabel: {self.newsLinkLabel},
    membershipStatus: {self.membershipStatus},
    author: {self.author},
    installationId: {self.installationId},
    notificationType: {$self.notificationType.int},
    timestamp: {self.timestamp},
    read: {$self.read},
    dismissed: {$self.dismissed},
    deleted: {$self.deleted},
    accepted: {$self.accepted},
    message: {self.message},
    replyMessage: {self.replyMessage},
    tokenData: {self.tokenData}
    )"""

proc toActivityCenterNotificationDto*(jsonObj: JsonNode): ActivityCenterNotificationDto =
  result = ActivityCenterNotificationDto()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("chatId", result.chatId)
  discard jsonObj.getProp("communityId", result.communityId)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("newsTitle", result.newsTitle)
  discard jsonObj.getProp("newsDescription", result.newsDescription)
  discard jsonObj.getProp("newsContent", result.newsContent)
  discard jsonObj.getProp("newsImageUrl", result.newsImageUrl)
  discard jsonObj.getProp("newsLink", result.newsLink)
  discard jsonObj.getProp("newsLinkLabel", result.newsLinkLabel)

  result.membershipStatus = ActivityCenterMembershipStatus.Idle
  var membershipStatusInt: int
  if (jsonObj.getProp("membershipStatus", membershipStatusInt) and
    (membershipStatusInt >= ord(low(ActivityCenterMembershipStatus)) and
    membershipStatusInt <= ord(high(ActivityCenterMembershipStatus)))):
      result.membershipStatus = ActivityCenterMembershipStatus(membershipStatusInt)

  discard jsonObj.getProp("author", result.author)
  discard jsonObj.getProp("installationId", result.installationId)

  result.notificationType = ActivityCenterNotificationType.NoType
  var notificationTypeInt: int
  if (jsonObj.getProp("type", notificationTypeInt) and
    (notificationTypeInt >= ord(low(ActivityCenterNotificationType)) and
    notificationTypeInt <= ord(high(ActivityCenterNotificationType)))):
      result.notificationType = ActivityCenterNotificationType(notificationTypeInt)

  discard jsonObj.getProp("timestamp", result.timestamp)
  discard jsonObj.getProp("read", result.read)
  discard jsonObj.getProp("dismissed", result.dismissed)
  discard jsonObj.getProp("deleted", result.deleted)
  discard jsonObj.getProp("accepted", result.accepted)

  if jsonObj.contains("message") and jsonObj{"message"}.kind != JNull:
    result.message = jsonObj["message"].toMessageDto()
  elif result.notificationType == ActivityCenterNotificationType.NewOneToOne and
    jsonObj.contains("lastMessage") and jsonObj{"lastMessage"}.kind != JNull:
    result.message = jsonObj["lastMessage"].toMessageDto()

  if jsonObj.contains("replyMessage") and jsonObj{"replyMessage"}.kind != JNull:
    result.replyMessage = jsonObj["replyMessage"].toMessageDto()

  if jsonObj.contains("albumMessages") and jsonObj{"albumMessages"}.kind != JNull:
    let jsonAlbum = jsonObj["albumMessages"]
    for msg in jsonAlbum:
      result.albumMessages.add(toMessageDto(msg))

  if jsonObj.contains("tokenData") and jsonObj{"tokenData"}.kind != JNull:
    result.tokenData = jsonObj["tokenData"].toTokenDataDto()

proc parseActivityCenterNotifications*(rpcResult: JsonNode): (string, seq[ActivityCenterNotificationDto]) =
  var notifs: seq[ActivityCenterNotificationDto] = @[]
  if rpcResult{"notifications"}.kind != JNull:
    for jsonMsg in rpcResult["notifications"]:
      notifs.add(jsonMsg.toActivityCenterNotificationDto())
  return (rpcResult{"cursor"}.getStr, notifs)

proc activityCenterNotificationTypesByGroup*(group: ActivityCenterGroup) : seq[int] =
  case group
    of ActivityCenterGroup.All:
      return @[
        ActivityCenterNotificationType.NewPrivateGroupChat.int,
        ActivityCenterNotificationType.Mention.int,
        ActivityCenterNotificationType.Reply.int,
        ActivityCenterNotificationType.ContactRequest.int,
        ActivityCenterNotificationType.CommunityInvitation.int,
        ActivityCenterNotificationType.CommunityRequest.int,
        ActivityCenterNotificationType.CommunityMembershipRequest.int,
        ActivityCenterNotificationType.CommunityKicked.int,
        ActivityCenterNotificationType.ContactVerification.int,
        ActivityCenterNotificationType.ContactRemoved.int,
        ActivityCenterNotificationType.NewKeypairAddedToPairedDevice.int,
        ActivityCenterNotificationType.OwnerTokenReceived.int,
        ActivityCenterNotificationType.OwnershipReceived.int,
        ActivityCenterNotificationType.SetSignerFailed.int,
        ActivityCenterNotificationType.SetSignerDeclined.int,
        ActivityCenterNotificationType.OwnershipLost.int,
        ActivityCenterNotificationType.ShareAccounts.int,
        ActivityCenterNotificationType.CommunityTokenReceived.int,
        ActivityCenterNotificationType.FirstCommunityTokenReceived.int,
        ActivityCenterNotificationType.CommunityBanned.int,
        ActivityCenterNotificationType.CommunityUnbanned.int,
        ActivityCenterNotificationType.NewInstallationReceived.int,
        ActivityCenterNotificationType.NewInstallationCreated.int,
        ActivityCenterNotificationType.ActivityCenterNotificationTypeNews.int,
      ]
    of ActivityCenterGroup.Mentions:
      return @[ActivityCenterNotificationType.Mention.int]
    of ActivityCenterGroup.Replies:
      return @[ActivityCenterNotificationType.Reply.int]
    of ActivityCenterGroup.Membership:
      return @[
        ActivityCenterNotificationType.NewPrivateGroupChat.int,
        ActivityCenterNotificationType.CommunityInvitation.int,
        ActivityCenterNotificationType.CommunityRequest.int,
        ActivityCenterNotificationType.CommunityMembershipRequest.int,
        ActivityCenterNotificationType.CommunityKicked.int,
        ActivityCenterNotificationType.CommunityBanned.int,
        ActivityCenterNotificationType.CommunityUnbanned.int
      ]
    of ActivityCenterGroup.Admin:
      return @[ActivityCenterNotificationType.CommunityMembershipRequest.int]
    of ActivityCenterGroup.ContactRequests:
      return @[
        ActivityCenterNotificationType.ContactRequest.int,
        ActivityCenterNotificationType.ContactRemoved.int
      ]
    of ActivityCenterGroup.IdentityVerification:
      return @[ActivityCenterNotificationType.ContactVerification.int]
    of ActivityCenterGroup.News:
      return @[ActivityCenterNotificationType.ActivityCenterNotificationTypeNews.int]
    else:
      return @[]