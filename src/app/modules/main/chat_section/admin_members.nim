## Admin settings data of one community: requests to join, banned and
## awaiting-address members as items, plus the pending ban/kick states shown on
## roster members. Filled when admin settings open and rebuilt only when that
## data changes, not on every community description.

import std/[tables, sets, algorithm]

import app_service/common/types
import app_service/service/community/dto/community
import app/modules/shared_models/[member_model, member_item]

type
  AdminMemberEntry* = object
    pubKey*: string
    requestId*: string
    state*: MembershipRequestState

  AdminMembership* = object
    entries*: seq[AdminMemberEntry]
    rosterStates*: Table[string, MembershipRequestState]

  AdminMembers* = ref object
    model: member_model.Model
    membership: AdminMembership
    loaded: bool
    # the model was changed directly since the last refresh
    stale: bool

proc toAdminMembership*(community: CommunityDto): AdminMembership =
  var seen: HashSet[string]

  proc add(entries: var seq[AdminMemberEntry], pubKey, requestId: string, state: MembershipRequestState) =
    if not seen.containsOrIncl(pubKey):
      entries.add AdminMemberEntry(pubKey: pubKey, requestId: requestId, state: state)

  # Members kicked after an ownership change, re-joining once they share addresses
  for request in community.waitingForSharedAddressesRequestsToJoin:
    result.entries.add(request.publicKey, "", MembershipRequestState.AwaitingAddress)
  for request in community.pendingRequestsToJoin:
    result.entries.add(request.publicKey, request.id, MembershipRequestState(request.state))
  for request in community.declinedRequestsToJoin:
    result.entries.add(request.publicKey, request.id, MembershipRequestState(request.state))
  # sorted, so the same table compares equal whatever its insertion order
  var banned: seq[AdminMemberEntry]
  for memberId, memberState in community.pendingAndBannedMembers.pairs:
    let state = memberState.toMembershipRequestState()
    case state:
      of MembershipRequestState.Banned, MembershipRequestState.BannedWithAllMessagesDelete,
          MembershipRequestState.UnbannedPending:
        banned.add(memberId, "", state)
      of MembershipRequestState.BannedPending, MembershipRequestState.KickedPending:
        result.rosterStates[memberId] = state
      else:
        discard
  banned.sort(proc(a, b: AdminMemberEntry): int = cmp(a.pubKey, b.pubKey))
  result.entries.add banned

proc newAdminMembers*(model: member_model.Model): AdminMembers =
  AdminMembers(model: model)

proc isLoaded*(self: AdminMembers): bool =
  self.loaded

proc invalidate*(self: AdminMembers) =
  ## The model was changed directly; the next refresh applies even unchanged data.
  self.stale = true

proc refresh*(self: AdminMembers, membership: AdminMembership,
    buildItem: proc(entry: AdminMemberEntry): MemberItem,
    applyRosterStates: proc(states: Table[string, MembershipRequestState])): bool =
  ## Returns whether anything was applied; items are built only then.
  if self.loaded and not self.stale and membership == self.membership:
    return false
  var items = newSeqOfCap[MemberItem](membership.entries.len)
  for entry in membership.entries:
    items.add buildItem(entry)
  if self.loaded:
    self.model.updateToTheseItems(items)
  else:
    self.model.setItems(items)
  if not self.loaded or self.stale or membership.rosterStates != self.membership.rosterStates:
    applyRosterStates(membership.rosterStates)
  self.membership = membership
  self.loaded = true
  self.stale = false
  true

proc release*(self: AdminMembers) =
  ## Admin settings closed: drop the items until they open again.
  if self.loaded:
    self.model.setItems(@[])
  self.membership = AdminMembership()
  self.loaded = false
  self.stale = false
