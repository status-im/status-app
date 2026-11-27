import app/modules/shared_models/model_utils
import nimqml, sequtils, tables
import ephemeral_notification_item

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Timestamp
    DurationInMs
    Title
    SubTitle
    Image
    Icon
    IconColor
    Loading
    EphNotifType
    Url
    ActionType
    ActionData

QtObject:
  type Model* = ref object of QAbstractListModel
    items*: seq[Item]
    maxItems: Positive

  proc setup(self: Model)
  proc delete(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup
    result.maxItems = 3 # Retain enough startup toasts for either viewport orientation.

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Id.int:"id",
      ModelRole.Timestamp.int:"timestamp",
      ModelRole.DurationInMs.int:"durationInMs",
      ModelRole.Title.int:"title",
      ModelRole.SubTitle.int:"subTitle",
      ModelRole.Image.int:"image",
      ModelRole.Icon.int:"icon",
      ModelRole.IconColor.int:"iconColor",
      ModelRole.Loading.int:"loading",
      ModelRole.EphNotifType.int:"ephNotifType",
      ModelRole.Url.int:"url",
      ModelRole.ActionType.int:"actionType",
      ModelRole.ActionData.int:"actionData"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
      of ModelRole.Id:
        result = newQVariant(item.id)
      of ModelRole.Timestamp:
        result = newQVariant(item.timestamp)
      of ModelRole.DurationInMs:
        result = newQVariant(item.durationInMs)
      of ModelRole.Title:
        result = newQVariant(item.title)
      of ModelRole.SubTitle:
        result = newQVariant(item.subTitle)
      of ModelRole.Image:
        result = newQVariant(item.image)
      of ModelRole.Icon:
        result = newQVariant(item.icon)
      of ModelRole.IconColor:
        result = newQVariant(item.iconColor)
      of ModelRole.Loading:
        result = newQVariant(item.loading)
      of ModelRole.EphNotifType:
        result = newQVariant(item.ephNotifType.int)
      of ModelRole.Url:
        result = newQVariant(item.url)
      of ModelRole.ActionType:
        result = newQVariant(item.actionType.int)
      of ModelRole.ActionData:
        result = newQVariant(item.actionData)

  proc findIndexById(self: Model, id: int64): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].id == id):
        return i
    return -1

  proc getItemWithId*(self: Model, id: int64): Item =
    let ind = self.findIndexById(id)
    if(ind == -1):
      return
    return self.items[ind]

  proc removeItems(self: Model, first, last: int) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, first, last)
    self.items.delete(first .. last)
    self.endRemoveRows()

  proc setMaxItems*(self: Model, limit: Positive) =
    self.maxItems = limit
    let overflow = self.items.len - limit
    if overflow > 0:
      self.removeItems(0, overflow - 1)

  proc addItem*(self: Model, item: Item) =
    if self.items.len == self.maxItems:
      self.removeItems(0, 0)

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()

  proc removeItemWithId*(self: Model, id: int64) =
    let ind = self.findIndexById(id)
    if(ind == -1):
      return

    self.removeItems(ind, ind)

  proc setup(self: Model) =
    self.QAbstractListModel.setup

  proc delete(self: Model) =
    self.QAbstractListModel.delete
