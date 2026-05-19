import unittest

import app/modules/shared_models/[member_model, member_item]
import app_service/common/types

proc createTestMemberItem(pubKey: string): MemberItem =
  return initMemberItem(
      pubKey = pubKey,
      displayName = "",
      usesDefaultName = true,
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

suite "pubKeyIndex invariants":
  test "addItems drops duplicates against existing rows":
    let model = newModel()
    model.addItems(@[memberA, memberB])
    # memberA is already in the model; memberC is new
    model.addItems(@[memberA, memberC])
    check(model.rowCount == 3)
    check(model.findIndexForMember("0xa") == 0)
    check(model.findIndexForMember("0xb") == 1)
    check(model.findIndexForMember("0xc") == 2)

  test "addItems drops duplicates within the same batch":
    let model = newModel()
    model.addItems(@[memberA, memberA, memberB])
    check(model.rowCount == 2)
    check(model.findIndexForMember("0xa") == 0)
    check(model.findIndexForMember("0xb") == 1)

  test "removeItemById shifts pubKeyIndex of later rows":
    let model = newModel()
    model.addItems(@[memberA, memberB, memberC, memberD])
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
    model.addItems(@[memberA, memberB])
    model.updateToTheseItems(@[])
    check(model.rowCount == 0)
    check(model.findIndexForMember("0xa") == -1)
    check(model.findIndexForMember("0xb") == -1)
    # New inserts after a clear must start at row 0
    model.addItems(@[memberC])
    check(model.findIndexForMember("0xc") == 0)
