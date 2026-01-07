import std/strformat
import user_item

import ../../../app_service/common/types

export user_item

type
  MemberItem* = ref object of UserItem
    memberRole: MemberRole
    joined: bool
    requestToJoinId: string
    requestToJoinLoading*: bool
    airdropAddress*: string
    membershipRequestState*: MembershipRequestState

# FIXME: remove defaults
proc initMemberItem*(
  pubKey: string,
  displayName: string,
  usesDefaultName: bool,
  ensName: string,
  isEnsVerified: bool,
  localNickname: string,
  alias: string,
  icon: string,
  colorId: int,
  onlineStatus: OnlineStatus = OnlineStatus.Inactive,
  isCurrentUser: bool = false,
  isContact: bool = false,
  trustStatus: TrustStatus = TrustStatus.Unknown,
  isBlocked: bool = false,
  contactRequest: ContactRequest = ContactRequest.None,
  memberRole: MemberRole = MemberRole.None,
  joined: bool = false,
  requestToJoinId: string = "",
  requestToJoinLoading: bool = false,
  airdropAddress: string = "",
  membershipRequestState: MembershipRequestState = MembershipRequestState.None,
): MemberItem =
  result = MemberItem()
  result.memberRole = memberRole
  result.joined = joined
  result.requestToJoinId = requestToJoinId
  result.requestToJoinLoading = requestToJoinLoading
  result.airdropAddress = airdropAddress
  result.membershipRequestState = membershipRequestState
  result.UserItem.setup(
    pubKey = pubKey,
    displayName = displayName,
    usesDefaultName = usesDefaultName,
    ensName = ensName,
    isEnsVerified = isEnsVerified,
    localNickname = localNickname,
    alias = alias,
    icon = icon,
    colorId = colorId,
    onlineStatus = onlineStatus,
    isContact = isContact,
    isCurrentUser = isCurrentUser,
    isBlocked = isBlocked,
    contactRequest = contactRequest,
    trustStatus = trustStatus,
  )

proc `$`*(self: MemberItem): string =
  result = fmt"""Member Item(
    pubKey: {self.pubkey},
    displayName: {self.displayName},
    usesDefaultName: {self.usesDefaultName},
    ensName: {self.ensName},
    isEnsVerified: {self.isEnsVerified},
    localNickname: {self.localNickname},
    alias: {self.alias},
    airdropAddress: {self.airdropAddress},
    icon: {self.icon},
    colorId: {self.colorId},
    onlineStatus: {$self.onlineStatus.int},
    isContact: {self.isContact},
    trustStatus: {self.trustStatus.int},
    isBlocked: {self.isBlocked},
    contactRequest: {$self.contactRequest.int},
    memberRole: {self.memberRole},
    joined: {self.joined},
    requestToJoinId: {self.requestToJoinId},
    membershipRequestState: {$self.membershipRequestState.int}
    ]"""

proc memberRole*(self: MemberItem): MemberRole {.inline.} =
  self.memberRole

proc `memberRole=`*(self: MemberItem, value: MemberRole) {.inline.} =
  self.memberRole = value

proc joined*(self: MemberItem): bool {.inline.} =
  self.joined

proc `joined=`*(self: MemberItem, value: bool) {.inline.} =
  self.joined = value

proc requestToJoinId*(self: MemberItem): string {.inline.} =
  self.requestToJoinId

proc `requestToJoinId=`*(self: MemberItem, value: string) {.inline.} =
  self.requestToJoinId = value

proc requestToJoinLoading*(self: MemberItem): bool {.inline.} =
  self.requestToJoinLoading

proc airdropAddress*(self: MemberItem): string {.inline.} =
  self.airdropAddress

proc membershipRequestState*(self: MemberItem): MembershipRequestState {.inline.} =
  self.membershipRequestState
