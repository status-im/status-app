import app/modules/shared_models/model_utils
import nimqml, tables, strutils, sequtils, json

type
  ShowcasePreferencesSocialLinkItem* = object of RootObj
    url*: string
    text*: string
    showcasePosition*: int

type
  ModelRole {.pure.} = enum
    Url
    Text
    ShowcasePosition

QtObject:
  type
    ShowcasePreferencesSocialLinkModel* = ref object of QAbstractListModel
      items: seq[ShowcasePreferencesSocialLinkItem]

  proc delete(self: ShowcasePreferencesSocialLinkModel)
  proc setup(self: ShowcasePreferencesSocialLinkModel)
  proc newShowcasePreferencesSocialLinkModel*(): ShowcasePreferencesSocialLinkModel =
    new(result, delete)
    result.setup

  proc items*(self: ShowcasePreferencesSocialLinkModel): seq[ShowcasePreferencesSocialLinkItem] =
    self.items

  method rowCount(self: ShowcasePreferencesSocialLinkModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: ShowcasePreferencesSocialLinkModel): Table[int, string] =
    {
      ModelRole.Url.int: "url",
      ModelRole.Text.int: "text",
      ModelRole.ShowcasePosition.int: "showcasePosition",
    }.toTable

  method data(self: ShowcasePreferencesSocialLinkModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Url:
      result = newQVariant(item.url)
    of ModelRole.Text:
      result = newQVariant(item.text)
    of ModelRole.ShowcasePosition:
      result = newQVariant(item.showcasePosition)

  proc setItems*(self: ShowcasePreferencesSocialLinkModel, items: seq[ShowcasePreferencesSocialLinkItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc clear*(self: ShowcasePreferencesSocialLinkModel) {.slot.} =
    self.setItems(@[])

  proc delete(self: ShowcasePreferencesSocialLinkModel) =
    self.QAbstractListModel.delete

  proc setup(self: ShowcasePreferencesSocialLinkModel) =
    self.QAbstractListModel.setup
