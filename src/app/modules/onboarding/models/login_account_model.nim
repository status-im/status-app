import nimqml, tables, strutils

import login_account_item

type
  ModelRole {.pure.} = enum
    Order = UserRole + 1
    Name
    Icon
    ThumbnailImage
    LargeImage
    KeyUid
    ColorId
    KeycardPairing
    KeycardCreatedAccount

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items: seq[Item]

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.setup

  proc countChanged(self: Model) {.signal.}
  proc getCount*(self: Model): int {.slot.} =
    self.items.len
  QtProperty[int]count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Order.int:"order",
      ModelRole.Name.int:"username",
      ModelRole.Icon.int:"icon",
      ModelRole.ThumbnailImage.int:"thumbnailImage",
      ModelRole.LargeImage.int:"largeImage",
      ModelRole.KeyUid.int:"keyUid",
      ModelRole.ColorId.int:"colorId",
      ModelRole.KeycardPairing.int:"keycardPairing",
      ModelRole.KeycardCreatedAccount.int:"keycardCreatedAccount"
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Order:
      result = newQVariant(item.getOrder())
    of ModelRole.Name:
      result = newQVariant(item.getName())
    of ModelRole.Icon:
      result = newQVariant(item.getIcon())
    of ModelRole.ThumbnailImage:
      result = newQVariant(item.getThumbnailImage())
    of ModelRole.LargeImage:
      result = newQVariant(item.getLargeImage())
    of ModelRole.KeyUid:
      result = newQVariant(item.getKeyUid())
    of ModelRole.ColorId:
      result = newQVariant(item.getColorId())
    of ModelRole.KeycardPairing:
      result = newQVariant(item.getKeycardPairing())
    of ModelRole.KeycardCreatedAccount:
      result = newQVariant(item.getKeycardCreatedAccount())

  proc setItems*(self: Model, items: seq[Item]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()

  proc findIndexByKeyUid*(self: Model, keyUid: string): int =
    for i in 0 ..< self.items.len:
      if self.items[i].getKeyUid() == keyUid:
        return i

    return -1

  proc getItemAtIndex*(self: Model, index: int): Item =
    if(index < 0 or index >= self.items.len):
      return

    return self.items[index]

  proc removeItem*(self: Model, keyUid: string) =
    let index = self.findIndexByKeyUid(keyUid)
    if index == -1 or index >= self.items.len:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.endRemoveRows()
    self.countChanged()

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

