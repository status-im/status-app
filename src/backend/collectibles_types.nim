import json, std/strformat, json_serialization
import stint, tables, options, strutils
import community_tokens_types

include app_service/common/json_utils

const COLLECTIBLE_UNIQUE_ID_SEPARATOR = "-"

proc makeCollectibleUniqueID*(chainId: int, address: string, tokenId: string): string =
  return $chainId & COLLECTIBLE_UNIQUE_ID_SEPARATOR & address & COLLECTIBLE_UNIQUE_ID_SEPARATOR & tokenId

# follows the ContractType declared in status go status-go/services/wallet/common/const.go
type ContractType* {.pure.} = enum
  ContractTypeUnknown = 0,
  ContractTypeERC20 = 1,
  ContractTypeERC721 = 2,
  ContractTypeERC1155 = 3

type
  # Mirrors services/wallet/thirdparty/collectible_types.go ContractID
  ContractID* = ref object of RootObj
    chainID*: int
    address*: string

  # Mirrors services/wallet/thirdparty/collectible_types.go CollectibleUniqueID
  CollectibleUniqueID* = ref object of RootObj
    contractID*: ContractID
    tokenID*: UInt256

  # see status-go/services/wallet/collectibles/service.go CollectibleDataType
  CollectibleDataType* {.pure.} = enum
    UniqueID, Header, Details, CommunityHeader

  # Mirrors services/wallet/thirdparty/collectible_types.go CollectibleTrait
  CollectibleTrait* = ref object of RootObj
    trait_type*: string
    value*: string
    display_type*: string
    max_value*: string

  CollectibleData* = ref object of RootObj
    name*: string
    description*: Option[string]
    imageUrl*: Option[string]
    animationUrl*: Option[string]
    animationMediaType*: Option[string]
    traits*: Option[seq[CollectibleTrait]]
    backgroundColor*: Option[string]
    soulbound*: Option[bool]

  CollectionData* = ref object of RootObj
    name*: string
    slug*: string
    imageUrl*: string
    socials*: CollectionSocials

  CommunityData* = ref object of RootObj
    id*: string
    name*: string
    color*: string
    privilegesLevel*: PrivilegesLevel
    imageUrl*: Option[string]

  # Mirrors services/wallet/thirdparty/collectible_types.go CollectibleOwner
  AccountBalance* = ref object
    address*: string
    balance*: UInt256
    txTimestamp*: int

  Collectible* = ref object of RootObj
    dataType*: CollectibleDataType
    id* : CollectibleUniqueID
    collectibleData*: Option[CollectibleData]
    collectionData*: Option[CollectionData]
    communityData*: Option[CommunityData]
    ownership*: Option[seq[AccountBalance]]
    isFirst*: Option[bool]
    latestTxHash*: Option[string]
    receivedAmount*: Option[float64]
    contractType*: Option[ContractType]

  CollectionSocials* = ref object of RootObj
    website*: string
    twitterHandle*: string

  CollectionSocialsMessage* = ref object of RootObj
    socials*: CollectionSocials
    id*: ContractID

  # Mirrors services/wallet/thirdparty/collectible_types.go TokenBalance
  CollectibleBalance* = ref object
    tokenId*: UInt256
    balance*: UInt256

  # Mirrors services/wallet/thirdparty/collectible_types.go CollectibleOwner
  CollectibleOwner* = ref object
    address*: string
    balances*: seq[CollectibleBalance]

  # Mirrors services/wallet/thirdparty/collectible_types.go CollectibleContractOwnership
  CollectibleContractOwnership* = ref object
    contractAddress*: string
    owners*: seq[CollectibleOwner]

  # Mirrors status-go/multiaccounts/settings_wallet/database.go CollectiblePreferencesType
  CollectiblePreferencesItemType* {.pure.} = enum
    NonCommunityCollectible = 1,
    CommunityCollectible,
    Collection,
    Community

  # Mirrors status-go/multiaccounts/settings_wallet/database.go CollectiblePreferences
  CollectiblePreferences* = ref object of RootObj
    itemType* {.serializedFieldName("type").}: CollectiblePreferencesItemType
    key* {.serializedFieldName("key").}: string
    position* {.serializedFieldName("position").}: int
    visible* {.serializedFieldName("visible").}: bool

# ContractID
proc `$`*(self: ContractID): string =
  return fmt"""ContractID(
    chainID:{self.chainID},
    address:{self.address}
  )"""

proc `==`*(a, b: ContractID): bool =
  result = a.chainID == b.chainID and
    a.address == b.address

proc `%`*(t: ContractID): JsonNode {.inline.} =
  result = newJObject()
  result["chainID"] = %(t.chainID)
  result["address"] = %(t.address)

proc `%`*(t: ref ContractID): JsonNode {.inline.} =
  return %(t[])

proc `%`*(self: CollectibleBalance): JsonNode {.inline.} =
  result = newJObject()
  result["tokenId"] = %self.tokenId.toString()
  result["balance"] = %self.balance.toString()

proc fromJson*(t: JsonNode, T: typedesc[ContractID]): ContractID {.inline.} =
  result = ContractID()
  result.chainID = t["chainID"].getInt()
  result.address = t["address"].getStr()

proc fromJson*(t: JsonNode, T: typedesc[ref ContractID]): ref ContractID {.inline.} =
  result = new(ContractID)
  result[] = fromJson(t, ContractID)

proc toString*(t: ContractID): string =
  return $t.chainID & COLLECTIBLE_UNIQUE_ID_SEPARATOR & t.address

proc toContractID*(t: string): ContractID =
  var parts = t.split(COLLECTIBLE_UNIQUE_ID_SEPARATOR)
  return ContractID(chainID: parts[0].parseInt(), address: parts[1])

proc isContractID*(t: string): bool =
  try:
    discard toContractID(t)
    return true
  except Exception:
    return false

# CollectibleUniqueID
proc `$`*(self: CollectibleUniqueID): string =
  return fmt"""CollectibleUniqueID(
    contractID:{self.contractID},
    tokenID:{self.tokenID}
  )"""

proc `==`*(a, b: CollectibleUniqueID): bool =
  result = a.contractID == b.contractID and
    a.tokenID == b.tokenID

proc `%`*(t: CollectibleUniqueID): JsonNode {.inline.} =
  result = newJObject()
  result["contractID"] = %(t.contractID)
  result["tokenID"] = %(t.tokenID.toString())

proc `%`*(t: ref CollectibleUniqueID): JsonNode {.inline.} =
  return %(t[])

proc fromJson*(t: JsonNode, T: typedesc[CollectibleUniqueID]): CollectibleUniqueID {.inline.} =
  result = CollectibleUniqueID()
  result.contractID = fromJson(t["contractID"], ContractID)
  result.tokenID = stint.parse(t["tokenID"].getStr(), UInt256)

proc fromJson*(t: JsonNode, T: typedesc[ref CollectibleUniqueID]): ref CollectibleUniqueID {.inline.} =
  result = new(CollectibleUniqueID)
  result[] = fromJson(t, CollectibleUniqueID)

proc toString*(t: CollectibleUniqueID): string =
  return makeCollectibleUniqueID(t.contractID.chainID, t.contractID.address, t.tokenID.toString())

proc toCollectibleUniqueID*(t: string): CollectibleUniqueID =
  var parts = t.split(COLLECTIBLE_UNIQUE_ID_SEPARATOR)
  return CollectibleUniqueID(
    contractID: ContractID(
        chainID: parts[0].parseInt(),
        address: parts[1]
      ),
    tokenID: stint.parse(parts[2], UInt256)
  )

# CollectibleTrait
proc `$`*(self: CollectibleTrait): string =
  return fmt"""CollectibleTrait(
    trait_type:{self.trait_type},
    value:{self.value},
    display_type:{self.display_type},
    max_value:{self.max_value}
  )"""

proc fromJson*(t: JsonNode, T: typedesc[CollectibleTrait]): CollectibleTrait {.inline.} =
  result = CollectibleTrait()
  result.trait_type = t["trait_type"].getStr()
  result.value = t["value"].getStr()
  result.display_type = t["display_type"].getStr()
  result.max_value = t["max_value"].getStr()

proc fromJson*(t: JsonNode, T: typedesc[ref CollectibleTrait]): ref CollectibleTrait {.inline.} =
  result = new(CollectibleTrait)
  result[] = fromJson(t, CollectibleTrait)

# CollectionData
proc `$`*(self: CollectionData): string =
  return fmt"""CollectionData(
    name:{self.name},
    slug:{self.slug},
    imageUrl:{self.imageUrl}
    website:{self.socials.website}
    twitterHandle:{self.socials.twitterHandle}
  )"""

# CollectionSocials
proc `$`*(self: CollectionSocials): string =
  return fmt"""CollectionSocials(
    website:{self.website},
    twitterHandle:{self.twitterHandle},
  )"""

proc fromJson*(t: JsonNode, T: typedesc[CollectionData]): CollectionData =
  result = CollectionData()
  result.name = t["name"].getStr()
  result.slug = t["slug"].getStr()
  result.imageUrl = t["image_url"].getStr()
  result.socials = fromJson(t["socials"], CollectionSocials)

proc fromJson*(t: JsonNode, T: typedesc[ref CollectionData]): ref CollectionData =
  result = new(CollectionData)
  result[] = fromJson(t, CollectionData)

# CollectibleData
proc `$`*(self: CollectibleData): string =
  return fmt"""CollectibleData(
    name:{self.name},
    description:{self.description},
    imageUrl:{self.imageUrl},
    animationUrl:{self.animationUrl},
    animationMediaType:{self.animationMediaType},
    traits:{self.traits},
    backgroundColor:{self.backgroundColor},
    soulbound:{self.soulbound}
  )"""

proc getCollectibleTraits*(t: JsonNode): Option[seq[CollectibleTrait]] =
  var traitList: seq[CollectibleTrait] = @[]
  for item in t.getElems():
    traitList.add(fromJson(item, CollectibleTrait))
  if traitList.len == 0:
    return none(seq[CollectibleTrait])
  else:
    return some(traitList)

proc fromJson*(t: JsonNode, T: typedesc[CollectibleData]): CollectibleData =
  result = CollectibleData()

  result.name = t["name"].getStr()
  let descriptionNode = t{"description"}
  if descriptionNode != nil and descriptionNode.kind != JNull:
    result.description = some(descriptionNode.getStr())
  else:
    result.description = none(string)
  let imageUrlNode = t{"image_url"}
  if imageUrlNode != nil and imageUrlNode.kind != JNull:
    result.imageUrl = some(imageUrlNode.getStr())
  else:
    result.imageUrl = none(string)
  let animationUrlNode = t{"animation_url"}
  if animationUrlNode != nil and animationUrlNode.kind != JBool:
    result.animationUrl = some(animationUrlNode.getStr())
  else:
    result.animationUrl = none(string)
  let animationMediaTypeNode = t{"animation_media_type"}
  if animationMediaTypeNode != nil and animationMediaTypeNode.kind != JNull:
    result.animationMediaType = some(animationMediaTypeNode.getStr())
  else:
    result.animationMediaType = none(string)
  let soulboundNode = t{"soulbound"}
  if soulboundNode != nil and soulboundNode.kind != JNull:
    result.soulbound = some(soulboundNode.getBool())
  else:
    result.soulbound = none(bool)
  result.traits = getCollectibleTraits(t{"traits"})
  let backgroundColorNode = t{"background_color"}
  if backgroundColorNode != nil and backgroundColorNode.kind != JNull:
    result.backgroundColor = some(backgroundColorNode.getStr())
  else:
    result.backgroundColor = none(string)

proc fromJson*(t: JsonNode, T: typedesc[ref CollectibleData]): ref CollectibleData {.inline.} =
  result = new(CollectibleData)
  result[] = fromJson(t, CollectibleData)

# CommunityData
proc `$`*(self: CommunityData): string =
  return fmt"""CommunityData(
    id:{self.id},
    name:{self.name},
    color:{self.color},
    privilegesLevel:{self.privilegesLevel},
    imageUrl:{self.imageUrl}
  )"""

proc fromJson*(t: JsonNode, T: typedesc[CommunityData]): CommunityData =
  result = CommunityData()
  result.id = t["id"].getStr
  result.name = t["name"].getStr
  result.color = t["color"].getStr
  result.privilegesLevel = PrivilegesLevel(t["privileges_level"].getInt)
  let imageUrlNode = t{"image_url"}
  if imageUrlNode != nil and imageUrlNode.kind != JNull:
    result.imageUrl = some(imageUrlNode.getStr())
  else:
    result.imageUrl = none(string)

proc fromJson*(t: JsonNode, T: typedesc[ref CommunityData]): ref CommunityData {.inline.} =
  result = new(CommunityData)
  result[] = fromJson(t, CommunityData)

# AccountBalance
proc `$`*(self: AccountBalance): string =
  return fmt"""AccountBalance(
    address:{self.address},
    balance:{self.balance},
    txTimestamp:{self.txTimestamp}
  )"""

proc getAccountBalances(jsonAsset: JsonNode): seq[AccountBalance] =
  var balanceList: seq[AccountBalance] = @[]
  for item in jsonAsset.getElems():
      balanceList.add(AccountBalance(
          address: item{"address"}.getStr,
          balance: stint.parse(item{"balance"}.getStr, Uint256),
          txTimestamp: item{"txTimestamp"}.getInt
      ))
  return balanceList

# Collectible
proc `$`*(self: Collectible): string =
  return fmt"""Collectible(
    dataType:{self.dataType},
    id:{self.id},
    collectibleData:{self.collectibleData},
    collectionData:{self.collectionData},
    communityData:{self.communityData},
    ownership:{self.ownership},
    isFist:{self.isFirst},
    latestTxHash:{self.latestTxHash}
  )"""

proc fromJson*(t: JsonNode, T: typedesc[Collectible]): Collectible {.inline.} =
  result = Collectible()
  result.dataType = t["data_type"].getInt().CollectibleDataType
  result.id = fromJson(t["id"], CollectibleUniqueID)
  let collectibleDataNode = t{"collectible_data"}
  if collectibleDataNode != nil and collectibleDataNode.kind != JNull:
    result.collectibleData = some(fromJson(collectibleDataNode, CollectibleData))
  else:
    result.collectibleData = none(CollectibleData)
  let collectionDataNode = t{"collection_data"}
  if collectionDataNode != nil and collectionDataNode.kind != JNull:
    result.collectionData = some(fromJson(collectionDataNode, CollectionData))
  else:
    result.collectionData = none(CollectionData)
  let communityDataNode = t{"community_data"}
  if communityDataNode != nil and communityDataNode.kind != JNull:
    result.communityData = some(fromJson(communityDataNode, CommunityData))
  else:
    result.communityData = none(CommunityData)
  let ownershipNode = t{"ownership"}
  if ownershipNode != nil and ownershipNode.kind != JNull:
    result.ownership = some(getAccountBalances(ownershipNode))
  else:
    result.ownership = none(seq[AccountBalance])
  let isFirstNode = t{"is_first"}
  if isFirstNode != nil and isFirstNode.kind != JNull:
    result.isFirst = some(isFirstNode.getBool())
  else:
    result.isFirst = none(bool)
  let latestTxHashNode = t{"latest_tx_hash"}
  if latestTxHashNode != nil and latestTxHashNode.kind != JNull:
    result.latestTxHash = some(latestTxHashNode.getStr())
  else:
    result.latestTxHash = none(string)
  let receivedAmountNode = t{"received_amount"}
  if receivedAmountNode != nil and receivedAmountNode.kind != JNull:
    result.receivedAmount = some(receivedAmountNode.getFloat())
  else:
    result.receivedAmount = none(float64)
  let contractTypeNode = t{"contract_type"}
  if contractTypeNode != nil and contractTypeNode.kind != JNull:
    result.contractType = some(ContractType(contractTypeNode.getInt()))
  else:
    result.contractType = none(ContractType)

proc toIds(self: seq[Collectible]): seq[CollectibleUniqueID] =
  result = @[]
  for c in self:
    result.add(c.id)

# CollectibleBalance
proc `$`*(self: CollectibleBalance): string =
  return fmt"""CollectibleBalance(
    tokenId:{self.tokenId},
    balance:{self.balance}
    """

proc getCollectibleBalances*(jsonAsset: JsonNode): seq[CollectibleBalance] =
  var balanceList: seq[CollectibleBalance] = @[]
  for item in jsonAsset.items:
      balanceList.add(CollectibleBalance(
          tokenId: stint.parse(item{"tokenId"}.getStr, Uint256),
          balance: stint.parse(item{"balance"}.getStr, Uint256)
      ))
  return balanceList

# CollectibleOwner
proc `$`*(self: CollectibleOwner): string =
  return fmt"""CollectibleOwner(
    address:{self.address},
    balances:{self.balances}
    """

proc getCollectibleOwner*(jsonAsset: JsonNode): CollectibleOwner =
  return CollectibleOwner(
    address: jsonAsset{"ownerAddress"}.getStr,
    balances: getCollectibleBalances(jsonAsset{"tokenBalances"})
  )

proc `%`*(self: CollectibleOwner): JsonNode {.inline.} =
  result = newJObject()
  result["ownerAddress"] = %(self.address)
  result["tokenBalances"] = %(self.balances)

proc getCollectibleOwners(jsonAsset: JsonNode): seq[CollectibleOwner] =
  var ownerList: seq[CollectibleOwner] = @[]
  for item in jsonAsset.items:
      ownerList.add(getCollectibleOwner(item))
  return ownerList

# CollectibleContractOwnership
proc `$`*(self: CollectibleContractOwnership): string =
  return fmt"""CollectibleContractOwnership(
    contractAddress:{self.contractAddress},
    owners:{self.owners}
    """

proc fromJson*(t: JsonNode, T: typedesc[CollectibleContractOwnership]): CollectibleContractOwnership {.inline.} =
    return CollectibleContractOwnership(
        contractAddress: t{"contractAddress"}.getStr,
        owners: getCollectibleOwners(t{"owners"})
    )

# CollectiblePreferences
proc `$`*(self: CollectiblePreferences): string =
  return fmt"""CollectiblePreferences(
    type:{self.itemType},
    key:{self.key},
    position:{self.position},
    visible:{self.visible}
    """

proc fromJson*(t: JsonNode, T: typedesc[CollectiblePreferences]): CollectiblePreferences {.inline.} =
  result = CollectiblePreferences()
  result.itemType = t{"type"}.getInt().CollectiblePreferencesItemType
  discard t.getProp("key", result.key)
  discard t.getProp("position", result.position)
  discard t.getProp("visible", result.visible)

proc `%`*(cp: CollectiblePreferences): JsonNode {.inline.} =
  result = newJObject()
  result["type"] = %int(cp.itemType)
  result["key"] = %cp.key
  result["position"] = %cp.position
  result["visible"] = %cp.visible

proc fromJson*(t: JsonNode, T: typedesc[CollectionSocials]): CollectionSocials {.inline.} =
  result = CollectionSocials()
  if t.kind != JNull:
    result.website = t["website"].getStr()
    result.twitterHandle = t["twitter_handle"].getStr()

proc fromJson*(t: JsonNode, T: typedesc[CollectionSocialsMessage]): CollectionSocialsMessage {.inline.} =
  result = CollectionSocialsMessage()
  result.socials = fromJson(t["socials"], CollectionSocials)
  result.id = fromJson(t["id"], ContractID)
