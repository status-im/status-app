import app/modules/shared_models/model_utils
import nimqml, tables, strutils, sequtils, json

type
  ShowcaseContactGenericItem* = object of RootObj
    showcaseKey*: string
    showcasePosition*: int

type
  ModelRole {.pure.} = enum
    ShowcaseKey
    ShowcasePosition

QtObject:
  type
    ShowcaseContactGenericModel* = ref object of QAbstractListModel
      items: seq[ShowcaseContactGenericItem]

  proc delete(self: ShowcaseContactGenericModel)
  proc setup(self: ShowcaseContactGenericModel)
  proc newShowcaseContactGenericModel*(): ShowcaseContactGenericModel =
    new(result, delete)
    result.setup

  proc items*(self: ShowcaseContactGenericModel): seq[ShowcaseContactGenericItem] =
    self.items

  method rowCount(self: ShowcaseContactGenericModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: ShowcaseContactGenericModel): Table[int, string] =
    {
      ModelRole.ShowcaseKey.int: "showcaseKey",
      ModelRole.ShowcasePosition.int: "showcasePosition",
    }.toTable

  method data(self: ShowcaseContactGenericModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.ShowcaseKey:
      result = newQVariant(item.showcaseKey)
    of ModelRole.ShowcasePosition:
      result = newQVariant(item.showcasePosition)

  proc setItems*(self: ShowcaseContactGenericModel, items: seq[ShowcaseContactGenericItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc clear*(self: ShowcaseContactGenericModel) {.slot.} =
    self.setItems(@[])

  proc delete(self: ShowcaseContactGenericModel) =
    self.QAbstractListModel.delete

  proc setup(self: ShowcaseContactGenericModel) =
    self.QAbstractListModel.setup
