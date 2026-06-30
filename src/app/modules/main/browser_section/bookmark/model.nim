import app/modules/shared_models/model_utils
import nimqml, tables, strutils, std/strformat

import item

type
  ModelRole {.pure.} = enum
    Name = UserRole + 1
    Url = UserRole + 2
    ImageUrl = UserRole + 3

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[Item]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup

  proc `$`*(self: Model): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i]})
      """

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Name.int:"name",
      ModelRole.Url.int:"url",
      ModelRole.ImageUrl.int:"imageUrl"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Name:
      result = newQVariant(item.name)
    of ModelRole.Url:
      result = newQVariant(item.url)
    of ModelRole.ImageUrl:
      result = newQVariant(item.imageUrl)

  proc addItem*(self: Model, item: Item) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    for i in self.items:
      if i.url == item.url:
        return

    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()

  proc getBookmarkIndexByUrl*(self: Model, url: string): int {.slot.} =
    var index = -1
    var i = -1
    for item in self.items:
      i += 1
      if item.url == url:
        index = i
        break
    return index

  proc removeItemByUrl*(self: Model, url: string) =
    var index = self.getBookmarkIndexByUrl(url)
    if index == -1:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.endRemoveRows()


  proc updateItemByUrl*(self: Model, oldUrl: string, item: Item) =
    updateItemRolesAndNotify self.getBookmarkIndexByUrl(oldUrl):
      updateRoleWithValue(name, item.name)
      updateRoleWithValue(url, item.url)
      updateRoleWithValue(imageUrl, item.imageUrl)

  proc delete(self: Model) =
    self.items = @[]
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
