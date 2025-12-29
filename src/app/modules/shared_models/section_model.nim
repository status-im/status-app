import nimqml, tables, strutils, std/strformat

import json

import section_item, member_model, member_item
import ../main/communities/tokens/models/[token_item, token_model]
import model_utils
import ../../../app_service/common/types

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    SectionType
    Name
    MemberRole
    IsControlNode
    Description
    IntroMessage
    OutroMessage
    Image
    BannerImageData
    Icon
    Color
    Tags
    HasNotification
    NotificationsCount
    Active
    Enabled
    Joined
    Spectated
    IsMember
    CanJoin
    CanManageUsers
    CanRequestAccess
    Access
    EnsOnly
    Muted
    MembersModel
    JoinedMembersCount
    HistoryArchiveSupportEnabled
    PinMessageAllMembersEnabled
    Encrypted
    CommunityTokensModel
    AmIBanned
    IsPendingOwnershipRequest
    ActiveMembersCount
    MembersLoaded
    TokensLoading

QtObject:
  type
    SectionModel* = ref object of QAbstractListModel
      items: seq[SectionItem]

  # Forward declarations for ORC
  proc delete(self: SectionModel)
  proc setup(self: SectionModel)

  proc newModel*(): SectionModel =
    new(result, delete)
    result.setup

  # Implementations after constructor
  proc delete(self: SectionModel) =
    self.QAbstractListModel.delete

  proc setup(self: SectionModel) =
    self.QAbstractListModel.setup

  proc `$`*(self: SectionModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i]})
      """

  proc countChanged(self: SectionModel) {.signal.}

  proc getCount(self: SectionModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: SectionModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: SectionModel): Table[int, string] =
    {
      ModelRole.Id.int:"id",
      ModelRole.SectionType.int:"sectionType",
      ModelRole.Name.int:"name",
      ModelRole.MemberRole.int: "memberRole",
      ModelRole.IsControlNode.int: "isControlNode",
      ModelRole.Description.int:"description",
      ModelRole.IntroMessage.int:"introMessage",
      ModelRole.OutroMessage.int:"outroMessage",
      ModelRole.Image.int:"image",
      ModelRole.BannerImageData.int:"bannerImageData",
      ModelRole.Icon.int:"icon",
      ModelRole.Color.int:"color",
      ModelRole.Tags.int:"tags",
      ModelRole.HasNotification.int:"hasNotification",
      ModelRole.NotificationsCount.int:"notificationsCount",
      ModelRole.Active.int:"active",
      ModelRole.Enabled.int:"enabled",
      ModelRole.Joined.int:"joined",
      ModelRole.Spectated.int:"spectated",
      ModelRole.IsMember.int:"isMember",
      ModelRole.CanJoin.int:"canJoin",
      ModelRole.CanManageUsers.int:"canManageUsers",
      ModelRole.CanRequestAccess.int:"canRequestAccess",
      ModelRole.Access.int:"access",
      ModelRole.EnsOnly.int:"ensOnly",
      ModelRole.Muted.int:"muted",
      ModelRole.MembersModel.int:"allMembers",
      ModelRole.JoinedMembersCount.int:"joinedMembersCount",
      ModelRole.HistoryArchiveSupportEnabled.int:"historyArchiveSupportEnabled",
      ModelRole.PinMessageAllMembersEnabled.int:"pinMessageAllMembersEnabled",
      ModelRole.Encrypted.int:"encrypted",
      ModelRole.CommunityTokensModel.int:"communityTokens",
      ModelRole.AmIBanned.int:"amIBanned",
      ModelRole.IsPendingOwnershipRequest.int:"isPendingOwnershipRequest",
      ModelRole.ActiveMembersCount.int:"activeMembersCount",
      ModelRole.MembersLoaded.int:"membersLoaded",
      ModelRole.TokensLoading.int:"tokensLoading",
    }.toTable

  method data(self: SectionModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Id:
      result = newQVariant(item.id)
    of ModelRole.SectionType:
      result = newQVariant(item.sectionType.int)
    of ModelRole.Name:
      result = newQVariant(item.name)
    of ModelRole.MemberRole:
      result = newQVariant(item.memberRole.int)
    of ModelRole.IsControlNode:
      result = newQVariant(item.isControlNode)
    of ModelRole.Description:
      result = newQVariant(item.description)
    of ModelRole.IntroMessage:
      result = newQVariant(item.introMessage)
    of ModelRole.OutroMessage:
      result = newQVariant(item.outroMessage)
    of ModelRole.Image:
      result = newQVariant(item.image)
    of ModelRole.BannerImageData:
      result = newQVariant(item.bannerImageData)
    of ModelRole.Icon:
      result = newQVariant(item.icon)
    of ModelRole.Color:
      result = newQVariant(item.color)
    of ModelRole.Tags:
      result = newQVariant(item.tags)
    of ModelRole.HasNotification:
      result = newQVariant(item.hasNotification)
    of ModelRole.NotificationsCount:
      result = newQVariant(item.notificationsCount)
    of ModelRole.Active:
      result = newQVariant(item.active)
    of ModelRole.Enabled:
      result = newQVariant(item.enabled)
    of ModelRole.Joined:
      result = newQVariant(item.joined)
    of ModelRole.Spectated:
      result = newQVariant(item.spectated)
    of ModelRole.IsMember:
      result = newQVariant(item.isMember)
    of ModelRole.CanJoin:
      result = newQVariant(item.canJoin)
    of ModelRole.CanManageUsers:
      result = newQVariant(item.canManageUsers)
    of ModelRole.CanRequestAccess:
      result = newQVariant(item.canRequestAccess)
    of ModelRole.Access:
      result = newQVariant(item.access)
    of ModelRole.EnsOnly:
      result = newQVariant(item.ensOnly)
    of ModelRole.Muted:
      result = newQVariant(item.muted)
    of ModelRole.MembersModel:
      result = newQVariant(item.members)
    of ModelRole.JoinedMembersCount:
      result = newQVariant(item.joinedMembersCount)
    of ModelRole.HistoryArchiveSupportEnabled:
      result = newQVariant(item.historyArchiveSupportEnabled)
    of ModelRole.PinMessageAllMembersEnabled:
      result = newQVariant(item.pinMessageAllMembersEnabled)
    of ModelRole.Encrypted:
      result = newQVariant(item.encrypted)
    of ModelRole.CommunityTokensModel:
      result = newQVariant(item.communityTokens)
    of ModelRole.AmIBanned:
      result = newQVariant(item.isBanned)
    of ModelRole.IsPendingOwnershipRequest:
      result = newQVariant(item.isPendingOwnershipRequest)
    of ModelRole.ActiveMembersCount:
      result = newQVariant(item.activeMembersCount)
    of ModelRole.MembersLoaded:
      result = newQVariant(item.membersLoaded)
    of ModelRole.TokensLoading:
      result = newQVariant(item.tokensLoading)

  proc itemExists*(self: SectionModel, id: string): bool =
    for it in self.items:
      if(it.id == id):
        return true
    return false

  proc addItem*(self: SectionModel, item: SectionItem) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    if not self.itemExists(item.id):
      self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
      self.items.add(item)
      self.endInsertRows()

      self.countChanged()

  proc addItem*(self: SectionModel, item: SectionItem, index: int) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    if not self.itemExists(item.id):
      self.beginInsertRows(parentModelIndex, index, index)
      self.items.insert(item, index)
      self.endInsertRows()

      self.countChanged()

  proc addItems*(self: SectionModel, items: seq[SectionItem]) =
    if items.len == 0:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    let first = self.items.len
    let last = first + items.len - 1
    self.beginInsertRows(parentModelIndex, first, last)
    self.items.add(items)
    self.endInsertRows()
    self.countChanged()

  proc getItemIndex*(self: SectionModel, id: string): int =
    var i = 0
    for item in self.items:
      if item.id == id:
        return i
      i.inc()
    return -1

  proc removeItem*(self: SectionModel, itemId: string) =
    let index = self.getItemIndex(itemId)
    if (index == -1):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.endRemoveRows()

    self.countChanged()

  proc setMuted*(self: SectionModel, id: string, muted: bool) = 
    let index = self.getItemIndex(id)
    if index == -1:
      return

    if self.items[index].muted == muted:
      return

    self.items[index].muted = muted 
    let dataIndex = self.createIndex(index, 0, nil)
    defer: dataIndex.delete
    self.dataChanged(dataIndex, dataIndex, @[ModelRole.Muted.int])

  proc editItem*(self: SectionModel, item: SectionItem) =
    let ind = self.getItemIndex(item.id)
    if ind == -1:
      return
    
    var roles: seq[int] = @[]

    updateRoleWithValue(name, Name, item.name)
    updateRoleWithValue(memberRole, MemberRole, item.memberRole)
    updateRoleWithValue(isControlNode, IsControlNode, item.isControlNode)
    updateRoleWithValue(description, Description, item.description)
    updateRoleWithValue(introMessage, IntroMessage, item.introMessage)
    updateRoleWithValue(outroMessage, OutroMessage, item.outroMessage)
    updateRoleWithValue(image, Image, item.image)
    updateRoleWithValue(bannerImageData, BannerImageData, item.bannerImageData)
    updateRoleWithValue(icon, Icon, item.icon)
    updateRoleWithValue(color, Color, item.color)
    updateRoleWithValue(tags, Tags, item.tags)
    updateRoleWithValue(hasNotification, HasNotification, item.hasNotification)
    updateRoleWithValue(notificationsCount, NotificationsCount, item.notificationsCount)
    updateRoleWithValue(active, Active, item.active)
    updateRoleWithValue(enabled, Enabled, item.enabled)
    updateRoleWithValue(joined, Joined, item.joined)
    updateRoleWithValue(spectated, Spectated, item.spectated)
    updateRoleWithValue(isMember, IsMember, item.isMember)
    updateRoleWithValue(canJoin, CanJoin, item.canJoin)
    updateRoleWithValue(canManageUsers, CanManageUsers, item.canManageUsers)
    updateRoleWithValue(canRequestAccess, CanRequestAccess, item.canRequestAccess)
    updateRoleWithValue(access, Access, item.access)
    updateRoleWithValue(ensOnly, EnsOnly, item.ensOnly)
    updateRoleWithValue(muted, Muted, item.muted)
    updateRoleWithValue(historyArchiveSupportEnabled, HistoryArchiveSupportEnabled, item.historyArchiveSupportEnabled)
    updateRoleWithValue(pinMessageAllMembersEnabled, PinMessageAllMembersEnabled, item.pinMessageAllMembersEnabled)
    updateRoleWithValue(encrypted, Encrypted, item.encrypted)
    updateRoleWithValue(isPendingOwnershipRequest, IsPendingOwnershipRequest, item.isPendingOwnershipRequest)
    updateRoleWithValue(activeMembersCount, ActiveMembersCount, item.activeMembersCount)
    updateRoleWithValue(joinedMembersCount, JoinedMembersCount, item.joinedMembersCount)

    self.items[ind].members.updateToTheseItems(item.members.getItems())

    if roles.len == 0:
      return

    let dataIndex = self.createIndex(ind, 0, nil)
    defer: dataIndex.delete
    self.dataChanged(dataIndex, dataIndex, roles)

  proc updateMemberItemInSections*(
      self: SectionModel,
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
      contactRequest: ContactRequest,
    ) =
    for item in self.items:
      item.members.updateItem(
        pubKey,
        displayName,
        ensName,
        isEnsVerified,
        localNickname,
        alias,
        icon,
        isContact,
        isBlocked,
        trustStatus,
        contactRequest,
      )

  proc getNthEnabledItem*(self: SectionModel, nth: int): SectionItem =
    if nth >= 0 and nth < self.items.len:
      var counter = 0
      for i in 0 ..< self.items.len:
        if self.items[i].enabled:
          if counter == nth:
            return self.items[i]
          else:
            counter = counter + 1
    return SectionItem()

  proc getItemById*(self: SectionModel, id: string): SectionItem =
    for it in self.items:
      if(it.id == id):
        return it

  proc getItemBySectionType*(self: SectionModel, sectionType: SectionType): SectionItem =
    for it in self.items:
      if(it.sectionType == sectionType):
        return it

  proc getItemEnabledBySectionType*(self: SectionModel, sectionType: int): bool {.slot.} =
    let item = self.getItemBySectionType((SectionType)sectionType)
    return not item.isEmpty() and item.enabled()

  proc setActiveSection*(self: SectionModel, id: string) =
    for i in 0 ..< self.items.len:
      if self.items[i].active:
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.items[i].active = false
        self.dataChanged(index, index, @[ModelRole.Active.int])

      if self.items[i].id == id:
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.items[i].active = true

        self.dataChanged(index, index, @[ModelRole.Active.int])

  proc sectionVisibilityUpdated*(self: SectionModel) {.signal.}

  proc notificationsCountChanged*(self: SectionModel) {.signal.}

  proc enableDisableSection(self: SectionModel, sectionType: SectionType, value: bool) =
    if sectionType != SectionType.Community:
      for i in 0 ..< self.items.len:
        if self.items[i].sectionType == sectionType:
          if self.items[i].enabled == value:
            continue
          let index = self.createIndex(i, 0, nil)
          defer: index.delete
          self.items[i].enabled = value
          self.dataChanged(index, index, @[ModelRole.Enabled.int])
    else:
      var topInd = -1
      var bottomInd = -1
      for i in 0 ..< self.items.len:
        if self.items[i].sectionType == sectionType:
          self.items[i].enabled = value
          if topInd == -1:
            topInd = i

          bottomInd = i

      let topIndex = self.createIndex(topInd, 0, nil)
      let bottomIndex = self.createIndex(bottomInd, 0, nil)
      defer: topIndex.delete
      defer: bottomIndex.delete
      self.dataChanged(topIndex, bottomIndex, @[ModelRole.Enabled.int])

    # This signal is emitted to update buttons visibility in the left navigation bar,
    # `dataChanged` signal doesn't do the job because of `DelegateModel` used in `StatusAppNavBar` component
    self.sectionVisibilityUpdated()

  proc enableSection*(self: SectionModel, sectionType: SectionType) =
    self.enableDisableSection(sectionType, true)

  proc disableSection*(self: SectionModel, sectionType: SectionType) =
    self.enableDisableSection(sectionType, false)

  proc isAMessengerItem*(item: SectionItem): bool =
    return item.sectionType == SectionType.Chat or item.sectionType == SectionType.Community

  # Count all mentions from all chat&community sections
  proc allMentionsCount*(self: SectionModel): int =
    for item in self.items:
      if item.isAMessengerItem():
        result += item.notificationsCount

  proc updateIsPendingOwnershipRequest*(self: SectionModel, id: string, isPending: bool) =
    for i in 0 ..< self.items.len:
      if self.items[i].id == id:
        let index = self.createIndex(i, 0, nil)
        defer: index.delete

        if self.items[i].isPendingOwnershipRequest == isPending:
          return

        self.items[i].setIsPendingOwnershipRequest(isPending)
        self.dataChanged(index, index, @[ModelRole.IsPendingOwnershipRequest.int])
        return

  proc updateNotifications*(self: SectionModel, id: string, hasNotification: bool, notificationsCount: int) =
    for ind in 0 ..< self.items.len:
      if self.items[ind].id == id:
        var roles: seq[int] = @[]

        updateRole(hasNotification, HasNotification)
        updateRole(notificationsCount, NotificationsCount)

        if roles.len == 0:
          return

        let index = self.createIndex(ind, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, roles)
        self.notificationsCountChanged()
        return

  proc isThereASectionWithUnreadMessages*(self: SectionModel): bool =
    for item in self.items:
      if item.isAMessengerItem() and item.hasNotification == true:
        return true
    return false

  proc appendCommunityToken*(self: SectionModel, id: string, item: TokenItem) =
    for i in 0 ..< self.items.len:
      if(self.items[i].id == id):
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.items[i].appendCommunityToken(item)
        return

  proc getSectionNameById*(self: SectionModel, sectionId: string): string {.slot.} =
    for item in self.items:
      if item.id == sectionId:
        return item.name
    
  proc getSectionByIdJson(self: SectionModel, sectionId: string): string {.slot.} =
    for item in self.items:
      if (item.id == sectionId):
        let jsonObj = %* {
          "id": item.id,
          "name": item.name,
          "memberRole": item.memberRole.int,
          "isControlNode": item.isControlNode,
          "description": item.description,
          "introMessage": item.introMessage,
          "outroMessage": item.outroMessage,
          "image": item.image,
          "bannerImageData": item.bannerImageData,
          "icon": item.icon,
          "color": item.color,
          "tags": item.tags,
          "hasNotification": item.hasNotification,
          "notificationsCount": item.notificationsCount,
          "active": item.active,
          "enabled": item.enabled,
          "joined": item.joined,
          "spectated": item.spectated,
          "canJoin": item.canJoin,
          "canManageUsers": item.canManageUsers,
          "canRequestAccess": item.canRequestAccess,
          "isMember": item.isMember,
          "amIBanned": item.isBanned,
          "access": item.access,
          "ensOnly": item.ensOnly,
          "nbMembers": item.joinedMembersCount,
          "encrypted": item.encrypted,
        }
        return $jsonObj

  proc setMembersAirdropAddress*(self: SectionModel, id: string, communityMembersAirdropAddress: Table[string, string]) = 
    let index = self.getItemIndex(id)
    if (index == -1):
      return

    for pubkey, airdropAddress in communityMembersAirdropAddress.pairs:
      self.items[index].members.setAirdropAddress(pubkey, airdropAddress)

  proc setTokenItems*(self: SectionModel, id: string, communityTokensItems: seq[TokenItem]) =
    let index = self.getItemIndex(id)
    if (index == -1):
      return

    self.items[index].communityTokens.setItems(communityTokensItems)

  proc setMembersItems*(self: SectionModel, id: string, communityMembersItems: seq[MemberItem]) =
    let index = self.getItemIndex(id)
    if index == -1:
      return

    self.items[index].members.setItems(communityMembersItems)
    self.items[index].membersLoaded = true

    let dataIndex = self.createIndex(index, 0, nil)
    defer: dataIndex.delete
    self.dataChanged(dataIndex, dataIndex, @[ModelRole.MembersLoaded.int])

  proc setTokensLoading*(self: SectionModel, id: string, value: bool) =
    let index = self.getItemIndex(id)
    if index == -1 or self.items[index].tokensLoading == value:
      return

    self.items[index].tokensLoading = value

    let dataIndex = self.createIndex(index, 0, nil)
    defer: dataIndex.delete
    self.dataChanged(dataIndex, dataIndex, @[ModelRole.TokensLoading.int])

  proc addMember*(self: SectionModel, communityId: string, memberItem: MemberItem) =
    let i = self.getItemIndex(communityId)
    if i == -1:
      return

    self.items[i].members.addItem(memberItem)

  proc removeMember*(self: SectionModel, communityId: string, memberId: string) =
    let i = self.getItemIndex(communityId)
    if i == -1:
      return

    self.items[i].members.removeItemById(memberId)

  proc setIsBanned*(self: SectionModel, communityId: string, isBanned: bool) =
    let ind = self.getItemIndex(communityId)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    updateRole(isBanned, AmIBanned)

    if roles.len == 0:
      return

    let dataIndex = self.createIndex(ind, 0, nil)
    defer: dataIndex.delete
    self.dataChanged(dataIndex, dataIndex, roles)
