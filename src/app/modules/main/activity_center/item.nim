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

proc `id=`*(self: Item, value: string) =
  self.id = value

proc name*(self: Item): string =
  return self.name

proc `name=`*(self: Item, value: string) =
  self.name = value

proc newsTitle*(self: Item): string =
  return self.newsTitle

proc `newsTitle=`*(self: Item, value: string) =
  self.newsTitle = value

proc newsDescription*(self: Item): string =
  return self.newsDescription

proc `newsDescription=`*(self: Item, value: string) =
  self.newsDescription = value

proc newsContent*(self: Item): string =
  return self.newsContent

proc `newsContent=`*(self: Item, value: string) =
  self.newsContent = value

proc newsImageUrl*(self: Item): string =
  return self.newsImageUrl

proc `newsImageUrl=`*(self: Item, value: string) =
  self.newsImageUrl = value

proc newsLink*(self: Item): string =
  return self.newsLink

proc `newsLink=`*(self: Item, value: string) =
  self.newsLink = value

proc newsLinkLabel*(self: Item): string =
  return self.newsLinkLabel

proc `newsLinkLabel=`*(self: Item, value: string) =
  self.newsLinkLabel = value

proc author*(self: Item): string =
  return self.author

proc `author=`*(self: Item, value: string) =
  self.author = value

proc installationId*(self: Item): string =
  return self.installationId

proc `installationId=`*(self: Item, value: string) =
  self.installationId = value

proc chatId*(self: Item): string =
  return self.chatId

proc `chatId=`*(self: Item, value: string) =
  self.chatId = value

proc chatType*(self: Item): ChatType =
  return self.chatType

proc `chatType=`*(self: Item, value: ChatType) =
  self.chatType = value

proc communityId*(self: Item): string =
  return self.communityId

proc `communityId=`*(self: Item, value: string) =
  self.communityId = value

proc membershipStatus*(self: Item): ActivityCenterMembershipStatus =
  return self.membershipStatus

proc `membershipStatus=`*(self: Item, value: ActivityCenterMembershipStatus) =
  self.membershipStatus = value

proc sectionId*(self: Item): string =
  return self.sectionId

proc `sectionId=`*(self: Item, value: string) =
  self.sectionId = value

proc notificationType*(self: Item): ActivityCenterNotificationType =
  return self.notificationType

proc `notificationType=`*(self: Item, value: ActivityCenterNotificationType) =
  self.notificationType = value

proc timestamp*(self: Item): int64 =
  return self.timestamp

proc `timestamp=`*(self: Item, value: int64) =
  self.timestamp = value

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

proc `messageItem=`*(self: Item, value: MessageItem) =
  self.messageItem = value

proc repliedMessageItem*(self: Item): MessageItem =
  return self.repliedMessageItem

proc `repliedMessageItem=`*(self: Item, value: MessageItem) =
  self.repliedMessageItem = value

proc tokenDataItem*(self: Item): TokenDataItem =
  return self.tokenDataItem

proc `tokenDataItem=`*(self: Item, value: TokenDataItem) =
  self.tokenDataItem = value