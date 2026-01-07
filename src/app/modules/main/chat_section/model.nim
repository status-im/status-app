import nimqml, tables, std/strformat, json, sequtils, system
import ../../../../app_service/common/types
import ../../../../app_service/service/chat/dto/chat
import item
import ../../shared_models/model_utils

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
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

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
    for i in 0 ..< self.items.len:
      if self.items[i].categoryId == categoryId:
        if self.items[i].categoryOpened == opened:
          return
        self.items[i].categoryOpened = opened
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, @[ModelRole.CategoryOpened.int])

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
    let modelIndex = self.createIndex(index, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, @[ModelRole.ShouldBeHiddenBecausePermissionsAreNotMet.int])

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
    let index = self.getItemIdxById(categoryId)
    if index == -1:
      return
    if self.items[index].hasUnreadMessages == unread:
      return
    self.items[index].hasUnreadMessages = unread
    let modelIndex = self.createIndex(index, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, @[ModelRole.HasUnreadMessages.int])

  proc setActiveItem*(self: Model, id: string) =
    for i in 0 ..< self.items.len:
      let isChannelToSetActive = (self.items[i].id == id)
      if self.items[i].active != isChannelToSetActive:
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        # Set active channel to true and others to false
        self.items[i].active = isChannelToSetActive
        if (isChannelToSetActive):
          self.items[i].loaderActive = true
          self.dataChanged(index, index, @[ModelRole.Active.int, ModelRole.LoaderActive.int])
        else:
          self.dataChanged(index, index, @[ModelRole.Active.int])

  proc activeItem*(self: Model): ChatItem =
    for i in 0 ..< self.items.len:
      if self.items[i].active:
        return self.items[i]

  proc setItemLocked*(self: Model, id: string, locked: bool) =
    let index = self.getItemIdxById(id)
    if index == -1:
      return

    if (self.items[index].locked == locked):
      return

    self.items[index].locked = locked
    let modelIndex = self.createIndex(index, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, @[ModelRole.Locked.int])

  proc setItemPermissionsRequired*(self: Model, id: string, value: bool) =
    let index = self.getItemIdxById(id)
    if index == -1:
      return

    if (self.items[index].requiresPermissions == value):
      return

    self.items[index].requiresPermissions = value
    let modelIndex = self.createIndex(index, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, @[ModelRole.RequiresPermissions.int])

  proc getItemPermissionsRequired*(self: Model, id: string): bool =
    let index = self.getItemIdxById(id)
    if index == -1:
      return false

    return self.items[index].requiresPermissions

  proc changeMutedOnItemById*(self: Model, id: string, muted: bool) =
    let index = self.getItemIdxById(id)
    if index == -1:
      return
    if(self.items[index].muted == muted):
      return
    self.items[index].muted = muted
    let modelIndex = self.createIndex(index, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, @[ModelRole.Muted.int])

  proc changeCanPostValues*(self: Model, id: string, canPost, canView, canPostReactions, viewersCanPostReactions: bool): seq[int] =
    let ind = self.getItemIdxById(id)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    updateRole(canView, CanView)
    updateRole(canPost, CanPost)
    updateRole(canPostReactions, CanPostReactions)
    updateRole(viewersCanPostReactions, ViewersCanPostReactions)

    if roles.len == 0:
      return
    
    let modelIndex = self.createIndex(ind, 0, nil)
    defer: modelIndex.delete
    roles.add(ModelRole.HideIfPermissionsNotMet.int) # depends on canPost, canView
    roles.add(ModelRole.ShouldBeHiddenBecausePermissionsAreNotMet.int) # depends on hideIfPermissionsNotMet
    self.dataChanged(modelIndex, modelIndex, roles)
    return roles # return roles so that we can use it in tests

  proc changeMutedOnItemByCategoryId*(self: Model, categoryId: string, muted: bool) =
    for i in 0 ..< self.items.len:
      if self.items[i].categoryId == categoryId and self.items[i].muted != muted:
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.items[i].muted = muted
        self.dataChanged(index, index, @[ModelRole.Muted.int])

  proc allChannelsAreHiddenBecauseNotPermitted*(self: Model): bool =
    for i in 0 ..< self.items.len:
      if not self.items[i].isCategory and not self.itemShouldBeHiddenBecauseNotPermitted(self.items[i]):
        return false
    return true

  proc changeBlockedOnItemById*(self: Model, id: string, blocked: bool) =
    let index = self.getItemIdxById(id)
    if index == -1:
      return
    if(self.items[index].blocked == blocked):
      return
    self.items[index].blocked = blocked
    let modelIndex = self.createIndex(index, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, @[ModelRole.Blocked.int])

  proc updateUserItemDetailsById*(self: Model, id, name: string, usesDefaultName: bool, icon: string, trustStatus: TrustStatus) =
    let ind = self.getItemIdxById(id)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    updateRole(name, Name)
    updateRole(icon, Icon)
    updateRole(trustStatus, TrustStatus)
    updateRole(usesDefaultName, UsesDefaultName)

    if roles.len == 0:
      return

    let modelIndex = self.createIndex(ind, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, roles)

  proc updateCommunityItemDetailsById*(self: Model, id, name, description, emoji, color: string, hideIfPermissionsNotMet: bool): seq[int] =
    let ind = self.getItemIdxById(id)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    updateRole(name, Name)
    updateRole(description, Description)
    updateRole(emoji, Emoji)
    updateRole(color, Color)
    if self.items[ind].hideIfPermissionsNotMet != hideIfPermissionsNotMet:
      roles.add(ModelRole.ShouldBeHiddenBecausePermissionsAreNotMet.int)
    updateRole(hideIfPermissionsNotMet, HideIfPermissionsNotMet)

    if roles.len == 0:
      return

    let modelIndex = self.createIndex(ind, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, roles)
    self.updateHiddenFlagForCategory(self.items[ind].categoryId)
    return roles # return roles so that we can use it in tests

  proc updateNameColorIconOnGroupItemById*(self: Model, id, name, color, icon: string) =
    let ind = self.getItemIdxById(id)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    updateRole(name, Name)
    updateRole(color, Color)
    updateRole(icon, Icon)

    if roles.len == 0:
      return

    let modelIndex = self.createIndex(ind, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, roles)

  proc updateCategoryDetailsById*(
      self: Model,
      categoryId,
      name: string,
      categoryPosition: int,
    ) =
    let ind = self.getItemIdxById(categoryId)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    updateRole(name, Name)
    updateRole(categoryPosition, CategoryPosition)

    if roles.len == 0:
      return

    let modelIndex = self.createIndex(ind, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, roles)

  proc updateItemsWithCategoryDetailsById*(
      self: Model,
      chats: seq[ChatDto],
      categoryId: string,
      newCategoryPosition: int,
    ) =
    for i in 0 ..< self.items.len:
      var item = self.items[i]
      if item.`type` == CATEGORY_TYPE:
        continue
      var nowHasCategory = false
      var found = false
      for chat in chats:
        if item.id != chat.id:
          continue
        found = true
        nowHasCategory = chat.categoryId == categoryId
        item.position = chat.position
        item.categoryId = chat.categoryId
        item.categoryPosition = if nowHasCategory: newCategoryPosition else: -1
        let modelIndex = self.createIndex(i, 0, nil)
        defer: modelIndex.delete
        var roleChanges = @[
          ModelRole.Position.int,
          ModelRole.CategoryId.int,
          ModelRole.CategoryPosition.int,
        ]
        if not nowHasCategory:
          item.categoryOpened = true
          roleChanges.add(ModelRole.CategoryOpened.int)
        self.dataChanged(modelIndex, modelIndex, roleChanges)
        break

  proc removeCategory*(
      self: Model,
      categoryId: string,
      chats: seq[ChatDto]
    ) =
    self.removeItemById(categoryId)

    for i in 0 ..< self.items.len:
      var item = self.items[i]
      if item.categoryId != categoryId:
        continue

      for chat in chats:
        if chat.id != item.id:
          continue

        item.position = chat.position
        item.categoryId = ""
        item.categoryPosition = -1
        item.categoryOpened = true
        let modelIndex = self.createIndex(i, 0, nil)
        defer: modelIndex.delete
        self.dataChanged(modelIndex, modelIndex, @[
          ModelRole.Position.int,
          ModelRole.CategoryId.int,
          ModelRole.CategoryPosition.int,
          ModelRole.CategoryOpened.int,
        ])
        break

  proc renameCategory*(self: Model, categoryId, name: string) =
    let ind = self.getItemIdxById(categoryId)
    if ind == -1:
      return
    
    var roles: seq[int] = @[]

    updateRole(name, Name)

    if roles.len == 0:
      return

    let modelIndex = self.createIndex(ind, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, roles)

  proc renameItemById*(self: Model, id, name: string) =
    let index = self.getItemIdxById(id)
    if index == -1:
      return
    if(self.items[index].name == name):
      return
    self.items[index].name = name
    let modelIndex = self.createIndex(index, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, @[ModelRole.Name.int, ModelRole.UsesDefaultName.int])

  proc updateItemOnlineStatusById*(self: Model, id: string, onlineStatus: OnlineStatus) =
    let ind = self.getItemIdxById(id)
    if ind == -1:
      return

    var roles: seq[int] = @[]
    updateRole(onlineStatus, OnlineStatus)
    if roles.len == 0:
      return

    let modelIndex = self.createIndex(ind, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, roles)

  proc updateNotificationsForItemById*(self: Model, id: string, hasUnreadMessages: bool,
      notificationsCount: int) =
    let ind = self.getItemIdxById(id)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    updateRole(hasUnreadMessages, HasUnreadMessages)
    updateRole(notificationsCount, NotificationsCount)

    if roles.len == 0:
      return

    let modelIndex = self.createIndex(ind, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, roles)

  proc updateLastMessageOnItemById*(self: Model, id: string, lastMessageText: string, lastMessageTimestamp: int) =
    let ind = self.getItemIdxById(id)
    if ind == -1:
      return

    var roles: seq[int] = @[]

    updateRole(lastMessageText, LastMessageText)
    updateRole(lastMessageTimestamp, LastMessageTimestamp)

    if roles.len == 0:
      return

    let modelIndex = self.createIndex(ind, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, roles)

  proc reorderChats*(
      self: Model,
      updatedChats: seq[ChatDto],
    ) =
    for updatedChat in updatedChats:
      let index = self.getItemIdxById(updatedChat.id)
      if index == -1:
        continue

      var roles = @[ModelRole.Position.int]
      if(self.items[index].categoryId != updatedChat.categoryId):
        if updatedChat.categoryId == "":
          # Moved out of a category
          self.items[index].categoryId = updatedChat.categoryId
          self.items[index].categoryPosition = -1
        else:
          let category = self.getItemById(updatedChat.categoryId)
          if category.id == "":
            continue
          self.items[index].categoryId = category.id
          self.items[index].categoryPosition = category.categoryPosition
        roles = roles.concat(@[
          ModelRole.CategoryId.int,
          ModelRole.CategoryPosition.int,
        ])

      self.items[index].position = updatedChat.position
      let modelIndex = self.createIndex(index, 0, nil)
      defer: modelIndex.delete
      self.dataChanged(modelIndex, modelIndex, roles)

  proc reorderCategoryById*(
      self: Model,
      categoryId: string,
      position: int,
    ) =
    for i in 0 ..< self.items.len:
      var item = self.items[i]
      if item.categoryId != categoryId:
        continue
      if item.categoryPosition == position:
        continue
      item.categoryPosition = position
      let modelIndex = self.createIndex(i, 0, nil)
      defer: modelIndex.delete
      self.dataChanged(modelIndex, modelIndex, @[ModelRole.CategoryPosition.int])

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
    let index = self.getItemIdxById(chatId)
    if index == -1:
      return

    self.items[index].loaderActive = false
    self.items[index].active = false
    let modelIndex = self.createIndex(index, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, @[ModelRole.Active.int, ModelRole.LoaderActive.int])

  proc updateMissingEncryptionKey*(self: Model, id: string, missingEncryptionKey: bool) =
    let index = self.getItemIdxById(id)
    if index == -1:
      return

    if self.items[index].missingEncryptionKey != missingEncryptionKey:
      self.items[index].missingEncryptionKey = missingEncryptionKey
      let modelIndex = self.createIndex(index, 0, nil)
      defer: modelIndex.delete
      self.dataChanged(modelIndex, modelIndex, @[ModelRole.MissingEncryptionKey.int])

  proc updatePermissionsCheckOngoing*(self: Model, id: string, permissionsCheckOngoing: bool) =
    let index = self.getItemIdxById(id)
    if index == -1:
      return

    if self.items[index].permissionsCheckOngoing != permissionsCheckOngoing:
      self.items[index].permissionsCheckOngoing = permissionsCheckOngoing
      let modelIndex = self.createIndex(index, 0, nil)
      defer: modelIndex.delete
      self.dataChanged(modelIndex, modelIndex, @[ModelRole.PermissionsCheckOngoing.int])

  proc delete*(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

