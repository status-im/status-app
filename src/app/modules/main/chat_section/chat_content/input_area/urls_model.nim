import app/modules/shared_models/model_utils
import nimqml, tables, sequtils

type
  ModelRole {.pure.} = enum
    Url = UserRole + 1

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[string]

  proc delete*(self: Model)
  proc setup(self: Model)
  proc newUrlsModel*(): Model =
    new(result, delete)
    result.setup

  proc countChanged(self: Model) {.signal.}

  proc getCount*(self: Model): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Url.int:"url"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Url:
      let item = self.items[index.row]
      result = newQVariant(item)
    else:
      result = newQVariant()

  proc removeItemWithIndex(self: Model, ind: int) =
    if(ind < 0 or ind >= self.items.len):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, ind, ind)
    self.items.delete(ind)
    self.endRemoveRows()

  proc setUrls*(self: Model, urls: seq[string]) =
    var itemsToInsert: seq[string]
    var indexesToRemove: seq[int]

    #remove
    for i in 0 ..< self.items.len:
      if not urls.anyIt(it == self.items[i]):
        indexesToRemove.add(i)

    while indexesToRemove.len > 0:
      let index = pop(indexesToRemove)
      self.removeItemWithIndex(index)

    # Move or insert
    for i in 0 ..< urls.len:
      if self.items.anyIt(it == urls[i]):
        continue
      itemsToInsert.add(urls[i])


    if itemsToInsert.len > 0:
      let parentModelIndex = newQModelIndex()
      defer: parentModelIndex.delete
      self.beginInsertRows(parentModelIndex, self.items.len, self.items.len + itemsToInsert.len - 1)
      self.items = self.items & itemsToInsert
      self.endInsertRows()

    self.countChanged()

  proc delete*(self: Model) = 
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup
