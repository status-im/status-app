# buildFlatCollectibles / buildCollectibleGroups — pure core for the collectibles
# picker, the Nim counterpart of CollectiblesSelectionAdaptor's QML proxy graph
# (LeftJoin(networks) -> per-row ObjectProxyModel with ownership SFPM + SumAggregator
# -> RangeFilter -> sort -> GroupingModel -> nested per-community GroupingModel).
#
# The whole pipeline is a single O(universe) scan with no per-row QObjects:
#   1. filter each collectible's ownership to the account, sum -> balance
#   2. drop balance < 1; drop off-chain; drop community owner/master tokens
#   3. join the network (icon + name)
#   4. sort communityId desc, then collectionUid asc
#   5. group by groupingValue (communityId else collectionUid)
#   6. community groups regroup their subitems by collectionUid (collection rows)
#
# Qt-free on purpose — unit-testable with a plain `nim c -r`.

import std/[tables, algorithm, strutils]

import ./collectibles_selector_item
export collectibles_selector_item

const
  # Constants.TokenPrivilegesLevel: Owner = 0, TMaster = 1, Community = 2.
  PrivilegeOwner = 0
  PrivilegeTMaster = 1

proc iconFor(item: CollectibleItem): string =
  ## imageUrl preferred, else mediaUrl. The default-token-icon fallback is applied
  ## in the QML delegate (needs the Assets singleton), so it is NOT added here.
  if item.imageUrl.len > 0: item.imageUrl else: item.mediaUrl

proc balanceForAccount(item: CollectibleItem, accountLower: string): int =
  ## Sum the ownership entries belonging to the account (empty account = all).
  for o in item.ownership:
    if accountLower.len == 0 or o.accountAddress.toLowerAscii == accountLower:
      result += o.balance

proc buildFlatCollectibles*(items: seq[CollectibleItem],
    networks: seq[CollectiblesNetworkInfo],
    params: CollectiblesSelectorParams): seq[FlatCollectible] =
  ## Steps 1-4. Produces the sorted `filteredFlatModel` rows.
  var netByChain = initTable[int, CollectiblesNetworkInfo]()
  for n in networks:
    netByChain[n.chainId] = n

  let accountLower = params.accountKey.toLowerAscii
  let chainSet = block:
    var s = initTable[int, bool]()
    for c in params.enabledChainIds: s[c] = true
    s

  result = newSeqOfCap[FlatCollectible](items.len)
  for item in items:
    if chainSet.len > 0 and not chainSet.hasKey(item.chainId):
      continue
    if params.filterCommunityOwnerAndMasterTokens and item.communityId.len > 0 and
        (item.communityPrivilegesLevel == PrivilegeOwner or
         item.communityPrivilegesLevel == PrivilegeTMaster):
      continue
    let balance = item.balanceForAccount(accountLower)
    if balance < 1:
      continue
    let net = netByChain.getOrDefault(item.chainId)
    result.add(FlatCollectible(
      key: item.key, chainId: item.chainId, collectionUid: item.collectionUid,
      contractAddress: item.contractAddress, tokenId: item.tokenId,
      tokenType: item.tokenType,
      name: item.name, collectionName: item.collectionName,
      mediaUrl: item.mediaUrl, imageUrl: item.imageUrl, icon: item.iconFor(),
      iconUrl: net.iconUrl, chainName: net.chainName,
      communityId: item.communityId, communityName: item.communityName,
      communityImage: item.communityImage,
      communityPrivilegesLevel: item.communityPrivilegesLevel,
      balance: balance,
      groupingValue: if item.communityId.len > 0: item.communityId else: item.collectionUid))

  # Step 4: communityId desc, then collectionUid asc. Stable so equal keys keep
  # source order — puts community collectibles first, groups them consecutively.
  result.sort(proc(a, b: FlatCollectible): int =
    if a.communityId != b.communityId:
      return cmp(b.communityId, a.communityId)
    return cmp(a.collectionUid, b.collectionUid))

proc communitySubitems(rows: seq[FlatCollectible]): seq[CollectibleSubItem] =
  ## Regroup a community group's collectibles by collectionUid into collection
  ## rows: key = collectionUid, balance = item count, name = collectionName.
  ## (Divergence: the adaptor passed the representative collectible's `name`
  ## through here; collectionName is the correct label — see the test notes.)
  var order: seq[string] = @[]
  var countByColl = initTable[string, int]()
  var repByColl = initTable[string, FlatCollectible]()
  for r in rows:
    if not countByColl.hasKey(r.collectionUid):
      order.add(r.collectionUid)
      countByColl[r.collectionUid] = 0
      repByColl[r.collectionUid] = r
    inc countByColl[r.collectionUid]
  for uid in order:
    let rep = repByColl[uid]
    result.add(CollectibleSubItem(key: uid, name: rep.collectionName,
      balance: countByColl[uid], icon: rep.icon, iconUrl: rep.iconUrl))

proc buildCollectibleGroups*(flat: seq[FlatCollectible]): seq[CollectibleGroup] =
  ## Steps 5-6. `flat` must already be sorted (buildFlatCollectibles output), so
  ## rows sharing a groupingValue are consecutive.
  var i = 0
  while i < flat.len:
    let gv = flat[i].groupingValue
    var j = i
    var members: seq[FlatCollectible] = @[]
    while j < flat.len and flat[j].groupingValue == gv:
      members.add(flat[j])
      inc j
    let rep = members[0]
    let isCommunity = rep.communityId.len > 0
    var group = CollectibleGroup(
      groupKey: gv,
      groupType: if isCommunity: "community" else: "other",
      # communityName || collectionName parity: an empty embedded community name
      # (grouping is keyed on communityId, not the label) falls back to collectionName.
      groupName: if isCommunity and rep.communityName.len > 0: rep.communityName else: rep.collectionName,
      icon: if isCommunity: rep.communityImage else: rep.icon,
      iconUrl: rep.iconUrl,
      # Representative collectible's raw media; the shared SearchableCollectiblesPanel
      # top-level delegate reads `imageUrl || mediaUrl` for the group thumbnail.
      imageUrl: rep.imageUrl, mediaUrl: rep.mediaUrl)
    if isCommunity:
      group.subitems = communitySubitems(members)
    else:
      for m in members:
        group.subitems.add(CollectibleSubItem(key: m.key, name: m.name,
          balance: m.balance, icon: m.icon, iconUrl: m.iconUrl))
    result.add(group)
    i = j

proc buildDisplay*(items: seq[CollectibleItem],
    networks: seq[CollectiblesNetworkInfo],
    params: CollectiblesSelectorParams):
    tuple[flat: seq[FlatCollectible], groups: seq[CollectibleGroup]] =
  ## Single entry point the terminal model calls to (re)derive both views.
  let flat = buildFlatCollectibles(items, networks, params)
  (flat: flat, groups: buildCollectibleGroups(flat))
