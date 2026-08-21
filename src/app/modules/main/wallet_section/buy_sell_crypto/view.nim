import nimqml
import options

import ./model
import ./item
import ./io_interface

import app_service/service/ramp/dto

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      model: Model
      isFetching: bool

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.model = newModel()
    result.isFetching = false

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc modelChanged*(self: View) {.signal.}

  proc getModel(self: View): QAbstractListModel {.slot.} =
    return self.model

  QtProperty[QAbstractListModel] model:
    read = getModel
    notify = modelChanged

  proc isFetchingChanged*(self: View) {.signal.}

  proc getIsFetching*(self: View): bool {.slot.} =
    return self.isFetching

  QtProperty[bool] isFetching:
    read = getIsFetching
    notify = isFetchingChanged

  proc setIsFetching*(self: View, value: bool) =
    if self.isFetching == value:
      return
    self.isFetching = value
    self.isFetchingChanged()

  proc setItems*(self: View, items: seq[Item]) =
    self.model.setItems(items)
    self.modelChanged()

  proc fetchProviders*(self: View) {.slot.} =
    self.delegate.fetchProviders()

  proc fetchProviderUrl*(self: View, 
    uuid: string, 
    providerID: string, 
    isRecurrent: bool, 
    destinationAccountAddress: string, 
    chainID: int, 
    symbol: string) {.slot.} =
    let parameters = CryptoRampParametersDto(
      isRecurrent: isRecurrent,
    )

    if destinationAccountAddress.len > 0:
      parameters.destinationAddress = some(destinationAccountAddress)
    if chainID > 0:
      parameters.chainID = some(chainID)
    if symbol.len > 0:
      parameters.symbol = some(symbol)

    self.delegate.fetchProviderUrl(uuid, providerID, parameters)

  proc providerUrlReady*(self: View, uuid: string, url: string) {.signal.}

  proc onProviderUrlReady*(self: View, uuid: string, url: string) =
    self.providerUrlReady(uuid, url)

  proc delete*(self: View) =
    self.QObject.delete

