import nimqml, tables, std/strformat, sequtils, sugar

import app_service/common/types
import app_service/service/contacts/dto/[contacts, contact_details]
import contacts_utils
import model_utils
import user_item

type
  ModelRole {.pure.} = enum
    PubKey = UserRole + 1
    CompressedPubKey
    DisplayName
    PreferredDisplayName
    UsesDefaultName
    EnsName
    IsEnsVerified
    LocalNickname
    Alias
    Icon
    ColorId
    OnlineStatus
    IsContact
    IsVerified
    IsUntrustworthy
    IsBlocked
    ContactRequest
    IsCurrentUser
    LastUpdated
    LastUpdatedLocally
    Bio
    ThumbnailImage
    LargeImage
    IsContactRequestReceived
    IsContactRequestSent
    IsRemoved
    TrustStatus
    EmojiHash

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[UserItem]
      # O(1) pubkey -> row index lookup. Maintained by every mutation
      # (setItems / addItem / addItems / removeItemWithIndex / clear).
      # Mirrors `member_model.nim`'s pubKeyIndex.
      pubKeyIndex: Table[string, int]

  # Forward declarations for ORC
  proc delete(self: Model)
  proc setup(self: Model)

  proc newModel*(): Model =
    new(result, delete)
    result.setup

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

  proc countChanged(self: Model) {.signal.}

  proc rebuildPubKeyIndex(self: Model) =
    self.pubKeyIndex.clear()
    for i, it in self.items:
      self.pubKeyIndex[it.pubKey] = i

  proc setItems*(self: Model, items: seq[UserItem]) =
    self.beginResetModel()
    self.items = items
    self.rebuildPubKeyIndex()
    self.endResetModel()
    self.countChanged()

  proc `$`*(self: Model): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""User Model:
      [{i}]:({$self.items[i]})
      """

  proc getCount*(self: Model): int {.slot.} =
    self.items.len
  QtProperty[int]count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.PubKey.int: "pubKey",
      ModelRole.CompressedPubKey.int: "compressedPubKey",
      ModelRole.DisplayName.int: "displayName",
      ModelRole.PreferredDisplayName.int: "preferredDisplayName",
      ModelRole.UsesDefaultName.int: "usesDefaultName",
      ModelRole.EnsName.int: "ensName",
      ModelRole.IsEnsVerified.int: "isEnsVerified",
      ModelRole.LocalNickname.int: "localNickname",
      ModelRole.Alias.int: "alias",
      ModelRole.Icon.int: "icon",
      ModelRole.ColorId.int: "colorId",
      ModelRole.OnlineStatus.int: "onlineStatus",
      ModelRole.IsContact.int: "isContact",
      ModelRole.IsVerified.int: "isVerified",
      ModelRole.IsUntrustworthy.int: "isUntrustworthy",
      ModelRole.IsBlocked.int: "isBlocked",
      ModelRole.ContactRequest.int: "contactRequest",
      ModelRole.IsCurrentUser.int: "isCurrentUser",
      ModelRole.LastUpdated.int: "lastUpdated",
      ModelRole.LastUpdatedLocally.int: "lastUpdatedLocally",
      ModelRole.Bio.int: "bio",
      ModelRole.ThumbnailImage.int: "thumbnailImage",
      ModelRole.LargeImage.int: "largeImage",
      ModelRole.IsContactRequestReceived.int: "isContactRequestReceived",
      ModelRole.IsContactRequestSent.int: "isContactRequestSent",
      ModelRole.IsRemoved.int: "isRemoved",
      ModelRole.TrustStatus.int: "trustStatus",
      ModelRole.EmojiHash.int: "emojiHash"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.PubKey:
      result = newQVariant(item.pubKey)
    of ModelRole.CompressedPubKey:
      result = newQVariant(item.compressedPubKey)
    of ModelRole.DisplayName:
      result = newQVariant(item.displayName)
    of ModelRole.PreferredDisplayName:
      return newQVariant(resolvePreferredDisplayName(
        item.localNickname, item.ensName, item.displayName, item.alias))
    of ModelRole.UsesDefaultName:
      result = newQVariant(resolveUsesDefaultName(item.localNickname, item.ensName, item.displayName))
    of ModelRole.EnsName:
      result = newQVariant(item.ensName)
    of ModelRole.IsEnsVerified:
      result = newQVariant(item.isEnsVerified)
    of ModelRole.LocalNickname:
      result = newQVariant(item.localNickname)
    of ModelRole.Alias:
      result = newQVariant(item.alias)
    of ModelRole.Icon:
      result = newQVariant(item.icon)
    of ModelRole.ColorId:
      result = newQVariant(item.colorId)
    of ModelRole.OnlineStatus:
      result = newQVariant(item.onlineStatus.int)
    of ModelRole.IsContact:
      result = newQVariant(item.isContact)
    of ModelRole.IsVerified:
      result = newQVariant(not item.isCurrentUser and item.trustStatus == TrustStatus.Trusted)
    of ModelRole.IsUntrustworthy:
      result = newQVariant(not item.isCurrentUser and item.trustStatus == TrustStatus.Untrustworthy)
    of ModelRole.IsBlocked:
      result = newQVariant(item.isBlocked)
    of ModelRole.ContactRequest:
      result = newQVariant(item.contactRequest.int)
    of ModelRole.IsCurrentUser:
      result = newQVariant(item.isCurrentUser)
    of ModelRole.LastUpdated:
      result = newQVariant(item.lastUpdated)
    of ModelRole.LastUpdatedLocally:
      result = newQVariant(item.lastUpdatedLocally)
    of ModelRole.Bio:
      result = newQVariant(item.bio)
    of ModelRole.ThumbnailImage:
      result = newQVariant(item.thumbnailImage)
    of ModelRole.LargeImage:
      result = newQVariant(item.largeImage)
    of ModelRole.IsContactRequestReceived:
      result = newQVariant(item.isContactRequestReceived)
    of ModelRole.IsContactRequestSent:
      result = newQVariant(item.isContactRequestSent)
    of ModelRole.IsRemoved:
      result = newQVariant(item.isRemoved)
    of ModelRole.TrustStatus:
      result = newQVariant(item.trustStatus.int)
    of ModelRole.EmojiHash:
      result = newQVariant(item.emojiHash)

    else:
      result = newQVariant()

  proc addItems*(self: Model, items: seq[UserItem]) =
    if(items.len == 0):
      return

    var newItems: seq[UserItem] = @[]
    let first = self.items.len
    for it in items:
      if self.pubKeyIndex.hasKey(it.pubKey):
        continue
      self.pubKeyIndex[it.pubKey] = first + newItems.len
      newItems.add(it)

    if newItems.len == 0:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    let last = first + newItems.len - 1
    self.beginInsertRows(parentModelIndex, first, last)
    self.items.add(newItems)
    self.endInsertRows()
    self.countChanged()

  proc findIndexByPubKey*(self: Model, pubKey: string): int =
    return self.pubKeyIndex.getOrDefault(pubKey, -1)

  proc hasUser*(self: Model, pubKey: string): bool {.slot.} =
    return self.pubKeyIndex.hasKey(pubKey)


  proc addItem*(self: Model, item: UserItem) =
    if self.pubKeyIndex.hasKey(item.pubKey):
      return

    let position = self.items.len

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginInsertRows(parentModelIndex, position, position)
    self.pubKeyIndex[item.pubKey] = position
    self.items.insert(item, position)
    self.endInsertRows()
    self.countChanged()

  proc clear*(self: Model) =
     self.beginResetModel()
     self.items = @[]
     self.pubKeyIndex.clear()
     self.endResetModel()

  proc getItemByPubKey*(self: Model, pubKey: string): UserItem =
    let ind = self.pubKeyIndex.getOrDefault(pubKey, -1)
    if ind != -1:
      return self.items[ind]

  proc removeItemWithIndex(self: Model, index: int) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    let removedPubKey = self.items[index].pubKey
    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.pubKeyIndex.del(removedPubKey)
    for v in self.pubKeyIndex.mvalues:
      if v > index:
        dec v
    self.endRemoveRows()
    self.countChanged()

  proc isContactWithIdAdded*(self: Model, id: string): bool =
    return self.findIndexByPubKey(id) != -1

  proc setName*(self: Model, pubKey: string, displayName: string,
      ensName: string, localNickname: string) =
    updateItemRolesAndNotify self.findIndexByPubKey(pubKey):
      let preferredDisplayNameChanged =
        resolvePreferredDisplayName(self.items[ind].localNickname, self.items[ind].ensName, self.items[ind].displayName, self.items[ind].alias) !=
        resolvePreferredDisplayName(localNickname, ensName, displayName, self.items[ind].alias)

      updateRole(displayName)
      updateRole(ensName)
      updateRole(localNickname)

      if preferredDisplayNameChanged:
        roles.add(ModelRole.PreferredDisplayName.int)
        roles.add(ModelRole.UsesDefaultName.int)

  proc setIcon*(self: Model, pubKey: string, icon: string) =
    let ind = self.findIndexByPubKey(pubKey)
    if(ind == -1):
      return

    self.items[ind].icon = icon

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.Icon.int])

  proc updateItem*(
      self: Model,
      pubKey: string,
      displayName: string,
      ensName: string,
      isEnsVerified: bool,
      localNickname: string,
      alias: string,
      icon: string,
      trustStatus: TrustStatus,
      onlineStatus: OnlineStatus,
      isContact: bool,
      isBlocked: bool,
      contactRequest: ContactRequest,
      lastUpdated: int64,
      lastUpdatedLocally: int64,
      bio: string,
      thumbnailImage: string,
      largeImage: string,
      isContactRequestReceived: bool,
      isContactRequestSent: bool,
      isRemoved: bool,
    ) =
    updateItemRolesAndNotify self.findIndexByPubKey(pubKey):
      let preferredDisplayNameChanged =
        resolvePreferredDisplayName(self.items[ind].localNickname, self.items[ind].ensName, self.items[ind].displayName, self.items[ind].alias) !=
        resolvePreferredDisplayName(localNickname, ensName, displayName, alias)

      let trustStatusChanged = trustStatus != self.items[ind].trustStatus

      updateRole(displayName)
      updateRole(ensName)
      updateRole(localNickname)
      # `alias` is deterministic from the pubkey — preserve if set
      updateRolePreserveOnEmpty(alias, Alias)
      updateRole(icon)
      updateRole(trustStatus)
      updateRole(onlineStatus)
      updateRole(isContact)
      updateRole(isBlocked)
      updateRole(contactRequest)
      updateRole(lastUpdated)
      updateRole(lastUpdatedLocally)
      updateRole(bio)
      updateRole(thumbnailImage)
      updateRole(largeImage)
      updateRole(isContactRequestReceived)
      updateRole(isContactRequestSent)
      updateRole(isRemoved)

      if preferredDisplayNameChanged:
        roles.add(ModelRole.PreferredDisplayName.int)
        roles.add(ModelRole.UsesDefaultName.int)

      if trustStatusChanged:
        roles.add(ModelRole.IsUntrustworthy.int)
        roles.add(ModelRole.IsVerified.int)

  proc updateItem*(
      self: Model,
      pubKey: string,
      displayName: string,
      ensName: string,
      isEnsVerified: bool,
      localNickname: string,
      alias: string,
      icon: string,
      trustStatus: TrustStatus,
    ) =
    let ind = self.findIndexByPubKey(pubKey)
    if ind == -1:
      return
    let item = self.items[ind]
    self.updateItem(
      pubKey,
      displayName,
      ensName,
      isEnsVerified,
      localNickname,
      alias,
      icon,
      trustStatus,
      item.onlineStatus,
      item.isContact,
      item.isBlocked,
      item.contactRequest,
      item.lastUpdated,
      item.lastUpdatedLocally,
      item.bio,
      item.thumbnailImage,
      item.largeImage,
      item.isContactRequestReceived,
      item.isContactRequestSent,
      item.isRemoved,
    )

  proc updateTrustStatus*(self: Model, pubKey: string, trustStatus: TrustStatus) =
    let ind = self.findIndexByPubKey(pubKey)
    if ind == -1:
      return

    if self.items[ind].trustStatus == trustStatus:
      return

    self.items[ind].trustStatus = trustStatus

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.TrustStatus.int, ModelRole.IsUntrustworthy.int, ModelRole.IsVerified.int])

  proc setOnlineStatus*(self: Model, pubKey: string, onlineStatus: OnlineStatus) =
    let ind = self.findIndexByPubKey(pubKey)
    if ind == -1:
      return

    if self.items[ind].onlineStatus == onlineStatus:
      return

    self.items[ind].onlineStatus = onlineStatus

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.OnlineStatus.int])


# TODO: rename me to removeItemByPubkey
  proc removeItemById*(self: Model, pubKey: string) =
    let ind = self.findIndexByPubKey(pubKey)
    if(ind == -1):
      return

    self.removeItemWithIndex(ind)

# TODO: rename me to getItemsAsPubkeys
  proc getItemIds*(self: Model): seq[string] =
    return self.items.map(i => i.pubKey)

  proc createItemFromDto*(
      contactDetails: ContactDetails,
      status: OnlineStatus,
      contactRequest: ContactRequestState,
    ): UserItem =
    return initUserItem(
      pubKey = contactDetails.dto.id,
      displayName = contactDetails.dto.displayName,
      usesDefaultName = resolveUsesDefaultName(
        contactDetails.dto.localNickname,
        contactDetails.dto.name,
        contactDetails.dto.displayName),
      ensName = contactDetails.dto.name,
      isEnsVerified = contactDetails.dto.ensVerified,
      localNickname = contactDetails.dto.localNickname,
      alias = contactDetails.dto.alias,
      icon = contactDetails.icon,
      colorId = contactDetails.colorId,
      onlineStatus = status,
      isContact = contactDetails.dto.isContact(),
      isBlocked = contactDetails.dto.isBlocked(),
      isCurrentUser = contactDetails.isCurrentUser,
      contactRequest = toContactStatus(contactRequest),
      compressedPubKey = contactDetails.dto.compressedPubKey,
      emojiHash = contactDetails.dto.emojiHash,
      lastUpdated = contactDetails.dto.lastUpdated,
      lastUpdatedLocally = contactDetails.dto.lastUpdatedLocally,
      bio = contactDetails.dto.bio,
      thumbnailImage = contactDetails.dto.image.thumbnail,
      largeImage = contactDetails.dto.image.large,
      isContactRequestReceived = contactDetails.dto.isContactRequestReceived,
      isContactRequestSent = contactDetails.dto.isContactRequestSent,
      isRemoved = contactDetails.dto.removed,
      trustStatus = contactDetails.dto.trustStatus,
    )
