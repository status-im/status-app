import std/[unittest, json, tables, sequtils]

import app_service/common/[pubkey_codec, types]
import app_service/service/community/dto/roster
import app_service/service/community/roster_sync

const
  keyA = "0x0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"
  keyB = "0x04c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee51ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a"
  communityId = "0x02aaaa"

proc raw(hex: string): RawPubKey =
  doAssert parseRawPubKey(hex, result)

proc delta(clock: uint64, added: seq[string] = @[], removed: seq[string] = @[]): RosterDelta =
  result = RosterDelta(communityId: communityId, clock: clock)
  for k in added:
    result.added.add RosterMember(key: raw(k))
  for k in removed:
    result.removed.add raw(k)

proc clocks(deltas: seq[RosterDelta]): seq[uint64] =
  deltas.mapIt(it.clock)

suite "roster wire parsing":
  test "snapshot":
    let node = %*{
      "clock": 42,
      "members": [
        {"pubKey": keyA, "roles": [1], "displayName": "alice", "ensName": "alice.eth",
         "ensVerified": true, "colorId": 3, "thumbnailImageClock": 1712345678},
        {"pubKey": keyB, "roles": [], "alias": "Adorable Brave Cat", "colorId": 7},
        {"pubKey": "0xbad", "roles": []},
      ],
      "channels": {"chat1": {keyA: 1, keyB: 0}},
    }
    let snapshot = parseRosterSnapshot(node)
    check snapshot.clock == 42
    check snapshot.members.len == 2
    check snapshot.members[0].key == raw(keyA)
    check snapshot.members[0].role == MemberRole.Owner
    check snapshot.members[0].displayName == "alice"
    check snapshot.members[0].ensName == "alice.eth"
    check snapshot.members[0].ensVerified
    check snapshot.members[0].colorId == 3
    check snapshot.members[0].thumbnailImageClock == 1712345678'u64
    check snapshot.members[1].alias == "Adorable Brave Cat"
    check snapshot.members[1].role == MemberRole.None
    check snapshot.channels.len == 1
    let chat1 = snapshot.channels["chat1"]
    check chat1.len == 2
    for m in chat1:
      if m.key == raw(keyA):
        check m.role == ChannelRole.Viewer
      else:
        check m.role == ChannelRole.Poster

  test "the highest role wins":
    check toMemberRole(@[MemberRole.TokenMaster.int, MemberRole.Admin.int]) == MemberRole.Admin
    check toMemberRole(@[MemberRole.Admin.int, MemberRole.Owner.int]) == MemberRole.Owner
    check toMemberRole(newSeq[int]()) == MemberRole.None

  test "community changes delta":
    let node = %*{
      "community": {"id": communityId},
      "communityId": communityId,
      "clock": 43,
      "membersAdded": {keyB: {"roles": [4]}},
      "rosterAdded": {keyB: {"pubKey": keyB, "roles": [4], "alias": "Cat", "colorId": 7}},
      "rosterRemoved": {keyA: {"pubKey": keyA, "roles": []}},
      "rosterModified": {},
      "chatsModified": {
        "chat1": {"ChatModified": nil, "MembersAdded": {keyB: {"channel_role": 1}},
                  "MembersRemoved": {keyA: {}}, "MembersModified": nil,
                  "CategoryModified": "", "PositionModified": 0},
        "chat2": {"ChatModified": nil, "MembersAdded": {}, "MembersRemoved": {},
                  "CategoryModified": "cat", "PositionModified": 1},
      },
    }
    var d: RosterDelta
    check parseRosterDelta(node, d)
    check d.communityId == communityId
    check d.clock == 43
    check d.added.len == 1
    check d.added[0].key == raw(keyB)
    check d.added[0].role == MemberRole.Admin
    check d.added[0].alias == "Cat"
    check d.removed == @[raw(keyA)]
    check d.modified.len == 0
    # chat2 carries no member change
    check d.channels.len == 1
    check d.channels[0].chatId == "chat1"
    check d.channels[0].added == @[ChannelMember(key: raw(keyB), role: ChannelRole.Viewer)]
    check d.channels[0].removed == @[raw(keyA)]

  test "a change without a community id is not a roster delta":
    var d: RosterDelta
    check not parseRosterDelta(%*{"clock": 1, "rosterAdded": {}}, d)

  test "a change without roster keys yields an empty delta":
    var d: RosterDelta
    check parseRosterDelta(%*{"communityId": communityId, "clock": 5}, d)
    check d.isEmpty

  test "message signal community changes":
    let event = %*[
      {"communityId": communityId, "clock": 2, "rosterAdded": {keyA: {"pubKey": keyA, "roles": []}}},
      {"communityId": communityId, "clock": 3},
      {"clock": 4},
    ]
    let deltas = parseRosterDeltas(event)
    check deltas.clocks == @[2'u64]

suite "roster sync":
  test "deltas are ignored while there is no roster":
    var sync: RosterSync
    check sync.acceptDeltas(@[delta(5, added = @[keyA])]).len == 0
    check sync.state == RosterSyncState.Empty

  test "deltas during a load are held and applied above the snapshot clock":
    var sync: RosterSync
    check sync.beginLoad(1)
    check sync.state == RosterSyncState.Loading
    check sync.acceptDeltas(@[delta(12, added = @[keyB]), delta(10, added = @[keyA])]).len == 0
    check sync.acceptDeltas(@[delta(11, removed = @[keyA])]).len == 0
    var held: seq[RosterDelta]
    check sync.acceptSnapshot(1, 10, held)
    check sync.state == RosterSyncState.Loaded
    check held.clocks == @[11'u64, 12]

  test "a second load request while loading or loaded starts nothing":
    var sync: RosterSync
    check sync.beginLoad(1)
    check not sync.beginLoad(2)
    var held: seq[RosterDelta]
    check sync.acceptSnapshot(1, 1, held)
    check not sync.beginLoad(3)

  test "deltas after the load are applied in clock order":
    var sync: RosterSync
    var held: seq[RosterDelta]
    check sync.beginLoad(1)
    check sync.acceptSnapshot(1, 10, held)
    check sync.acceptDeltas(@[delta(14), delta(12), delta(13)]).clocks == @[12'u64, 13, 14]

  test "deltas at or below the snapshot clock or older than the last applied are dropped":
    var sync: RosterSync
    var held: seq[RosterDelta]
    check sync.beginLoad(1)
    check sync.acceptSnapshot(1, 10, held)
    check sync.acceptDeltas(@[delta(10), delta(9)]).len == 0
    check sync.acceptDeltas(@[delta(15)]).clocks == @[15'u64]
    check sync.acceptDeltas(@[delta(14)]).len == 0
    # an event and a description update can share a clock
    check sync.acceptDeltas(@[delta(15)]).clocks == @[15'u64]

  test "release drops the roster, its held deltas and the in-flight load":
    var sync: RosterSync
    check sync.beginLoad(1)
    discard sync.acceptDeltas(@[delta(20)])
    sync.release()
    check sync.state == RosterSyncState.Empty
    var held: seq[RosterDelta]
    check not sync.acceptSnapshot(1, 10, held)
    check sync.state == RosterSyncState.Empty
    check sync.acceptDeltas(@[delta(30)]).len == 0

  test "a stale load result is rejected after a reload":
    var sync: RosterSync
    var held: seq[RosterDelta]
    check sync.beginLoad(1)
    sync.release()
    check sync.beginLoad(2)
    check not sync.acceptSnapshot(1, 10, held)
    check sync.state == RosterSyncState.Loading
    check sync.acceptSnapshot(2, 10, held)

  test "a failed load leaves no roster":
    var sync: RosterSync
    check sync.beginLoad(1)
    discard sync.acceptDeltas(@[delta(20)])
    sync.failLoad(1)
    check sync.state == RosterSyncState.Empty
    check sync.beginLoad(2)
    var held: seq[RosterDelta]
    check sync.acceptSnapshot(2, 10, held)
    check held.len == 0
