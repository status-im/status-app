import app/modules/shared_models/model_utils
import nimqml, tables, strutils, sequtils, json

type
  ShowcaseContactAccountItem* = object of RootObj
    address*: string
    name*: string
    emoji*: string
    colorId*: string
    showcasePosition*: int

type
  ModelRole {.pure.} = enum
    Address
    Name
    Emoji
    ColorId
    ShowcasePosition

QtObject:
  type
    ShowcaseContactAccountModel* = ref object of QAbstractListModel
      items: seq[ShowcaseContactAccountItem]

  proc delete(self: ShowcaseContactAccountModel)
  proc setup(self: ShowcaseContactAccountModel)
  proc newShowcaseContactAccountModel*(): ShowcaseContactAccountModel =
    new(result, delete)
    result.setup

  proc items*(self: ShowcaseContactAccountModel): seq[ShowcaseContactAccountItem] =
    self.items

  method rowCount(self: ShowcaseContactAccountModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: ShowcaseContactAccountModel): Table[int, string] =
    {
      ModelRole.Address.int: "address",
      ModelRole.Name.int: "name",
      ModelRole.Emoji.int: "emoji",
      ModelRole.ColorId.int: "colorId",
      ModelRole.ShowcasePosition.int: "showcasePosition",
    }.toTable

  method data(self: ShowcaseContactAccountModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Address:
      result = newQVariant(item.address)
    of ModelRole.Name:
      result = newQVariant(item.name)
    of ModelRole.Emoji:
      result = newQVariant(item.emoji)
    of ModelRole.ColorId:
      result = newQVariant(item.colorId)
    of ModelRole.ShowcasePosition:
      result = newQVariant(item.showcasePosition)

  proc setItems*(self: ShowcaseContactAccountModel, items: seq[ShowcaseContactAccountItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc clear*(self: ShowcaseContactAccountModel) {.slot.} =
    self.setItems(@[])

  proc delete(self: ShowcaseContactAccountModel) =
    self.QAbstractListModel.delete

  proc setup(self: ShowcaseContactAccountModel) =
    self.QAbstractListModel.setup
