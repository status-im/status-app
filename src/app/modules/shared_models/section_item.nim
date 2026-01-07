import std/strformat, stint
import ./member_model, ./member_item
import ../main/communities/tokens/models/token_model as community_tokens_model
import ../main/communities/tokens/models/token_item

import ../../../app_service/common/types
import ../../../app_service/service/community_tokens/community_collectible_owner

type
  # has to match Constants.appSection
  SectionType* {.pure.} = enum
    HomePage = 0,
    Wallet,
    Chat,
    Community,
    ProfileSettings,
    NodeManagement,
    CommunitiesPortal,
    LoadingSection,
    Swap,
    Market,
    Browser
    ActivityCenter

type
  SectionItem* = object
    sectionType: SectionType
    id: string
    name: string
    memberRole: MemberRole
    isControlNode: bool
    description: string
    introMessage: string
    outroMessage: string
    image: string
    bannerImageData: string
    icon: string
    color: string
    tags: string
    hasNotification: bool
    notificationsCount: int
    active: bool
    enabled: bool
    isMember: bool
    isBanned: bool
    joined: bool
    canJoin: bool
    spectated: bool
    canManageUsers: bool
    canRequestAccess: bool
    access: int
    ensOnly: bool
    muted: bool
    membersModel: member_model.Model
    joinedMembersCount: int # This is a separate property because the membersModel may not be loaded yet
    historyArchiveSupportEnabled: bool
    pinMessageAllMembersEnabled: bool
    encrypted: bool
    communityTokensModel: community_tokens_model.TokenModel
    isPendingOwnershipRequest: bool
    activeMembersCount: int
    membersLoaded: bool
    tokensLoading: bool

proc initSectionItem*(
    id: string,
    sectionType: SectionType,
    name: string,
    memberRole = MemberRole.None,
    isControlNode = false,
    description = "",
    introMessage = "",
    outroMessage = "",
    image = "",
    bannerImageData = "",
    icon = "",
    color = "",
    tags = "",
    hasNotification = false,
    notificationsCount: int = 0,
    active = false,
    enabled = true,
    joined = false,
    canJoin = false,
    spectated = false,
    canManageUsers = false,
    canRequestAccess = false,
    isMember = false,
    isBanned = false,
    access: int = 0,
    ensOnly = false,
    muted = false,
    members: seq[MemberItem] = @[],
    joinedMembersCount: int = 0,
    historyArchiveSupportEnabled = false,
    pinMessageAllMembersEnabled = false,
    encrypted: bool = false,
    communityTokens: seq[TokenItem] = @[],
    isPendingOwnershipRequest: bool = false,
    activeMembersCount: int = 0,
    ): SectionItem =
  result.id = id
  result.sectionType = sectionType
  result.name = name
  result.memberRole = memberRole
  result.isControlNode = isControlNode
  result.description = description
  result.introMessage = introMessage
  result.outroMessage = outroMessage
  result.image = image
  result.bannerImageData = bannerImageData
  result.icon = icon
  result.color = color
  result.tags = tags
  result.hasNotification = hasNotification
  result.notificationsCount = notificationsCount
  result.active = active
  result.enabled = enabled
  result.joined = joined
  result.canJoin = canJoin
  result.spectated = spectated
  result.canManageUsers = canManageUsers
  result.canRequestAccess = canRequestAccess
  result.isMember = isMember
  result.isBanned = isBanned
  result.access = access
  result.ensOnly = ensOnly
  result.muted = muted
  result.membersModel = newModel()
  result.membersModel.setItems(members)
  result.joinedMembersCount = joinedMembersCount
  result.historyArchiveSupportEnabled = historyArchiveSupportEnabled
  result.pinMessageAllMembersEnabled = pinMessageAllMembersEnabled
  result.encrypted = encrypted
  result.communityTokensModel = newTokenModel()
  result.communityTokensModel.setItems(communityTokens)
  result.isPendingOwnershipRequest = isPendingOwnershipRequest
  result.activeMembersCount = activeMembersCount
  result.membersLoaded = false
  result.tokensLoading = false

proc isEmpty*(self: SectionItem): bool =
  return self.id.len == 0

proc `$`*(self: SectionItem): string =
  result = fmt"""SectionItem(
    id: {self.id},
    sectionType: {self.sectionType.int},
    name: {self.name},
    memberRole: {self.memberRole},
    isControlNode: {self.isControlNode},
    description: {self.description},
    introMessage: {self.introMessage},
    outroMessage: {self.outroMessage},
    image: {self.image},
    bannerImageData: {self.bannerImageData},
    icon: {self.icon},
    color: {self.color},
    tags: {self.tags},
    hasNotification: {self.hasNotification},
    notificationsCount:{self.notificationsCount},
    active:{self.active},
    enabled:{self.enabled},
    joined:{self.joined},
    canJoin:{self.canJoin},
    spectated:{self.spectated},
    canManageUsers:{self.canManageUsers},
    canRequestAccess:{self.canRequestAccess},
    isMember:{self.isMember},
    isBanned:{self.isBanned},
    access:{self.access},
    ensOnly:{self.ensOnly},
    muted:{self.muted},
    membersLoaded:{self.membersLoaded},
    tokensLoading:{self.tokensLoading},
    members:{self.membersModel},
    joinedMembersCount:{self.joinedMembersCount},
    historyArchiveSupportEnabled:{self.historyArchiveSupportEnabled},
    pinMessageAllMembersEnabled:{self.pinMessageAllMembersEnabled},
    encrypted:{self.encrypted},
    communityTokensModel:{self.communityTokensModel},
    isPendingOwnershipRequest:{self.isPendingOwnershipRequest}
    ]"""

proc id*(self: SectionItem): string {.inline.} =
  self.id

proc sectionType*(self: SectionItem): SectionType {.inline.} =
  self.sectionType

proc name*(self: SectionItem): string {.inline.} =
  self.name

proc `name=`*(self: var SectionItem, value: string) {.inline.} =
  self.name = value

proc memberRole*(self: SectionItem): MemberRole {.inline.} =
  self.memberRole

proc `memberRole=`*(self: var SectionItem, value: MemberRole) {.inline.} =
  self.memberRole = value

proc isControlNode*(self: SectionItem): bool {.inline.} =
  self.isControlNode

proc `isControlNode=`*(self: var SectionItem, value: bool) {.inline.} =
  self.isControlNode = value

proc description*(self: SectionItem): string {.inline.} =
  self.description

proc `description=`*(self: var SectionItem, value: string) {.inline.} =
  self.description = value

proc introMessage*(self: SectionItem): string {.inline.} =
  self.introMessage

proc `introMessage=`*(self: var SectionItem, value: string) {.inline.} =
  self.introMessage = value

proc outroMessage*(self: SectionItem): string {.inline.} =
  self.outroMessage

proc `outroMessage=`*(self: var SectionItem, value: string) {.inline.} =
  self.outroMessage = value

proc image*(self: SectionItem): string {.inline.} =
  self.image

proc `image=`*(self: var SectionItem, value: string) {.inline.} =
  self.image = value

proc bannerImageData*(self: SectionItem): string {.inline.} =
  self.bannerImageData

proc `bannerImageData=`*(self: var SectionItem, value: string) {.inline.} =
  self.bannerImageData = value

proc icon*(self: SectionItem): string {.inline.} =
  self.icon

proc `icon=`*(self: var SectionItem, value: string) {.inline.} =
  self.icon = value

proc color*(self: SectionItem): string {.inline.} =
  self.color

proc `color=`*(self: var SectionItem, value: string) {.inline.} =
  self.color = value

proc tags*(self: SectionItem): string {.inline.} =
  self.tags

proc `tags=`*(self: var SectionItem, value: string) {.inline.} =
  self.tags = value

proc hasNotification*(self: SectionItem): bool {.inline.} =
  self.hasNotification

proc `hasNotification=`*(self: var SectionItem, value: bool) {.inline.} =
  self.hasNotification = value

proc setHasNotification*(self: var SectionItem, value: bool) {.inline.} =
  self.hasNotification = value

proc notificationsCount*(self: SectionItem): int {.inline.} =
  self.notificationsCount

proc setNotificationsCount*(self: var SectionItem, value: int) {.inline.} =
  self.notificationsCount = value

proc `notificationsCount=`*(self: var SectionItem, value: int) {.inline.} =
  self.notificationsCount = value

proc active*(self: SectionItem): bool {.inline.} =
  self.active

proc `active=`*(self: var SectionItem, value: bool) {.inline.} =
  self.active = value

proc enabled*(self: SectionItem): bool {.inline.} =
  self.enabled

proc `enabled=`*(self: var SectionItem, value: bool) {.inline.} =
  self.enabled = value

proc joined*(self: SectionItem): bool {.inline.} =
  self.joined

proc `joined=`*(self: var SectionItem, value: bool) {.inline.} =
  self.joined = value

proc canJoin*(self: SectionItem): bool {.inline.} =
  self.canJoin

proc `canJoin=`*(self: var SectionItem, value: bool) {.inline.} =
  self.canJoin = value

proc spectated*(self: SectionItem): bool {.inline.} =
  self.spectated

proc `spectated=`*(self: var SectionItem, value: bool) {.inline.} =
  self.spectated = value

proc canRequestAccess*(self: SectionItem): bool {.inline.} =
  self.canRequestAccess

proc `canRequestAccess=`*(self: var SectionItem, value: bool) {.inline.} =
  self.canRequestAccess = value

proc canManageUsers*(self: SectionItem): bool {.inline.} =
  self.canManageUsers

proc `canManageUsers=`*(self: var SectionItem, value: bool) {.inline.} =
  self.canManageUsers = value

proc isMember*(self: SectionItem): bool {.inline.} =
  self.isMember

proc `isMember=`*(self: var SectionItem, value: bool) {.inline.} =
  self.isMember = value

proc isBanned*(self: SectionItem): bool {.inline.} =
  self.isBanned

proc `isBanned=`*(self: var SectionItem, value: bool) {.inline.} =
  self.isBanned = value

proc access*(self: SectionItem): int {.inline.} =
  self.access

proc `access=`*(self: var SectionItem, value: int) {.inline.} =
  self.access = value

proc ensOnly*(self: SectionItem): bool {.inline.} =
  self.ensOnly

proc `ensOnly=`*(self: var SectionItem, value: bool) {.inline.} =
  self.ensOnly = value

proc muted*(self: SectionItem): bool {.inline.} =
  self.muted

proc `muted=`*(self: var SectionItem, value: bool) {.inline.} =
  self.muted = value

proc members*(self: SectionItem): member_model.Model {.inline.} =
  self.membersModel

proc joinedMembersCount*(self: SectionItem): int {.inline.} =
  self.joinedMembersCount

proc `joinedMembersCount=`*(self: var SectionItem, value: int) {.inline.} =
  self.joinedMembersCount = value

proc isPendingOwnershipRequest*(self: SectionItem): bool {.inline.} =
  self.isPendingOwnershipRequest

proc `isPendingOwnershipRequest=`*(self: var SectionItem, value: bool) {.inline.} =
  self.isPendingOwnershipRequest = value

proc setIsPendingOwnershipRequest*(self: var SectionItem, isPending: bool) {.inline.} =
  self.isPendingOwnershipRequest = isPending

proc historyArchiveSupportEnabled*(self: SectionItem): bool {.inline.} =
  self.historyArchiveSupportEnabled

proc `historyArchiveSupportEnabled=`*(self: var SectionItem, value: bool) {.inline.} =
  self.historyArchiveSupportEnabled = value

proc pinMessageAllMembersEnabled*(self: SectionItem): bool {.inline.} =
  self.pinMessageAllMembersEnabled

proc `pinMessageAllMembersEnabled=`*(self: var SectionItem, value: bool) {.inline.} =
  self.pinMessageAllMembersEnabled = value

proc encrypted*(self: SectionItem): bool {.inline.} =
  self.encrypted

proc `encrypted=`*(self: var SectionItem, value: bool) {.inline.} =
  self.encrypted = value

proc appendCommunityToken*(self: SectionItem, item: TokenItem) {.inline.} =
  self.communityTokensModel.appendItem(item)

proc removeCommunityToken*(self: SectionItem, chainId: int, contractAddress: string) {.inline.} =
  self.communityTokensModel.removeItemByChainIdAndAddress(chainId, contractAddress)

proc updateCommunityTokenDeployState*(self: SectionItem, chainId: int, contractAddress: string, deployState: DeployState) {.inline.} =
  self.communityTokensModel.updateDeployState(chainId, contractAddress, deployState)

proc updateCommunityTokenAddress*(self: SectionItem, chainId: int, oldContractAddress: string, newContractAddress: string) {.inline.} =
  self.communityTokensModel.updateAddress(chainId, oldContractAddress, newContractAddress)

proc updateCommunityTokenSupply*(self: SectionItem, chainId: int, contractAddress: string, supply: Uint256, destructedAmount: Uint256) {.inline.} =
  self.communityTokensModel.updateSupply(chainId, contractAddress, supply, destructedAmount)

proc updateCommunityRemainingSupply*(self: SectionItem, chainId: int, contractAddress: string, remainingSupply: Uint256) {.inline.} =
  self.communityTokensModel.updateRemainingSupply(chainId, contractAddress, remainingSupply)

proc updateBurnState*(self: SectionItem, chainId: int, contractAddress: string, burnState: ContractTransactionStatus) {.inline.} =
  self.communityTokensModel.updateBurnState(chainId, contractAddress, burnState)

proc updateRemoteDestructedAddresses*(self: SectionItem, chainId: int, contractAddress: string, addresess: seq[string]) {.inline.} =
  self.communityTokensModel.updateRemoteDestructedAddresses(chainId, contractAddress, addresess)

proc setCommunityTokenOwners*(self: SectionItem, chainId: int, contractAddress: string, owners: seq[CommunityCollectibleOwner], isOwner: bool) {.inline.} =
  self.communityTokensModel.setCommunityTokenOwners(chainId, contractAddress, owners, isOwner)

proc setCommunityTokenHoldersLoading*(self: SectionItem, chainId: int, contractAddress: string, value: bool) {.inline.} =
  self.communityTokensModel.setCommunityTokenHoldersLoading(chainId, contractAddress, value)

proc communityTokens*(self: SectionItem): community_tokens_model.TokenModel {.inline.} =
  self.communityTokensModel

proc updatePendingRequestLoadingState*(self: SectionItem, memberKey: string, loading: bool) {.inline.} =
  self.membersModel.updateLoadingState(memberKey, loading)

proc updateMembershipStatus*(self: SectionItem, memberKey: string, state: MembershipRequestState) {.inline.} =
  self.membersModel.updateMembershipStatus(memberKey, state)

proc activeMembersCount*(self: SectionItem): int {.inline.} =
  self.activeMembersCount

proc `activeMembersCount=`*(self: var SectionItem, value: int) {.inline.} =
  self.activeMembersCount = value

proc membersLoaded*(self: SectionItem): bool {.inline.} =
  self.membersLoaded

proc `membersLoaded=`*(self: var SectionItem, value: bool) {.inline.} =
  self.membersLoaded = value

proc tokensLoading*(self: SectionItem): bool {.inline.} =
  self.tokensLoading

proc `tokensLoading=`*(self: var SectionItem, value: bool) {.inline.} =
  self.tokensLoading = value
