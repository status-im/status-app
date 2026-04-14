import nimqml
import io_interface
import model

import app_service/service/token/items/token
from app_service/service/ens/utils import ENS_REGISTRY

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      model: Model
      modelVariant: QVariant
      etherscanTxLink: string
      etherscanAddressLink: string

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.model = newModel()
    result.modelVariant = newQVariant(result.model)
    result.delegate = delegate

  proc load*(self: View, txLink, addressLink: string) =
    self.etherscanTxLink = txLink
    self.etherscanAddressLink = addressLink
    self.delegate.viewDidLoad()

  proc model*(self: View): Model =
    return self.model

  proc modelChanged*(self: View) {.signal.}
  proc getModel(self: View): QVariant {.slot.} =
    return self.modelVariant
  QtProperty[QVariant] model:
    read = getModel
    notify = modelChanged

  proc getEnsRegistry(self: View): string {.slot.} =
    return ENS_REGISTRY

  proc usernameAvailabilityChecked(self: View, availabilityStatus: string, ownerAddress: string) {.signal.}
  proc sendUsernameAvailabilityCheckedSignal*(self: View, availabilityStatus: string, ownerAddress: string) =
    self.usernameAvailabilityChecked(availabilityStatus, ownerAddress)

  proc checkEnsUsernameAvailability*(self: View, desiredEnsUsername: string, statusDomain: bool) {.slot.} =
    self.delegate.checkEnsUsernameAvailability(desiredEnsUsername, statusDomain)

  proc numOfPendingEnsUsernames*(self: View): int {.slot.} =
    return self.delegate.numOfPendingEnsUsernames()

  proc loading(self: View, isLoading: bool) {.signal.}
  proc detailsObtained(self: View, chainId: int, ensName: string, address: string, pubkey: string, isStatus: bool, expirationTime: int) {.signal.}

  proc fetchDetailsForEnsUsername*(self: View, chainId: int, ensUsername: string) {.slot.} =
    self.loading(true)
    self.delegate.fetchDetailsForEnsUsername(chainId, ensUsername)

  proc processObtainedEnsUsermesDetails*(self: View, chainId: int, ensUsername: string, address: string, pubkey: string, isStatus: bool,
    expirationTime: int) =
    self.loading(false)
    self.detailsObtained(chainId, ensUsername, address, pubkey, isStatus, expirationTime)

  proc transactionWasSent(self: View, trxType: string, chainId: int, txHash: string, username: string, error: string) {.signal.}
  proc emitTransactionWasSentSignal*(self: View, trxType: string, chainId: int, txHash: string, username: string, error: string) =
    self.transactionWasSent(trxType, chainId, txHash, username, error)

  proc getEtherscanTxLink*(self: View): string {.slot.} =
    return self.etherscanTxLink

  proc getEtherscanAddressLink*(self: View): string {.slot.} =
    return self.etherscanAddressLink

  proc transactionCompleted(self: View, success: bool, txHash: string, username: string, trxType: string) {.signal.}
  proc emitTransactionCompletedSignal*(self: View, success: bool, txHash: string, username: string, trxType: string) =
    self.transactionCompleted(success, txHash, username, trxType)

  proc removeEnsUsername*(self: View, chainId: int, ensUsername: string): bool {.slot.} =
    return self.delegate.removeEnsUsername(chainId, ensUsername)

  proc connectOwnedUsername*(self: View, ensUsername: string, isStatus: bool) {.slot.} =
    self.delegate.connectOwnedUsername(ensUsername, isStatus)

  proc getEnsRegisteredAddress*(self: View): string {.slot.} =
    return self.delegate.getEnsRegisteredAddress()

  proc getWalletDefaultAddress*(self: View): string {.slot.} =
    return self.delegate.getWalletDefaultAddress()

  proc getCurrentCurrency*(self: View): string {.slot.} =
    return self.delegate.getCurrentCurrency()

  proc getFiatValue*(self: View, cryptoBalance: string, tokenKey: string): string {.slot.} =
    return self.delegate.getFiatValue(cryptoBalance, tokenKey)

  proc getCryptoValue*(self: View, fiatAmount: string, tokenKey: string): string {.slot.} =
    return self.delegate.getCryptoValue(fiatAmount, tokenKey)

  proc getStatusTokenKeyForChainId*(self: View, chainId: int): string {.slot.} =
    let tokenItem = createStatusTokenItem(chainId)
    if tokenItem.isNil:
      return ""
    return tokenItem.key

  proc setPrefferedEnsUsername*(self: View, ensUsername: string) {.slot.} =
    self.delegate.setPrefferedEnsUsername(ensUsername)

  proc ensnameResolverAddress*(self: View, ensUsername: string): string {.slot.} =
    return self.delegate.ensnameResolverAddress(ensUsername)

  proc delete*(self: View) =
    self.QObject.delete

