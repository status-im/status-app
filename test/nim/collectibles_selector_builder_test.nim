## Pure-core tests for the collectibles picker builder. Qt-free, runs with a plain
## `nim c -r` (no nimqml/seaqt). Covers the filter/sum/sort/group semantics the
## retired CollectiblesSelectionAdaptor computed via its QML proxy graph.
##
## Recorded divergences from the adaptor (robust semantics preferred; the adaptor
## behaviors were accidental QML-proxy artifacts):
##  - Default-token-icon fallback: the adaptor's flat `icon` was
##    `imageUrl || mediaUrl || Assets.png(defaultTokenIcon)`. The builder emits
##    only `imageUrl || mediaUrl` and leaves the default fallback to the QML
##    delegate (the Assets singleton is not reachable from Nim).
##  - Community collection subitem `name`: the adaptor's inner ObjectProxyModel
##    passed the representative COLLECTIBLE's `name` through as the collection's
##    name. The builder uses `collectionName`, the correct collection label.

import unittest, sequtils, tables

import app/modules/shared_models/collectibles_selector_builder

proc own(account: string, balance = 1): CollectibleOwnership =
  CollectibleOwnership(accountAddress: account, balance: balance)

proc item(key: string, chainId = 1, collectionUid = "c0", collectionName = "Coll 0",
    name = "", communityId = "", communityName = "", communityImage = "",
    privileges = 2, imageUrl = "", mediaUrl = "", tokenType = 2,
    ownership: seq[CollectibleOwnership] = @[]): CollectibleItem =
  CollectibleItem(
    key: key, chainId: chainId, collectionUid: collectionUid,
    collectionName: collectionName, tokenType: tokenType,
    name: if name.len > 0: name else: key,
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

suite "collectibles builder - flat filtering":

  test "balance summed per account; other accounts excluded":
    let items = @[
      item("k1", ownership = @[own("0xA", 2), own("0xB", 5), own("0xA", 3)]),
    ]
    let flat = buildFlatCollectibles(items, networks, params("0xA"))
    check flat.len == 1
    check flat[0].balance == 5 # 2 + 3, not 0xB's 5

  test "account match is case-insensitive":
    let items = @[item("k1", ownership = @[own("0xABC", 1)])]
    check buildFlatCollectibles(items, networks, params("0xabc")).len == 1

  test "zero-balance rows are dropped":
    let items = @[
      item("owned", ownership = @[own("0xA", 1)]),
      item("notowned", ownership = @[own("0xB", 1)]),
      item("zero", ownership = @[own("0xA", 0)]),
    ]
    check buildFlatCollectibles(items, networks, params("0xA")).mapIt(it.key) == @["owned"]

  test "chain filter keeps only enabled chains":
    let items = @[
      item("eth", chainId = 1, ownership = @[own("0xA", 1)]),
      item("op", chainId = 10, ownership = @[own("0xA", 1)]),
    ]
    let flat = buildFlatCollectibles(items, networks, params("0xA", chains = @[10]))
    check flat.mapIt(it.key) == @["op"]

  test "empty chain filter keeps all chains":
    let items = @[
      item("eth", chainId = 1, ownership = @[own("0xA", 1)]),
      item("op", chainId = 10, ownership = @[own("0xA", 1)]),
    ]
    check buildFlatCollectibles(items, networks, params("0xA")).len == 2

  test "owner/master community tokens filtered when requested":
    let items = @[
      item("owner", communityId = "com1", privileges = 0, ownership = @[own("0xA", 1)]),
      item("master", communityId = "com1", privileges = 1, ownership = @[own("0xA", 1)]),
      item("member", communityId = "com1", privileges = 2, ownership = @[own("0xA", 1)]),
      item("noncomm", privileges = 0, ownership = @[own("0xA", 1)]), # privilege ignored (no community)
    ]
    let flat = buildFlatCollectibles(items, networks, params("0xA", filterOwnerMaster = true))
    check "owner" notin flat.mapIt(it.key)
    check "master" notin flat.mapIt(it.key)
    check "member" in flat.mapIt(it.key)
    check "noncomm" in flat.mapIt(it.key) # non-community owner-privilege stays

  test "tokenType + key(uid) pass through to the flat rows":
    let items = @[
      item("erc721", tokenType = 2, ownership = @[own("0xA", 1)]),
      item("erc1155", tokenType = 3, ownership = @[own("0xA", 5)]),
    ]
    let flat = buildFlatCollectibles(items, networks, params("0xA"))
    let byKey = flat.mapIt((it.key, it.tokenType)).toTable
    check byKey["erc721"] == 2   # Constants.TokenType.ERC721
    check byKey["erc1155"] == 3  # Constants.TokenType.ERC1155

  test "network join fills chainName + iconUrl":
    let items = @[item("op", chainId = 10, ownership = @[own("0xA", 1)])]
    let flat = buildFlatCollectibles(items, networks, params("0xA"))
    check flat[0].chainName == "Optimism"
    check flat[0].iconUrl == "net/op"

  test "icon prefers imageUrl then mediaUrl (no default fallback in Nim)":
    let items = @[
      item("img", imageUrl = "i.png", mediaUrl = "m.mp4", ownership = @[own("0xA", 1)]),
      item("media", imageUrl = "", mediaUrl = "m.mp4", ownership = @[own("0xA", 1)]),
      item("none", imageUrl = "", mediaUrl = "", ownership = @[own("0xA", 1)]),
    ]
    let flat = buildFlatCollectibles(items, networks, params("0xA"))
    let byKey = flat.mapIt((it.key, it.icon)).toTable
    check byKey["img"] == "i.png"
    check byKey["media"] == "m.mp4"
    check byKey["none"] == "" # default token icon applied in the QML delegate

suite "collectibles builder - sort and grouping":

  test "community collectibles sort first (communityId desc), then collectionUid asc":
    let items = @[
      item("a", collectionUid = "z", ownership = @[own("0xA", 1)]),               # non-community
      item("b", collectionUid = "a", communityId = "com1", ownership = @[own("0xA", 1)]),
      item("c", collectionUid = "b", communityId = "com2", ownership = @[own("0xA", 1)]),
    ]
    let flat = buildFlatCollectibles(items, networks, params("0xA"))
    # com2 > com1 (desc), then non-community ("") last
    check flat.mapIt(it.communityId) == @["com2", "com1", ""]

  test "grouping: community group by communityId, other group by collectionUid":
    let items = @[
      item("g1", collectionUid = "collX", collectionName = "X",
        communityId = "com1", communityName = "Comm One", communityImage = "cimg",
        ownership = @[own("0xA", 1)]),
      item("g2", collectionUid = "collY", collectionName = "Y",
        communityId = "com1", communityName = "Comm One", communityImage = "cimg",
        ownership = @[own("0xA", 1)]),
      item("o1", collectionUid = "collZ", collectionName = "Zed",
        imageUrl = "z.png", ownership = @[own("0xA", 1)]),
    ]
    let (flat, groups) = buildDisplay(items, networks, params("0xA"))
    check flat.len == 3
    check groups.len == 2
    # community group first
    check groups[0].groupType == "community"
    check groups[0].groupKey == "com1"
    check groups[0].groupName == "Comm One"
    check groups[0].icon == "cimg"
    # its subitems are collections: collX + collY, each count 1, named by collection
    check groups[0].subitems.mapIt(it.key) == @["collX", "collY"]
    check groups[0].subitems.mapIt(it.balance) == @[1, 1]
    check groups[0].subitems.mapIt(it.name) == @["X", "Y"] # collectionName, not collectible name
    # other group
    check groups[1].groupType == "other"
    check groups[1].groupKey == "collZ"
    check groups[1].groupName == "Zed"
    check groups[1].icon == "z.png"
    check groups[1].subitems.mapIt(it.key) == @["o1"]

  test "community group name uses communityName when non-empty":
    let items = @[
      item("g1", collectionUid = "collX", collectionName = "Coll X",
        communityId = "com1", communityName = "Comm One", ownership = @[own("0xA", 1)]),
    ]
    let groups = buildDisplay(items, networks, params("0xA")).groups
    check groups[0].groupType == "community"
    check groups[0].groupName == "Comm One"

  test "community group name falls back to collectionName when communityName empty":
    let items = @[
      item("g1", collectionUid = "collX", collectionName = "Coll X",
        communityId = "com1", communityName = "", ownership = @[own("0xA", 1)]),
    ]
    let groups = buildDisplay(items, networks, params("0xA")).groups
    check groups[0].groupType == "community"
    check groups[0].groupName == "Coll X" # communityName || collectionName parity, never the hex communityId

  test "community collection subitem balance = number of collectibles in the collection":
    let items = @[
      item("m1", collectionUid = "collX", communityId = "com1", ownership = @[own("0xA", 1)]),
      item("m2", collectionUid = "collX", communityId = "com1", ownership = @[own("0xA", 1)]),
      item("m3", collectionUid = "collX", communityId = "com1", ownership = @[own("0xA", 1)]),
      item("n1", collectionUid = "collY", communityId = "com1", ownership = @[own("0xA", 1)]),
    ]
    let groups = buildDisplay(items, networks, params("0xA")).groups
    check groups.len == 1
    check groups[0].subitems.mapIt((it.key, it.balance)) == @[("collX", 3), ("collY", 1)]

  test "other group subitem balance = the collectible's owned amount (ERC-1155)":
    let items = @[
      item("e1155", collectionUid = "coll", ownership = @[own("0xA", 7)]),
    ]
    let groups = buildDisplay(items, networks, params("0xA")).groups
    check groups[0].subitems[0].balance == 7
