import nimqml
import models/[result_model, location_menu_model, location_menu_sub_model, chat_search_model]
import io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      searchResultModel: result_model.Model
      locationMenuModel: location_menu_model.Model
      threadLocationMenuModel: SubModel
      threadLocationsLoading: bool
      threadLocationsError: bool
      chatSearchModel: chat_search_model.Model
      chatSearchModelVariant: QVariant
      switcherThreadModel: chat_search_model.Model
      switcherThreadModelVariant: QVariant

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.searchResultModel = result_model.newModel()
    result.locationMenuModel = location_menu_model.newModel()
    result.threadLocationMenuModel = newSubModel()
    result.chatSearchModel = chat_search_model.newModel(delegate)
    result.chatSearchModelVariant = newQVariant(result.chatSearchModel)
    result.switcherThreadModel = chat_search_model.newModel(delegate)
    result.switcherThreadModel.setItems(@[])
    result.switcherThreadModel.onEverythingLoaded()
    result.switcherThreadModelVariant = newQVariant(result.switcherThreadModel)

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc searchResultModel*(self: View): result_model.Model =
    return self.searchResultModel

  proc locationMenuModel*(self: View): location_menu_model.Model =
    return self.locationMenuModel

  proc getSearchResultModel*(self: View): QVariant {.slot.} =
    return newQVariant(self.searchResultModel)

  QtProperty[QVariant] resultModel:
    read = getSearchResultModel

  proc getLocationMenuModel*(self: View): QVariant {.slot.} =
    newQVariant(self.locationMenuModel)

  QtProperty[QVariant] locationMenuModel:
    read = getLocationMenuModel

  proc prepareLocationMenuModel*(self: View) {.slot.} =
    self.delegate.prepareLocationMenuModel()

  proc prepareThreadLocationsForSection*(self: View, sectionId: string) {.slot.} =
    self.delegate.prepareThreadLocationsForSection(sectionId)

  proc setSearchLocation*(self: View, location: string = "", subLocation: string = "", threadId: string = "") {.slot.} =
    self.delegate.setSearchLocation(location, subLocation, threadId)

  proc getSearchLocationObject*(self: View, chatId: string = "", threadId: string = ""): string {.slot.} =
    self.delegate.getSearchLocationObject(chatId, threadId)

  proc threadLocationMenuModel*(self: View): SubModel =
    self.threadLocationMenuModel

  proc getThreadLocationMenuModel(self: View): QVariant {.slot.} =
    newQVariant(self.threadLocationMenuModel)
  QtProperty[QVariant] threadLocationMenuModel:
    read = getThreadLocationMenuModel

  proc threadLocationsStateChanged(self: View) {.signal.}
  proc getThreadLocationsLoading(self: View): bool {.slot.} =
    self.threadLocationsLoading
  QtProperty[bool] threadLocationsLoading:
    read = getThreadLocationsLoading
    notify = threadLocationsStateChanged

  proc getThreadLocationsError(self: View): bool {.slot.} =
    self.threadLocationsError
  QtProperty[bool] threadLocationsError:
    read = getThreadLocationsError
    notify = threadLocationsStateChanged

  proc setThreadLocationsState*(self: View, loading, error: bool) =
    self.threadLocationsLoading = loading
    self.threadLocationsError = error
    self.threadLocationsStateChanged()

  proc prepareThreadLocationMenuModel*(self: View, chatId: string) {.slot.} =
    self.delegate.prepareThreadLocationMenuModel(chatId)

  proc searchMessages*(self: View, searchTerm: string) {.slot.} =
    self.delegate.searchMessages(searchTerm)

  proc resultItemClicked*(self: View, itemId: string) {.slot.} =
    self.delegate.resultItemClicked(itemId)

  proc appSearchCompleted(self: View) {.signal.}
  proc emitAppSearchCompletedSignal*(self: View) =
    self.appSearchCompleted()

  proc chatSearchModel*(self: View): chat_search_model.Model =
    return self.chatSearchModel

  proc getChatSearchModel(self: View): QVariant {.slot.} =
    return self.chatSearchModelVariant
  QtProperty[QVariant] chatSearchModel:
    read = getChatSearchModel

  proc switcherThreadModel*(self: View): chat_search_model.Model =
    self.switcherThreadModel

  proc getSwitcherThreadModel(self: View): QVariant {.slot.} =
    self.switcherThreadModelVariant

  QtProperty[QVariant] switcherThreadModel:
    read = getSwitcherThreadModel

  proc setSwitcherOpen*(self: View, open: bool) {.slot.} =
    self.delegate.setSwitcherOpen(open)

  proc delete*(self: View) =
    self.QObject.delete

