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
        result = newQVariant(item.getId())
      of ModelRole.CategoryId:
        result = newQVariant(item.getCategoryId())
      of ModelRole.Name:
        result = newQVariant(item.getName())
      of ModelRole.Description:
        result = newQVariant(item.getDescription())
      of ModelRole.FilePath:
        result = newQVariant(item.getFilePath())
      of ModelRole.Selected:
        result = newQVariant(item.getSelected())

  method setData(self: DiscordChannelsModel, index: QModelIndex, value: QVariant, role: int): bool =
    let row = index.row
    guardModelSetDataIndex(index, row, self.items.len)
    guardModelSetDataRole(role, ModelRole)

    case role.ModelRole:
      of ModelRole.Id:
        self.items[row].id = value.stringVal()
        self.dataChanged(index, index, @[ModelRole.Id.int])
      of ModelRole.CategoryId:
        self.items[row].categoryId = value.stringVal()
        self.dataChanged(index, index, @[ModelRole.CategoryId.int])
      of ModelRole.Name:
        self.items[row].name = value.stringVal()
        self.dataChanged(index, index, @[ModelRole.Name.int])
      of ModelRole.Description:
        self.items[row].description = value.stringVal()
        self.dataChanged(index, index, @[ModelRole.Description.int])
      of ModelRole.FilePath:
        self.items[row].filePath = value.stringVal()
        self.dataChanged(index, index, @[ModelRole.FilePath.int])
      of ModelRole.Selected:
        self.items[row].selected = value.boolVal()
        self.dataChanged(index, index, @[ModelRole.Selected.int])
        self.hasSelectedItemsChanged()
    return true

  proc findIndexById(self: DiscordChannelsModel, id: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].getId() == id):
        return i
    return -1

  proc findIndicesByFilePath(self: DiscordChannelsModel, filePath: string): seq[int] =
    var indices: seq[int] = @[]
    for i in 0 ..< self.items.len:
      if(self.items[i].getFilePath() == filePath):
        indices.add(i)
    return indices

  proc getItem*(self: DiscordChannelsModel, id: string): DiscordChannelItem =
    for i in 0 ..< self.items.len:
      if(self.items[i].getId() == id):
        return self.items[i]

  proc allChannelsByCategoryUnselected*(self: DiscordChannelsModel, id: string): bool =
    var allUnselected = true
    for i in 0 ..< self.items.len:
      if self.items[i].getCategoryId() == id and self.items[i].getSelected():
        allUnselected = false
        break
    return allUnselected

  proc hasItemsWithCategoryId*(self: DiscordChannelsModel, categoryId: string): bool =
    for i in 0 ..< self.items.len:
      if(self.items[i].getCategoryId() == categoryId):
        return true
    return false

  proc getHasSelectedItems*(self: DiscordChannelsModel): bool {.slot.} =
    for i in 0 ..< self.items.len:
      if self.items[i].getSelected():
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
    for i in 0 ..< self.items.len:
      if(self.items[i].getCategoryId() == id):
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.items[i].selected = false
        self.dataChanged(index, index, @[ModelRole.Selected.int])
    self.hasSelectedItemsChanged()

  proc selectItemsByCategoryId*(self: DiscordChannelsModel, id: string) =
    for i in 0 ..< self.items.len:
      if(self.items[i].getCategoryId() == id):
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.items[i].selected = true
        self.dataChanged(index, index, @[ModelRole.Selected.int])
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
    let idx = self.findIndexById(id)
    if idx > -1:
      let index = self.createIndex(idx, 0, nil)
      defer: index.delete
      self.items[idx].selected = false
      self.dataChanged(index, index, @[ModelRole.Selected.int])
      self.hasSelectedItemsChanged()

  proc selectItem*(self: DiscordChannelsModel, id: string) =
    let idx = self.findIndexById(id)
    if idx > -1:
      let index = self.createIndex(idx, 0, nil)
      defer: index.delete
      self.items[idx].selected = true
      self.dataChanged(index, index, @[ModelRole.Selected.int])
      self.hasSelectedItemsChanged()

  proc selectOneItem*(self: DiscordChannelsModel, id: string) =
    for i in 0 ..< self.items.len:
      let index = self.createIndex(i, 0, nil)
      defer: index.delete
      self.items[i].selected = self.items[i].getId() == id
      self.dataChanged(index, index, @[ModelRole.Selected.int])
    self.hasSelectedItemsChanged()

  proc setup(self: DiscordChannelsModel) =
    self.QAbstractListModel.setup

  proc delete(self: DiscordChannelsModel) =
    self.QAbstractListModel.delete
