import nimqml, tables, strutils, std/strformat, sequtils, stint, json
import chronicles

import ./collectibles_entry
import backend/collectibles as backend_collectibles
import backend/collectibles_types as backend_collectibles_types

type
  CollectibleRole* {.pure.} = enum
    Uid = UserRole + 1,
    ChainId
    ContractAddress
    TokenId
    Name
    ImageUrl
    MediaUrl
    MediaType
    BackgroundColor
    CollectionUid
    CollectionName
    CollectionSlug
    CollectionImageUrl
    IsLoading
    Ownership
    # Community-related roles
    CommunityId
    CommunityPrivilegesLevel
    TokenType
    Soulbound

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[CollectiblesEntry]
      hasMore: bool
      isFetching: bool
      isUpdating: bool
      isError: bool

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup
    result.items = @[]
    result.hasMore = true
    result.isUpdating = false
    result.isFetching = false
    result.isError = false

  proc `$`*(self: Model): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  proc countChanged(self: Model) {.signal.}
  proc getCount*(self: Model): int {.slot.} =
    return self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc isFetchingChanged(self: Model) {.signal.}
  proc getIsFetching*(self: Model): bool {.slot.} =
    self.isFetching
  QtProperty[bool] isFetching:
    read = getIsFetching
    notify = isFetchingChanged
  proc setIsFetching*(self: Model, value: bool) =
    if value == self.isFetching:
      return
    self.isFetching = value
    self.isFetchingChanged()

  proc isUpdatingChanged(self: Model) {.signal.}
  proc getIsUpdating*(self: Model): bool {.slot.} =
    self.isUpdating
  QtProperty[bool] isUpdating:
    read = getIsUpdating
    notify = isUpdatingChanged
  proc setIsUpdating*(self: Model, isUpdating: bool) =
    if isUpdating == self.isUpdating:
      return
    self.isUpdating = isUpdating
    self.isUpdatingChanged()

  proc isErrorChanged(self: Model) {.signal.}
  proc getIsError*(self: Model): bool {.slot.} =
    self.isError
  QtProperty[bool] isError:
    read = getIsError
    notify = isErrorChanged
  proc setIsError*(self: Model, value: bool) =
    if value == self.isError:
      return
    self.isError = value
    self.isErrorChanged()

  proc hasMoreChanged*(self: Model) {.signal.}
  proc getHasMore*(self: Model): bool {.slot.} =
    self.hasMore
  QtProperty[bool] hasMore:
    read = getHasMore
    notify = hasMoreChanged
  proc setHasMore(self: Model, hasMore: bool) =
    if hasMore == self.hasMore:
      return
    self.hasMore = hasMore
    self.hasMoreChanged()

  method canFetchMore*(self: Model, parent: QModelIndex): bool =
    return self.hasMore

  proc loadMoreItems(self: Model) {.signal.}

  proc loadMore*(self: Model) {.slot.} =
    self.loadMoreItems()

  method fetchMore*(self: Model, parent: QModelIndex) =
    self.loadMore()

  method rowCount*(self: Model, index: QModelIndex = nil): int =
    return self.getCount()

  method roleNames(self: Model): Table[int, string] =
    {
      CollectibleRole.Uid.int:"uid",
      CollectibleRole.ChainId.int:"chainId",
      CollectibleRole.ContractAddress.int:"contractAddress",
      CollectibleRole.TokenId.int:"tokenId",
      CollectibleRole.Name.int:"name",
      CollectibleRole.MediaUrl.int:"mediaUrl",
      CollectibleRole.MediaType.int:"mediaType",
      CollectibleRole.ImageUrl.int:"imageUrl",
      CollectibleRole.BackgroundColor.int:"backgroundColor",
      CollectibleRole.CollectionUid.int:"collectionUid",
      CollectibleRole.CollectionName.int:"collectionName",
      CollectibleRole.CollectionSlug.int:"collectionSlug",
      CollectibleRole.CollectionImageUrl.int:"collectionImageUrl",
      CollectibleRole.IsLoading.int:"isLoading",
      CollectibleRole.Ownership.int:"ownership",
      CollectibleRole.CommunityId.int:"communityId",
      CollectibleRole.CommunityPrivilegesLevel.int:"communityPrivilegesLevel",
      CollectibleRole.TokenType.int:"tokenType",
      CollectibleRole.Soulbound.int:"soulbound"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.getCount()):
      return
    let enumRole = role.CollectibleRole
    if index.row < self.items.len:
      let item = self.items[index.row]
      case enumRole:
      of CollectibleRole.Uid:
        result = newQVariant(item.getIDAsString())
      of CollectibleRole.ChainId:
        result = newQVariant(item.getChainID())
      of CollectibleRole.ContractAddress:
        result = newQVariant(item.getContractAddress())
      of CollectibleRole.TokenId:
        result = newQVariant(item.getTokenIDAsString())
      of CollectibleRole.Name:
        result = newQVariant(item.getName())
      of CollectibleRole.MediaUrl:
        result = newQVariant(item.getMediaURL())
      of CollectibleRole.MediaType:
        result = newQVariant(item.getMediaType())
      of CollectibleRole.ImageUrl:
        result = newQVariant(item.getImageURL())
      of CollectibleRole.BackgroundColor:
        result = newQVariant(item.getBackgroundColor())
      of CollectibleRole.CollectionUid:
        result = newQVariant(item.getCollectionIDAsString())
      of CollectibleRole.CollectionName:
        result = newQVariant(item.getCollectionName())
      of CollectibleRole.CollectionSlug:
        result = newQVariant(item.getCollectionSlug())
      of CollectibleRole.CollectionImageUrl:
        result = newQVariant(item.getCollectionImageURL())
      of CollectibleRole.IsLoading:
        result = newQVariant(false)
      of CollectibleRole.Ownership:
        result = item.getOwnershipModelAsVariant()
      of CollectibleRole.CommunityId:
        result = newQVariant(item.getCommunityId())
      of CollectibleRole.CommunityPrivilegesLevel:
        result = newQVariant(item.getCommunityPrivilegesLevel())
      of CollectibleRole.TokenType:
        result = newQVariant(item.getTokenType())
      of CollectibleRole.Soulbound:
        result = newQVariant(item.getSoulbound())
      else:
        result = newQVariant()
    else:
      result = newQVariant()

  proc resetCollectibleItems(self: Model, newItems: seq[CollectiblesEntry] = @[]) =
    self.beginResetModel()
    self.items = newItems
    self.endResetModel()
    self.countChanged()

  proc appendCollectibleItems(self: Model, newItems: seq[CollectiblesEntry]) =
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

  proc removeCollectibleItem(self: Model, idx: int) =
    if idx < 0 or idx >= self.items.len:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, idx, idx)
    self.items.delete(idx)
    self.endRemoveRows()
    self.countChanged()

  proc updateCollectibleItems(self: Model, newItems: seq[CollectiblesEntry]) =
    if len(self.items) == 0:
      # Current list is empty, just replace with new list
      self.resetCollectibleItems(newItems)
      return

    if len(newItems) == 0:
      # New list is empty, just remove all items
      self.resetCollectibleItems()
      return

    var newTable = initTable[string, int](len(newItems))
    for i in 0 ..< len(newItems):
      newTable[newItems[i].getIDAsString()] = i

    # Needs to be built in sequential index order
    var oldIndicesToRemove: seq[int] = @[]
    for idx in 0 ..< len(self.items):
      let uid = self.items[idx].getIDAsString()
      if not newTable.hasKey(uid):
        # Item in old list but not in new -> Must remove
        oldIndicesToRemove.add(idx)
      else:
        # Item both in old and new lists -> Nothing to do in the current list,
        # remove from the new list so it only holds new items.
        newTable.del(uid)

    if len(oldIndicesToRemove) > 0:
      var removedItems = 0
      for idx in oldIndicesToRemove:
        let updatedIdx = idx - removedItems
        self.removeCollectibleItem(updatedIdx)
        removedItems += 1
      self.countChanged()

    var newItemsToAdd: seq[CollectiblesEntry] = @[]
    for uid, idx in newTable:
      newItemsToAdd.add(newItems[idx])
    self.appendCollectibleItems(newItemsToAdd)

  proc getItems*(self: Model): seq[CollectiblesEntry] =
    return self.items

  proc getItemById*(self: Model, id: string): CollectiblesEntry =
    for item in self.items:
      if(cmpIgnoreCase(item.getIDAsString(), id) == 0):
        return item
    return nil

  proc setItems*(self: Model, newItems: seq[CollectiblesEntry], offset: int, hasMore: bool) =
    if offset == 0:
      self.resetCollectibleItems(newItems)
    elif offset != self.getCount():
      error "invalid offset"
      return
    else:
      self.appendCollectibleItems(newItems)
    self.setHasMore(hasMore)

  # Checks the diff between the current list and the new list, appends new items,
  # removes missing items.
  # We assume the order of the items in the input could change, and we don't care
  # about the order of the items in the model.
  proc updateItems*(self: Model, newItems: seq[CollectiblesEntry]) =
    self.updateCollectibleItems(newItems)
    self.setHasMore(false)

  proc itemsDataUpdated(self: Model) {.signal.}
  proc updateItemsData*(self: Model, updates: seq[backend_collectibles.Collectible]) =
    var anyUpdated = false
    for i in countdown(self.items.high, 0):
      let entry = self.items[i]
      for j in countdown(updates.high, 0):
        let update = updates[j]
        if entry.updateDataIfSameID(update):
          let index = self.createIndex(i, 0, nil)
          defer: index.delete
          self.dataChanged(index, index)
          anyUpdated = true
          break
    if anyUpdated:
      self.itemsDataUpdated()

  proc getImageUrl*(self: Model, id: string): string {.slot.} =
    for item in self.items:
      if(cmpIgnoreCase(item.getIDAsString(), id) == 0):
        return item.getImageUrl()
    return ""

  proc getName*(self: Model, id: string): string {.slot.} =
    for item in self.items:
      if(cmpIgnoreCase(item.getIDAsString(), id) == 0):
        return item.getName()
    return ""

  proc getUidForData*(self: Model, tokenId: string, tokenAddress: string, chainId: int): string {.slot.} =
    for item in self.items:
      if(cmpIgnoreCase(item.getTokenIDAsString(), tokenId) == 0 and cmpIgnoreCase(item.getContractAddress(), tokenAddress) == 0) and item.getChainID() == chainId:
        return item.getIDAsString()
    # Fallback, create uid from data, because it still might not be fetched
    if chainId > 0 and len(tokenAddress) > 0 and len(tokenId) > 0:
      return backend_collectibles_types.makeCollectibleUniqueID(chainId, tokenAddress, tokenId)
    return ""

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

