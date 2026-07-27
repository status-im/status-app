## Structural + value tests for CollectiblesSelectorModel (the terminal picker
## model + its flat companion + nested subitems submodels). Compile -d:QT_MODEL_SPY.
##
## Acceptance gate: the FIRST source push is a reset (bulk load); after that a
## single ownership-balance tick on a shown collectible propagates as O(1) work
## (a nested subitems dataChanged + the flat row's dataChanged) with NO reset,
## NO parent group dataChanged, and NO insert/remove; an account switch over
## overlapping row sets is granular inserts/removes (NO reset) and preserves the
## surviving groups' nested submodel identity.
##
## The QtModelSpy records signals from ALL QT_MODEL_SPY models in-process (grouped
## + flat + every nested subitems model), so the counts below are whole-graph.

import unittest

import app/modules/shared_models/collectibles_selector_model
import app/modules/shared/qt_model_spy

proc dataChangedRows(spy: QtModelSpy): int =
  for c in spy.calls:
    if c.kind == DataChanged:
      result += (c.bottomRight - c.topLeft + 1)

proc own(account: string, balance = 1): CollectibleOwnership =
  CollectibleOwnership(accountAddress: account, balance: balance)

proc item(key: string, chainId = 1, collectionUid = "c0", collectionName = "Coll 0",
    communityId = "", communityName = "", communityImage = "", privileges = 2,
    imageUrl = "", mediaUrl = "", tokenType = 2,
    ownership: seq[CollectibleOwnership] = @[]): CollectibleItem =
  CollectibleItem(
    key: key, chainId: chainId, collectionUid: collectionUid,
    collectionName: collectionName, name: key, tokenType: tokenType,
    communityId: communityId, communityName: communityName,
    communityImage: communityImage, communityPrivilegesLevel: privileges,
    imageUrl: imageUrl, mediaUrl: mediaUrl, ownership: ownership)

let networks = @[
  CollectiblesNetworkInfo(chainId: 1, chainName: "Mainnet", iconUrl: "net/eth"),
  CollectiblesNetworkInfo(chainId: 10, chainName: "Optimism", iconUrl: "net/op"),
]

proc params(account = "0xA", chains: seq[int] = @[],
    filterOwnerMaster = false): CollectiblesSelectorParams =
  CollectiblesSelectorParams(accountKey: account, enabledChainIds: chains,
    filterCommunityOwnerAndMasterTokens: filterOwnerMaster)

suite "CollectiblesSelectorModel - grouping + views":

  setup:
    let spy = newQtModelSpy()
    spy.enable()
  teardown:
    spy.disable()

  test "community groups first (as community type), then collection groups":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    m.setSource(@[
      item("g1", collectionUid = "collX", communityId = "com1",
        communityName = "Comm One", communityImage = "cimg", ownership = @[own("0xA")]),
      item("g2", collectionUid = "collY", communityId = "com1",
        communityName = "Comm One", ownership = @[own("0xA")]),
      item("o1", collectionUid = "collZ", collectionName = "Zed",
        imageUrl = "z.png", ownership = @[own("0xA")]),
    ], networks)
    check m.groupKeysInOrder() == @["com1", "collZ"]
    check m.groupTypeAt(0) == "community"
    check m.groupTypeAt(1) == "other"
    check m.groupNameAt(0) == "Comm One"
    # nested subitems: community group -> collections (collX, collY)
    let cm = m.subitemsModelForKey("com1")
    check cm != nil
    check cm.keysInOrder() == @["collX", "collY"]
    # other group -> the collectible
    check m.subitemsModelForKey("collZ").keysInOrder() == @["o1"]

  test "flat companion holds account+chain filtered rows with summed balance":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    m.setSource(@[
      item("owned", ownership = @[own("0xA", 2), own("0xB", 9)]),
      item("notmine", ownership = @[own("0xB", 1)]),
    ], networks)
    let fm = m.flatModelForTest()
    check fm.keysInOrder() == @["owned"]
    check fm.balanceForKey("owned") == 2

  test "grouped model exposes representative imageUrl/mediaUrl for the shared panel thumbnail":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    m.setSource(@[
      # community group: top-level thumbnail is the representative collectible's
      # raw media (SearchableCollectiblesPanel reads imageUrl||mediaUrl), NOT the
      # community image (which is exposed separately as `icon`).
      item("g1", collectionUid = "collX", communityId = "com1",
        communityName = "Comm One", communityImage = "cimg",
        imageUrl = "g1.png", mediaUrl = "g1.mp4", ownership = @[own("0xA")]),
      item("o1", collectionUid = "collZ", imageUrl = "", mediaUrl = "o1.mp4",
        ownership = @[own("0xA")]),
    ], networks)
    let roles = m.groupRoleNamesForTest()
    check "imageUrl" in roles
    check "mediaUrl" in roles
    check m.groupImageUrlAt(0) == "g1.png"   # community group -> rep collectible image
    check m.groupMediaUrlAt(0) == "g1.mp4"
    check m.groupImageUrlAt(1) == ""         # other group falls back to mediaUrl in QML
    check m.groupMediaUrlAt(1) == "o1.mp4"

  test "flat model exposes uid + tokenType roles the send modal reads":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    m.setSource(@[
      item("erc721", tokenType = 2, ownership = @[own("0xA", 1)]),
      item("erc1155", tokenType = 3, ownership = @[own("0xA", 5)]),
    ], networks)
    let fm = m.flatModelForTest()
    let roles = fm.roleNamesForTest()
    check "uid" in roles      # SimpleSendModal.qml:367 item.uid
    check "tokenType" in roles # SimpleSendModal.qml:514 getByKey(..., "tokenType")
    check fm.tokenTypeForKey("erc721") == 2
    check fm.tokenTypeForKey("erc1155") == 3

  test "zero-balance + chain + owner/master filters flow through the model":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA", chains = @[1], filterOwnerMaster = true))
    m.setSource(@[
      item("keep", chainId = 1, ownership = @[own("0xA", 1)]),
      item("otherchain", chainId = 10, ownership = @[own("0xA", 1)]),
      item("zero", chainId = 1, ownership = @[own("0xA", 0)]),
      item("owner", chainId = 1, communityId = "com1", privileges = 0, ownership = @[own("0xA", 1)]),
    ], networks)
    check m.flatModelForTest().keysInOrder() == @["keep"]

suite "CollectiblesSelectorModel - granular updates":

  setup:
    let spy = newQtModelSpy()
    spy.enable()
  teardown:
    spy.disable()

  test "first source push bulk-loads via reset; then stable set does not reset":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    m.setSource(@[item("o1", collectionUid = "cZ", ownership = @[own("0xA", 1)])], networks)
    check spy.countResets() >= 1 # initial bulk load
    spy.clear()
    # re-push the identical source: no signals at all
    m.setSource(@[item("o1", collectionUid = "cZ", ownership = @[own("0xA", 1)])], networks)
    check spy.countResets() == 0
    check spy.countDataChanged() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0

  test "single ERC-1155 balance tick on a shown collectible is O(1): no reset, no parent group dataChanged":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    m.setSource(@[
      item("a", collectionUid = "cA", ownership = @[own("0xA", 1)]),
      item("b", collectionUid = "cB", ownership = @[own("0xA", 1)]),
    ], networks)
    let subA = m.subitemsModelForKey("cA")
    spy.clear()
    # b's ERC-1155 balance rises from 1 to 4; its group + position are unchanged.
    m.setSource(@[
      item("a", collectionUid = "cA", ownership = @[own("0xA", 1)]),
      item("b", collectionUid = "cB", ownership = @[own("0xA", 4)]),
    ], networks)
    check spy.countResets() == 0
    check spy.countInserts() == 0
    check spy.countRemoves() == 0
    # only the flat row + the "cB" subitem carry the balance -> tiny row span
    check dataChangedRows(spy) <= 4
    check m.flatModelForTest().balanceForKey("b") == 4
    check m.subitemsModelForKey("cB").balancesInOrder() == @[4]
    # cA untouched -> its submodel emitted nothing and kept identity
    check m.subitemsModelForKey("cA") == subA

  test "account switch over overlapping sets: granular, no reset, survivor submodel identity preserved":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    m.setSource(@[
      item("s1", collectionUid = "collS", ownership = @[own("0xA", 1), own("0xB", 1)]),
      item("a1", collectionUid = "collA", ownership = @[own("0xA", 1)]),
      item("b1", collectionUid = "collB", ownership = @[own("0xB", 1)]),
    ], networks)
    check m.groupKeysInOrder() == @["collA", "collS"]
    let sharedSub = m.subitemsModelForKey("collS")
    spy.clear()
    m.setAccountKey("0xB")
    check m.groupKeysInOrder() == @["collB", "collS"] # collA out, collB in, collS stays
    check spy.countResets() == 0
    check spy.countInserts() >= 1
    check spy.countRemoves() >= 1
    check m.subitemsModelForKey("collS") == sharedSub # identity preserved

  test "removed group's subitems submodel outlives the parent remove (no UAF)":
    # subitemsByKey is the dropped child's SOLE ORC owner, and a nimqml QVariant of
    # a QObject keeps only the raw C++ pointer. If reconcileByKey frees the child
    # before modelSync removes the parent row, the delegate bound to data(Subitems)
    # derefs freed memory while tearing its own row down. The parent's row count at
    # the moment of the free tells us which side of modelSync we are on.
    # ORC-gated: free order is deterministic only under --mm:orc (the production
    # mm). Run via `make nim-test-run-orc/...`; the refc suite reports it skipped.
    when defined(gcOrc):
      let m = newCollectiblesSelectorModel()
      m.setParams(params("0xA"))
      m.setSource(@[
        item("keep", collectionUid = "collS", ownership = @[own("0xA", 1), own("0xB", 1)]),
        item("sentinel777", collectionUid = "collA", ownership = @[own("0xA", 1)]),
      ], networks)
      check m.groupKeysInOrder() == @["collA", "collS"]

      # Recognise the doomed child by a sentinel VALUE — capturing a ref (even via
      # cast[int]) would keep it ORC-alive and mask the very free we want to observe.
      var groupsWhenFreed = -1
      onCollectiblesSelectorSubitemsModelDeleted = proc(sm: CollectiblesSelectorSubitemsModel) =
        if sm.keysInOrder() == @["sentinel777"]:
          groupsWhenFreed = m.getCount()

      m.setAccountKey("0xB")   # collA drops out
      onCollectiblesSelectorSubitemsModelDeleted = nil

      check m.groupKeysInOrder() == @["collS"]
      check groupsWhenFreed == 1  # row already removed; 2 would mean freed too early
    else:
      skip()

  test "batch append: new groups insert, existing untouched, no reset":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    let base = @[
      item("a", collectionUid = "cA", ownership = @[own("0xA", 1)]),
      item("b", collectionUid = "cB", ownership = @[own("0xA", 1)]),
    ]
    m.setSource(base, networks)
    let subA = m.subitemsModelForKey("cA")
    spy.clear()
    m.setSource(base & @[
      item("c", collectionUid = "cC", ownership = @[own("0xA", 1)]),
      item("d", collectionUid = "cD", ownership = @[own("0xA", 1)]),
    ], networks)
    check m.groupKeysInOrder() == @["cA", "cB", "cC", "cD"]
    check spy.countResets() == 0
    check spy.countInserts() >= 1
    check m.subitemsModelForKey("cA") == subA # untouched survivor keeps identity

  test "removing all rows clears both views":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    m.setSource(@[item("a", ownership = @[own("0xA", 1)])], networks)
    m.setSource(@[], networks)
    check m.groupKeysInOrder().len == 0
    check m.flatModelForTest().keysInOrder().len == 0

  test "filteredFlatModel property returns the live flat model":
    let m = newCollectiblesSelectorModel()
    m.setParams(params("0xA"))
    m.setSource(@[item("a", ownership = @[own("0xA", 1)])], networks)
    check m.getCount() == 1
    check m.flatModelForTest().keysInOrder().len == 1
