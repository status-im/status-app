import app/modules/shared_models/model_utils
import nimqml, tables, strutils
import discord_channel_item

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    CategoryId
    Name
    Description
    FilePath
    Selected

QtObject:
  type DiscordChannelsModel* = ref object of QAbstractListModel
    items*: seq[DiscordChannelItem]

  proc setup(self: DiscordChannelsModel)
  proc delete(self: DiscordChannelsModel)
  proc newDiscordChannelsModel*(): DiscordChannelsModel =
    new(result, delete)
    result.setup

  proc countChanged(self: DiscordChannelsModel) {.signal.}
  proc hasSelectedItemsChanged*(self: DiscordChannelsModel) {.signal.}

  proc clearItems*(self: DiscordChannelsModel) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()
    self.countChanged()
    self.hasSelectedItemsChanged()

  proc setItems*(self: DiscordChannelsModel, items: seq[DiscordChannelItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()
    self.hasSelectedItemsChanged()

  proc getCount(self: DiscordChannelsModel): int {.slot.} =
    self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: DiscordChannelsModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: DiscordChannelsModel): Table[int, string] =
    {
      ModelRole.Id.int:"id",
      ModelRole.CategoryId.int:"categoryId",
      ModelRole.Name.int:"name",
      ModelRole.Description.int:"description",
      ModelRole.FilePath.int:"filePath",
      ModelRole.Selected.int:"selected",
    }.toTable

  method data(self: DiscordChannelsModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Id:
        result = newQVariant(item.id)
      of ModelRole.CategoryId:
        result = newQVariant(item.categoryId)
      of ModelRole.Name:
        result = newQVariant(item.name)
      of ModelRole.Description:
        result = newQVariant(item.description)
      of ModelRole.FilePath:
        result = newQVariant(item.filePath)
      of ModelRole.Selected:
        result = newQVariant(item.selected)

  method setData(self: DiscordChannelsModel, index: QModelIndex, value: QVariant, role: int): bool =
    let row = index.row
    guardModelSetDataIndex(index, row, self.items.len)
    guardModelSetDataRole(role, ModelRole)

    let notifyHasSelectedItems = role.ModelRole == ModelRole.Selected and self.items[row].selected != value.boolVal()

    let ind = row
    updateRolesAndNotify:
      case role.ModelRole:
        of ModelRole.Id:
          updateRoleWithValue(id, value.stringVal())
        of ModelRole.CategoryId:
          updateRoleWithValue(categoryId, value.stringVal())
        of ModelRole.Name:
          updateRoleWithValue(name, value.stringVal())
        of ModelRole.Description:
          updateRoleWithValue(description, value.stringVal())
        of ModelRole.FilePath:
          updateRoleWithValue(filePath, value.stringVal())
        of ModelRole.Selected:
          updateRoleWithValue(selected, value.boolVal())
    if notifyHasSelectedItems:
      self.hasSelectedItemsChanged()
    return true

  proc findIndexById(self: DiscordChannelsModel, id: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].id == id):
        return i
    return -1

  proc findIndicesByFilePath(self: DiscordChannelsModel, filePath: string): seq[int] =
    var indices: seq[int] = @[]
    for i in 0 ..< self.items.len:
      if(self.items[i].filePath == filePath):
        indices.add(i)
    return indices

  proc getItem*(self: DiscordChannelsModel, id: string): DiscordChannelItem =
    for i in 0 ..< self.items.len:
      if(self.items[i].id == id):
        return self.items[i]

  proc allChannelsByCategoryUnselected*(self: DiscordChannelsModel, id: string): bool =
    var allUnselected = true
    for i in 0 ..< self.items.len:
      if self.items[i].categoryId == id and self.items[i].selected:
        allUnselected = false
        break
    return allUnselected

  proc hasItemsWithCategoryId*(self: DiscordChannelsModel, categoryId: string): bool =
    for i in 0 ..< self.items.len:
      if(self.items[i].categoryId == categoryId):
        return true
    return false

  proc getHasSelectedItems*(self: DiscordChannelsModel): bool {.slot.} =
    for i in 0 ..< self.items.len:
      if self.items[i].selected:
        return true
    return false

  QtProperty[bool] hasSelectedItems:
    read = getHasSelectedItems
    notify = hasSelectedItemsChanged

  proc removeItemsByFilePath*(self: DiscordChannelsModel, filePath: string) =
    let indices = self.findIndicesByFilePath(filePath)
    for i in 0 ..< indices.len:

      let parentModelIndex = newQModelIndex()
      defer: parentModelIndex.delete

      self.beginRemoveRows(parentModelIndex, indices[i], indices[i])
      self.items.delete(indices[i])
      self.endRemoveRows()
      self.countChanged()

  proc addItem*(self: DiscordChannelsModel, item: DiscordChannelItem) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()

  proc unselectItemsByCategoryId*(self: DiscordChannelsModel, id: string) =
    var hasChanged = false

    for ind in 0 ..< self.items.len:
      if(self.items[ind].getCategoryId() == id):
        updateRolesAndNotify:
          updateRoleWithValue(selected, false)
          if roles.len > 0:
            hasChanged = true
    if hasChanged:
      self.hasSelectedItemsChanged()

  proc selectItemsByCategoryId*(self: DiscordChannelsModel, id: string) =
    var hasChanged = false

    for ind in 0 ..< self.items.len:
      if(self.items[ind].getCategoryId() == id):
        updateRolesAndNotify:
          updateRoleWithValue(selected, true)
          if roles.len > 0:
            hasChanged = true
    if hasChanged:
      self.hasSelectedItemsChanged()

  proc getChannelCategoryIdByFilePath*(self: DiscordChannelsModel, filePath: string): string =
    for i in 0 ..< self.items.len:
      if(self.items[i].getFilePath() == filePath):
        return self.items[i].getCategoryId()
    return ""

  proc getSelectedItems*(self: DiscordChannelsModel): seq[DiscordChannelItem] =
    for i in 0 ..< self.items.len:
      if self.items[i].getSelected():
        result.add(self.items[i])

  proc unselectItem*(self: DiscordChannelsModel, id: string) =
    var hasChanged = false

    updateItemRolesAndNotify self.findIndexById(id):
      updateRoleWithValue(selected, false)
      if roles.len > 0:
        hasChanged = true
    if hasChanged:
      self.hasSelectedItemsChanged()

  proc selectItem*(self: DiscordChannelsModel, id: string) =
    var hasChanged = false

    updateItemRolesAndNotify self.findIndexById(id):
      updateRoleWithValue(selected, true)
      if roles.len > 0:
        hasChanged = true
    if hasChanged:
      self.hasSelectedItemsChanged()

  proc selectOneItem*(self: DiscordChannelsModel, id: string) =
    var hasChanged = false

    for ind in 0 ..< self.items.len:
      updateRolesAndNotify:
        updateRoleWithValue(selected, self.items[ind].getId() == id)
        if roles.len > 0:
          hasChanged = true
    if hasChanged:
      self.hasSelectedItemsChanged()

  proc setup(self: DiscordChannelsModel) =
    self.QAbstractListModel.setup

  proc delete(self: DiscordChannelsModel) =
    self.QAbstractListModel.delete
