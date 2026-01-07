import std/strformat
import ../../shared_models/message_item_qobject
import ../../../../app_service/service/activity_center/dto/notification
import ../../../../app_service/service/chat/dto/chat
import ../../../../app_service/service/contacts/dto/contacts
import ./token_data_item

type Item* = ref object
  id: string # ID is the id of the chat, for public chats it is the name e.g. status, for one-to-one is the hex encoded public key and for group chats is a random uuid appended with the hex encoded pk of the creator of the chat
  chatId: string
  communityId: string
  membershipStatus: ActivityCenterMembershipStatus
  sectionId: string
  name: string
  newsTitle: string
  newsDescription: string
  newsContent: string
  newsImageUrl: string
  newsLink: string
  newsLinkLabel: string
  author: string
  notificationType: ActivityCenterNotificationType
  timestamp: int64
  read: bool
  dismissed: bool
  accepted: bool
  messageItem: MessageItem
  repliedMessageItem: MessageItem
  chatType: ChatType
  tokenDataItem: TokenDataItem
  installationId: string

proc initItem*(
  id: string,
  chatId: string,
  communityId: string,
  membershipStatus: ActivityCenterMembershipStatus,
  sectionId: string,
  name: string,
  newsTitle: string,
  newsDescription: string,
  newsContent: string,
  newsImageUrl: string,
  newsLink: string,
  newsLinkLabel: string,
  author: string,
  notificationType: ActivityCenterNotificationType,
  timestamp: int64,
  read: bool,
  dismissed: bool,
  accepted: bool,
  messageItem: MessageItem,
  repliedMessageItem: MessageItem,
  chatType: ChatType,
  tokenDataItem: TokenDataItem,
  installationId: string
): Item =
  result = Item()
  result.id = id
  result.chatId = chatId
  result.communityId = communityId
  result.membershipStatus = membershipStatus
  result.sectionId = sectionId
  result.name = name
  result.newsTitle = newsTitle
  result.newsDescription = newsDescription
  result.newsContent = newsContent
  result.newsImageUrl = newsImageUrl
  result.newsLink = newsLink
  result.newsLinkLabel = newsLinkLabel
  result.author = author
  result.notificationType = notificationType
  result.timestamp = timestamp
  result.read = read
  result.dismissed = dismissed
  result.accepted = accepted
  result.messageItem = messageItem
  result.repliedMessageItem = repliedMessageItem
  result.chatType = chatType
  result.tokenDataItem = tokenDataItem
  result.installationId = installationId

proc `$`*(self: Item): string =
  result = fmt"""activity_center/Item(
    id: {self.id},
    name: {$self.name},
    newsTitle: {$self.newsTitle},
    newsDescription: {$self.newsDescription},
    newsContent: {$self.newsContent},
    newsImageUrl: {$self.newsImageUrl},
    newsLink: {$self.newsLink},
    newsLinkLabel: {$self.newsLinkLabel},
    chatId: {$self.chatId},
    communityId: {$self.communityId},
    membershipStatus: {$self.membershipStatus.int},
    sectionId: {$self.sectionId},
    author: {$self.author},
    installationId: {$self.installationId},
    notificationType: {$self.notificationType.int},
    timestamp: {$self.timestamp},
    read: {$self.read},
    dismissed: {$self.dismissed},
    accepted: {$self.accepted},
    # messageItem: {$self.messageItem},
    # repliedMessageItem: {$self.repliedMessageItem},
    tokenData: {$self.tokenDataItem}
    ]"""

proc id*(self: Item): string =
  return self.id

proc name*(self: Item): string =
  return self.name

proc newsTitle*(self: Item): string =
  return self.newsTitle

proc newsDescription*(self: Item): string =
  return self.newsDescription

proc newsContent*(self: Item): string =
  return self.newsContent

proc newsImageUrl*(self: Item): string =
  return self.newsImageUrl

proc newsLink*(self: Item): string =
  return self.newsLink

proc newsLinkLabel*(self: Item): string =
  return self.newsLinkLabel

proc author*(self: Item): string =
  return self.author

proc installationId*(self: Item): string =
  return self.installationId

proc chatId*(self: Item): string =
  return self.chatId

proc chatType*(self: Item): ChatType =
  return self.chatType

proc communityId*(self: Item): string =
  return self.communityId

proc membershipStatus*(self: Item): ActivityCenterMembershipStatus =
  return self.membershipStatus

proc sectionId*(self: Item): string =
  return self.sectionId

proc notificationType*(self: Item): ActivityCenterNotificationType =
  return self.notificationType

proc timestamp*(self: Item): int64 =
  return self.timestamp

proc read*(self: Item): bool =
  return self.read

proc `read=`*(self: Item, value: bool) =
  self.read = value

proc dismissed*(self: Item): bool =
  return self.dismissed

proc `dismissed=`*(self: Item, value: bool) =
  self.dismissed = value

proc accepted*(self: Item): bool =
  return self.accepted

proc `accepted=`*(self: Item, value: bool) =
  self.accepted = value

proc messageItem*(self: Item): MessageItem =
  return self.messageItem

proc repliedMessageItem*(self: Item): MessageItem =
  return self.repliedMessageItem

proc tokenDataItem*(self: Item): TokenDataItem =
  return self.tokenDataItem