import nimqml

import model
import io_interface

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      model: Model

  proc delete*(self: View)

  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.model = newModel()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc modelChanged*(self: View) {.signal.}

  proc getModel*(self: View): Model =
    return self.model

  proc getModelVariant(self: View): QAbstractListModel {.slot.} =
    return self.model

  QtProperty[QAbstractListModel] model:
    read = getModelVariant
    notify = modelChanged

  proc setItems*(self: View, items: seq[Item]) =
    self.model.setItems(items)

  proc followingAddressesUpdated*(self: View, userAddress: string) {.signal.}
  
  proc totalFollowingCountChanged*(self: View) {.signal.}

  proc getTotalFollowingCount*(self: View): int {.slot.} =
    return self.delegate.getTotalFollowingCount()

  QtProperty[int] totalFollowingCount:
    read = getTotalFollowingCount
    notify = totalFollowingCountChanged

  proc fetchFollowingAddresses*(self: View, userAddress: string, search: string = "", limit: int = 10, offset: int = 0) {.slot.} =
    self.delegate.fetchFollowingAddresses(userAddress, search, limit, offset)

  proc delete*(self: View) =
    self.QObject.delete
