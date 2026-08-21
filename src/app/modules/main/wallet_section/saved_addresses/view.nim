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

  proc savedAddressAddedOrUpdated*(self: View, added: bool, name: string, address: string, errorMsg: string) {.signal.}

  proc createOrUpdateSavedAddress*(self: View, name: string, address: string, ens: string, colorId: string) {.slot.} =
    self.delegate.createOrUpdateSavedAddress(name, address, ens, colorId)

  proc savedAddressDeleted*(self: View, name: string, address: string, errorMsg: string) {.signal.}

  proc deleteSavedAddress*(self: View, address: string) {.slot.} =
    self.delegate.deleteSavedAddress(address)

  proc savedAddressNameExists*(self: View, name: string): bool {.slot.} =
    return self.delegate.savedAddressNameExists(name)

  proc getSavedAddressAsJson*(self: View, address: string): string {.slot.} =
    return self.delegate.getSavedAddressAsJson(address)

  proc remainingCapacityForSavedAddresses*(self: View): int {.slot.} =
    return self.delegate.remainingCapacityForSavedAddresses()

  proc delete*(self: View) =
    self.QObject.delete

