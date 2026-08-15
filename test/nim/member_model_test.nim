import unittest

import app/modules/shared_models/[member_model, member_item]
import app/modules/shared/qt_model_spy
import app_service/common/types

proc createTestMemberItem(pubKey: string): MemberItem =
  return initMemberItem(
      pubKey = pubKey,
      displayName = "",
      ensName = "",
      isEnsVerified = false,
      localNickname = "",
      alias = "",
      icon = "",
      colorId = 0,
      trustStatus = TrustStatus.Unknown,
    )

let memberA = createTestMemberItem("0xa")
let memberB = createTestMemberItem("0xb")
let memberC = createTestMemberItem("0xc")
let memberD = createTestMemberItem("0xd")
let memberE = createTestMemberItem("0xe")

suite "empty member model":
  let model = newModel()

  test "initial size":
    require(model.rowCount() == 0)

suite "updating member items":
  setup:
    let model = newModel()
    model.addItems(@[memberA, memberB, memberC])
    check(model.rowCount() == 3)

  test "update only display name":
    let updatedRoles = model.updateItem(
        pubkey = "0xa",
        displayName = "newName",
        ensName = "",
        isEnsVerified = false,
        localNickname = "",
        alias = "",
        icon = "",
        isContact = false,
        isBlocked = false,
        memberRole = MemberRole.None,
        joined = false,
        trustStatus = TrustStatus.Unknown,
        contactRequest = ContactRequest.None,
        callDataChanged = false,
      )
    # Three updated roles, because preferredDisplayName and UsesDefaultName get updated too
    check(updatedRoles.len() == 3)
    let item = model.getMemberItem("0xa")
    check(item.displayName == "newName")

  test "update two properties not related to name":
    let updatedRoles = model.updateItem(
        pubkey = "0xb",
        displayName = "",
        ensName = "",
        isEnsVerified = false,
        localNickname = "",
        alias = "",
        icon = "icon", # Updated
        isContact = true, # Updated
        isBlocked = false,
        memberRole = MemberRole.None,
        joined = false,
        trustStatus = TrustStatus.Unknown,
        contactRequest = ContactRequest.None,
        callDataChanged = false,
      )
    check(updatedRoles.len() == 2)
    let item = model.getMemberItem("0xb")
    check(item.icon == "icon")
    check(item.isContact == true)

  test "update two items at the same time":
    let memberACopy = memberA
    memberACopy.displayName = "bob"

    let memberBCopy = memberB
    memberBCopy.displayName = "alice"

    model.updateItems(@[memberACopy, memberBCopy])
    let itemA = model.getMemberItem("0xa")
    check(itemA.displayName == "bob")
    model.updateItems(@[memberACopy, memberBCopy])
    let itemB = model.getMemberItem("0xb")
    check(itemB.displayName == "alice")

  test "remove an item using updateToTheseItems":
    model.updateToTheseItems(@[memberA, memberB])
    check(model.rowCount == 2)

  test "add an item using updateToTheseItems":
    model.updateToTheseItems(@[memberA, memberB, memberD])
    check(model.rowCount == 3)

  test "applies an airdrop address received before the member is added":
    model.setAirdropAddress("0xd", "0xairdrop")
    model.updateToTheseItems(@[memberA, memberB, memberC, memberD])
    check(model.getAirdropAddressForMember("0xd") == "0xairdrop")

  test "applies an airdrop address received before the model is populated":
    let emptyModel = newModel()
    emptyModel.setAirdropAddress("0xd", "0xairdrop")
    emptyModel.setItems(@[memberA, memberB, memberC, memberD])
    check(emptyModel.getAirdropAddressForMember("0xd") == "0xairdrop")

  test "add an item and update another using updateToTheseItems":
    let memberACopy = memberA
    memberACopy.displayName = "roger"
    model.updateToTheseItems(@[memberACopy, memberB, memberD, memberE])
    check(model.rowCount == 4)
    let itemA = model.getMemberItem("0xa")
    check(itemA.displayName == "roger")

  test "add an item, remove one and update another using updateToTheseItems":
    let memberACopy = memberA
    memberACopy.displayName = "brandon"
    let memberCCopy = memberC
    memberCCopy.displayName = "kurt"
    let memberDCopy = memberD
    memberDCopy.displayName = "amanda"
    let memberECopy = memberE
    memberECopy.displayName = "gina"

    model.updateToTheseItems(@[memberACopy, memberCCopy, memberDCopy, memberECopy])
    check(model.rowCount == 4)
    let itemA = model.getMemberItem("0xa")
    check(itemA.displayName == "brandon")
    let itemC = model.getMemberItem("0xc")
    check(itemC.displayName == "kurt")
    let itemD = model.getMemberItem("0xd")
    check(itemD.displayName == "amanda")
    let itemE = model.getMemberItem("0xe")
    check(itemE.displayName == "gina")

suite "derived name state":
  setup:
    let model = newModel()
    model.setItems(@[createTestMemberItem("0xa")])

  test "derived at construction with fixed precedence":
    proc named(nickname, ens: string, verified: bool, display, alias: string): MemberItem =
      initMemberItem(
        pubKey = "0xkey", displayName = display, ensName = ens, isEnsVerified = verified,
        localNickname = nickname, alias = alias, icon = "", colorId = 0)

    check(named("nick", "foo.eth", true, "display", "alias").preferredDisplayName == "nick")
    check(named("", "foo.eth", true, "display", "alias").preferredDisplayName == "foo.eth")
    check(named("", "foo.eth", false, "display", "alias").preferredDisplayName == "display")
    check(named("", "", false, "", "alias").preferredDisplayName == "alias")
    # Nameless-last sentinel
    check(named("", "", false, "", "").preferredDisplayName == "zzz")
    # Uses-default-name follows the same effective-ENS rule
    check(named("", "foo.eth", false, "", "alias").usesDefaultName == true)
    check(named("", "foo.eth", true, "", "alias").usesDefaultName == false)

  test "alias updated in the same batch changes preferredDisplayName":
    let updatedRoles = model.updateItem(
        pubkey = "0xa",
        displayName = "",
        ensName = "",
        isEnsVerified = false,
        localNickname = "",
        alias = "generated alias",
        icon = "",
        isContact = false,
        isBlocked = false,
        memberRole = MemberRole.None,
        joined = false,
        trustStatus = TrustStatus.Unknown,
        contactRequest = ContactRequest.None,
        callDataChanged = false,
      )
    # Alias + PreferredDisplayName ("zzz" sentinel -> alias)
    check(updatedRoles.len() == 2)
    let item = model.getMemberItem("0xa")
    check(item.preferredDisplayName == "generated alias")

  test "unverified ENS name is not a name":
    let updatedRoles = model.updateItem(
        pubkey = "0xa",
        displayName = "",
        ensName = "foo.eth",
        isEnsVerified = false,
        localNickname = "",
        alias = "",
        icon = "",
        isContact = false,
        isBlocked = false,
        memberRole = MemberRole.None,
        joined = false,
        trustStatus = TrustStatus.Unknown,
        contactRequest = ContactRequest.None,
        callDataChanged = false,
      )
    # Only EnsName changed; the served name and usesDefaultName must not move
    check(updatedRoles.len() == 1)
    let item = model.getMemberItem("0xa")
    check(item.usesDefaultName == true)
    check(item.preferredDisplayName == "zzz")

  test "verifying the ENS name promotes it to preferredDisplayName":
    discard model.updateItem(
        pubkey = "0xa",
        displayName = "",
        ensName = "foo.eth",
        isEnsVerified = true,
        localNickname = "",
        alias = "",
        icon = "",
        isContact = false,
        isBlocked = false,
        memberRole = MemberRole.None,
        joined = false,
        trustStatus = TrustStatus.Unknown,
        contactRequest = ContactRequest.None,
        callDataChanged = false,
      )
    let item = model.getMemberItem("0xa")
    check(item.preferredDisplayName == "foo.eth")
    check(item.usesDefaultName == false)

suite "pubKeyIndex invariants":
  # Fresh nameless items: the canonical order falls through to the pubKey
  # tie-break, so rows land in pubKey order. (The global memberA..E refs are
  # mutated by earlier suites and would reorder here.)
  setup:
    let mA = createTestMemberItem("0xa")
    let mB = createTestMemberItem("0xb")
    let mC = createTestMemberItem("0xc")
    let mD = createTestMemberItem("0xd")

  test "addItems drops duplicates against existing rows":
    let model = newModel()
    model.addItems(@[mA, mB])
    # mA is already in the model; mC is new
    model.addItems(@[mA, mC])
    check(model.rowCount == 3)
    check(model.findIndexForMember("0xa") == 0)
    check(model.findIndexForMember("0xb") == 1)
    check(model.findIndexForMember("0xc") == 2)

  test "addItems drops duplicates within the same batch":
    let model = newModel()
    model.addItems(@[mA, mA, mB])
    check(model.rowCount == 2)
    check(model.findIndexForMember("0xa") == 0)
    check(model.findIndexForMember("0xb") == 1)

  test "removeItemById shifts pubKeyIndex of later rows":
    let model = newModel()
    model.addItems(@[mA, mB, mC, mD])
    model.removeItemById("0xb")
    check(model.rowCount == 3)
    check(model.findIndexForMember("0xa") == 0)
    check(model.findIndexForMember("0xb") == -1)
    check(model.findIndexForMember("0xc") == 1)
    check(model.findIndexForMember("0xd") == 2)
    # The shifted index must point at the right item
    check(model.getMemberItemByIndex(1).pubKey == "0xc")
    check(model.getMemberItemByIndex(2).pubKey == "0xd")

  test "updateToTheseItems with empty seq clears pubKeyIndex":
    let model = newModel()
    model.addItems(@[mA, mB])
    model.updateToTheseItems(@[])
    check(model.rowCount == 0)
    check(model.findIndexForMember("0xa") == -1)
    check(model.findIndexForMember("0xb") == -1)
    # New inserts after a clear must start at row 0
    model.addItems(@[mC])
    check(model.findIndexForMember("0xc") == 0)

# Canonical member order (see CONTEXT.md): onlineStatus descending, then
# case-folded preferredDisplayName ascending, then pubKey — an invariant of the
# model itself, maintained via granular moves (never resets).
suite "canonical member order":
  proc namedMember(pubKey, name: string, status: OnlineStatus = OnlineStatus.Inactive): MemberItem =
    initMemberItem(
      pubKey = pubKey, displayName = name, ensName = "", isEnsVerified = false,
      localNickname = "", alias = "", icon = "", colorId = 0, onlineStatus = status)

  proc orderedKeys(model: Model): seq[string] =
    for i in 0 ..< model.rowCount():
      result.add(model.getMemberItemByIndex(i).pubKey)

  proc indexConsistent(model: Model): bool =
    result = true
    for i in 0 ..< model.rowCount():
      if model.findIndexForMember(model.getMemberItemByIndex(i).pubKey) != i:
        return false

  test "setItems sorts online-first, then case-folded name":
    let model = newModel()
    model.setItems(@[
      namedMember("0x1", "charlie"),
      namedMember("0x2", "alice", OnlineStatus.Online),
      namedMember("0x3", "Bob"),
      namedMember("0x4", "Delta", OnlineStatus.Online),
    ])
    check(model.orderedKeys == @["0x2", "0x4", "0x3", "0x1"])
    check(model.indexConsistent)

  test "addItems merges into sorted positions":
    let model = newModel()
    model.setItems(@[
      namedMember("0x1", "bob"),
      namedMember("0x2", "olga", OnlineStatus.Online),
    ])
    model.addItems(@[
      namedMember("0x3", "alice"),
      namedMember("0x4", "Zed", OnlineStatus.Online),
      namedMember("0x5", "carol"),
    ])
    check(model.orderedKeys == @["0x2", "0x4", "0x3", "0x1", "0x5"])
    check(model.indexConsistent)

  test "addItem inserts at sorted position":
    let model = newModel()
    model.setItems(@[namedMember("0x1", "alice"), namedMember("0x2", "charlie")])
    model.addItem(namedMember("0x3", "bob"))
    check(model.orderedKeys == @["0x1", "0x3", "0x2"])
    check(model.indexConsistent)

  test "equal names tie-break on pubKey":
    let model = newModel()
    model.setItems(@[namedMember("0x9", "alice"), namedMember("0x2", "alice")])
    check(model.orderedKeys == @["0x2", "0x9"])

  test "rename repositions via a move, not a reset":
    let model = newModel()
    model.setItems(@[
      namedMember("0x1", "alice"),
      namedMember("0x2", "bob"),
      namedMember("0x3", "carol"),
    ])
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()
    model.setName("0x1", "zoe", ensName = "", localNickname = "")
    check(model.orderedKeys == @["0x2", "0x3", "0x1"])
    check(model.indexConsistent)
    check(spy.countResets == 0)
    let moves = spy.getMoves()
    check(moves.len == 1)
    check(moves[0].sourceFirst == 0)
    check(moves[0].sourceLast == 0)
    check(moves[0].destChild == 3)

  test "status flip moves the row into the online group":
    let model = newModel()
    model.setItems(@[
      namedMember("0x1", "alice"),
      namedMember("0x2", "bob"),
      namedMember("0x3", "carol"),
    ])
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()
    model.setOnlineStatus("0x3", OnlineStatus.Online)
    check(model.orderedKeys == @["0x3", "0x1", "0x2"])
    check(model.indexConsistent)
    check(spy.countResets == 0)
    let moves = spy.getMoves()
    check(moves.len == 1)
    check(moves[0].sourceFirst == 2)
    check(moves[0].destChild == 0)

  test "non-key update does not move":
    let model = newModel()
    model.setItems(@[namedMember("0x1", "alice"), namedMember("0x2", "bob")])
    let spy = newQtModelSpy()
    spy.enable()
    defer: spy.disable()
    model.setIcon("0x2", "icon")
    check(spy.countMoves == 0)
    check(model.orderedKeys == @["0x1", "0x2"])

  test "updateItems repositions renamed rows":
    let model = newModel()
    model.setItems(@[
      namedMember("0x1", "alice"),
      namedMember("0x2", "bob"),
      namedMember("0x3", "carol"),
    ])
    let renamed = namedMember("0x1", "walter")
    model.updateItems(@[renamed])
    check(model.orderedKeys == @["0x2", "0x3", "0x1"])
    check(model.indexConsistent)
