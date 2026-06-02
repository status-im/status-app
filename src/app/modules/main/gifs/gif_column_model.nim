import app/modules/shared_models/model_utils
import nimqml, tables, sequtils

import ../../../../app_service/service/gif/dto

type
  GifRoles {.pure.} = enum
    Url = UserRole + 1
    Id = UserRole + 2
    Title = UserRole + 3
    TinyUrl = UserRole + 4

QtObject:
  type
    GifColumnModel* = ref object of QAbstractListModel
      gifs*: seq[GifDto]

  proc setup(self: GifColumnModel)
  proc delete(self: GifColumnModel)
  proc newGifColumnModel*(): GifColumnModel =
    new(result, delete)
    result.gifs = @[]
    result.setup()

  proc setNewData*(self: GifColumnModel, gifs: seq[GifDto]) =
    self.beginResetModel()
    self.gifs = gifs
    self.endResetModel()

  method rowCount(self: GifColumnModel, index: QModelIndex = nil): int =
    self.gifs.len

  method data(self: GifColumnModel, index: QModelIndex, role: int): QVariant =
    guardModelDataIndex(index, self.gifs.len)

    let gif = self.gifs[index.row]
    case role.GifRoles:
      of GifRoles.Url: result = newQVariant(gif.url)
      of GifRoles.Id: result = newQVariant(gif.id)
      of GifRoles.Title: result = newQVariant(gif.title)
      of GifRoles.TinyUrl: result = newQVariant(gif.tinyUrl)

  method roleNames(self: GifColumnModel): Table[int, string] =
    {
      GifRoles.Url.int:"url",
      GifRoles.Id.int:"id",
      GifRoles.Title.int:"title",
      GifRoles.TinyUrl.int:"tinyUrl",
    }.toTable

  proc setup(self: GifColumnModel) = self.QAbstractListModel.setup
  proc delete(self: GifColumnModel) = self.QAbstractListModel.delete