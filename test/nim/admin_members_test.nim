import std/[unittest, tables]

import app/modules/main/chat_section/admin_members
import app/modules/shared_models/[member_model, member_item]
import app/modules/shared/qt_model_spy
import app_service/common/types
import app_service/service/community/dto/community

const
  communityId = "0x02b5bdaf5a25fcfe2ee14c501fab1836b8de57f61621080c3d52073d16de0d98d6"
  keyA = "0x0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"
  keyB = "0x04c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee51ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a"
  keyC = "0x04f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9388f7b0f632de8140fe337e62a37f3566500a99934c2231b6cb9fd7584b8e672"
  keyD = "0x04e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd1351ed993ea0d455b75642e2098ea51448d967ae33bfbdfe40cfe97bdc47739922"

proc request(pubKey, id: string, state: RequestToJoinType): CommunityMembershipRequestDto =
  CommunityMembershipRequestDto(id: id, publicKey: pubKey, communityId: communityId, state: state.int)

proc community(): CommunityDto =
  result.id = communityId
  result.pendingRequestsToJoin = @[request(keyA, "0x01", RequestToJoinType.Pending)]
  result.declinedRequestsToJoin = @[request(keyB, "0x02", RequestToJoinType.Declined)]
  result.pendingAndBannedMembers[keyC] = CommunityMemberPendingBanOrKick.Banned
  result.pendingAndBannedMembers[keyD] = CommunityMemberPendingBanOrKick.KickPending

suite "admin membership":
  test "requests and bans become items, pending bans and kicks roster states":
    let membership = toAdminMembership(community())
    check membership.entries.len == 3
    check membership.entries[0] == AdminMemberEntry(pubKey: keyA, requestId: "0x01",
      state: MembershipRequestState.Pending)
    check membership.entries[1] == AdminMemberEntry(pubKey: keyB, requestId: "0x02",
      state: MembershipRequestState.Declined)
    check membership.entries[2] == AdminMemberEntry(pubKey: keyC, state: MembershipRequestState.Banned)
    check membership.rosterStates == {keyD: MembershipRequestState.KickedPending}.toTable

  test "the same data is the same membership, whatever unrelated fields change":
    var edited = community()
    edited.name = "renamed"
    edited.membersCount = 5000
    check toAdminMembership(edited) == toAdminMembership(community())

type Recorder = ref object
  built: seq[string]
  rosterStates: seq[Table[string, MembershipRequestState]]

proc builder(rec: Recorder): proc(entry: AdminMemberEntry): MemberItem =
  result = proc(entry: AdminMemberEntry): MemberItem =
    rec.built.add entry.pubKey
    initMemberItem(pubKey = entry.pubKey, displayName = "", ensName = "", isEnsVerified = false,
      localNickname = "", alias = "", icon = "", colorId = 0, trustStatus = TrustStatus.Unknown,
      membershipRequestState = entry.state, requestToJoinId = entry.requestId)

proc stateSink(rec: Recorder): proc(states: Table[string, MembershipRequestState]) =
  result = proc(states: Table[string, MembershipRequestState]) =
    rec.rosterStates.add states

suite "admin members":
  setup:
    let spy = newQtModelSpy()
    spy.enable()
    let model = member_model.newModel()
    let admin = newAdminMembers(model)
    let rec = Recorder()
    let buildItem = rec.builder()
    let applyRosterStates = rec.stateSink()

  teardown:
    spy.disable()

  test "the first refresh fills the model":
    check not admin.isLoaded()
    check admin.refresh(toAdminMembership(community()), buildItem, applyRosterStates)
    check admin.isLoaded()
    check model.rowCount() == 3
    check rec.built == @[keyA, keyB, keyC]
    check rec.rosterStates.len == 1

  test "a community edit that leaves the admin data alone is a no-op":
    discard admin.refresh(toAdminMembership(community()), buildItem, applyRosterStates)
    rec.built = @[]
    spy.clear()
    var edited = community()
    edited.description = "new description"
    check not admin.refresh(toAdminMembership(edited), buildItem, applyRosterStates)
    check rec.built.len == 0
    check rec.rosterStates.len == 1
    check spy.calls.len == 0

  test "a new request to join refreshes the model":
    discard admin.refresh(toAdminMembership(community()), buildItem, applyRosterStates)
    rec.built = @[]
    var edited = community()
    edited.pendingRequestsToJoin.add request(keyD, "0x04", RequestToJoinType.Pending)
    edited.pendingAndBannedMembers.del(keyD)
    check admin.refresh(toAdminMembership(edited), buildItem, applyRosterStates)
    check model.rowCount() == 4
    check model.hasMember(keyD)
    check rec.rosterStates.len == 2
    check rec.rosterStates[1].len == 0

  test "a direct model change makes the next refresh apply":
    let membership = toAdminMembership(community())
    discard admin.refresh(membership, buildItem, applyRosterStates)
    model.removeItemById(keyA)
    admin.invalidate()
    rec.built = @[]
    check admin.refresh(membership, buildItem, applyRosterStates)
    check model.hasMember(keyA)

  test "release empties the model until the next refresh":
    discard admin.refresh(toAdminMembership(community()), buildItem, applyRosterStates)
    admin.release()
    check not admin.isLoaded()
    check model.rowCount() == 0
    rec.built = @[]
    check admin.refresh(toAdminMembership(community()), buildItem, applyRosterStates)
    check rec.built.len == 3
    check model.rowCount() == 3
