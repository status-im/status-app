import app/modules/shared_models/model_utils
import nimqml, tables, strutils, sequtils, json

type
  ShowcaseContactSocialLinkItem* = object of RootObj
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
    ShowcaseContactSocialLinkModel* = ref object of QAbstractListModel
      items: seq[ShowcaseContactSocialLinkItem]

  proc delete(self: ShowcaseContactSocialLinkModel)
  proc setup(self: ShowcaseContactSocialLinkModel)
  proc newShowcaseContactSocialLinkModel*(): ShowcaseContactSocialLinkModel =
    new(result, delete)
    result.setup

  proc items*(self: ShowcaseContactSocialLinkModel): seq[ShowcaseContactSocialLinkItem] =
    self.items

  method rowCount(self: ShowcaseContactSocialLinkModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: ShowcaseContactSocialLinkModel): Table[int, string] =
    {
      ModelRole.Url.int: "url",
      ModelRole.Text.int: "text",
      ModelRole.ShowcasePosition.int: "showcasePosition",
    }.toTable

  method data(self: ShowcaseContactSocialLinkModel, index: QModelIndex, role: int): QVariant =
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

  proc setItems*(self: ShowcaseContactSocialLinkModel, items: seq[ShowcaseContactSocialLinkItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc clear*(self: ShowcaseContactSocialLinkModel) {.slot.} =
    self.setItems(@[])

  proc delete(self: ShowcaseContactSocialLinkModel) =
    self.QAbstractListModel.delete

  proc setup(self: ShowcaseContactSocialLinkModel) =
    self.QAbstractListModel.setup
