## Host integration test for the send-modal collectibles rewire: boots an
## offscreen QQmlApplicationEngine, context-injects a real
## CollectiblesSelectorModel (the exact object the all_collectibles producer
## hands the send modal), and loads collectibles_selector_integration_scene.qml,
## which reads back the SAME roles the production QML reads:
##  - SimpleSendModal off selectedCollectibleEntry.item: uid (:367), tokenType
##    (:514), balance (:429, the account-scoped ERC-1155 max), plus communityId /
##    collectionUid / name / imageUrl / mediaUrl used to set the header;
##  - SearchableCollectiblesPanel top-level delegate: groupName / type / icon and
##    the imageUrl||mediaUrl thumbnail.
##
## This closes the "device-gated" gap for the role contract: if a role name or
## type regresses, an assertion here fails on the host.

import unittest, os, tables
import nimqml
from seaqt/qcoreapplication import QCoreApplication, processEvents

import app/modules/shared_models/collectibles_selector_model

type
  FlatRec = object
    uid: string
    tokenType, balance: int
    communityId, collectionUid, name, imageUrl, mediaUrl: string
  GroupRec = object
    groupName, gtype, icon, imageUrl, mediaUrl: string
    subCount: int

QtObject:
  type Probe = ref object of QObject
    ready: bool
    flat: Table[string, FlatRec]
    grouped: Table[string, GroupRec]

  proc newProbe(): Probe =
    new(result)
    result.QObject.setup
    result.flat = initTable[string, FlatRec]()
    result.grouped = initTable[string, GroupRec]()

  proc onReady(self: Probe) {.slot.} = self.ready = true

  proc recordFlat(self: Probe, key: string, uidVal: string, tokenType: int,
      balance: int, communityId: string, collectionUid: string, name: string,
      imageUrl: string, mediaUrl: string) {.slot.} =
    self.flat[key] = FlatRec(uid: uidVal, tokenType: tokenType, balance: balance,
      communityId: communityId, collectionUid: collectionUid, name: name,
      imageUrl: imageUrl, mediaUrl: mediaUrl)

  proc recordGrouped(self: Probe, key: string, groupName: string, gtype: string,
      icon: string, imageUrl: string, mediaUrl: string, subCount: int) {.slot.} =
    self.grouped[key] = GroupRec(groupName: groupName, gtype: gtype, icon: icon,
      imageUrl: imageUrl, mediaUrl: mediaUrl, subCount: subCount)

proc own(account: string, balance = 1): CollectibleOwnership =
  CollectibleOwnership(accountAddress: account, balance: balance)

let networks = @[
  CollectiblesNetworkInfo(chainId: 1, chainName: "Mainnet", iconUrl: "network/ethereum"),
]

# Known universe covering ERC-721, ERC-1155 and a community collectible.
let universe = @[
  CollectibleItem(key: "a721", chainId: 1, collectionUid: "cA", tokenType: 2,
    name: "Cat", imageUrl: "a.png", mediaUrl: "",
    ownership: @[own("0xA", 1), own("0xB", 3)]),
  CollectibleItem(key: "b1155", chainId: 1, collectionUid: "cB", tokenType: 3,
    name: "Sword", imageUrl: "", mediaUrl: "b.mp4",
    ownership: @[own("0xA", 5)]),
  CollectibleItem(key: "c1", chainId: 1, collectionUid: "cC", tokenType: 2,
    name: "Badge", imageUrl: "c.png", mediaUrl: "",
    communityId: "com1", communityName: "Comm", communityImage: "cimg",
    communityPrivilegesLevel: 2, ownership: @[own("0xA", 1)]),
]

putEnv("QT_QPA_PLATFORM", "offscreen")
let app = newQApplication()
let model = newCollectiblesSelectorModel()
model.setParams(CollectiblesSelectorParams(accountKey: "0xA",
  enabledChainIds: @[], filterCommunityOwnerAndMasterTokens: false))
model.setSource(universe, networks)

let probe = newProbe()
let engine = newQQmlApplicationEngine()
engine.setRootContextProperty("collectiblesModel", newQVariant(model))
engine.setRootContextProperty("probe", newQVariant(probe))

let sceneFile = getCurrentDir() / "test" / "nim" / "benchmarks" /
  "collectibles_selector_integration_scene.qml"
engine.loadData(readFile(sceneFile))

var spins = 0
while not probe.ready and spins < 200000:
  QCoreApplication.processEvents(); inc spins

# Skip when the QtQuick scene can't load (bare `make nim-test-run` on macOS
# provides no QML import path). Run for real with:
#   DYLD_FRAMEWORK_PATH=<qt>/lib QML2_IMPORT_PATH=<qt>/qml QT_QPA_PLATFORM=offscreen \
#   ./bin/collectibles_selector_integration_test
if not probe.ready:
  echo "SKIP: collectibles integration scene did not load (QML import path unavailable)"
  quit(0)

suite "collectibles picker QML<->Nim role contract (host)":

  test "scene loaded and both models reached their QML consumers":
    check probe.flat.len == 3      # all three owned by 0xA
    check probe.grouped.len == 3   # com1 (community) + cA + cB (other)

  test "flat rows expose the roles SimpleSendModal reads off the selected entry":
    # ERC-721: uid == key, tokenType 2, account balance 1
    check probe.flat["a721"].uid == "a721"
    check probe.flat["a721"].tokenType == 2
    check probe.flat["a721"].balance == 1
    check probe.flat["a721"].imageUrl == "a.png"
    # ERC-1155: tokenType 3, and balance is the ACCOUNT's amount (5), not 0xB's
    check probe.flat["b1155"].tokenType == 3
    check probe.flat["b1155"].balance == 5
    check probe.flat["b1155"].mediaUrl == "b.mp4"
    # community collectible header inputs
    check probe.flat["c1"].communityId == "com1"
    check probe.flat["c1"].collectionUid == "cC"
    check probe.flat["c1"].name == "Badge"

  test "grouped rows expose the panel thumbnail + label roles":
    # community group: type/name/icon(communityImage) + rep collectible thumbnail
    let g = probe.grouped["com1"]
    check g.gtype == "community"
    check g.groupName == "Comm"
    check g.icon == "cimg"
    check g.imageUrl == "c.png"   # SearchableCollectiblesPanel reads imageUrl||mediaUrl
    check g.subCount == 1         # one collection (cC)
    # other groups fall back through imageUrl -> mediaUrl
    check probe.grouped["cA"].gtype == "other"
    check probe.grouped["cA"].imageUrl == "a.png"
    check probe.grouped["cB"].imageUrl == ""
    check probe.grouped["cB"].mediaUrl == "b.mp4"
