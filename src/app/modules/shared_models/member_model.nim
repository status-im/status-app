import nimqml, tables, std/strformat, sequtils, sugar
# TODO: use generics to remove duplication between user_model and member_model

import app/global/global_singleton
import ../../../app_service/common/types
import ../../../app_service/service/contacts/dto/[contacts, contact_details]
import member_item
import contacts_utils
import model_utils

type
  ModelRole {.pure.} = enum
    PubKey = UserRole + 1
    CompressedPubKey
    IsCurrentUser
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
    TrustStatus
    IsBlocked
    ContactRequest
    MemberRole
    Joined
    RequestToJoinId
    RequestToJoinLoading
    AirdropAddress
    MembershipRequestState
    EmojiHash

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[MemberItem]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup

  proc countChanged(self: Model) {.signal.}

  proc setItems*(self: Model, items: seq[MemberItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc getItems*(self: Model): seq[MemberItem] =
    self.items

  proc `$`*(self: Model): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""Member Model:
      [{i}]:({$self.items[i]})
      """

  proc getCount*(self: Model): int {.slot.} =
    self.items.len

  QtProperty[int]count:
    read = getCount
    notify = countChanged

  method rowCount*(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.PubKey.int: "pubKey",
      ModelRole.CompressedPubKey.int: "compressedPubKey",
      ModelRole.IsCurrentUser.int: "isCurrentUser",
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
      ModelRole.TrustStatus.int: "trustStatus",
      ModelRole.IsBlocked.int: "isBlocked",
      ModelRole.ContactRequest.int: "contactRequest",
      ModelRole.MemberRole.int: "memberRole",
      ModelRole.Joined.int: "joined",
      ModelRole.RequestToJoinId.int: "requestToJoinId",
      ModelRole.RequestToJoinLoading.int: "requestToJoinLoading",
      ModelRole.AirdropAddress.int: "airdropAddress",
      ModelRole.MembershipRequestState.int: "membershipRequestState",
      ModelRole.EmojiHash.int: "emojiHash"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.PubKey:
      result = newQVariant(item.pubKey)
    of ModelRole.CompressedPubKey:
      result = newQVariant(compressPk(item.pubKey))
    of ModelRole.IsCurrentUser:
      result = newQVariant(item.isCurrentUser)
    of ModelRole.DisplayName:
      result = newQVariant(item.displayName)
    of ModelRole.UsesDefaultName:
      result = newQVariant(item.usesDefaultName)
    of ModelRole.PreferredDisplayName:
      return newQVariant(resolvePreferredDisplayName(
        item.localNickname, item.ensName, item.displayName, item.alias))
    of ModelRole.EnsName:
      result = newQVariant(item.ensName)
    of ModelRole.IsEnsVerified:
      result = newQVariant(item.isEnsVerified)
    of ModelRole.LocalNickname:
      result = newQVariant(item.localNickname)
    of ModelRole.Alias:
      if item.alias == "":
        item.alias = singletonInstance.utils.generateAlias(item.pubKey)
      result = newQVariant(item.alias)
    of ModelRole.Icon:
      result = newQVariant(item.icon)
    of ModelRole.ColorId:
      if item.colorId == 0:
        item.colorId = singletonInstance.utils.getColorId(item.pubKey)
      result = newQVariant(item.colorId)
    of ModelRole.OnlineStatus:
      result = newQVariant(item.onlineStatus.int)
    of ModelRole.IsContact:
      result = newQVariant(item.isContact)
    of ModelRole.IsVerified:
      result = newQVariant(not item.isCurrentUser and item.trustStatus == TrustStatus.Trusted)
    of ModelRole.IsUntrustworthy:
      result = newQVariant(not item.isCurrentUser and item.trustStatus == TrustStatus.Untrustworthy)
    of ModelRole.TrustStatus:
      result = newQVariant(item.trustStatus.int)
    of ModelRole.IsBlocked:
      result = newQVariant(item.isBlocked)
    of ModelRole.ContactRequest:
      result = newQVariant(item.contactRequest.int)
    of ModelRole.MemberRole:
      result = newQVariant(item.memberRole.int)
    of ModelRole.Joined:
      result = newQVariant(item.joined)
    of ModelRole.RequestToJoinId:
      result = newQVariant(item.requestToJoinId)
    of ModelRole.RequestToJoinLoading:
      result = newQVariant(item.requestToJoinLoading)
    of ModelRole.AirdropAddress:
      result = newQVariant(item.airdropAddress)
    of ModelRole.MembershipRequestState:
      result = newQVariant(item.membershipRequestState.int)
    of ModelRole.EmojiHash:
      result = newQVariant(item.emojiHash)

  proc addItem*(self: Model, item: MemberItem) =
    let modelIndex = newQModelIndex()
    defer: modelIndex.delete
    self.beginInsertRows(modelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()

  proc findIndexForMember*(self: Model, pubKey: string): int =
    for i in 0 ..< self.items.len:
      if self.items[i].pubKey == pubKey:
        return i

    return -1

  proc getMemberItemByIndex*(self: Model, ind: int): MemberItem =
    if ind >= 0 and ind < self.items.len:
      return self.items[ind]

  proc getMemberItem*(self: Model, pubKey: string): MemberItem =
    let ind = self.findIndexForMember(pubKey)
    if ind != -1:
      return self.items[ind]

  proc hasMember*(self: Model, pubKey: string): bool {.slot.} =
    let ind = self.findIndexForMember(pubKey)
    return ind != -1

  proc removeItemWithIndex(self: Model, index: int) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.endRemoveRows()
    self.countChanged()

  proc removeAllItems(self: Model) =
    if self.items.len <= 0:
      return

    self.beginResetModel()
    self.items = @[]
    self.endResetModel()
    self.countChanged()

  # TODO: rename me to removeItemByPubkey
  proc removeItemById*(self: Model, pubKey: string) =
    let ind = self.findIndexForMember(pubKey)
    if ind == -1:
      return

    self.removeItemWithIndex(ind)

  proc addItems*(self: Model, items: seq[MemberItem]) =
    if items.len == 0:
      return

    let modelIndex = newQModelIndex()
    defer: modelIndex.delete

    let first = self.items.len
    let last = first + items.len - 1

    self.beginInsertRows(modelIndex, first, last)
    self.items.add(items)
    self.endInsertRows()
    self.countChanged()

  proc isContactWithIdAdded*(self: Model, id: string): bool =
    return self.findIndexForMember(id) != -1

  proc setName*(self: Model, pubKey: string, displayName: string, ensName: string, localNickname: string) =
    let ind = self.findIndexForMember(pubKey)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    let preferredDisplayNameChanged =
      resolvePreferredDisplayName(self.items[ind].localNickname, self.items[ind].ensName, self.items[ind].displayName, self.items[ind].alias) !=
      resolvePreferredDisplayName(localNickname, ensName, displayName, self.items[ind].alias)

    let usesDefaultName = resolveUsesDefaultName(localNickname, ensName, displayName)

    updateRole(displayName, DisplayName)
    updateRole(ensName, EnsName)
    updateRole(localNickname, LocalNickname)
    updateRole(usesDefaultName, UsesDefaultName)

    if roles.len == 0:
      return

    if preferredDisplayNameChanged:
      roles.add(ModelRole.PreferredDisplayName.int)

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, roles)

  proc setIcon*(self: Model, pubKey: string, icon: string) =
    let ind = self.findIndexForMember(pubKey)
    if ind == -1:
      return

    if self.items[ind].icon == icon:
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
      isContact: bool,
      isBlocked: bool,
      memberRole: MemberRole,
      joined: bool,
      membershipRequestState: MembershipRequestState = MembershipRequestState.None,
      trustStatus: TrustStatus,
      contactRequest: ContactRequest,
      callDataChanged: bool = true,
    ): seq[int] =
    let ind = self.findIndexForMember(pubKey)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    let preferredDisplayNameChanged =
      resolvePreferredDisplayName(self.items[ind].localNickname, self.items[ind].ensName, self.items[ind].displayName, self.items[ind].alias) !=
      resolvePreferredDisplayName(localNickname, ensName, displayName, self.items[ind].alias)

    let trustStatusChanged = trustStatus != self.items[ind].trustStatus
    let usesDefaultName = resolveUsesDefaultName(localNickname, ensName, displayName)

    updateRole(displayName, DisplayName)
    updateRole(usesDefaultName, UsesDefaultName)
    updateRole(ensName, EnsName)
    updateRole(localNickname, LocalNickname)
    updateRole(isEnsVerified, IsEnsVerified)
    updateRole(alias, Alias)
    updateRole(icon, Icon)
    updateRole(isContact, IsContact)
    updateRole(memberRole, MemberRole)
    updateRole(joined, Joined)
    updateRole(trustStatus, TrustStatus)
    updateRole(isBlocked, IsBlocked)
    updateRole(contactRequest, ContactRequest)

    var updatedMembershipRequestState = membershipRequestState
    if updatedMembershipRequestState == MembershipRequestState.None:
      updatedMembershipRequestState = self.items[ind].membershipRequestState

    updateRoleWithValue(membershipRequestState, MembershipRequestState, updatedMembershipRequestState)

    if preferredDisplayNameChanged:
      roles.add(ModelRole.PreferredDisplayName.int)

    if trustStatusChanged:
      roles.add(ModelRole.IsUntrustworthy.int)
      roles.add(ModelRole.IsVerified.int)

    if roles.len == 0:
      return

    if callDataChanged:
      let index = self.createIndex(ind, 0, nil)
      defer: index.delete
      self.dataChanged(index, index, roles)

    return roles

  proc updateItems*(self: Model, items: seq[MemberItem]) =
    var startIndex = -1
    var endIndex = -1
    var allRoles: seq[int] = @[]
    for item in items:
      let itemIndex = self.findIndexForMember(item.pubKey)
      if itemIndex == -1:
        continue
      let roles = self.updateItem(
        item.pubKey,
        item.displayName,
        item.ensName,
        item.isEnsVerified,
        item.localNickname,
        item.alias,
        item.icon,
        item.isContact,
        item.isBlocked,
        item.memberRole,
        item.joined,
        item.membershipRequestState,
        item.trustStatus,
        item.contactRequest,
        callDataChanged = false,
      )

      if roles.len > 0:
        if startIndex == -1:
          startIndex = itemIndex
        endIndex = itemIndex
        allRoles = concat(allRoles, roles)

    if allRoles.len == 0:
      return

    let startModelIndex = self.createIndex(startIndex, 0, nil)
    let endModelIndex = self.createIndex(endIndex, 0, nil)
    defer: startModelIndex.delete
    defer: endModelIndex.delete
    self.dataChanged(startModelIndex, endModelIndex, allRoles)


  proc updateToTheseItems*(self: Model, items: seq[MemberItem]) =
    if items.len == 0:
      self.removeAllItems()
      return

    # Check for removals
    var itemsToRemove: seq[string] = @[]
    for oldItem in self.items:
      var found = false
      for newItem in items:
        if oldItem.pubKey == newItem.pubKey:
          found = true
          break
      if not found:
        itemsToRemove.add(oldItem.pubKey)
    
    for itemToRemove in itemsToRemove:
      self.removeItemById(itemToRemove)

    var itemsToAdd: seq[MemberItem] = @[]
    var itemsToUpdate: seq[MemberItem] = @[]

    for item in items:
      let ind = self.findIndexForMember(item.pubKey)
      if ind == -1:
        # Item does not exist, we add it
        itemsToAdd.add(item)
        continue

      itemsToUpdate.add(item)

    if itemsToUpdate.len > 0:
      self.updateItems(itemsToUpdate)

    if itemsToAdd.len > 0:
      self.addItems(itemsToAdd)

  proc updateItem*(
      self: Model,
      pubKey: string,
      displayName: string,
      ensName: string,
      isEnsVerified: bool,
      localNickname: string,
      alias: string,
      icon: string,
      isContact: bool,
      isBlocked: bool,
      trustStatus: TrustStatus,
      contactRequest: ContactRequest
    ) =
    let ind = self.findIndexForMember(pubKey)
    if ind == -1:
      return

    discard self.updateItem(
      pubKey,
      displayName,
      ensName,
      isEnsVerified,
      localNickname,
      alias,
      icon,
      isContact,
      isBlocked,
      memberRole = self.items[ind].memberRole,
      joined = self.items[ind].joined,
      self.items[ind].membershipRequestState,
      trustStatus,
      contactRequest,
    )

  proc setOnlineStatus*(self: Model, pubKey: string, onlineStatus: OnlineStatus) =
    let idx = self.findIndexForMember(pubKey)
    if idx == -1:
      return

    if self.items[idx].onlineStatus == onlineStatus:
      return

    self.items[idx].onlineStatus = onlineStatus
    let index = self.createIndex(idx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[
      ModelRole.OnlineStatus.int
    ])

  proc setAirdropAddress*(self: Model, pubKey: string, airdropAddress: string) =
    let idx = self.findIndexForMember(pubKey)
    if idx == -1:
      return

    if self.items[idx].airdropAddress == airdropAddress:
      return

    self.items[idx].airdropAddress = airdropAddress
    let index = self.createIndex(idx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[
      ModelRole.AirdropAddress.int
    ])

  proc getAirdropAddressForMember*(self: Model, pubKey: string): string =
    let idx = self.findIndexForMember(pubKey)
    if idx == -1:
      return ""

    return self.items[idx].airdropAddress

# TODO: rename me to getItemsAsPubkeys
  proc getItemIds*(self: Model): seq[string] =
    return self.items.map(i => i.pubKey)

  proc updateLoadingState*(self: Model, memberKey: string, requestToJoinLoading: bool) =
    let idx = self.findIndexForMember(memberKey)
    if idx == -1:
      return

    if self.items[idx].requestToJoinLoading == requestToJoinLoading:
      return

    self.items[idx].requestToJoinLoading = requestToJoinLoading
    let index = self.createIndex(idx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[
      ModelRole.RequestToJoinLoading.int
    ])

  proc updateMembershipStatus*(self: Model, memberKey: string, membershipRequestState: MembershipRequestState) {.inline.} =
    let idx = self.findIndexForMember(memberKey)
    if idx == -1:
      return

    if self.items[idx].membershipRequestState == membershipRequestState:
      return

    self.items[idx].membershipRequestState = membershipRequestState
    let index = self.createIndex(idx, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[
      ModelRole.MembershipRequestState.int
    ])

  proc getNewMembers*(self: Model, pubkeys: seq[string]): seq[string] = 
    for pubkey in pubkeys:
      var found = false
      for item in self.items:
        if item.pubKey == pubkey:
          found = true
          break
      if not found:
        result.add(pubkey)

  proc createMemberItemFromDtos*(
      contactDetails: ContactDetails,
      status: OnlineStatus,
      state: MembershipRequestState,
      requestId: string = "",
      role: MemberRole,
      airdropAddress: string = "",
      joined: bool = false,
      ): MemberItem =
    return initMemberItem(
      pubKey = contactDetails.dto.id,
      displayName = contactDetails.dto.displayName,
      usesDefaultName = resolveUsesDefaultName(
        contactDetails.dto.localNickname,
        contactDetails.dto.name,
        contactDetails.dto.displayName,
      ),
      ensName = contactDetails.dto.name,
      isEnsVerified = contactDetails.dto.ensVerified,
      localNickname = contactDetails.dto.localNickname,
      alias = contactDetails.dto.alias,
      icon = contactDetails.icon,
      colorId = contactDetails.colorId,
      onlineStatus = status,
      isContact = contactDetails.dto.isContact,
      isBlocked = contactDetails.dto.isBlocked,
      isCurrentUser = contactDetails.isCurrentUser,
      trustStatus = contactDetails.dto.trustStatus,
      contactRequest = toContactStatus(contactDetails.dto.contactRequestState),
      memberRole = role,
      membershipRequestState = state,
      requestToJoinId = requestId,
      airdropAddress = airdropAddress,
      joined = joined,
    )

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

