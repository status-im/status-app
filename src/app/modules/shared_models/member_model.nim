import nimqml, tables, std/strformat, algorithm, sequtils, sets, sugar
# TODO: use generics to remove duplication between user_model and member_model

import ../../../app_service/common/types
import ../../../app_service/service/contacts/dto/[contacts, contact_details]
import member_item
import model_utils

when defined(QT_MODEL_SPY):
  import ../shared/qt_model_spy

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
    DeclineRequestToJoinLoading
    AirdropAddress
    MembershipRequestState
    EmojiHash

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[MemberItem]
      # O(1) pubkey -> row index lookup for hasMember and the various per-pubkey
      # update procs. Maintained by every mutation below.
      pubKeyIndex: Table[string, int]
      # Revealed airdrop addresses can arrive before the corresponding member
      # is inserted into the model. Keep them until that member is available.
      pendingAirdropAddresses: Table[string, string]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.pendingAirdropAddresses = initTable[string, string]()
    result.setup

  proc countChanged(self: Model) {.signal.}

  proc rebuildPubKeyIndex(self: Model) =
    self.pubKeyIndex.clear()
    for i, it in self.items:
      self.pubKeyIndex[it.pubKey] = i

  # The model maintains the canonical member order (see cmpCanonicalOrder in
  # user_item) as an invariant: sorted on population, kept sorted via granular
  # inserts and moves on every mutation. Consumers bind directly — no proxy
  # sorting above this model.
  proc cmpMembers(a, b: MemberItem): int =
    cmpCanonicalOrder(a, b)

  # Move row `ind` to where the canonical order wants it. The O(n) scan is fine:
  # every caller already paid an O(n)-class table update, and it runs once per
  # member event.
  proc repositionRow(self: Model, ind: int) =
    if ind < 0 or ind >= self.items.len:
      return
    let item = self.items[ind]
    var dest = 0
    for i in 0 ..< self.items.len:
      if i != ind and cmpMembers(self.items[i], item) < 0:
        inc dest
    if dest == ind:
      return

    # Qt wants destinationChild in pre-move coordinates: moving down, the
    # target slot is past the row's own current position.
    let destChild = if dest > ind: dest + 1 else: dest
    let parentIndex = newQModelIndex()
    defer: parentIndex.delete
    when defined(QT_MODEL_SPY):
      recordBeginMoveRows(ind, ind, destChild)
    self.beginMoveRows(parentIndex, ind, ind, parentIndex, destChild)
    self.items.delete(ind)
    self.items.insert(item, dest)
    for i in min(ind, dest) .. max(ind, dest):
      self.pubKeyIndex[self.items[i].pubKey] = i
    self.endMoveRows()
    when defined(QT_MODEL_SPY):
      recordEndMoveRows()

  proc applyPendingAirdropAddress(self: Model, item: MemberItem) =
    if not self.pendingAirdropAddresses.hasKey(item.pubKey):
      return

    item.airdropAddress = self.pendingAirdropAddresses[item.pubKey]
    self.pendingAirdropAddresses.del(item.pubKey)

  proc setItems*(self: Model, items: seq[MemberItem]) =
    when defined(QT_MODEL_SPY):
      recordBeginResetModel()
    self.beginResetModel()
    var sortedItems = items
    sortedItems.sort(cmpMembers)
    self.items = sortedItems
    self.rebuildPubKeyIndex()
    for item in self.items:
      self.applyPendingAirdropAddress(item)
    self.endResetModel()
    when defined(QT_MODEL_SPY):
      recordEndResetModel()
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
      ModelRole.DeclineRequestToJoinLoading.int: "declineRequestToJoinLoading",
      ModelRole.AirdropAddress.int: "airdropAddress",
      ModelRole.MembershipRequestState.int: "membershipRequestState",
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
    of ModelRole.IsCurrentUser:
      result = newQVariant(item.isCurrentUser)
    of ModelRole.DisplayName:
      result = newQVariant(item.displayName)
    of ModelRole.UsesDefaultName:
      result = newQVariant(item.usesDefaultName)
    of ModelRole.PreferredDisplayName:
      result = newQVariant(item.preferredDisplayName)
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
    of ModelRole.DeclineRequestToJoinLoading:
      result = newQVariant(item.declineRequestToJoinLoading)
    of ModelRole.AirdropAddress:
      result = newQVariant(item.airdropAddress)
    of ModelRole.MembershipRequestState:
      result = newQVariant(item.membershipRequestState.int)
    of ModelRole.EmojiHash:
      result = newQVariant(item.emojiHash)

  proc addItems*(self: Model, items: seq[MemberItem])

  proc addItem*(self: Model, item: MemberItem) =
    self.addItems(@[item])

  proc findIndexForMember*(self: Model, pubKey: string): int =
    return self.pubKeyIndex.getOrDefault(pubKey, -1)

  proc getMemberItemByIndex*(self: Model, ind: int): MemberItem =
    if ind >= 0 and ind < self.items.len:
      return self.items[ind]

  proc getMemberItem*(self: Model, pubKey: string): MemberItem =
    let ind = self.findIndexForMember(pubKey)
    if ind != -1:
      return self.items[ind]

  proc hasMember*(self: Model, pubKey: string): bool {.slot.} =
    return self.pubKeyIndex.hasKey(pubKey)


  proc removeItemWithIndex(self: Model, index: int) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    let removedPubKey = self.items[index].pubKey
    when defined(QT_MODEL_SPY):
      recordBeginRemoveRows(index, index)
    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.pubKeyIndex.del(removedPubKey)
    self.pendingAirdropAddresses.del(removedPubKey)
    # seq.delete shifts every later entry left by one — reflect that in the index.
    for v in self.pubKeyIndex.mvalues:
      if v > index:
        dec v
    self.endRemoveRows()
    when defined(QT_MODEL_SPY):
      recordEndRemoveRows()
    self.countChanged()

  proc removeAllItems(self: Model) =
    if self.items.len <= 0:
      return

    when defined(QT_MODEL_SPY):
      recordBeginResetModel()
    self.beginResetModel()
    self.items = @[]
    self.pubKeyIndex.clear()
    self.endResetModel()
    when defined(QT_MODEL_SPY):
      recordEndResetModel()
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

    var newItems: seq[MemberItem] = @[]
    var batchKeys = initHashSet[string]()
    for it in items:
      if self.pubKeyIndex.hasKey(it.pubKey) or batchKeys.contains(it.pubKey):
        continue
      batchKeys.incl(it.pubKey)
      self.applyPendingAirdropAddress(it)
      newItems.add(it)

    if newItems.len == 0:
      return

    # Merge the sorted batch into the sorted model as contiguous insert runs —
    # one beginInsertRows per run instead of one per item.
    newItems.sort(cmpMembers)

    let modelIndex = newQModelIndex()
    defer: modelIndex.delete

    var i = 0
    while i < newItems.len:
      let pos = self.items.lowerBound(newItems[i], cmpMembers)
      var j = i + 1
      while j < newItems.len and
          (pos == self.items.len or cmpMembers(newItems[j], self.items[pos]) < 0):
        inc j

      when defined(QT_MODEL_SPY):
        recordBeginInsertRows(pos, pos + (j - i) - 1)
      self.beginInsertRows(modelIndex, pos, pos + (j - i) - 1)
      self.items = concat(self.items[0 ..< pos], newItems[i ..< j], self.items[pos .. ^1])
      self.endInsertRows()
      when defined(QT_MODEL_SPY):
        recordEndInsertRows()
      i = j

    self.rebuildPubKeyIndex()
    self.countChanged()

  proc isContactWithIdAdded*(self: Model, id: string): bool =
    return self.findIndexForMember(id) != -1

  proc setName*(self: Model, pubKey: string, displayName: string, ensName: string, localNickname: string) =
    updateItemRolesAndNotify self.findIndexForMember(pubKey):
      let previousPreferredDisplayName = self.items[ind].preferredDisplayName
      let previousUsesDefaultName = self.items[ind].usesDefaultName

      updateRole(displayName)
      updateRole(ensName)
      updateRole(localNickname)

      addChangedRole(roles, previousPreferredDisplayName, self.items[ind].preferredDisplayName, ModelRole.PreferredDisplayName.int): discard
      addChangedRole(roles, previousUsesDefaultName, self.items[ind].usesDefaultName, ModelRole.UsesDefaultName.int): discard
    if roles.len > 0:
      self.repositionRow(ind)

  proc setIcon*(self: Model, pubKey: string, icon: string) =
    updateItemRolesAndNotify self.findIndexForMember(pubKey):
      updateRole(icon)

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

    let previousPreferredDisplayName = self.items[ind].preferredDisplayName
    let previousUsesDefaultName = self.items[ind].usesDefaultName
    let previousTrustStatus = self.items[ind].trustStatus

    updateRole(displayName)
    updateRole(ensName)
    updateRole(localNickname)
    updateRole(isEnsVerified)
    # `alias` is deterministic from the pubkey — preserve any previously
    # resolved value when the incoming alias is empty (typical for
    # `getContactDetails` placeholders that haven't been enriched yet).
    updateRolePreserveOnEmpty(alias, Alias)
    updateRole(icon)
    updateRole(isContact)
    updateRole(memberRole)
    updateRole(joined)
    updateRole(trustStatus)
    updateRole(isBlocked)
    updateRole(contactRequest)

    var updatedMembershipRequestState = membershipRequestState
    if updatedMembershipRequestState == MembershipRequestState.None:
      updatedMembershipRequestState = self.items[ind].membershipRequestState

    updateRoleWithValue(membershipRequestState, updatedMembershipRequestState)

    addChangedRole(roles, previousPreferredDisplayName, self.items[ind].preferredDisplayName, ModelRole.PreferredDisplayName.int): discard
    addChangedRole(roles, previousUsesDefaultName, self.items[ind].usesDefaultName, ModelRole.UsesDefaultName.int): discard
    addChangedRole(roles, previousTrustStatus, trustStatus, ModelRole.IsUntrustworthy.int): discard
    addChangedRole(roles, previousTrustStatus, trustStatus, ModelRole.IsVerified.int): discard

    result = roles

    if roles.len > 0:
      if callDataChanged:
        let modelIndex = self.createIndex(ind, 0, nil)
        defer: modelIndex.delete
        self.dataChanged(modelIndex, modelIndex, roles)
      self.repositionRow(ind)

  proc updateItems*(self: Model, items: seq[MemberItem]) =
    for item in items:
      discard self.updateItem(
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
      )


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
    updateItemRolesAndNotify self.findIndexForMember(pubKey):
      updateRole(onlineStatus)
    if roles.len > 0:
      self.repositionRow(ind)

  proc setAirdropAddress*(self: Model, pubKey: string, airdropAddress: string) =
    let ind = self.findIndexForMember(pubKey)
    if ind == -1:
      if airdropAddress.len == 0:
        self.pendingAirdropAddresses.del(pubKey)
      else:
        self.pendingAirdropAddresses[pubKey] = airdropAddress
      return

    self.pendingAirdropAddresses.del(pubKey)
    updateRolesAndNotify:
      updateRole(airdropAddress)

  proc getAirdropAddressForMember*(self: Model, pubKey: string): string =
    let idx = self.findIndexForMember(pubKey)
    if idx == -1:
      return ""

    return self.items[idx].airdropAddress

# TODO: rename me to getItemsAsPubkeys
  proc getItemIds*(self: Model): seq[string] =
    return self.items.map(i => i.pubKey)

  proc updateLoadingState*(self: Model, memberKey: string, requestToJoinLoading: bool) =
    updateItemRolesAndNotify self.findIndexForMember(memberKey):
      updateRole(requestToJoinLoading)

  proc updateDeclineLoadingState*(self: Model, memberKey: string, declineRequestToJoinLoading: bool) =
    updateItemRolesAndNotify self.findIndexForMember(memberKey):
      updateRole(declineRequestToJoinLoading)

  proc updateMembershipStatus*(self: Model, memberKey: string, membershipRequestState: MembershipRequestState) {.inline.} =
    updateItemRolesAndNotify self.findIndexForMember(memberKey):
      updateRole(membershipRequestState)

  proc getNewMembers*(self: Model, pubkeys: seq[string]): seq[string] =
    for pubkey in pubkeys:
      if not self.pubKeyIndex.hasKey(pubkey):
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
      compressedPubKey = contactDetails.dto.compressedPubKey,
      emojiHash = contactDetails.dto.emojiHash,
    )

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
