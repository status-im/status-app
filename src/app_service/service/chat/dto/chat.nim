{.used.}

import json, std/strformat, strutils, tables
import ../../shared_urls/dto/url_data
import app_service/service/message/dto/message

include ../../../common/json_utils

type ChatType* {.pure.}= enum
  Unknown = 0,
  OneToOne = 1,
  Public = 2,
  PrivateGroupChat = 3,
  Profile = 4,
  Timeline {.deprecated.} = 5,
  CommunityChat = 6

type ChatSectionType* {.pure.}= enum
  Unknown = "unknown",
  Personal = "personal",
  Community = "community"

type Category* = object
  id*: string
  name*: string
  position*: int
  collapsed*: bool

type
  Permission* = object
    access*: int
    ensOnly*: bool

type
  Images* = object
    thumbnail*: string
    large*: string
    banner*: string

type ChatMember* = object
  id*: string
  joined*: bool
  role*: MemberRole

type CheckPermissionsResultDto* = object
  criteria*: seq[bool]

type ViewOnlyOrViewAndPostPermissionsResponseDto* = object
  satisfied*: bool
  permissions*: Table[string, CheckPermissionsResultDto]

type CheckChannelPermissionsResponseDto* = object
  viewOnlyPermissions*: ViewOnlyOrViewAndPostPermissionsResponseDto
  viewAndPostPermissions*: ViewOnlyOrViewAndPostPermissionsResponseDto

type CheckAllChannelsPermissionsResponseDto* = object
  channels*: Table[string, CheckChannelPermissionsResponseDto]

type ChatDto* = object
  id*: string # ID is the id of the chat, for public chats it is the name e.g. status,
  # for one-to-one is the hex encoded public key and for group chats is a random
  # uuid appended with the hex encoded pk of the creator of the chat
  name*: string
  description*: string
  color*: string
  emoji*: string
  active*: bool # indicates whether the chat has been soft deleted
  chatType*: ChatType
  timestamp*: int64 # indicates the last time this chat has received/sent a message
  lastClockValue*: int64 # indicates the last clock value to be used when sending messages
  deletedAtClockValue*: int64 # indicates the clock value at time of deletion, messages with lower clock value of this should be discarded
  readMessagesAtClockValue*: int64
  unviewedMessagesCount*: int
  unviewedMentionsCount*: int
  lastMessage*: MessageDto
  members*: seq[ChatMember]
  alias*: string
  icon*: string
  muted*: bool
  communityId*: string #set if chat belongs to a community
  profile*: string
  joined*: int64 # indicates when the user joined the chat last time
  syncedTo*: int64
  syncedFrom*: int64
  firstMessageTimestamp: int64 # valid only for community chats, 0 - undefined, 1 - no messages, >1 valid timestamps
  canPost*: bool
  canView*: bool
  canPostReactions*: bool
  viewersCanPostReactions*: bool
  position*: int
  categoryId*: string
  highlight*: bool
  permissions*: Permission
  hideIfPermissionsNotMet*: bool
  tokenGated*: bool
  missingEncryptionKey*: bool

type ClearedHistoryDto* = object
  chatId*: string
  clearedAt*: int

proc `$`*(self: ChatDto): string =
  result = fmt"""ChatDto(
    id: {self.id},
    name: {self.name},
    description: {self.description},
    color: {self.color},
    emoji: {self.emoji},
    active: {self.active},
    chatType: {self.chatType},
    timestamp: {self.timestamp},
    lastClockValue: {self.lastClockValue},
    deletedAtClockValue: {self.deletedAtClockValue},
    readMessagesAtClockValue: {self.readMessagesAtClockValue},
    unviewedMessagesCount: {self.unviewedMessagesCount},
    unviewedMentionsCount: {self.unviewedMentionsCount},
    members: {self.members},
    alias: {self.alias},
    icon: {self.icon},
    muted: {self.muted},
    communityId: {self.communityId},
    profile: {self.profile},
    joined: {self.joined},
    canPostReactions: {self.canPostReactions},
    viewersCanPostReactions: {self.viewersCanPostReactions},
    syncedTo: {self.syncedTo},
    syncedFrom: {self.syncedFrom},
    firstMessageTimestamp: {self.firstMessageTimestamp},
    categoryId: {self.categoryId},
    position: {self.position},
    highlight: {self.highlight},
    hideIfPermissionsNotMet: {self.hideIfPermissionsNotMet},
    tokenGated: {self.tokenGated},
    missingEncryptionKey: {self.missingEncryptionKey}
    )"""

proc toCheckPermissionsResultDto*(jsonObj: JsonNode): CheckPermissionsResultDto =
  result = CheckPermissionsResultDto()
  var criteriaObj: JsonNode
  if(jsonObj.getProp("criteria", criteriaObj) and criteriaObj.kind == JArray):
    for c in criteriaObj:
      result.criteria.add(c.getBool)

proc toViewOnlyOrViewAndPostPermissionsResponseDto*(jsonObj: JsonNode): ViewOnlyOrViewAndPostPermissionsResponseDto =
  result = ViewOnlyOrViewAndPostPermissionsResponseDto()
  discard jsonObj.getProp("satisfied", result.satisfied)

  var permissionsObj: JsonNode
  if(jsonObj.getProp("permissions", permissionsObj) and permissionsObj.kind == JObject):
    result.permissions = initTable[string, CheckPermissionsResultDto]()
    for permissionId, permission in permissionsObj:
      result.permissions[permissionId] = permission.toCheckPermissionsResultDto

proc toCheckChannelPermissionsResponseDto*(jsonObj: JsonNode): CheckChannelPermissionsResponseDto =
  result = CheckChannelPermissionsResponseDto()

  var viewOnlyPermissionsObj: JsonNode
  if(jsonObj.getProp("viewOnlyPermissions", viewOnlyPermissionsObj) and viewOnlyPermissionsObj.kind == JObject):
    result.viewOnlyPermissions = viewOnlyPermissionsObj.toViewOnlyOrViewAndPostPermissionsResponseDto()

  var viewAndPostPermissionsObj: JsonNode
  if(jsonObj.getProp("viewAndPostPermissions", viewAndPostPermissionsObj) and viewAndPostPermissionsObj.kind == JObject):
    result.viewAndPostPermissions = viewAndPostPermissionsObj.toViewOnlyOrViewAndPostPermissionsResponseDto()

proc toClearedHistoryDto*(jsonObj: JsonNode): ClearedHistoryDto =
  result = ClearedHistoryDto()
  discard jsonObj.getProp("chatId", result.chatId)
  discard jsonObj.getProp("clearedAt", result.clearedAt)

proc toPermission*(jsonObj: JsonNode): Permission =
  result = Permission()
  discard jsonObj.getProp("access", result.access)
  discard jsonObj.getProp("ens_only", result.ensOnly)

proc toImages*(jsonObj: JsonNode): Images =
  result = Images()

  var largeObj: JsonNode
  if(jsonObj.getProp("large", largeObj)):
    discard largeObj.getProp("uri", result.large)

  var thumbnailObj: JsonNode
  if(jsonObj.getProp("thumbnail", thumbnailObj)):
    discard thumbnailObj.getProp("uri", result.thumbnail)

  var bannerObj: JsonNode
  if(jsonObj.getProp("banner", bannerObj)):
    discard bannerObj.getProp("uri", result.banner)

proc toCategory*(jsonObj: JsonNode): Category =
  result = Category()
  if (not jsonObj.getProp("category_id", result.id)):
    discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("position", result.position)
  discard jsonObj.getProp("collapsed", result.collapsed)

proc toChatMember*(jsonObj: JsonNode, memberId: string): ChatMember =
  # Parse status-go "Member" type
  # Mapping this DTO is not strightforward since only keys are used for id
  result = ChatMember()
  result.id = memberId
  discard jsonObj.getProp("joined", result.joined)
  discard jsonObj.getProp("role", result.role)

proc toGroupChatMember*(jsonObj: JsonNode): ChatMember =
  # parse status-go "ChatMember" type
  result = ChatMember()
  discard jsonObj.getProp("id", result.id)
  let admin = jsonObj["admin"].getBool(false)
  result.role = if admin: MemberRole.Owner else: MemberRole.None
  result.joined = true

proc toChannelMember*(jsonObj: JsonNode, memberId: string): ChatMember =
  # Parse status-go "CommunityMember" type
  # Mapping this DTO is not straightforward since only keys are used for id. We
  # handle it a bit different.
  result = ChatMember()
  result.id = memberId
  var rolesObj: JsonNode
  var roles: seq[int] = @[]
  if(jsonObj.getProp("roles", rolesObj)):
    for roleObj in rolesObj:
      roles.add(roleObj.getInt)

  # People in the community members' list are joined by default
  result.joined = true

  result.role = MemberRole.None
  if roles.contains(MemberRole.Owner.int):
    result.role = MemberRole.Owner
  elif roles.contains(MemberRole.Admin.int):
    result.role = MemberRole.Admin
  elif roles.contains(MemberRole.ManageUsers.int):
    result.role = MemberRole.ManageUsers
  elif roles.contains(MemberRole.ModerateContent.int):
    result.role = MemberRole.ModerateContent
  elif roles.contains(MemberRole.TokenMaster.int):
    result.role = MemberRole.TokenMaster

proc toChatDto*(jsonObj: JsonNode): ChatDto =
  result = ChatDto()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("description", result.description)
  discard jsonObj.getProp("color", result.color)
  discard jsonObj.getProp("emoji", result.emoji)
  discard jsonObj.getProp("active", result.active)
  discard jsonObj.getProp("timestamp", result.timestamp)
  discard jsonObj.getProp("lastClockValue", result.lastClockValue)
  discard jsonObj.getProp("deletedAtClockValue", result.deletedAtClockValue)
  discard jsonObj.getProp("readMessagesAtClockValue", result.readMessagesAtClockValue)
  discard jsonObj.getProp("unviewedMessagesCount", result.unviewedMessagesCount)
  discard jsonObj.getProp("unviewedMentionsCount", result.unviewedMentionsCount)
  discard jsonObj.getProp("alias", result.alias)
  discard jsonObj.getProp("muted", result.muted)
  discard jsonObj.getProp("categoryId", result.categoryId)
  if (result.categoryId == ""):
    # Communities have `categoryID` and chats have `categoryId`
    # This should be fixed in status-go, but would be a breaking change
    discard jsonObj.getProp("categoryID", result.categoryId)
  discard jsonObj.getProp("hideIfPermissionsNotMet", result.hideIfPermissionsNotMet)
  discard jsonObj.getProp("tokenGated", result.tokenGated)
  discard jsonObj.getProp("missingEncryptionKey", result.missingEncryptionKey)
  discard jsonObj.getProp("position", result.position)
  discard jsonObj.getProp("communityId", result.communityId)
  discard jsonObj.getProp("profile", result.profile)
  discard jsonObj.getProp("joined", result.joined)
  discard jsonObj.getProp("syncedTo", result.syncedTo)
  discard jsonObj.getProp("syncedFrom", result.syncedFrom)
  discard jsonObj.getProp("firstMessageTimestamp", result.firstMessageTimestamp)
  discard jsonObj.getProp("highlight", result.highlight)
  var permissionObj: JsonNode
  if(jsonObj.getProp("permissions", permissionObj)):
    result.permissions = toPermission(permissionObj)

  result.chatType = ChatType.Unknown
  var chatTypeInt: int
  if (jsonObj.getProp("chatType", chatTypeInt) and
    (chatTypeInt >= ord(low(ChatType)) or chatTypeInt <= ord(high(ChatType)))):
      result.chatType = ChatType(chatTypeInt)

  # Default those properties to true as they are only provided for community chats
  # To be refactored with https://github.com/status-im/status-app/issues/11694
  result.canPostReactions = true
  result.canPost = true
  result.canView = true
  result.viewersCanPostReactions = true
  discard jsonObj.getProp("canPostReactions", result.canPostReactions)
  discard jsonObj.getProp("canPost", result.canPost)
  discard jsonObj.getProp("canView", result.canView)
  discard jsonObj.getProp("viewersCanPostReactions", result.viewersCanPostReactions)

  var chatImage: string
  discard jsonObj.getProp("image", chatImage)
  if (result.chatType == ChatType.PrivateGroupChat and len(chatImage) > 0):
    result.icon = chatImage

  var membersObj: JsonNode
  if jsonObj.getProp("members", membersObj):
    if membersObj.kind == JArray:
      # during group chat updates
      for memberObj in membersObj:
        result.members.add(toGroupChatMember(memberObj))
    elif membersObj.kind == JObject:
      # on a startup, chat/channel creation
      for memberId, memberObj in membersObj:
        result.members.add(toChatMember(memberObj, memberId))

  # Add community ID if needed
  if result.communityId != "" and not result.id.contains(result.communityId):
    result.id = result.communityId & result.id

  var lastMessageObj: JsonNode
  if jsonObj.getProp("lastMessage", lastMessageObj):
    result.lastMessage = lastMessageObj.toMessageDto()

# To parse Community chats to ChatDto, we need to add the commuity ID and type
proc toChatDto*(jsonObj: JsonNode, communityId: string, communityMembers: seq[ChatMember]): ChatDto =
  result = jsonObj.toChatDto()
  result.chatType = ChatType.CommunityChat
  result.communityId = communityId
  if communityId != "":
    result.id = communityId & result.id.replace(communityId, "") # Adding communityID prefix in case it's not available

  if not result.tokenGated:
    result.members = communityMembers

proc isOneToOneChat*(chatDto: ChatDto): bool =
  return chatDto.chatType == ChatType.OneToOne

proc hasMoreMessagesToRequest*(chatDto: ChatDto, syncedFrom: int64): bool =
  # only for community chat we can determine the first message ever sent to the chat
  if chatDto.chatType != ChatType.CommunityChat:
    return true

  const firstMessageTimestampUndefined = 0
  const firstMessageTimestampNoMessages = 1

  if chatDto.firstMessageTimestamp == firstMessageTimestampUndefined:
    return true
  if chatDto.firstMessageTimestamp == firstMessageTimestampNoMessages:
    return false

  return syncedFrom > chatDto.firstMessageTimestamp

proc hasMoreMessagesToRequest*(chatDto: ChatDto): bool =
  chatDto.hasMoreMessagesToRequest(chatDto.syncedFrom)

proc communityChannelUuid*(self: ChatDto): string =
  if self.communityId == "":
    return ""
  return self.id[self.communityId.len .. ^1]

proc updateMissingFields*(chatToUpdate: var ChatDto, oldChat: ChatDto) =
  # This proc sets fields of `chatToUpdate` which are available only for community channels.
  chatToUpdate.position = oldChat.position
  chatToUpdate.canPostReactions = oldChat.canPostReactions
  chatToUpdate.viewersCanPostReactions = oldChat.viewersCanPostReactions
  chatToUpdate.categoryId = oldChat.categoryId
  chatToUpdate.members = oldChat.members

proc isOneToOne*(c: ChatDto): bool =
  return c.chatType == ChatType.OneToOne

proc isPrivateGroupChat*(c: ChatDto): bool =
  return c.chatType == ChatType.PrivateGroupChat

proc isActivePersonalChat*(c: ChatDto): bool =
  return c.active and (c.isOneToOne() or c.isPrivateGroupChat()) and c.communityId == ""

proc isHiddenChat*(chatDto: ChatDto): bool =
  return chatDto.hideIfPermissionsNotMet and not chatDto.canView
