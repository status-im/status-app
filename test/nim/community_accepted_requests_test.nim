import std/unittest

import app_service/service/community/dto/[community, roster]

const
  communityId = "0x02b5bdaf5a25fcfe2ee14c501fab1836b8de57f61621080c3d52073d16de0d98d6"
  keyA = "0x0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"
  keyB = "0x04c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee51ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a"
  keyC = "0x04f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9388f7b0f632de8140fe337e62a37f3566500a99934c2231b6cb9fd7584b8e672"

proc member(hex: string): RosterMember =
  doAssert parseRawPubKey(hex, result.key)

proc pending(pubKey, id: string): CommunityMembershipRequestDto =
  CommunityMembershipRequestDto(id: id, publicKey: pubKey, communityId: communityId,
    state: RequestToJoinType.Pending.int)

suite "requests accepted by roster changes":
  setup:
    var community = CommunityDto(id: communityId)
    community.pendingRequestsToJoin = @[pending(keyA, "0x01"), pending(keyB, "0x02")]

  test "a requester who joins the roster is taken out of the pending requests":
    check community.takeJoinedRequests([member(keyB)]) == @[keyB]
    check community.pendingRequestsToJoin.len == 1
    check community.pendingRequestsToJoin[0].publicKey == keyA

  test "members who never asked leave the requests alone":
    check community.takeJoinedRequests([member(keyC)]).len == 0
    check community.pendingRequestsToJoin.len == 2

  test "every joined requester is taken, in request order":
    check community.takeJoinedRequests([member(keyB), member(keyA)]) == @[keyA, keyB]
    check community.pendingRequestsToJoin.len == 0

  test "no additions, nothing taken":
    check community.takeJoinedRequests([]).len == 0
    check community.pendingRequestsToJoin.len == 2
