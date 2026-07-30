import nimqml, tables

import app/modules/shared_models/model_utils
import app/modules/shared/model_sync
import ./collectibles_selector_item
export collectibles_selector_item

# The `filteredFlatModel` view: input-shaped collectible rows filtered to the
# account + chains with per-account balance >= 1, joined with their network. The
# send modal reads it for deep-link resolution (ModelEntry over key + chainId) and
# the flat delegates. A terminal QAbstractListModel; the parent
# CollectiblesSelectorModel pushes fresh rows via setRows(), diffed keyed by
# key + chainId so a balance tick is a single-row dataChanged (no reset).

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    Uid                    # same value as Key; SimpleSendModal reads item.uid
    ChainId
    CollectionUid
    ContractAddress
    TokenId
    TokenType
    Name
    CollectionName
    MediaUrl
    ImageUrl
    Icon
    IconUrl
    ChainName
    CommunityId
    CommunityName
    CommunityImage
    CommunityPrivilegesLevel
    Balance

QtObject:
  type
    CollectiblesSelectorFlatModel* = ref object of QAbstractListModel
      items: seq[FlatCollectible]

  proc setup(self: CollectiblesSelectorFlatModel)
  proc delete(self: CollectiblesSelectorFlatModel)
  proc newCollectiblesSelectorFlatModel*(
      items: seq[FlatCollectible] = @[]): CollectiblesSelectorFlatModel =
    new(result, delete)
    result.setup
    result.items = items

  proc countChanged(self: CollectiblesSelectorFlatModel) {.signal.}
  proc getCount(self: CollectiblesSelectorFlatModel): int {.slot.} =
    return self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: CollectiblesSelectorFlatModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: CollectiblesSelectorFlatModel): Table[int, string] =
    {
      ModelRole.Key.int: "key",
      ModelRole.Uid.int: "uid",
      ModelRole.ChainId.int: "chainId",
      ModelRole.CollectionUid.int: "collectionUid",
      ModelRole.ContractAddress.int: "contractAddress",
      ModelRole.TokenId.int: "tokenId",
      ModelRole.TokenType.int: "tokenType",
      ModelRole.Name.int: "name",
      ModelRole.CollectionName.int: "collectionName",
      ModelRole.MediaUrl.int: "mediaUrl",
      ModelRole.ImageUrl.int: "imageUrl",
      ModelRole.Icon.int: "icon",
      ModelRole.IconUrl.int: "iconUrl",
      ModelRole.ChainName.int: "chainName",
      ModelRole.CommunityId.int: "communityId",
      ModelRole.CommunityName.int: "communityName",
      ModelRole.CommunityImage.int: "communityImage",
      ModelRole.CommunityPrivilegesLevel.int: "communityPrivilegesLevel",
      ModelRole.Balance.int: "balance",
    }.toTable

  method data(self: CollectiblesSelectorFlatModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.rowCount(), role, ModelRole)
    let item = self.items[index.row]
    case role.ModelRole:
    of ModelRole.Key: return newQVariant(item.key)
    of ModelRole.Uid: return newQVariant(item.key)
    of ModelRole.ChainId: return newQVariant(item.chainId)
    of ModelRole.CollectionUid: return newQVariant(item.collectionUid)
    of ModelRole.ContractAddress: return newQVariant(item.contractAddress)
    of ModelRole.TokenId: return newQVariant(item.tokenId)
    of ModelRole.TokenType: return newQVariant(item.tokenType)
    of ModelRole.Name: return newQVariant(item.name)
    of ModelRole.CollectionName: return newQVariant(item.collectionName)
    of ModelRole.MediaUrl: return newQVariant(item.mediaUrl)
    of ModelRole.ImageUrl: return newQVariant(item.imageUrl)
    of ModelRole.Icon: return newQVariant(item.icon)
    of ModelRole.IconUrl: return newQVariant(item.iconUrl)
    of ModelRole.ChainName: return newQVariant(item.chainName)
    of ModelRole.CommunityId: return newQVariant(item.communityId)
    of ModelRole.CommunityName: return newQVariant(item.communityName)
    of ModelRole.CommunityImage: return newQVariant(item.communityImage)
    of ModelRole.CommunityPrivilegesLevel: return newQVariant(item.communityPrivilegesLevel)
    of ModelRole.Balance: return newQVariant(item.balance)

  proc syncKey(it: FlatCollectible): string =
    it.key & "@" & $it.chainId

  proc syncRoles(o, n: FlatCollectible): seq[int] =
    # Only mutable roles are diffed. key/uid (identity), chainId, tokenId,
    # tokenType, collectionUid, contractAddress are immutable for a given
    # key@chainId row, so a value change there means a different row (handled as
    # remove+insert by the id-keyed sync), never an in-place dataChanged.
    result = @[]
    if o.name != n.name: result.add(ModelRole.Name.int)
    if o.icon != n.icon: result.add(ModelRole.Icon.int)
    if o.iconUrl != n.iconUrl: result.add(ModelRole.IconUrl.int)
    if o.chainName != n.chainName: result.add(ModelRole.ChainName.int)
    if o.balance != n.balance: result.add(ModelRole.Balance.int)
    if o.communityName != n.communityName: result.add(ModelRole.CommunityName.int)
    if o.communityImage != n.communityImage: result.add(ModelRole.CommunityImage.int)

  proc setRows*(self: CollectiblesSelectorFlatModel, rows: seq[FlatCollectible]) =
    self.modelSync(self.items, rows)

  proc setup(self: CollectiblesSelectorFlatModel) =
    self.QAbstractListModel.setup

  proc delete(self: CollectiblesSelectorFlatModel) =
    self.QAbstractListModel.delete

  when defined(testing) or defined(QT_MODEL_SPY):
    proc keysInOrder*(self: CollectiblesSelectorFlatModel): seq[string] =
      for it in self.items: result.add(it.key)
    proc balanceForKey*(self: CollectiblesSelectorFlatModel, key: string): int =
      for it in self.items:
        if it.key == key: return it.balance
      return -1
    proc tokenTypeForKey*(self: CollectiblesSelectorFlatModel, key: string): int =
      for it in self.items:
        if it.key == key: return it.tokenType
      return -1
    proc roleNamesForTest*(self: CollectiblesSelectorFlatModel): seq[string] =
      for _, name in self.roleNames(): result.add(name)
