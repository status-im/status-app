import tables

import app_service/service/transaction/dto
import app_service/service/transaction/router_transactions_dto
import app_service/service/transaction/dtoV2

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method suggestedRoutes*(self: AccessInterface,
  uuid: string,
  sendType: SendType,
  chainId: int,
  accountFrom: string,
  accountTo: string,
  tokenGroupKey: string,
  tokenIsOwnerToken: bool,
  amountIn: string,
  toTokenGroupKey: string = "",
  amountOut: string = "",
  slippagePercentage: float = 0.0,
  extraParamsTable: Table[string, string] = initTable[string, string]()) {.base.} =
    raise newException(ValueError, "No implementation available")

method resetData*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method authenticateAndTransfer*(self: AccessInterface, fromAddr: string, uuid: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method suggestedRoutesReady*(self: AccessInterface, uuid: string, routes: seq[TransactionPathDtoV2], errCode: string, errDescription: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method setFeeMode*(self: AccessInterface, feeMode: int, routerInputParamsUuid: string, pathName: string, chainId: int,
  isApprovalTx: bool, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method setCustomTxDetails*(self: AccessInterface, nonce: int, gasAmount: int, gasPrice: string, maxFeesPerGas: string, priorityFee: string,
  routerInputParamsUuid: string, pathName: string, chainId: int, isApprovalTx: bool, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method getEstimatedTime*(self: AccessInterface, chainId: int, gasPrice: string, maxFeesPerGas: string, priorityFee: string): int {.base.} =
  raise newException(ValueError, "No implementation available")

method transactionWasSent*(self: AccessInterface, uuid: string, chainId: int = 0, approvalTx: bool = false, txHash: string = "", error: string = "") {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method prepareSignaturesForTransactions*(self:AccessInterface, txForSigning: RouterTransactionsForSigningDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onSigningResult*(self: AccessInterface, signature: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method transactionSendingComplete*(self: AccessInterface, txHash: string, status: string) {.base.} =
  raise newException(ValueError, "No implementation available")