{.used.}

import json, sequtils, sugar, tables, strutils, json_serialization, strformat

import ../../../../backend/communities
include ../../../common/json_utils
import ../../../common/conversion

import ../../chat/dto/chat
import ../../shared_urls/dto/url_data
import ../../../../app_service/common/types

import backend/collectibles_types

type RequestToJoinType* {.pure.}= enum
  Pending = 1,
  Declined = 2,
  Accepted = 3,
  Canceled = 4,
  AcceptedPending = 5,
  DeclinedPending = 6,
  AwaitingAddress = 7,

type MutedType* {.pure.}= enum
  For15min = 1,
  For1hr = 2,
  For8hr = 3,
  For1week = 4,
  TillUnmuted = 5,
  For1min = 6,
  Unmuted = 7

type
  CommunityMetricsType* {.pure.} = enum
    MessagesTimestamps = 0,
    MessagesCount,
    Members,
    ControlNodeUptime

type
  CommunityMemberPendingBanOrKick* {.pure.} = enum
    Banned = 0,
    BanPending,
    UnbanPending,
    KickPending,
    BannedWithAllMessagesDelete

proc isBanned*(state: CommunityMemberPendingBanOrKick): bool =
  return state == CommunityMemberPendingBanOrKick.Banned or state == CommunityMemberPendingBanOrKick.BannedWithAllMessagesDelete

type RevealedAccount* = object
  address*: string
  chainIds*: seq[int]
  isAirdropAddress*: bool

type MembersRevealedAccounts* = Table[string, seq[RevealedAccount]]

type CommunityMembershipRequestDto* = object
  id*: string
  publicKey*: string
  chatId*: string
  communityId*: string
  state*: int
  our*: string #FIXME: should be bool
  revealedAccounts*: seq[RevealedAccount]

proc `$`*(self: CommunityMembershipRequestDto): string =
  return fmt"""CommunityMembershipRequestDto(
    id:{self.id}, 
    publicKey:{self.publicKey},
    chatId:{self.chatId},
    communityId:{self.communityId},
    state:{self.state},
    our:{self.our},
    revealedAccounts.count:{self.revealedAccounts.len},
    """

type CommunitySettingsDto* = object
  id*: string
  historyArchiveSupportEnabled*: bool
  categoriesMuted*: seq[string]

type CommunityAdminSettingsDto* = object
  pinMessageAllMembersEnabled*: bool

type TokenPermissionType* {.pure.}= enum
  Unknown = 0,
  BecomeAdmin = 1,
  BecomeMember = 2,
  View = 3,
  ViewAndPost = 4,
  BecomeTokenMaster = 5,
  BecomeTokenOwner = 6

type TokenPermissionState* {.pure.}= enum
  Approved = 0,
  AdditionPending = 1,
  UpdatePending = 2,
  RemovalPending = 3,

type TokenCriteriaDto* = object
  contractAddresses* {.serializedFieldName("contract_addresses").}: Table[int, string]
  `type`* {.serializedFieldName("type").}: TokenType
  symbol* {.serializedFieldName("symbol").}: string
  name* {.serializedFieldName("name").}: string
  amount* {.serializedFieldName("amount").}: string
  decimals* {.serializedFieldName("decimals").}: int
  tokenIds* {.serializedFieldName("tokenIds").}: seq[string]
  ensPattern* {.serializedFieldName("ens_pattern").}: string
  amountInWei* {.serializedFieldName("amountInWei").}: string

type CommunityTokenPermissionDto* = object
  id*: string
  `type`*: TokenPermissionType
  tokenCriteria*: seq[TokenCriteriaDto]
  chatIds*: seq[string]
  isPrivate*: bool
  state*: TokenPermissionState

type CommunityTokensMetadataDto* = object
  addresses*: Table[int, string]
  description*: string
  image*: string
  symbol*: string
  name*: string
  tokenType*: TokenType

type AccountChainIDsCombinationDto* = object
  address*: string
  chainIds*: seq[int]

type CheckPermissionsToJoinResponseDto* = object
  satisfied*: bool
  permissions*: Table[string, CheckPermissionsResultDto]
  validCombinations*: seq[AccountChainIDsCombinationDto]

type MetricsIntervalDto* = object
  startTimestamp*: uint64
  endTimestamp*: uint64
  timestamps*: seq[uint64]
  count*: int

type CommunityMetricsDto* = object
  communityId*: string
  metricsType*: CommunityMetricsType
  intervals*: seq[MetricsIntervalDto]

type CommunityDto* = object
  id*: string
  memberRole*: MemberRole
  isControlNode*: bool
  verified*: bool
  joined*: bool
  spectated*: bool
  requestedAccessAt: int64
  name*: string
  description*: string
  introMessage*: string
  outroMessage*: string
  chats*: seq[ChatDto]
  categories*: seq[Category]
  images*: Images
  permissions*: Permission
  members*: seq[ChatMember]
  canRequestAccess*: bool
  canManageUsers*: bool
  canJoin*: bool
  color*: string
  tags*: string
  requestedToJoinAt*: int64
  isMember*: bool
  muted*: bool
  listedInDirectory*: bool
  featuredInDirectory*: bool
  pendingRequestsToJoin*: seq[CommunityMembershipRequestDto]
  declinedRequestsToJoin*: seq[CommunityMembershipRequestDto]
  canceledRequestsToJoin*: seq[CommunityMembershipRequestDto]
  waitingForSharedAddressesRequestsToJoin*: seq[CommunityMembershipRequestDto]
  settings*: CommunitySettingsDto
  adminSettings*: CommunityAdminSettingsDto
  pendingAndBannedMembers*: Table[string, CommunityMemberPendingBanOrKick]
  encrypted*: bool
  tokenPermissions*: Table[string, CommunityTokenPermissionDto]
  communityTokensMetadata*: seq[CommunityTokensMetadataDto]
  channelPermissions*: CheckAllChannelsPermissionsResponseDto
  activeMembersCount*: int64

proc isAvailable*(communityDto: CommunityDto): bool =
  return communityDto.name != "" and communityDto.description != ""

type DiscordCategoryDto* = object
  id*: string
  name*: string

type DiscordChannelDto* = object
  id*: string
  categoryId*: string
  name*: string
  description*: string
  filePath*: string

type DiscordImportErrorCode* {.pure.}= enum
  Unknown = 1,
  Warning = 2,
  Error = 3

type DiscordImportError* = object
  code*: int
  message*: string

type DiscordImportTaskProgress* = object
  `type`*: string
  progress*: float
  errors*: seq[DiscordImportError]
  errorsCount*: int
  warningsCount*: int
  stopped*: bool
  state*: string

proc toCommunityAdminSettingsDto*(jsonObj: JsonNode): CommunityAdminSettingsDto =
  result = CommunityAdminSettingsDto()
  discard jsonObj.getProp("pinMessageAllMembersEnabled", result.pinMessageAllMembersEnabled)

proc toDiscordCategoryDto*(jsonObj: JsonNode): DiscordCategoryDto =
  result = DiscordCategoryDto()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("name", result.name)

proc toDiscordChannelDto*(jsonObj: JsonNode): DiscordChannelDto =
  result = DiscordChannelDto()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("categoryId", result.categoryId)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("topic", result.description)
  discard jsonObj.getProp("filePath", result.filePath)

proc toDiscordImportError*(jsonObj: JsonNode): DiscordImportError =
  result = DiscordImportError()
  discard jsonObj.getProp("code", result.code)
  discard jsonObj.getProp("message", result.message)

proc toCommunityTokenAdresses*(jsonObj: JsonNode): Table[int, string] =
  for i in jsonObj.keys():
    result[parseInt(i)] = jsonObj[i].getStr().toLower()

proc toCommunityTokensMetadataDto*(jsonObj: JsonNode): CommunityTokensMetadataDto =
  result = CommunityTokensMetadataDto()
  discard jsonObj.getProp("description", result.description)
  discard jsonObj.getProp("image", result.image)
  discard jsonObj.getProp("symbol", result.symbol)
  discard jsonObj.getProp("name", result.name)
  var tokenTypeInt: int
  discard jsonObj.getProp("tokenType", tokenTypeInt)
  result.tokenType = intToEnum(tokenTypeInt, TokenType.ERC721)
  var addressesObj: JsonNode
  discard jsonObj.getProp("contract_addresses", addressesObj)
  result.addresses = toCommunityTokenAdresses(addressesObj)

proc toDiscordImportTaskProgress*(jsonObj: JsonNode): DiscordImportTaskProgress =
  result = DiscordImportTaskProgress()
  result.`type` = jsonObj{"type"}.getStr()
  result.progress = jsonObj{"progress"}.getFloat()
  result.stopped = jsonObj{"stopped"}.getBool()
  result.errorsCount = jsonObj{"errorsCount"}.getInt()
  result.warningsCount = jsonObj{"warningsCount"}.getInt()
  result.state = jsonObj{"state"}.getStr()

  var importErrorsObj: JsonNode
  if(jsonObj.getProp("errors", importErrorsObj) and importErrorsObj.kind == JArray):
    for error in importErrorsObj:
      let importError = error.toDiscordImportError()
      result.errors.add(importError)

proc toTokenCriteriaDto*(jsonObj: JsonNode): TokenCriteriaDto =
  result = TokenCriteriaDto()
  discard jsonObj.getProp("amount", result.amount)
  discard jsonObj.getProp("amountInWei", result.amountInWei)
  discard jsonObj.getProp("decimals", result.decimals)
  discard jsonObj.getProp("symbol", result.symbol)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("ens_pattern", result.ensPattern)

  var typeInt: int
  discard jsonObj.getProp("type", typeInt)
  if (typeInt >= ord(low(TokenType)) and typeInt <= ord(high(TokenType))):
      result.`type` = TokenType(typeInt)

  var contractAddressesObj: JsonNode
  if(jsonObj.getProp("contract_addresses", contractAddressesObj) and contractAddressesObj.kind == JObject):
    result.contractAddresses = initTable[int, string]()
    for chainId, contractAddress in contractAddressesObj:
      result.contractAddresses[parseInt(chainId)] = contractAddress.getStr().toLower()

  var tokenIdsObj: JsonNode
  if(jsonObj.getProp("tokenIds", tokenIdsObj) and tokenIdsObj.kind == JArray):
    for tokenId in tokenIdsObj:
      result.tokenIds.add(tokenId.getStr)

  # When `toTokenCriteriaDto` is called with data coming from
  # the front-end, there's a key field we have to account for
  if jsonObj.hasKey("key"):
    if result.`type` == TokenType.ENS:
      discard jsonObj.getProp("key", result.ensPattern)
    else:
      var tmpSymbol = ""
      discard jsonObj.getProp("key", tmpSymbol)
      if not isContractID(tmpSymbol):
        # overwrite only if key does not contain contractID
        result.symbol = tmpSymbol

proc toCommunityTokenPermissionDto*(jsonObj: JsonNode): CommunityTokenPermissionDto =
  result = CommunityTokenPermissionDto()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("is_private", result.isPrivate)
  var tokenPermissionTypeInt: int
  discard jsonObj.getProp("type", tokenPermissionTypeInt)
  if (tokenPermissionTypeInt >= ord(low(TokenPermissionType)) and tokenPermissionTypeInt <= ord(high(TokenPermissionType))):
      result.`type` = TokenPermissionType(tokenPermissionTypeInt)

  var tokenPermissionStateInt: int
  discard jsonObj.getProp("state", tokenPermissionStateInt)
  if (tokenPermissionStateInt >= ord(low(TokenPermissionState)) and tokenPermissionStateInt <= ord(high(TokenPermissionState))):
      result.state = TokenPermissionState(tokenPermissionStateInt)

  var tokenCriteriaObj: JsonNode
  if(jsonObj.getProp("token_criteria", tokenCriteriaObj)):
    for tokenCriteria in tokenCriteriaObj:
      result.tokenCriteria.add(tokenCriteria.toTokenCriteriaDto)

  var chatIdsObj: JsonNode
  if(jsonObj.getProp("chat_ids", chatIdsObj) and chatIdsObj.kind == JArray):
    for chatId in chatIdsObj:
      result.chatIds.add(chatId.getStr)

  # When `toTokenPermissionDto` is called with data coming from
  # the front-end, there's a key field we have to account for
  if jsonObj.hasKey("key"):
    discard jsonObj.getProp("key", result.id)

proc toAccountChainIDsCombinationDto*(jsonObj: JsonNode): AccountChainIDsCombinationDto =
  result = AccountChainIDsCombinationDto()
  discard jsonObj.getProp("address", result.address)
  var chainIdsObj: JsonNode
  if(jsonObj.getProp("chainIds", chainIdsObj) and chainIdsObj.kind == JArray):
    for chainId in chainIdsObj:
      result.chainIds.add(chainId.getInt)

proc toCheckPermissionsToJoinResponseDto*(jsonObj: JsonNode): CheckPermissionsToJoinResponseDto =
  result = CheckPermissionsToJoinResponseDto()
  discard jsonObj.getProp("satisfied", result.satisfied)

  var validCombinationsObj: JsonNode
  if(jsonObj.getProp("validCombinations", validCombinationsObj) and validCombinationsObj.kind == JArray):
    for validCombination in validCombinationsObj:
      result.validCombinations.add(validCombination.toAccountChainIDsCombinationDto)

  var permissionsObj: JsonNode
  if(jsonObj.getProp("permissions", permissionsObj) and permissionsObj.kind == JObject):
    result.permissions = initTable[string, CheckPermissionsResultDto]()
    for permissionId, permission in permissionsObj:
      result.permissions[permissionId] = permission.toCheckPermissionsResultDto

proc toCheckAllChannelsPermissionsResponseDto*(jsonObj: JsonNode): CheckAllChannelsPermissionsResponseDto =
  result = CheckAllChannelsPermissionsResponseDto()
  result.channels = initTable[string, CheckChannelPermissionsResponseDto]()

  var channelsObj: JsonNode
  if(jsonObj.getProp("channels", channelsObj) and channelsObj.kind == JObject):
    for channelId, permissionResponse in channelsObj:
      result.channels[channelId] = permissionResponse.toCheckChannelPermissionsResponseDto()

proc toMetricsIntervalDto*(jsonObj: JsonNode): MetricsIntervalDto =
  result = MetricsIntervalDto()
  discard jsonObj.getProp("startTimestamp", result.startTimestamp)
  discard jsonObj.getProp("endTimestamp", result.endTimestamp)

  var timestampsObj: JsonNode
  if (jsonObj.getProp("timestamps", timestampsObj) and timestampsObj.kind == JArray):
    for timestamp in timestampsObj:
      result.timestamps.add(uint64(timestamp.getInt))

  discard jsonObj.getProp("count", result.count)

proc toCommunityMetricsDto*(jsonObj: JsonNode): CommunityMetricsDto =
  result = CommunityMetricsDto()

  discard jsonObj.getProp("communityId", result.communityId)

  result.metricsType = CommunityMetricsType.MessagesTimestamps
  var metricsTypeInt: int
  if (jsonObj.getProp("type", metricsTypeInt) and (metricsTypeInt >= ord(low(CommunityMetricsType)) and
      metricsTypeInt <= ord(high(CommunityMetricsType)))):
    result.metricsType = CommunityMetricsType(metricsTypeInt)

  var intervalsObj: JsonNode
  if (jsonObj.getProp("intervals", intervalsObj) and intervalsObj.kind == JArray):
    for interval in intervalsObj:
      result.intervals.add(interval.toMetricsIntervalDto)

proc toRevealedAccount*(revealedAccountObj: JsonNode): RevealedAccount =
  var chainIdsObj: JsonNode
  var chainIds: seq[int] = @[]
  if revealedAccountObj.getProp("chain_ids", chainIdsObj):
    for chainIdObj in chainIdsObj:
      chainIds.add(chainIdObj.getInt)

  result = RevealedAccount(
    address: revealedAccountObj["address"].getStr,
    chainIds: chainIds,
    isAirdropAddress: revealedAccountObj{"isAirdropAddress"}.getBool,
  )

proc toRevealedAccounts*(revealedAccountsObj: JsonNode): seq[RevealedAccount] =
  result = @[]
  for revealedAccountObj in revealedAccountsObj:
    result.add(revealedAccountObj.toRevealedAccount())

proc toCommunityMembershipRequestDto*(jsonObj: JsonNode): CommunityMembershipRequestDto =
  result = CommunityMembershipRequestDto()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("publicKey", result.publicKey)
  discard jsonObj.getProp("chatId", result.chatId)
  discard jsonObj.getProp("state", result.state)
  discard jsonObj.getProp("communityId", result.communityId)
  discard jsonObj.getProp("our", result.our)

  var revealedAccountObj: JsonNode
  if(jsonObj.getProp("revealedAccounts", revealedAccountObj)):
    result.revealedAccounts = toRevealedAccounts(revealedAccountObj)

proc toCollapsedCategoryDto*(jsonObj: JsonNode, isCollapsed: bool = false): Category =
  result = Category()
  discard jsonObj.getProp("categoryId", result.id)
  # The CollapsedCommunityCategories API only returns **collapsed** categories.
  # So if a category is **not** collapsed, it's not in the list
  # The collapsed property on the json is always false
  result.collapsed = true

proc toCommunityDto*(jsonObj: JsonNode): CommunityDto =
  result = CommunityDto()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("memberRole", result.memberRole)
  discard jsonObj.getProp("isControlNode", result.isControlNode)
  discard jsonObj.getProp("verified", result.verified)
  discard jsonObj.getProp("joined", result.joined)
  discard jsonObj.getProp("spectated", result.spectated)
  discard jsonObj.getProp("requestedAccessAt", result.requestedAccessAt)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("description", result.description)
  discard jsonObj.getProp("introMessage", result.introMessage)
  discard jsonObj.getProp("outroMessage", result.outroMessage)
  discard jsonObj.getProp("encrypted", result.encrypted)
  discard jsonObj.getProp("isMember", result.isMember)

  var categoriesObj: JsonNode
  if(jsonObj.getProp("categories", categoriesObj)):
    for _, categoryObj in categoriesObj:
      result.categories.add(toCategory(categoryObj))

  var imagesObj: JsonNode
  if(jsonObj.getProp("images", imagesObj)):
    result.images = toImages(imagesObj)

  var permissionObj: JsonNode
  if(jsonObj.getProp("permissions", permissionObj)):
    result.permissions = toPermission(permissionObj)

  var tokenPermissionsObj: JsonNode
  if(jsonObj.getProp("tokenPermissions", tokenPermissionsObj) and tokenPermissionsObj.kind == JObject):
    result.tokenPermissions = initTable[string, CommunityTokenPermissionDto]()
    for tokenPermissionId, tokenPermission in tokenPermissionsObj:
      result.tokenPermissions[tokenPermissionId] = toCommunityTokenPermissionDto(tokenPermission)

  var adminSettingsObj: JsonNode
  if(jsonObj.getProp("adminSettings", adminSettingsObj)):
    result.adminSettings = toCommunityAdminSettingsDto(adminSettingsObj)

  var membersObj: JsonNode
  if(jsonObj.getProp("members", membersObj) and membersObj.kind == JObject):
    for memberId, memberObj in membersObj:
      result.members.add(toChannelMember(memberObj, memberId))

  var chatsObj: JsonNode
  if(jsonObj.getProp("chats", chatsObj)):
    for _, chatObj in chatsObj:
      result.chats.add(chatObj.toChatDto(result.id, result.members))

  var tagsObj: JsonNode
  if(jsonObj.getProp("tags", tagsObj)):
    toUgly(result.tags, tagsObj)
  else:
    result.tags = "[]"

  var pendingAndBannedMembersObj: JsonNode
  if (jsonObj.getProp("pendingAndBannedMembers", pendingAndBannedMembersObj) and pendingAndBannedMembersObj.kind == JObject):
    result.pendingAndBannedMembers = initTable[string, CommunityMemberPendingBanOrKick]()
    for memberId, pendingKickOrBanMember in pendingAndBannedMembersObj:
      result.pendingAndBannedMembers[memberId] = CommunityMemberPendingBanOrKick(pendingKickOrBanMember.getInt())

  discard jsonObj.getProp("canRequestAccess", result.canRequestAccess)
  discard jsonObj.getProp("canManageUsers", result.canManageUsers)
  discard jsonObj.getProp("canJoin", result.canJoin)
  discard jsonObj.getProp("color", result.color)

  discard jsonObj.getProp("requestedToJoinAt", result.requestedToJoinAt)
  discard jsonObj.getProp("muted", result.muted)
  discard jsonObj.getProp("activeMembersCount", result.activeMembersCount)

  var communityTokensMetadataObj: JsonNode
  if(jsonObj.getProp("communityTokensMetadata", communityTokensMetadataObj) and communityTokensMetadataObj.kind == JArray):
    for tokenObj in communityTokensMetadataObj:
      result.communityTokensMetadata.add(tokenObj.toCommunityTokensMetadataDto())

proc toMembershipRequestState*(state: CommunityMemberPendingBanOrKick): MembershipRequestState =
  case state:
    of CommunityMemberPendingBanOrKick.Banned:
      return MembershipRequestState.Banned
    of CommunityMemberPendingBanOrKick.BanPending:
      return MembershipRequestState.BannedPending
    of CommunityMemberPendingBanOrKick.UnbanPending:
      return MembershipRequestState.UnbannedPending
    of CommunityMemberPendingBanOrKick.KickPending:
      return MembershipRequestState.KickedPending
    of CommunityMemberPendingBanOrKick.BannedWithAllMessagesDelete:
      return MembershipRequestState.BannedWithAllMessagesDelete
    else:
      return MembershipRequestState.None

proc toCommunitySettingsDto*(jsonObj: JsonNode): CommunitySettingsDto =
  result = CommunitySettingsDto()
  discard jsonObj.getProp("communityId", result.id)
  discard jsonObj.getProp("historyArchiveSupportEnabled", result.historyArchiveSupportEnabled)

proc parseCommunities*(response: JsonNode, categories: seq[Category]): seq[CommunityDto] =
  var categoryCollapsedMap = initTable[string, bool]()
  for category in categories:
    categoryCollapsedMap[category.id] = true

  for communityNode in response["result"].getElems():
    var community = communityNode.toCommunityDto()

    for category in community.categories.mitems:
      if categoryCollapsedMap.hasKey(category.id):
        category.collapsed = true
    result.add(community)

proc parseKnownCuratedCommunities(jsonCommunities: JsonNode): seq[CommunityDto] =
  for _, communityJson in jsonCommunities.pairs():
    var community = communityJson.toCommunityDto()
    community.listedInDirectory = true
    result.add(community)

proc parseUnknownCuratedCommunities(jsonCommunities: JsonNode): seq[CommunityDto] =
  for communityId in jsonCommunities.items():
    var community = CommunityDto()
    community.id = communityId.getStr
    community.listedInDirectory = true
    result.add(community)

proc parseCuratedCommunities*(response: JsonNode): seq[CommunityDto] =
  if (response["communities"].kind == JObject):
    result = parseKnownCuratedCommunities(response["communities"])
  if (response["unknownCommunities"].kind == JArray):
    result = concat(result, parseUnknownCuratedCommunities(response["unknownCommunities"]))
  if (response["contractFeaturedCommunities"].kind == JArray):
    let featuredCommunityIDs = response["contractFeaturedCommunities"].to(seq[string])
    for i in 0..<result.len:
      let communityID = result[i].id
      result[i].featuredInDirectory = any(featuredCommunityIDs, id => id == communityID)

proc contains(arrayToSearch: seq[int], searched: int): bool =
  for element in arrayToSearch:
    if element == searched:
      return true
  return false

proc getBannedMembersIds*(self: CommunityDto): seq[string] =
  var bannedIds: seq[string] = @[]
  for memberId, state in self.pendingAndBannedMembers:
    if isBanned(state):
      bannedIds.add(memberId)
  return bannedIds

proc parseCommunitiesSettings*(response: JsonNode): seq[CommunitySettingsDto] =
  result = map(response["result"].getElems(),
    proc(x: JsonNode): CommunitySettingsDto = x.toCommunitySettingsDto())

proc parseDiscordCategories*(response: RpcResponse[JsonNode]): seq[DiscordCategoryDto] =
  if (response.result["discordCategories"].kind == JArray):
    for category in response.result["discordCategories"].items():
      result.add(category.toDiscordCategoryDto())

proc parseDiscordCategories*(response: JsonNode): seq[DiscordCategoryDto] =
  if (response["discordCategories"].kind == JArray):
    for category in response["discordCategories"].items():
      result.add(category.toDiscordCategoryDto())

proc parseDiscordChannels*(response: RpcResponse[JsonNode]): seq[DiscordChannelDto] =
  if (response.result["discordChannels"].kind == JArray):
    for channel in response.result["discordChannels"].items():
      result.add(channel.toDiscordChannelDto())

proc parseDiscordChannels*(response: JsonNode): seq[DiscordChannelDto] =
  if (response["discordChannels"].kind == JArray):
    for channel in response["discordChannels"].items():
      result.add(channel.toDiscordChannelDto())

proc toMembersRevealedAccounts*(membersRevealedAccountsObj: JsonNode): MembersRevealedAccounts =
  result = initTable[string, seq[RevealedAccount]]()
  for (pubkey, revealedAccountsObj) in membersRevealedAccountsObj.pairs:
    result[pubkey] = revealedAccountsObj.toRevealedAccounts()

proc getCommunityChats*(self: CommunityDto, chatIds: seq[string]): seq[ChatDto] =
  var chats: seq[ChatDto] = @[]
  for chatId in chatIds:
    for communityChat in self.chats:
      if chatId == communityChat.id:
        chats.add(communityChat)
        break
  return chats

proc getCommunityChat*(self: CommunityDto, chatId: string): ChatDto =
  let chats = self.getCommunityChats(@[chatId])
  if chats.len > 0:
    return chats[0]

proc getCommunityChatIndex*(self: CommunityDto, chatId: string): int =
  var idx = 0
  for communityChat in self.chats:
    if chatId == communityChat.id:
      return idx
    idx.inc()
  return -1

proc hasCommunityChat*(self: CommunityDto, chatId: string): bool =
  for communityChat in self.chats:
    if chatId == communityChat.id:
      return true
  return false

proc isOwner*(self: CommunityDto): bool =
  return self.memberRole == MemberRole.Owner

proc isTokenMaster*(self: CommunityDto): bool =
  return self.memberRole == MemberRole.TokenMaster

proc isAdmin*(self: CommunityDto): bool =
  return self.memberRole == MemberRole.Admin

proc isPrivilegedUser*(self: CommunityDto): bool =
  return self.isControlNode or self.isOwner or self.isTokenMaster or self.isAdmin

proc getOwnerTokenAddressFromPermissions*(self: CommunityDto): (int, string) =
  for _, tokenPermission in self.tokenPermissions.pairs:
    if tokenPermission.`type` == TokenPermissionType.BecomeTokenOwner:
      if len(tokenPermission.tokenCriteria) == 0:
        return (0, "")
      let addresses = tokenPermission.tokenCriteria[0].contractAddresses
      # should be one address
      for ch, add in addresses.pairs:
        return (ch, add)
  return (0, "")

proc findOwner*(self: CommunityDto): ChatMember =
  for member in self.members:
    if member.role == MemberRole.Owner:
      return member
  raise newException(ValueError, "No owner found in members list")

proc getContractIdFromFirstAddress*(self: CommunityTokensMetadataDto): string =
  for chainID, address in self.addresses:
    let contractId = ContractID(chainID: chainID, address: address)
    return contractId.toString()
  return ""