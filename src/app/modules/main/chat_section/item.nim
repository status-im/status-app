import std/strformat, json

import ../../../../app_service/common/types
import ../../../../app_service/service/contacts/dto/contacts

const CATEGORY_TYPE* = -1

type
  ChatItem* = ref object
    id: string
    name: string
    usesDefaultName: bool
    `type`: int
    memberRole: MemberRole
    icon: string
    color: string
    colorId: int # only for oneToOne sections
    emoji: string
    description: string
    lastMessageTimestamp: int
    hasUnreadMessages: bool
    lastMessageText: string
    notificationsCount: int
    muted: bool
    blocked: bool
    active: bool
    position: int
    categoryId: string
    categoryPosition: int
    categoryOpened: bool
    highlight: bool
    trustStatus: TrustStatus
    onlineStatus: OnlineStatus
    loaderActive: bool
    locked: bool
    requiresPermissions: bool
    canPostReactions: bool
    canPost: bool
    canView: bool
    viewersCanPostReactions: bool
    hideIfPermissionsNotMet: bool
    missingEncryptionKey: bool
    permissionsCheckOngoing: bool

proc initChatItem*(
    id,
    name: string,
    usesDefaultName: bool,
    icon,
    color,
    emoji,
    description: string,
    `type`: int,
    memberRole: MemberRole,
    lastMessageTimestamp: int,
    lastMessageText: string,
    hasUnreadMessages: bool,
    notificationsCount: int,
    muted,
    blocked,
    active: bool,
    position: int,
    categoryId: string = "",
    categoryPosition: int = -1,
    colorId: int = 0,
    highlight: bool = false,
    categoryOpened: bool = true,
    trustStatus: TrustStatus = TrustStatus.Unknown,
    onlineStatus = OnlineStatus.Inactive,
    loaderActive = false,
    locked = false,
    requiresPermissions = false,
    canPost = true,
    canView = true,
    canPostReactions = true,
    viewersCanPostReactions = true,
    hideIfPermissionsNotMet: bool = false,
    missingEncryptionKey: bool = false,
    permissionsCheckOngoing: bool = false,
    ): ChatItem =
  result = ChatItem()
  result.id = id
  result.name = name
  result.usesDefaultName = usesDefaultName
  result.memberRole = memberRole
  result.icon = icon
  result.color = color
  result.colorId = colorId
  result.emoji = emoji
  result.description = description
  result.`type` = `type`
  result.lastMessageTimestamp = lastMessageTimestamp
  result.lastMessageText = lastMessageText
  result.hasUnreadMessages = hasUnreadMessages
  result.notificationsCount = notificationsCount
  result.muted = muted
  result.blocked = blocked
  result.active = active
  result.position = position
  result.categoryId = categoryId
  result.categoryPosition = categoryPosition
  result.highlight = highlight
  result.categoryOpened = categoryOpened
  result.trustStatus = trustStatus
  result.onlineStatus = onlineStatus
  result.loaderActive = loaderActive
  result.locked = locked
  result.requiresPermissions = requiresPermissions
  result.canPost = canPost
  result.canView = canView
  result.canPostReactions = canPostReactions
  result.viewersCanPostReactions = viewersCanPostReactions
  result.hideIfPermissionsNotMet = hideIfPermissionsNotMet
  result.missingEncryptionKey = missingEncryptionKey
  result.permissionsCheckOngoing = permissionsCheckOngoing

proc `$`*(self: ChatItem): string =
  result = fmt"""chat_section/ChatItem(
    id: {self.id},
    name: {$self.name},
    usesDefaultName: {$self.usesDefaultName},
    memberRole: {$self.memberRole},
    icon: {$self.icon},
    color: {$self.color},
    colorId: {$self.colorId},
    emoji: {$self.emoji},
    description: {$self.description},
    type: {$self.`type`},
    lastMessageTimestamp: {$self.lastMessageTimestamp},
    lastMessageText: {$self.lastMessageText},
    hasUnreadMessages: {$self.hasUnreadMessages},
    notificationsCount: {$self.notificationsCount},
    muted: {$self.muted},
    blocked: {$self.blocked},
    active: {$self.active},
    position: {$self.position},
    categoryId: {$self.categoryId},
    categoryPosition: {$self.categoryPosition},
    highlight: {$self.highlight},
    categoryOpened: {$self.categoryOpened},
    trustStatus: {$self.trustStatus},
    onlineStatus: {$self.onlineStatus},
    loaderActive: {$self.loaderActive},
    locked: {$self.locked},
    requiresPermissions: {$self.requiresPermissions},
    canPost: {$self.canPost},
    canView: {$self.canView},
    canPostReactions: {$self.canPostReactions},
    viewersCanPostReactions: {$self.viewersCanPostReactions},
    hideIfPermissionsNotMet: {$self.hideIfPermissionsNotMet},
    permissionsCheckOngoing: {$self.permissionsCheckOngoing},
    ]"""

proc toJsonNode*(self: ChatItem): JsonNode =
  result = %* {
    "itemId": self.id,
    "name": self.name,
    "usesDefaultName": self.usesDefaultName,
    "memberRole": self.memberRole,
    "icon": self.icon,
    "color": self.color,
    "colorId": self.colorId,
    "emoji": self.emoji,
    "description": self.description,
    "type": self.`type`,
    "lastMessageTimestamp": self.lastMessageTimestamp,
    "hasUnreadMessages": self.hasUnreadMessages,
    "notificationsCount": self.notificationsCount,
    "muted": self.muted,
    "blocked": self.blocked,
    "active": self.active,
    "position": self.position,
    "categoryId": self.categoryId,
    "categoryPosition": self.categoryPosition,
    "highlight": self.highlight,
    "categoryOpened": self.categoryOpened,
    "trustStatus": self.trustStatus,
    "onlineStatus": self.onlineStatus,
    "loaderActive": self.loaderActive,
    "locked": self.locked,
    "requiresPermissions": self.requiresPermissions,
    "canPost": self.canPost,
    "canView": self.canView,
    "canPostReactions": self.canPostReactions,
    "viewersCanPostReactions": self.viewersCanPostReactions,
    "hideIfPermissionsNotMet": self.hideIfPermissionsNotMet,
    "permissionsCheckOngoing": self.permissionsCheckOngoing,
  }

proc delete*(self: ChatItem) =
  discard

proc id*(self: ChatItem): string =
  self.id

proc name*(self: ChatItem): string =
  self.name

proc `name=`*(self: var ChatItem, value: string) =
  self.name = value

proc usesDefaultName*(self: ChatItem): bool =
  self.usesDefaultName

proc `usesDefaultName=`*(self: var ChatItem, value: bool) =
  self.usesDefaultName = value

proc memberRole*(self: ChatItem): MemberRole =
  self.memberRole

proc icon*(self: ChatItem): string =
  self.icon

proc `icon=`*(self: var ChatItem, value: string) =
  self.icon = value

proc color*(self: ChatItem): string =
  self.color

proc `color=`*(self: var ChatItem, value: string) =
  self.color = value

proc colorId*(self: ChatItem): int =
  self.colorId

proc emoji*(self: ChatItem): string =
  self.emoji

proc `emoji=`*(self: var ChatItem, value: string) =
  self.emoji = value

proc description*(self: ChatItem): string =
  self.description

proc `description=`*(self: var ChatItem, value: string) =
  self.description = value

proc type*(self: ChatItem): int =
  self.`type`

proc hasUnreadMessages*(self: ChatItem): bool =
  self.hasUnreadMessages

proc `hasUnreadMessages=`*(self: var ChatItem, value: bool) =
  self.hasUnreadMessages = value

proc lastMessageTimestamp*(self: ChatItem): int =
  self.lastMessageTimestamp

proc `lastMessageTimestamp=`*(self: var ChatItem, value: int) =
  self.lastMessageTimestamp = value

proc lastMessageText*(self: ChatItem): string =
  self.lastMessageText

proc `lastMessageText=`*(self: var ChatItem, value: string) =
  self.lastMessageText = value

proc notificationsCount*(self: ChatItem): int =
  self.notificationsCount

proc `notificationsCount=`*(self: var ChatItem, value: int) =
  self.notificationsCount = value

proc muted*(self: ChatItem): bool =
  self.muted

proc `muted=`*(self: ChatItem, value: bool) =
  self.muted = value

proc blocked*(self: ChatItem): bool =
  self.blocked

proc `blocked=`*(self: var ChatItem, value: bool) =
  self.blocked = value

proc active*(self: ChatItem): bool =
  self.active

proc `active=`*(self: var ChatItem, value: bool) =
  self.active = value

proc position*(self: ChatItem): int =
  self.position

proc `position=`*(self: var ChatItem, value: int) =
  self.position = value

proc categoryId*(self: ChatItem): string =
  self.categoryId

proc `categoryId=`*(self: var ChatItem, value: string) =
  self.categoryId = value

proc hideIfPermissionsNotMet*(self: ChatItem): bool =
  self.hideIfPermissionsNotMet

proc `hideIfPermissionsNotMet=`*(self: var ChatItem, value: bool) =
  self.hideIfPermissionsNotMet = value

proc categoryPosition*(self: ChatItem): int =
  self.categoryPosition

proc `categoryPosition=`*(self: var ChatItem, value: int) =
  self.categoryPosition = value

proc highlight*(self: ChatItem): bool =
  self.highlight

proc `highlight=`*(self: var ChatItem, value: bool) =
  self.highlight = value

proc categoryOpened*(self: ChatItem): bool =
  self.categoryOpened

proc `categoryOpened=`*(self: var ChatItem, value: bool) =
  self.categoryOpened = value

proc trustStatus*(self: ChatItem): TrustStatus =
  self.trustStatus

proc `trustStatus=`*(self: var ChatItem, value: TrustStatus) =
  self.trustStatus = value

proc onlineStatus*(self: ChatItem): OnlineStatus =
  self.onlineStatus

proc `onlineStatus=`*(self: var ChatItem, value: OnlineStatus) =
  self.onlineStatus = value

proc setHasUnreadMessages*(self: ChatItem, value: bool) =
  self.hasUnreadMessages = value

proc loaderActive*(self: ChatItem): bool =
  self.loaderActive

proc `loaderActive=`*(self: var ChatItem, value: bool) =
  self.loaderActive = value

proc isCategory*(self: ChatItem): bool =
  self.`type` == CATEGORY_TYPE

proc locked*(self: ChatItem): bool =
  self.locked

proc `locked=`*(self: ChatItem, value: bool) =
  self.locked = value

proc requiresPermissions*(self: ChatItem): bool =
  self.requiresPermissions

proc `requiresPermissions=`*(self: ChatItem, value: bool) =
  self.requiresPermissions = value

proc canPost*(self: ChatItem): bool =
  self.canPost

proc `canPost=`*(self: ChatItem, value: bool) =
  self.canPost = value

proc canView*(self: ChatItem): bool =
  self.canView

proc `canView=`*(self: ChatItem, value: bool) =
  self.canView = value

proc canPostReactions*(self: ChatItem): bool =
  self.canPostReactions

proc `canPostReactions=`*(self: ChatItem, value: bool) =
  self.canPostReactions = value

proc viewersCanPostReactions*(self: ChatItem): bool =
  self.viewersCanPostReactions

proc `viewersCanPostReactions=`*(self: ChatItem, value: bool) =
  self.viewersCanPostReactions = value

proc hideBecausePermissionsAreNotMet*(self: ChatItem): bool =
  self.hideIfPermissionsNotMet and not self.canPost and not self.canView

proc missingEncryptionKey*(self: ChatItem): bool =
  self.missingEncryptionKey

proc `missingEncryptionKey=`*(self: var ChatItem, value: bool) =
  self.missingEncryptionKey = value

proc permissionsCheckOngoing*(self: ChatItem): bool =
  self.permissionsCheckOngoing

proc `permissionsCheckOngoing=`*(self: var ChatItem, value: bool) =
  self.permissionsCheckOngoing = value
