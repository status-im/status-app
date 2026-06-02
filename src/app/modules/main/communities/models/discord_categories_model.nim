import app/modules/shared_models/model_utils
import nimqml, tables
import discord_category_item

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Name
    Selected

QtObject:
  type DiscordCategoriesModel* = ref object of QAbstractListModel
    items*: seq[DiscordCategoryItem]

  proc setup(self: DiscordCategoriesModel)
  proc delete(self: DiscordCategoriesModel)
  proc newDiscordCategoriesModel*(): DiscordCategoriesModel =
    new(result, delete)
    result.setup

  proc countChanged(self: DiscordCategoriesModel) {.signal.}

  proc clearItems*(self: DiscordCategoriesModel) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()
    self.countChanged()

  proc setItems*(self: DiscordCategoriesModel, items: seq[DiscordCategoryItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc getCount(self: DiscordCategoriesModel): int {.slot.} =
    self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: DiscordCategoriesModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: DiscordCategoriesModel): Table[int, string] =
    {
      ModelRole.Id.int:"id",
      ModelRole.Name.int:"name",
      ModelRole.Selected.int:"selected",
    }.toTable

  method data(self: DiscordCategoriesModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Id:
        result = newQVariant(item.getId())
      of ModelRole.Name:
        result = newQVariant(item.getName())
      of ModelRole.Selected:
        result = newQVariant(item.getSelected())

  proc findIndexById(self: DiscordCategoriesModel, id: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].getId() == id):
        return i
    return -1

  proc removeItem*(self: DiscordCategoriesModel, id: string) =
    let idx = self.findIndexById(id)
    if(idx == -1):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, idx, idx)
    self.items.delete(idx)
    self.endRemoveRows()
    self.countChanged()

  proc addItem*(self: DiscordCategoriesModel, item: DiscordCategoryItem) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()

  proc unselectItem*(self: DiscordCategoriesModel, id: string) =
    let idx = self.findIndexById(id)
    if idx > -1:
      let index = self.createIndex(idx, 0, nil)
      defer: index.delete
      self.items[idx].selected = false
      self.dataChanged(index, index, @[ModelRole.Selected.int])

  proc selectItem*(self: DiscordCategoriesModel, id: string) =
    let idx = self.findIndexById(id)
    if idx > -1:
      let index = self.createIndex(idx, 0, nil)
      defer: index.delete
      self.items[idx].selected = true
      self.dataChanged(index, index, @[ModelRole.Selected.int])

  proc selectOneItem*(self: DiscordCategoriesModel, id: string) =
    for i in 0 ..< self.items.len:
      let index = self.createIndex(i, 0, nil)
      defer: index.delete
      self.items[i].selected = self.items[i].getId() == id
      self.dataChanged(index, index, @[ModelRole.Selected.int])

  proc setup(self: DiscordCategoriesModel) =
    self.QAbstractListModel.setup

  proc delete(self: DiscordCategoriesModel) =
    self.QAbstractListModel.delete
