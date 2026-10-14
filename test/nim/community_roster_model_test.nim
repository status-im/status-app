import std/[unittest, tables, json]

import nimqml

import app/modules/shared_models/community_roster_model
import app/modules/shared/qt_model_spy
import app_service/common/types
import app_service/service/community/dto/roster

const
  keyA = "0x0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"
  keyB = "0x04c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee51ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a"
  keyC = "0x04f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9388f7b0f632de8140fe337e62a37f3566500a99934c2231b6cb9fd7584b8e672"
  compressedA = "zQ3shVc2UkAfJCdc1TR8E66J85h48P43r93q8jGPkPpjF9Ef9"

proc raw(hex: string): RawPubKey =
  doAssert parseRawPubKey(hex, result)

proc member(hex: string, displayName = "", alias = "", role = MemberRole.None): RosterMember =
  RosterMember(key: raw(hex), displayName: displayName, alias: alias, role: role, colorId: 4)

type FakeSources = ref object
  contacts: Table[string, RosterContact]
  statuses: Table[string, OnlineStatus]
  contactLookups: int
  mediaPort: int

proc lookups(fake: FakeSources, myPubKey = keyC): RosterLookups =
  RosterLookups(
    myPubKey: myPubKey,
    contact: proc(pubKey: string): RosterContact =
      inc fake.contactLookups
      fake.contacts.getOrDefault(pubKey),
    onlineStatus: proc(pubKey: string): OnlineStatus =
      fake.statuses.getOrDefault(pubKey, OnlineStatus.Inactive),
    contactImageUrl: proc(pubKey: string, clock: uint64): string =
      if fake.mediaPort == 0 or clock == 0: "" else: "img:" & $fake.mediaPort & ":" & pubKey & ":" & $clock,
  )

proc roleOf(model: CommunityRosterModel, name: string): int =
  for role, roleName in model.roleNames().pairs:
    if roleName == name:
      return role
  doAssert false, "no role " & name

proc value(model: CommunityRosterModel, row: int, name: string): QVariant =
  model.data(model.createIndex(row, 0, nil), model.roleOf(name))

proc str(model: CommunityRosterModel, row: int, name: string): string =
  model.value(row, name).stringVal

proc rowOfKey(model: CommunityRosterModel, hex: string): int =
  for row in 0 ..< model.rowCount():
    if model.str(row, "pubKey") == hex:
      return row
  -1

proc num(model: CommunityRosterModel, row: int, name: string): int =
  model.value(row, name).intVal

proc flag(model: CommunityRosterModel, row: int, name: string): bool =
  model.value(row, name).boolVal

proc snapshot(clock: uint64, members: varargs[RosterMember]): RosterSnapshot =
  result.clock = clock
  for m in members:
    result.members.add m

suite "community roster model":
  setup:
    let spy = newQtModelSpy()
    spy.enable()
    let fake = FakeSources()
    let model = newCommunityRosterModel(fake.lookups())

  teardown:
    spy.disable()

  test "the snapshot goes in with a single insert":
    var snap = snapshot(10, member(keyA, "alice"), member(keyB, alias = "Brave Cat"), member(keyC, "me"))
    snap.channels["gated"] = @[ChannelMember(key: raw(keyA), role: ChannelRole.Viewer)]
    model.fill(snap)
    check model.rowCount() == 3
    check model.getCount() == 3
    check model.isLoaded()
    check spy.countInserts() == 1
    check spy.getInserts()[0].first == 0
    check spy.getInserts()[0].last == 2
    check spy.countResets() == 0
    check model.hasMember(keyB)
    check not model.hasMember("0x04ff")
    check model.isGatedChannel("gated")
    check model.channelMembers("gated") == @[keyA]

  test "roles read the entry, the contacts cache and the online status table":
    fake.contacts[keyA] = RosterContact(isContact: true, localNickname: "Ali",
      icon: "https://localhost:1/contactImages?publicKey=a", trustStatus: TrustStatus.Trusted,
      contactRequest: ContactRequest.Mutual)
    fake.statuses[keyA] = OnlineStatus.Online
    model.fill(snapshot(10, member(keyA, "alice", role = MemberRole.Admin), member(keyB, alias = "Brave Cat"),
      member(keyC, "me")))
    check model.str(0, "pubKey") == keyA
    check model.str(0, "compressedPubKey") == compressedA
    check model.str(0, "displayName") == "alice"
    check model.str(0, "localNickname") == "Ali"
    check model.str(0, "preferredDisplayName") == "Ali"
    check not model.flag(0, "usesDefaultName")
    check model.str(0, "icon") == "https://localhost:1/contactImages?publicKey=a"
    check model.num(0, "colorId") == 4
    check model.num(0, "onlineStatus") == OnlineStatus.Online.int
    check model.flag(0, "isContact")
    check model.flag(0, "isVerified")
    check not model.flag(0, "isUntrustworthy")
    check model.num(0, "trustStatus") == TrustStatus.Trusted.int
    check model.num(0, "contactRequest") == ContactRequest.Mutual.int
    check model.num(0, "memberRole") == MemberRole.Admin.int
    check model.flag(0, "joined")
    check model.num(0, "membershipRequestState") == MembershipRequestState.Accepted.int
    check not model.flag(0, "isCurrentUser")

    check model.str(1, "alias") == "Brave Cat"
    check model.str(1, "preferredDisplayName") == "Brave Cat"
    check model.flag(1, "usesDefaultName")
    check not model.flag(1, "isContact")
    check model.num(1, "onlineStatus") == OnlineStatus.Inactive.int

    check model.flag(2, "isCurrentUser")

  test "an unverified ENS name is not preferred":
    var m = member(keyA, "alice")
    m.ensName = "alice.eth"
    model.fill(snapshot(1, m))
    check model.str(0, "preferredDisplayName") == "alice"
    m.ensVerified = true
    model.applyDelta(RosterDelta(clock: 2, modified: @[m]))
    check model.str(0, "preferredDisplayName") == "alice.eth"

  test "emojiHash is not a list role":
    for _, name in model.roleNames().pairs:
      check name != "emojiHash"

  test "each delta is one insert, remove or dataChanged":
    model.fill(snapshot(10, member(keyA, "alice"), member(keyB, "bob")))
    spy.clear()

    model.applyDelta(RosterDelta(clock: 11, added: @[member(keyC, "carol")]))
    check spy.countInserts() == 1
    check spy.getInserts()[0].first == 2
    check model.rowCount() == 3
    spy.clear()

    model.applyDelta(RosterDelta(clock: 12, modified: @[member(keyB, "bobby", role = MemberRole.TokenMaster)]))
    check spy.countDataChanged() == 1
    check spy.countInserts() == 0
    check model.str(1, "displayName") == "bobby"
    check model.num(1, "memberRole") == MemberRole.TokenMaster.int
    spy.clear()

    model.applyDelta(RosterDelta(clock: 13, removed: @[raw(keyA)]))
    check spy.countRemoves() == 1
    check model.rowCount() == 2
    check not model.hasMember(keyA)
    # rows after the removed one keep resolving
    check model.str(0, "pubKey") == keyB
    check model.str(1, "pubKey") == keyC
    check spy.countResets() == 0

  test "an added member already in the roster is updated in place":
    model.fill(snapshot(10, member(keyA, "alice")))
    spy.clear()
    model.applyDelta(RosterDelta(clock: 11, added: @[member(keyA, "alicia")]))
    check spy.countInserts() == 0
    check spy.countDataChanged() == 1
    check model.str(0, "displayName") == "alicia"

  test "removing an unknown member signals nothing":
    model.fill(snapshot(10, member(keyA, "alice")))
    spy.clear()
    model.applyDelta(RosterDelta(clock: 11, removed: @[raw(keyB)]))
    check spy.calls.len == 0

  test "gated-channel member sets follow channel deltas":
    var snap = snapshot(10, member(keyA), member(keyB))
    snap.channels["gated"] = @[ChannelMember(key: raw(keyA), role: ChannelRole.Poster)]
    model.fill(snap)
    var changed: seq[string]
    model.onChannelMembersChanged(proc(chatId: string) = changed.add chatId)
    spy.clear()
    model.applyDelta(RosterDelta(clock: 11, channels: @[
      ChannelMembersDelta(chatId: "gated", added: @[ChannelMember(key: raw(keyB), role: ChannelRole.Viewer)],
        removed: @[raw(keyA)])]))
    check model.channelMembers("gated") == @[keyB]
    check model.channelRole("gated", keyB) == ChannelRole.Viewer
    check changed == @["gated"]
    check spy.calls.len == 0
    # every member leaving a gated channel keeps it gated, with nobody in it
    model.applyDelta(RosterDelta(clock: 12, channels: @[ChannelMembersDelta(chatId: "gated", removed: @[raw(keyB)])]))
    check model.isGatedChannel("gated")
    check model.channelMembers("gated").len == 0
    check parseJson(model.getChannelMemberKeys("gated")) == %*[]

  test "a member delta on a channel the snapshot did not gate leaves it ungated":
    # status-go adds joiners and promoted members to every unpermissioned channel too
    var snap = snapshot(10, member(keyA), member(keyB))
    snap.channels["gated"] = @[ChannelMember(key: raw(keyA))]
    model.fill(snap)
    var changed: seq[string]
    model.onChannelMembersChanged(proc(chatId: string) = changed.add chatId)
    model.applyDelta(RosterDelta(clock: 11, channels: @[
      ChannelMembersDelta(chatId: "general", added: @[ChannelMember(key: raw(keyB))])]))
    check not model.isGatedChannel("general")
    check model.channelMembers("general").len == 0
    check changed.len == 0

  test "a reloaded snapshot gates and ungates channels and keeps the rows":
    var snap = snapshot(10, member(keyA, "alice"), member(keyB, "bob"))
    snap.channels["gated"] = @[ChannelMember(key: raw(keyA))]
    model.fill(snap)
    model.setMembershipState(keyB, MembershipRequestState.BannedPending)
    var changed: seq[string]
    model.onChannelMembersChanged(proc(chatId: string) = changed.add chatId)
    spy.clear()
    # the permission moved from "gated" to "general"; alice left, carol joined
    var reloaded = snapshot(20, member(keyB, "bobby"), member(keyC, "carol"))
    reloaded.channels["general"] = @[ChannelMember(key: raw(keyB), role: ChannelRole.Viewer)]
    model.fill(reloaded)
    check spy.countResets() == 0
    # only alice's row goes and only carol's comes
    check spy.countRemoves() == 1
    check spy.getRemoves()[0].first == 0
    check spy.getRemoves()[0].last == 0
    check spy.countInserts() == 1
    check spy.getInserts()[0].first == spy.getInserts()[0].last
    check model.isLoaded()
    check model.rowCount() == 2
    check not model.hasMember(keyA)
    check model.str(model.rowOfKey(keyB), "displayName") == "bobby"
    check model.num(model.rowOfKey(keyB), "membershipRequestState") == MembershipRequestState.BannedPending.int
    check model.hasMember(keyC)
    check not model.isGatedChannel("gated")
    check model.isGatedChannel("general")
    check model.channelMembers("general") == @[keyB]
    check "gated" in changed
    check "general" in changed

  test "contact and online status changes refresh only that row":
    model.fill(snapshot(10, member(keyA, "alice"), member(keyB, "bob")))
    spy.clear()
    fake.contacts[keyB] = RosterContact(localNickname: "B")
    model.contactChanged(keyB)
    check spy.countDataChanged() == 1
    check spy.calls[0].topLeft == 1
    check model.str(1, "preferredDisplayName") == "B"
    spy.clear()
    model.contactChanged("0x04unknown")
    check spy.calls.len == 0
    model.onlineStatusChanged(keyA)
    check spy.countDataChanged() == 1
    check spy.calls[0].topLeft == 0

  test "avatars come from the media server unless the contacts cache has one":
    fake.mediaPort = 4000
    var a = member(keyA, "alice")
    a.thumbnailImageClock = 9
    var b = member(keyB, "bob")
    b.thumbnailImageClock = 5
    model.fill(snapshot(10, a, b, member(keyC, "no image")))
    fake.contacts[keyB] = RosterContact(icon: "cached-b")
    check model.str(0, "icon") == "img:4000:" & keyA & ":9"
    check model.str(1, "icon") == "cached-b"
    check model.str(2, "icon") == ""

  test "a media server restart refreshes every icon with one dataChanged":
    model.fill(snapshot(10, member(keyA), member(keyB)))
    spy.clear()
    model.iconsChanged()
    check spy.countDataChanged() == 1
    check spy.calls[0].topLeft == 0
    check spy.calls[0].bottomRight == 1
    spy.clear()
    model.clear()
    spy.clear()
    model.iconsChanged()
    check spy.calls.len == 0

  test "admin overlays: membership state and airdrop address":
    model.fill(snapshot(10, member(keyA, "alice")))
    spy.clear()
    model.setMembershipState(keyA, MembershipRequestState.BannedPending)
    model.setAirdropAddress(keyA, "0xabc")
    check spy.countDataChanged() == 2
    check model.num(0, "membershipRequestState") == MembershipRequestState.BannedPending.int
    check model.str(0, "airdropAddress") == "0xabc"

  test "release drops every row without a reset":
    var snap = snapshot(10, member(keyA), member(keyB))
    snap.channels["gated"] = @[ChannelMember(key: raw(keyA))]
    model.fill(snap)
    spy.clear()
    model.clear()
    check model.rowCount() == 0
    check not model.isLoaded()
    check not model.isGatedChannel("gated")
    check spy.countRemoves() == 1
    check spy.countResets() == 0
    # clearing an empty roster signals nothing
    spy.clear()
    model.clear()
    check spy.calls.len == 0
