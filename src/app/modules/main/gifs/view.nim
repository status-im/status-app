import nimqml
import ./io_interface
import ./gif_column_model
import ../../../../app_service/service/gif/dto

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      gifColumnAModel: GifColumnModel
      gifColumnBModel: GifColumnModel
      gifColumnCModel: GifColumnModel
      gifLoading: bool

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.gifColumnAModel = newGifColumnModel()
    result.gifColumnBModel = newGifColumnModel()
    result.gifColumnCModel = newGifColumnModel()
    result.gifLoading = false

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc gifLoaded*(self: View) {.signal.}

  proc getGifColumnA*(self: View): QAbstractListModel {.slot.} =
    result = self.gifColumnAModel

  QtProperty[QAbstractListModel] gifColumnA:
    read = getGifColumnA
    notify = gifLoaded

  proc getGifColumnB*(self: View): QAbstractListModel {.slot.} =
    result = self.gifColumnBModel

  QtProperty[QAbstractListModel] gifColumnB:
    read = getGifColumnB
    notify = gifLoaded

  proc getGifColumnC*(self: View): QAbstractListModel {.slot.} =
    result = self.gifColumnCModel

  QtProperty[QAbstractListModel] gifColumnC:
    read = getGifColumnC
    notify = gifLoaded

  proc updateGifColumns*(self: View, data: seq[GifDto]) =
    var columnAData: seq[GifDto] = @[]
    var columnAHeight = 0
    var columnBData: seq[GifDto] = @[]
    var columnBHeight = 0
    var columnCData: seq[GifDto] = @[]
    var columnCHeight = 0

    for item in data:
      if columnAHeight <= columnBHeight:
        columnAData.add(item)
        columnAHeight += item.height
      elif columnBHeight <= columnCHeight:
        columnBData.add(item)
        columnBHeight += item.height
      else:
        columnCData.add(item)
        columnCHeight += item.height

    self.gifColumnAModel.setNewData(columnAData)
    self.gifColumnBModel.setNewData(columnBData)
    self.gifColumnCModel.setNewData(columnCData)
    self.gifLoaded()

  proc gifLoadingChanged*(self: View) {.signal.}
  proc setGifLoading*(self: View, value: bool) =
    self.gifLoading = value
    self.gifLoadingChanged()
  proc getGifLoading*(self: View): bool {.slot.} =
    result = self.gifLoading

  QtProperty[bool] gifLoading:
    read = getGifLoading
    notify = gifLoadingChanged

  proc searchGifs*(self: View, query: string) {.slot.} =
    self.delegate.searchGifs(query)

  proc getTrendingsGifs*(self: View) {.slot.} =
    self.delegate.getTrendingsGifs()

  proc getRecentsGifs*(self: View) {.slot.} =
    let data = self.delegate.getRecentsGifs()
    if data.len > 0:
      self.updateGifColumns(data)
      return

    # recent gifs were not loaded yet, so we do it now
    self.delegate.loadRecentGifs()

  proc getFavoritesGifs*(self: View) {.slot.} =
    let data = self.delegate.getFavoritesGifs()
    if data.len > 0:
      self.updateGifColumns(data)
      return

    # favorite gifs were not loaded yet, so we do it now
    self.delegate.loadFavoriteGifs()

  proc findGifDto(self: View, id: string): GifDto =
    for item in self.gifColumnAModel.gifs:
      if item.id == id:
        return item

    for item in self.gifColumnBModel.gifs:
      if item.id == id:
        return item

    for item in self.gifColumnCModel.gifs:
      if item.id == id:
        return item

    raise newException(ValueError, "Invalid id " & $id)

  proc toggleFavoriteGif*(self: View, id: string, reload: bool = false) {.slot.} =
    let gifItem = self.findGifDto(id)
    self.delegate.toggleFavoriteGif(gifItem)

    if reload:
      self.getFavoritesGifs()

  proc addToRecentsGif*(self: View, id: string) {.slot.} =
    let gifItem = self.findGifDto(id)
    self.delegate.addToRecentsGif(gifItem)

  proc isFavorite*(self: View, id: string): bool {.slot.} =
    let gifItem = self.findGifDto(id)
    return self.delegate.isFavorite(gifItem)

  proc delete*(self: View) =
    self.QObject.delete

