import nimqml, tables, std/strformat, json, sequtils, system
import ../../../../app_service/common/types
import ../../../../app_service/service/chat/dto/chat
import item
import app/modules/shared_models/model_utils

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Name
    UsesDefaultName
    MemberRole
    Icon
    Color
    ColorId
    Emoji
    Description
    Type
    LastMessageTimestamp
    LastMessageText
    HasUnreadMessages
    NotificationsCount
    Muted
    Blocked
    Active
    Position
    CategoryId
    CategoryPosition
    Highlight
    CategoryOpened
    TrustStatus
    OnlineStatus
    IsCategory
    LoaderActive
    Locked
    RequiresPermissions
    CanPost
    CanView
    CanPostReactions
    ViewersCanPostReactions
    HideIfPermissionsNotMet
    ShouldBeHiddenBecausePermissionsAreNotMet #this is a complex role which depends on other roles
                                              #(MemberRole , HideIfPermissionsNotMet, canPost and canView)
    MissingEncryptionKey
    PermissionsCheckOngoing

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[ChatItem]

  proc delete*(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup

  proc `$`*(self: Model): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i]})
      """

  proc countChanged(self: Model) {.signal.}

  proc getCount*(self: Model): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount*(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  proc items*(self: Model): seq[ChatItem] =
    return self.items

  proc categoryShouldBeHiddenBecauseNotPermitted(self: Model, categoryId: string): bool =
    var catHasNoChannels = true
    for i in 0 ..< self.items.len:
      if not self.items[i].isCategory and self.items[i].categoryId == categoryId:
        catHasNoChannels = false
        if not self.items[i].hideBecausePermissionsAreNotMet():
          return false
    if catHasNoChannels:
      return false
    return true

  proc itemShouldBeHiddenBecauseNotPermitted*(self: Model, item: ChatItem): bool =
    let isRegularUser = item.memberRole != MemberRole.Owner and item.memberRole != MemberRole.Admin and item.memberRole != MemberRole.TokenMaster
    if not isRegularUser:
      return false
    if item.isCategory:
      return self.categoryShouldBeHiddenBecauseNotPermitted(item.id)
    else:
      return item.hideBecausePermissionsAreNotMet()

  proc firstNotHiddenItemId*(self: Model): string =
    for i in 0 ..< self.items.len:
      if not self.items[i].isCategory and not self.itemShouldBeHiddenBecauseNotPermitted(self.items[i]):
        return self.items[i].id
    return ""

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Id.int:"itemId",
      ModelRole.Name.int:"name",
      ModelRole.UsesDefaultName.int:"usesDefaultName",
      ModelRole.MemberRole.int:"memberRole",
      ModelRole.Icon.int:"icon",
      ModelRole.Color.int:"color",
      ModelRole.ColorId.int:"colorId",
      ModelRole.Emoji.int:"emoji",
      ModelRole.Description.int:"description",
      ModelRole.Type.int:"type",
      ModelRole.LastMessageTimestamp.int:"lastMessageTimestamp",
      ModelRole.LastMessageText.int:"lastMessageText",
      ModelRole.HasUnreadMessages.int:"hasUnreadMessages",
      ModelRole.NotificationsCount.int:"notificationsCount",
      ModelRole.Muted.int:"muted",
      ModelRole.Blocked.int:"blocked",
      ModelRole.Active.int:"active",
      ModelRole.Position.int:"position",
      ModelRole.CategoryId.int:"categoryId",
      ModelRole.HideIfPermissionsNotMet.int:"hideIfPermissionsNotMet",
      ModelRole.CategoryPosition.int:"categoryPosition",
      ModelRole.Highlight.int:"highlight",
      ModelRole.CategoryOpened.int:"categoryOpened",
      ModelRole.TrustStatus.int:"trustStatus",
      ModelRole.OnlineStatus.int:"onlineStatus",
      ModelRole.IsCategory.int:"isCategory",
      ModelRole.LoaderActive.int:"loaderActive",
      ModelRole.Locked.int:"locked",
      ModelRole.RequiresPermissions.int:"requiresPermissions",
      ModelRole.CanPost.int:"canPost",
      ModelRole.CanView.int:"canView",
      ModelRole.CanPostReactions.int:"canPostReactions",
      ModelRole.ViewersCanPostReactions.int:"viewersCanPostReactions",
      ModelRole.ShouldBeHiddenBecausePermissionsAreNotMet.int:"shouldBeHiddenBecausePermissionsAreNotMet",
      ModelRole.MissingEncryptionKey.int:"missingEncryptionKey",
      ModelRole.PermissionsCheckOngoing.int:"permissionsCheckOngoing",

    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Id:
      result = newQVariant(item.id)
    of ModelRole.Name:
      result = newQVariant(item.name)
    of ModelRole.UsesDefaultName:
      result = newQVariant(item.usesDefaultName)
    of ModelRole.MemberRole:
      result = newQVariant(item.memberRole.int)
    of ModelRole.Icon:
      result = newQVariant(item.icon)
    of ModelRole.Color:
      result = newQVariant(item.color)
    of ModelRole.ColorId:
      result = newQVariant(item.colorId)
    of ModelRole.Emoji:
      result = newQVariant(item.emoji)
    of ModelRole.Description:
      result = newQVariant(item.description)
    of ModelRole.Type:
      result = newQVariant(item.`type`)
    of ModelRole.LastMessageTimestamp:
      result = newQVariant(item.lastMessageTimestamp)
    of ModelRole.LastMessageText:
      result = newQVariant(item.lastMessageText)
    of ModelRole.HasUnreadMessages:
      result = newQVariant(item.hasUnreadMessages)
    of ModelRole.NotificationsCount:
      result = newQVariant(item.notificationsCount)
    of ModelRole.Muted:
      result = newQVariant(item.muted)
    of ModelRole.Blocked:
      result = newQVariant(item.blocked)
    of ModelRole.Active:
      result = newQVariant(item.active)
    of ModelRole.Position:
      result = newQVariant(item.position)
    of ModelRole.CategoryId:
      result = newQVariant(item.categoryId)
    of ModelRole.CategoryPosition:
      result = newQVariant(item.categoryPosition)
    of ModelRole.Highlight:
      result = newQVariant(item.highlight)
    of ModelRole.CategoryOpened:
      result = newQVariant(item.categoryOpened)
    of ModelRole.TrustStatus:
      result = newQVariant(item.trustStatus.int)
    of ModelRole.OnlineStatus:
      result = newQVariant(item.onlineStatus.int)
    of ModelRole.IsCategory:
      result = newQVariant(item.isCategory)
    of ModelRole.LoaderActive:
      result = newQVariant(item.loaderActive)
    of ModelRole.Locked:
      result = newQVariant(item.locked)
    of ModelRole.RequiresPermissions:
      result = newQVariant(item.requiresPermissions)
    of ModelRole.CanPost:
      result = newQVariant(item.canPost)
    of ModelRole.CanView:
      result = newQVariant(item.canView)
    of ModelRole.CanPostReactions:
      result = newQVariant(item.canPostReactions)
    of ModelRole.ViewersCanPostReactions:
      result = newQVariant(item.viewersCanPostReactions)
    of ModelRole.HideIfPermissionsNotMet:
      result = newQVariant(item.hideIfPermissionsNotMet)
    of ModelRole.ShouldBeHiddenBecausePermissionsAreNotMet:
      return newQVariant(self.itemShouldBeHiddenBecauseNotPermitted(item))
    of ModelRole.MissingEncryptionKey:
      return newQVariant(item.missingEncryptionKey)
    of ModelRole.PermissionsCheckOngoing:
      return newQVariant(item.permissionsCheckOngoing)

  proc getItemIdxById(items: seq[ChatItem], id: string): int =
    var idx = 0
    for it in items:
      if(it.id == id):
        return idx
      idx.inc
    return -1

  proc getItemIdxById*(self: Model, id: string): int =
    return getItemIdxById(self.items, id)

  proc setData*(self: Model, items: seq[ChatItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

    self.countChanged()

  # IMPORTANT: if you call this function for a chat with a category, make sure the category is appended first
  proc appendItem*(self: Model, item: ChatItem, ignoreCategory: bool = false) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    var indexToInsertTo = item.position
    if item.isCategory:
      indexToInsertTo = item.categoryPosition
    elif item.categoryId != "":
      if ignoreCategory:
        # We don't care about the category position, just position it at the end
        indexToInsertTo = self.items.len
      else:
        let categoryIdx = self.getItemIdxById(item.categoryId)
        if categoryIdx == -1:
          return
        indexToInsertTo = categoryIdx + item.position + 1
    if indexToInsertTo < 0:
      indexToInsertTo = 0
    elif indexToInsertTo >= self.items.len + 1:
      indexToInsertTo = self.items.len

    self.beginInsertRows(parentModelIndex, indexToInsertTo, indexToInsertTo)
    self.items.insert(item, indexToInsertTo)
    self.endInsertRows()

    self.countChanged()

  proc changeCategoryOpened*(self: Model, categoryId: string, opened: bool) {.slot.} =
    for ind in 0 ..< self.items.len:
      if self.items[ind].categoryId == categoryId:
        updateRolesAndNotify:
          updateRoleWithValue(categoryOpened, opened)

  # This function only refreshes ShouldBeHiddenBecausePermissionsAreNotMet.
  # Then itemShouldBeHiddenBecauseNotPermitted() is used in data() to determined whether category is hidden or not.
  proc updateHiddenFlagForCategory(self: Model, id: string) =
    if id == "":
      return
    let index = self.getItemIdxById(id)
    if index == -1:
      return
    if not self.items[index].isCategory:
      return
    notifyRangeRolesChanged(index, index, @[ModelRole.ShouldBeHiddenBecausePermissionsAreNotMet.int])

  proc removeItemByIndex(self: Model, idx: int) =
    if idx == -1:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, idx, idx)
    self.items.delete(idx)
    self.endRemoveRows()

    self.countChanged()

  proc removeItemById*(self: Model, id: string) =
    let idx = self.getItemIdxById(id)
    if idx != -1:
      self.removeItemByIndex(idx)

  proc getItemAtIndex*(self: Model, index: int): ChatItem =
    if(index < 0 or index >= self.items.len):
      return

    return self.items[index]

  proc isItemWithIdAdded*(self: Model, id: string): bool =
    for it in self.items:
      if(it.id == id):
        return true
    return false

  proc getItemById*(self: Model, id: string): ChatItem =
    for it in self.items:
      if(it.id == id):
        return it

  proc setCategoryHasUnreadMessages*(self: Model, categoryId: string, unread: bool) =
    updateItemRolesAndNotify self.getItemIdxById(categoryId):
      updateRoleWithValue(hasUnreadMessages, unread)

  proc setActiveItem*(self: Model, id: string) =
    for ind in 0 ..< self.items.len:
      let isChannelToSetActive = (self.items[ind].id == id)
      if self.items[ind].active != isChannelToSetActive:
        updateRolesAndNotify:
          updateRoleWithValue(active, isChannelToSetActive)
          if isChannelToSetActive:
            updateRoleWithValue(loaderActive, true)

  proc activeItem*(self: Model): ChatItem =
    for i in 0 ..< self.items.len:
      if self.items[i].active:
        return self.items[i]

  proc setItemLocked*(self: Model, id: string, locked: bool) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(locked)

  proc setItemPermissionsRequired*(self: Model, id: string, value: bool) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRoleWithValue(requiresPermissions, value)

  proc getItemPermissionsRequired*(self: Model, id: string): bool =
    let index = self.getItemIdxById(id)
    if index == -1:
      return false

    return self.items[index].requiresPermissions

  proc changeMutedOnItemById*(self: Model, id: string, muted: bool) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(muted)

  proc changeCanPostValues*(self: Model, id: string, canPost, canView, canPostReactions, viewersCanPostReactions: bool): seq[int] =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(canView)
      updateRole(canPost)
      updateRole(canPostReactions)
      updateRole(viewersCanPostReactions)
      if roles.len > 0:
        roles.add(ModelRole.HideIfPermissionsNotMet.int) # depends on canPost, canView
        roles.add(ModelRole.ShouldBeHiddenBecausePermissionsAreNotMet.int) # depends on hideIfPermissionsNotMet
        result = roles # return roles so that we can use it in tests

  proc changeMutedOnItemByCategoryId*(self: Model, categoryId: string, muted: bool) =
    for ind in 0 ..< self.items.len:
      if self.items[ind].categoryId == categoryId and self.items[ind].muted != muted:
        updateRolesAndNotify:
          updateRole(muted)

  proc allChannelsAreHiddenBecauseNotPermitted*(self: Model): bool =
    for i in 0 ..< self.items.len:
      if not self.items[i].isCategory and not self.itemShouldBeHiddenBecauseNotPermitted(self.items[i]):
        return false
    return true

  proc changeBlockedOnItemById*(self: Model, id: string, blocked: bool) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(blocked)

  proc updateUserItemDetailsById*(self: Model, id, name: string, usesDefaultName: bool, icon: string, trustStatus: TrustStatus) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(name)
      updateRole(icon)
      updateRole(trustStatus)
      updateRole(usesDefaultName)

  proc updateCommunityItemDetailsById*(self: Model, id, name, description, emoji, color: string, hideIfPermissionsNotMet: bool): seq[int] =
    let ind = self.getItemIdxById(id)
    if ind == -1:
      return

    var rolesChanged = false
    updateRolesAndNotify rolesChanged:
      updateRole(name)
      updateRole(description)
      updateRole(emoji)
      updateRole(color)
      if self.items[ind].hideIfPermissionsNotMet != hideIfPermissionsNotMet:
        roles.add(ModelRole.ShouldBeHiddenBecausePermissionsAreNotMet.int)
      updateRole(hideIfPermissionsNotMet)
      if roles.len > 0:
        result = roles # return roles so that we can use it in tests

    if rolesChanged:
      self.updateHiddenFlagForCategory(self.items[ind].categoryId)

  proc updateNameColorIconOnGroupItemById*(self: Model, id, name, color, icon: string) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(name)
      updateRole(color)
      updateRole(icon)

  proc updateCategoryDetailsById*(
      self: Model,
      categoryId,
      name: string,
      newCategoryPosition: int,
    ) =
    updateItemRolesAndNotify self.getItemIdxById(categoryId):
      updateRole(name)
      updateRoleWithValue(categoryPosition, newCategoryPosition)

  proc updateItemsWithCategoryDetailsById*(
      self: Model,
      chats: seq[ChatDto],
      categoryId: string,
      newCategoryPosition: int,
    ) =
    for ind in 0 ..< self.items.len:
      let item = self.items[ind]
      if item.`type` == CATEGORY_TYPE:
        continue
      var nowHasCategory = false
      var found = false
      for chat in chats:
        if item.id != chat.id:
          continue
        found = true
        nowHasCategory = chat.categoryId == categoryId
        let targetPosition = chat.position
        let targetCategoryId = chat.categoryId
        let targetCategoryPosition = if nowHasCategory: newCategoryPosition else: -1
        let targetCategoryOpened = not nowHasCategory
        updateRolesAndNotify:
          updateRoleWithValue(position, targetPosition)
          updateRoleWithValue(categoryId, targetCategoryId)
          updateRoleWithValue(categoryPosition, targetCategoryPosition)
          if targetCategoryOpened:
            updateRoleWithValue(categoryOpened, true)
        break

  proc removeCategory*(
      self: Model,
      categoryId: string,
      chats: seq[ChatDto]
    ) =
    self.removeItemById(categoryId)

    for ind in 0 ..< self.items.len:
      let item = self.items[ind]
      if item.categoryId != categoryId:
        continue

      for chat in chats:
        if chat.id != item.id:
          continue

        let targetPosition = chat.position
        updateRolesAndNotify:
          updateRoleWithValue(position, targetPosition)
          updateRoleWithValue(categoryId, "")
          updateRoleWithValue(categoryPosition, -1)
          updateRoleWithValue(categoryOpened, true)
        break

  proc renameCategory*(self: Model, categoryId, name: string) =
    updateItemRolesAndNotify self.getItemIdxById(categoryId):
      updateRole(name)

  proc renameItemById*(self: Model, id, name: string) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(name)
      if roles.len > 0:
        roles.add(ModelRole.UsesDefaultName.int)

  proc updateItemOnlineStatusById*(self: Model, id: string, onlineStatus: OnlineStatus) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(onlineStatus)

  proc updateNotificationsForItemById*(self: Model, id: string, hasUnreadMessages: bool,
      notificationsCount: int) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(hasUnreadMessages)
      updateRole(notificationsCount)

  proc updateLastMessageOnItemById*(self: Model, id: string, lastMessageText: string, lastMessageTimestamp: int) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(lastMessageText)
      updateRole(lastMessageTimestamp)

  proc reorderChats*(
      self: Model,
      updatedChats: seq[ChatDto],
    ) =
    for updatedChat in updatedChats:
      let ind = self.getItemIdxById(updatedChat.id)
      if ind == -1:
        continue

      let categoryChanged = self.items[ind].categoryId != updatedChat.categoryId
      var targetCategoryPosition = self.items[ind].categoryPosition
      if categoryChanged:
        if updatedChat.categoryId == "":
          targetCategoryPosition = -1
        else:
          let category = self.getItemById(updatedChat.categoryId)
          if category.id == "":
            continue
          targetCategoryPosition = category.categoryPosition

      let targetPosition = updatedChat.position
      let targetCategoryId = updatedChat.categoryId
      updateRolesAndNotify:
        updateRoleWithValue(position, targetPosition)
        if categoryChanged:
          updateRoleWithValue(categoryId, targetCategoryId)
          updateRoleWithValue(categoryPosition, targetCategoryPosition)

  proc reorderCategoryById*(
      self: Model,
      categoryId: string,
      position: int,
    ) =
    for ind in 0 ..< self.items.len:
      let item = self.items[ind]
      if item.categoryId != categoryId:
        continue
      updateRolesAndNotify:
        updateRoleWithValue(categoryPosition, position)

  proc clearItems*(self: Model) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()

  proc getItemByIdAsJson*(self: Model, id: string): JsonNode =
    let index = self.getItemIdxById(id)
    if index == -1:
      return

    return self.items[index].toJsonNode()

  proc disableChatLoader*(self: Model, chatId: string) =
    updateItemRolesAndNotify self.getItemIdxById(chatId):
      updateRoleWithValue(loaderActive, false)
      updateRoleWithValue(active, false)

  proc updateMissingEncryptionKey*(self: Model, id: string, missingEncryptionKey: bool) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(missingEncryptionKey)

  proc updatePermissionsCheckOngoing*(self: Model, id: string, permissionsCheckOngoing: bool) =
    updateItemRolesAndNotify self.getItemIdxById(id):
      updateRole(permissionsCheckOngoing)

  proc delete*(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

