import app/modules/shared_models/model_utils
import nimqml, tables, strutils

import location_menu_item, location_menu_sub_item

type
  ModelRole {.pure.} = enum
    Value = UserRole + 1
    Title
    ImageSource
    IconName
    IconColor
    SubItems
    HasSubItems

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[Item]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup()

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Value.int:"value",
      ModelRole.Title.int:"title",
      ModelRole.ImageSource.int:"imageSource",
      ModelRole.IconName.int:"iconName",
      ModelRole.IconColor.int:"iconColor",
      ModelRole.SubItems.int:"subItems",
      ModelRole.HasSubItems.int:"hasSubItems"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Value:
      result = newQVariant(item.value)
    of ModelRole.Title:
      result = newQVariant(item.text)
    of ModelRole.ImageSource:
      result = newQVariant(item.image)
    of ModelRole.IconName:
      result = newQVariant(item.icon)
    of ModelRole.IconColor:
      result = newQVariant(item.iconColor)
    of ModelRole.SubItems:
      result = newQVariant(item.subItems)
    of ModelRole.HasSubItems:
      result = newQVariant(not isNil(item.subItems) and item.subItems.rowCount(nil) > 0)

  proc setItems*(self: Model, items: seq[Item]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc getItemForValue*(self: Model, value: string): Item =
    for i in self.items:
      if (i.value == value):
        return i

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
