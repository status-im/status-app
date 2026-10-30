import app/modules/shared_models/model_utils
import nimqml, tables, strutils, std/strformat, sequtils

import location_menu_sub_item

type
  SubModelRole {.pure.} = enum
    Value = UserRole + 1
    Text
    Image
    Icon
    IconColor
    IsUserIcon
    IsImage
    Position
    LastMessageTimestamp
    ColorId
    HasThreads

QtObject:
  type
    SubModel* = ref object of QAbstractListModel
      items: seq[SubItem]

  proc delete*(self: SubModel)
  proc setup(self: SubModel)
  proc newSubModel*(): SubModel =
    new(result, delete)
    result.setup()

  proc `$`*(self: SubModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i]})
      """

  proc countChanged*(self: SubModel) {.signal.}

  proc count*(self: SubModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = count
    notify = countChanged

  method rowCount(self: SubModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: SubModel): Table[int, string] =
    {
      SubModelRole.Value.int:"value",
      SubModelRole.Text.int:"text",
      SubModelRole.Image.int:"imageSource",
      SubModelRole.Icon.int:"iconName",
      SubModelRole.IconColor.int:"iconColor",
      SubModelRole.IsUserIcon.int:"isUserIcon",
      SubModelRole.IsImage.int:"isImage",
      SubModelRole.Position.int:"position",
      SubModelRole.LastMessageTimestamp.int:"lastMessageTimestamp",
      SubModelRole.ColorId.int:"colorId",
      SubModelRole.HasThreads.int:"hasThreads",
    }.toTable

  method data(self: SubModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, SubModelRole)

    let item = self.items[index.row]

    let enumRole = role.SubModelRole

    case enumRole:
    of SubModelRole.Value:
      result = newQVariant(item.value)
    of SubModelRole.Text:
      result = newQVariant(item.text)
    of SubModelRole.Image:
      result = newQVariant(item.image)
    of SubModelRole.Icon:
      result = newQVariant(item.icon)
    of SubModelRole.IconColor:
      result = newQVariant(item.iconColor)
    of SubModelRole.IsUserIcon:
      result = newQVariant(item.isUserIcon)
    of SubModelRole.IsImage:
      result = newQVariant(item.isImage)
    of SubModelRole.Position:
      result = newQVariant(item.position)
    of SubModelRole.LastMessageTimestamp:
      result = newQVariant(item.lastMessageTimestamp)
    of SubModelRole.ColorId:
      result = newQVariant(item.colorId)
    of SubModelRole.HasThreads:
      result = newQVariant(item.hasThreads)

  proc chatIds*(self: SubModel): seq[string] =
    for item in self.items:
      result.add(item.value)

  proc updateThreadAvailability*(self: SubModel, availability: Table[string, bool]) =
    for row, item in self.items:
      if availability.hasKey(item.value) and item.hasThreads != availability[item.value]:
        item.hasThreads = availability[item.value]
        let index = self.createIndex(row, 0, nil)
        defer: index.delete()
        self.dataChanged(index, index, @[SubModelRole.HasThreads.int])

  proc setItems*(self: SubModel, items: seq[SubItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc removeItemForValue*(self: SubModel, value: string) =
    if self.items.anyIt(it.value == value):
      self.setItems(self.items.filterIt(it.value != value))

  proc getItemForValue*(self: SubModel, value: string): SubItem =
    for i in self.items:
      if (i.value == value):
        return i

  proc delete*(self: SubModel) =
    self.QAbstractListModel.delete

  proc setup(self: SubModel) =
    self.QAbstractListModel.setup
