import nimqml
import models/[result_model, location_menu_model, chat_search_model]
import io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      searchResultModel: result_model.Model
      locationMenuModel: location_menu_model.Model
      chatSearchModel: chat_search_model.Model

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.searchResultModel = result_model.newModel()
    result.locationMenuModel = location_menu_model.newModel()
    result.chatSearchModel = chat_search_model.newModel(delegate)

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc searchResultModel*(self: View): result_model.Model =
    return self.searchResultModel

  proc locationMenuModel*(self: View): location_menu_model.Model =
    return self.locationMenuModel

  proc getSearchResultModel*(self: View): QAbstractListModel {.slot.} =
    return self.searchResultModel

  QtProperty[QAbstractListModel] resultModel:
    read = getSearchResultModel

  proc getLocationMenuModel*(self: View): QAbstractListModel {.slot.} =
    return self.locationMenuModel

  QtProperty[QAbstractListModel] locationMenuModel:
    read = getLocationMenuModel

  proc prepareLocationMenuModel*(self: View) {.slot.} =
    self.delegate.prepareLocationMenuModel()

  proc setSearchLocation*(self: View, location: string = "", subLocation: string = "") {.slot.} =
    self.delegate.setSearchLocation(location, subLocation)

  proc getSearchLocationObject*(self: View): string {.slot.} =
    self.delegate.getSearchLocationObject()

  proc searchMessages*(self: View, searchTerm: string) {.slot.} =
    self.delegate.searchMessages(searchTerm)

  proc resultItemClicked*(self: View, itemId: string) {.slot.} =
    self.delegate.resultItemClicked(itemId)

  proc appSearchCompleted(self: View) {.signal.}
  proc emitAppSearchCompletedSignal*(self: View) =
    self.appSearchCompleted()

  proc chatSearchModel*(self: View): chat_search_model.Model =
    return self.chatSearchModel

  proc getChatSearchModel(self: View): QAbstractListModel {.slot.} =
    return self.chatSearchModel
  QtProperty[QAbstractListModel] chatSearchModel:
    read = getChatSearchModel

  proc delete*(self: View) =
    self.QObject.delete

