import nimqml, tables, strutils, std/strformat, sequtils, stint, options
import chronicles

import ./collectibles_item
import web3/eth_api_types as eth
import backend/activity as backend_activity
import backend/collectibles_types as backend_collectibles_types
import app_service/common/types

type
  CollectibleRole* {.pure.} = enum
    Uid = UserRole + 1,
    ChainId
    ContractAddress
    TokenId
    Name
    ImageUrl

QtObject:
  type
    CollectiblesModel* = ref object of QAbstractListModel
      items: seq[CollectibleItem]
      hasMore: bool

  proc delete(self: CollectiblesModel)
  proc setup(self: CollectiblesModel)
  proc newCollectiblesModel*(): CollectiblesModel =
    new(result, delete)
    result.setup
    result.items = @[]
    result.hasMore = true

  proc `$`*(self: CollectiblesModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  proc getCollectiblesCount*(self: CollectiblesModel): int =
    return self.items.len

  proc countChanged(self: CollectiblesModel) {.signal.}
  proc getCount*(self: CollectiblesModel): int {.slot.} =
    return self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc hasMoreChanged*(self: CollectiblesModel) {.signal.}
  proc getHasMore*(self: CollectiblesModel): bool {.slot.} =
    self.hasMore
  QtProperty[bool] hasMore:
    read = getHasMore
    notify = hasMoreChanged

  proc setHasMore(self: CollectiblesModel, hasMore: bool) =
    if hasMore == self.hasMore:
      return
    self.hasMore = hasMore
    self.hasMoreChanged()

  method canFetchMore*(self: CollectiblesModel, parent: QModelIndex): bool =
    return self.hasMore

  proc loadMoreItems(self: CollectiblesModel) {.signal.}

  proc loadMore*(self: CollectiblesModel) {.slot.} =
    self.loadMoreItems()

  method fetchMore*(self: CollectiblesModel, parent: QModelIndex) =
    self.loadMore()

  method rowCount*(self: CollectiblesModel, index: QModelIndex = nil): int =
    return self.getCount()

  method roleNames(self: CollectiblesModel): Table[int, string] =
    {
      CollectibleRole.Uid.int:"uid",
      CollectibleRole.ChainId.int:"chainId",
      CollectibleRole.ContractAddress.int:"contractAddress",
      CollectibleRole.TokenId.int:"tokenId",
      CollectibleRole.Name.int:"name",
      CollectibleRole.ImageUrl.int:"imageUrl",
    }.toTable

  method data(self: CollectiblesModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.getCount()):
      return

    let enumRole = role.CollectibleRole

    if index.row < self.items.len:
      let item = self.items[index.row]
      case enumRole:
      of CollectibleRole.Uid:
        result = newQVariant(item.getId())
      of CollectibleRole.ChainId:
        result = newQVariant(item.getChainId())
      of CollectibleRole.ContractAddress:
        result = newQVariant(item.getContractAddress())
      of CollectibleRole.TokenId:
        result = newQVariant(item.getTokenId().toString())
      of CollectibleRole.Name:
        result = newQVariant(item.getName())
      of CollectibleRole.ImageUrl:
        result = newQVariant(item.getImageUrl())
    else:
      error "Invalid role for loading item"
      result = newQVariant()

  proc appendCollectibleItems(self: CollectiblesModel, newItems: seq[CollectibleItem]) =
    if len(newItems) == 0:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    # Start after the current last real item
    let startIdx = self.items.len
    # End at the new last real item
    let endIdx = startIdx + newItems.len - 1

    self.beginInsertRows(parentModelIndex, startIdx, endIdx)
    self.items.insert(newItems, startIdx)
    self.endInsertRows()
    self.countChanged()

  proc removeCollectibleItems(self: CollectiblesModel) =
    if self.items.len <= 0:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    # Start from the beginning
    let startIdx = 0
    # End at the last real item
    let endIdx = startIdx + self.items.len - 1

    self.beginRemoveRows(parentModelIndex, startIdx, endIdx)
    self.items = @[]
    self.endRemoveRows()
    self.countChanged()

  proc getItems*(self: CollectiblesModel): seq[CollectibleItem] =
    return self.items

  proc setItems*(self: CollectiblesModel, newItems: seq[CollectibleItem], offset: int, hasMore: bool) =
    if offset == 0:
      self.removeCollectibleItems()
    elif offset != self.getCollectiblesCount():
      error "invalid offset"
      return

    self.appendCollectibleItems(newItems)
    self.setHasMore(hasMore)

  proc getImageUrl*(self: CollectiblesModel, id: string): string {.slot.} =
    for item in self.items:
      if(cmpIgnoreCase(item.getId(), id) == 0):
        return item.getImageUrl()
    return ""

  proc getName*(self: CollectiblesModel, id: string): string {.slot.} =
    for item in self.items:
      if(cmpIgnoreCase(item.getId(), id) == 0):
        return item.getName()
    return ""

  proc getActivityToken*(self: CollectiblesModel, id: string): backend_activity.Token =
    for item in self.items:
      if(cmpIgnoreCase(item.getId(), id) == 0):
        result.tokenType = TokenType.ERC721
        result.chainId = backend_activity.ChainId(item.getChainId())
        var contract = item.getContractAddress()
        if len(contract) > 0:
          var address: eth.Address
          address = eth.fromHex(eth.Address, contract)
          result.address = some(address)
        var tokenId = item.getTokenId()
        if tokenId > 0:
          result.tokenId = some(backend_activity.TokenId("0x" & stint.toHex(tokenId)))
        return result

    # Fallback, use data from id
    var parts = id.split("+")
    if len(parts) == 3:
      result.chainId = backend_activity.ChainId(parseInt(parts[0]))
      result.address = some(eth.fromHex(eth.Address, parts[1]))
      var tokenIdInt = u256(parseInt(parts[2]))
      result.tokenId = some(backend_activity.TokenId("0x" & stint.toHex(tokenIdInt)))

    return result

  proc getUidForData*(self: CollectiblesModel, tokenId: string, tokenAddress: string, chainId: int): string {.slot.} =
    for item in self.items:
      if(cmpIgnoreCase(item.getTokenId().toString(), tokenId) == 0 and cmpIgnoreCase(item.getContractAddress(), tokenAddress) == 0):
        return item.getId()
    # Fallback, create uid from data, because it still might not be fetched
    if chainId > 0 and len(tokenAddress) > 0 and len(tokenId) > 0:
      return backend_collectibles_types.makeCollectibleUniqueID(chainId, tokenAddress, tokenId)
    return ""

  proc delete(self: CollectiblesModel) =
    self.QAbstractListModel.delete

  proc setup(self: CollectiblesModel) =
    self.QAbstractListModel.setup

