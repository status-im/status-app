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

  proc modelChanged(self: Model) {.signal.}

  proc getCount(self: Model): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Name.int:"name",
      ModelRole.Url.int:"url",
      ModelRole.ImageUrl.int:"imageUrl"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Name:
      result = newQVariant(item.getName())
    of ModelRole.Url:
      result = newQVariant(item.getUrl())
    of ModelRole.ImageUrl:
      result = newQVariant(item.getImageUrl())

  proc addItem*(self: Model, item: Item) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    for i in self.items:
      if i.getUrl() == item.getUrl():
        return

    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.modelChanged()

  proc getBookmarkIndexByUrl*(self: Model, url: string): int {.slot.} =
    var index = -1
    var i = -1
    for item in self.items:
      i += 1
      if item.getUrl() == url:
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
    self.modelChanged()


  proc updateItemByUrl*(self: Model, oldUrl: string, item: Item) =
    var index = self.getBookmarkIndexByUrl(oldUrl)
    if index == -1:
      return

    let topLeft = self.createIndex(index, index, nil)
    let bottomRight = self.createIndex(index, index, nil)
    defer: topLeft.delete
    defer: bottomRight.delete

    self.items[index] = item
    self.dataChanged(topLeft, bottomRight)
    self.modelChanged()

  proc delete(self: Model) =
    self.items = @[]
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

