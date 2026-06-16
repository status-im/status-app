import app_service/service/transaction/dto
import app_service/service/transaction/router_transactions_dto
import app_service/service/community/dto/community
import app_service/common/types
import app/modules/shared_models/currency_amount

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method computeAirdropFee*(self: AccessInterface, uuid: string, communityId: string, tokensJsonString: string,
  walletsJsonString: string, addressFrom: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method computeDeployCollectiblesFee*(self: AccessInterface,  uuid: string, communityId: string, fromAddress: string,
  name: string, symbol: string, description: string, supply: string, infiniteSupply: bool, transferable: bool,
  selfDestruct: bool, chainId: int, imageCropInfoJson: string) {.base.} =
    raise newException(ValueError, "No implementation available")

method computeDeployAssetsFee*(self: AccessInterface, uuid: string, communityId: string, address: string, name: string,
  symbol: string, description: string, supply: string, infiniteSupply: bool, chainId: int,
  imageCropInfoJson: string) {.base.} =
    raise newException(ValueError, "No implementation available")

method computeDeployTokenOwnerFee*(self: AccessInterface, uuid: string, communityId: string, fromAddress: string,
  ownerName: string, ownerSymbol: string, ownerDescription: string, masterName: string, masterSymbol: string,
  masterDescription: string, chainId: int, imageCropInfoJson: string) {.base.} =
    raise newException(ValueError, "No implementation available")

method authenticateAndTransfer*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method onSigningResult*(self: AccessInterface, signature: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method resetTempValues*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method computeDeployFee*(self: AccessInterface, uuid: string, communityId: string, chainId: int, accountAddress: string,
  tokenType: TokenType, isOwnerDeployment: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method computeSetSignerFee*(self: AccessInterface, uuid: string, communityId: string, chainId: int, contractAddress: string, addressFrom: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method computeSelfDestructFee*(self: AccessInterface, uuid: string, collectiblesToBurnJsonString: string, contractUniqueKey: string, addressFrom: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method computeBurnFee*(self: AccessInterface, uuid: string, contractUniqueKey: string, amount: string, addressFrom: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method removeCommunityToken*(self: AccessInterface, communityId: string, chainId: int, address: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method refreshCommunityToken*(self: AccessInterface, chainId: int, address: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onOwnerTokenReceived*(self: AccessInterface, communityId: string, communityName: string, chainId: int, contractAddress: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onCommunityTokenReceived*(self: AccessInterface, name: string, symbol: string, image: string, communityId: string, communityName: string, balance: string, chainId: int, txHash: string, isFirst: bool, tokenType: int, accountName: string, accountAddress: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onLostOwnership*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method declineOwnership*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onOwnerTokenOwnerAddress*(self: AccessInterface, chainId: int, contractAddress: string, address: string, addressName: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method asyncGetOwnerTokenDetails*(self: AccessInterface, communityId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method suggestedRoutesReady*(self: AccessInterface, uuid: string, sendType: SendType, nativeCryptoCurrency: CurrencyAmount,
  fiatCurrency: CurrencyAmount, costPerPath: seq[CostPerPath], errCode: string, errDescription: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method stopUpdatesForSuggestedRoute*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method prepareSignaturesForTransactions*(self:AccessInterface, txForSigning: RouterTransactionsForSigningDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method onTransactionSent*(self: AccessInterface, uuid: string, sendType: SendType, chainId: int, approvalTx: bool,
  txHash: string, toAddress: string, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")