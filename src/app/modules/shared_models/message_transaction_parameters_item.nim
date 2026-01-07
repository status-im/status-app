import Nimqml, json, std/strformat

QtObject:
  type
    TransactionParametersItem* = ref object of QObject
      id: string
      fromAddress: string
      address: string
      contract: string
      value: string
      transactionHash: string
      commandState: int
      signature: string

  proc setup(self: TransactionParametersItem)
  proc delete*(self: TransactionParametersItem)
  proc newTransactionParametersItem*(
      id: string,
      fromAddress: string,
      address: string,
      contract: string,
      value: string,
      transactionHash: string,
      commandState: int,
      signature: string,
      ): TransactionParametersItem =
    new(result, delete)
    result.setup
    result.id = id
    result.fromAddress = fromAddress
    result.address = address
    result.contract = contract
    result.value = value
    result.transactionHash = transactionHash
    result.commandState = commandState
    result.signature = signature

  proc `$`*(self: TransactionParametersItem): string =
    result = fmt"""TransactionParametersItem(
      id: {$self.id},
      fromAddress: {$self.fromAddress},
      address: {$self.address},
      contract: {$self.contract},
      value: {$self.value},
      transactionHash: {$self.transactionHash},
      commandState: {$self.commandState},
      signature: {$self.signature},
      )"""

  proc idChanged*(self: TransactionParametersItem) {.signal.}
  QtProperty[string] id:
    read = id
    notify = idChanged

  proc id*(self: TransactionParametersItem): string {.inline.} =
    self.id

  proc fromAddressChanged*(self: TransactionParametersItem) {.signal.}
  QtProperty[string] fromAddress:
    read = fromAddress
    notify = fromAddressChanged

  proc fromAddress*(self: TransactionParametersItem): string {.inline.} =
    self.fromAddress

  proc addressChanged*(self: TransactionParametersItem) {.signal.}
  QtProperty[string] address:
    read = address
    notify = addressChanged

  proc address*(self: TransactionParametersItem): string {.inline.} =
    self.address

  proc contractChanged*(self: TransactionParametersItem) {.signal.}
  QtProperty[string] contract:
    read = contract
    notify = contractChanged

  proc contract*(self: TransactionParametersItem): string {.inline.} =
    self.contract

  proc valueChanged*(self: TransactionParametersItem) {.signal.}
  QtProperty[string] value:
    read = value
    notify = valueChanged

  proc value*(self: TransactionParametersItem): string {.inline.} =
    self.value

  proc transactionHashChanged*(self: TransactionParametersItem) {.signal.}
  QtProperty[string] transactionHash:
    read = transactionHash
    notify = transactionHashChanged

  proc transactionHash*(self: TransactionParametersItem): string {.inline.} =
    self.transactionHash

  proc commandStateChanged*(self: TransactionParametersItem) {.signal.}
  QtProperty[int] commandState:
    read = commandState
    notify = commandStateChanged

  proc commandState*(self: TransactionParametersItem): int {.inline.} =
    self.commandState

  proc signatureChanged*(self: TransactionParametersItem) {.signal.}
  QtProperty[string] signature:
    read = signature
    notify = signatureChanged

  proc signature*(self: TransactionParametersItem): string {.inline.} =
    self.signature

  proc setup(self: TransactionParametersItem) =
    self.QObject.setup

  proc delete*(self: TransactionParametersItem) =
    self.QObject.delete

