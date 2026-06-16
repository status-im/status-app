import nimqml, json, strutils, sequtils

import ./io_interface as community_tokens_module_interface
import app/modules/shared_models/currency_amount

QtObject:
  type
    View* = ref object of QObject
      communityTokensModule: community_tokens_module_interface.AccessInterface
      ownerTokenDetails: string

  proc load*(self: View) =
    discard

  proc delete*(self: View)
  proc newView*(communityTokensModule: community_tokens_module_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.communityTokensModule = communityTokensModule

  proc authenticateAndTransfer*(self: View) {.slot.} =
    self.communityTokensModule.authenticateAndTransfer()

  proc signingRequested*(self: View, keyUid: string, txHash: string, path: string, address: string) {.signal.}
  proc emitSigningRequested*(self: View, keyUid: string, txHash: string, path: string, address: string) =
    self.signingRequested(keyUid, txHash, path, address)

  proc onSigningResult*(self: View, signature: string) {.slot.} =
    self.communityTokensModule.onSigningResult(signature)

  proc transactionError*(self: View, error: string) {.signal.}
  proc emitTransactionError*(self: View, error: string) =
    self.transactionError(error)

  proc computeDeployCollectiblesFee*(self: View, uuid: string, communityId: string, fromAddress: string, name: string,
    symbol: string, description: string, supply: string, infiniteSupply: bool, transferable: bool, selfDestruct: bool,
    chainId: int, imageCropInfoJson: string) {.slot.} =
      self.communityTokensModule.computeDeployCollectiblesFee(uuid, communityId, fromAddress, name, symbol, description,
        supply, infiniteSupply, transferable, selfDestruct, chainId, imageCropInfoJson)

  proc computeDeployAssetsFee*(self: View, uuid: string, communityId: string, fromAddress: string, name: string,
    symbol: string, description: string, supply: string, infiniteSupply: bool, chainId: int,
    imageCropInfoJson: string) {.slot.} =
      self.communityTokensModule.computeDeployAssetsFee(uuid, communityId, fromAddress, name, symbol, description, supply,
        infiniteSupply, chainId, imageCropInfoJson)

  proc computeDeployTokenOwnerFee*(self:View, uuid: string, communityId: string, fromAddress: string, ownerName: string,
    ownerSymbol: string, ownerDescription: string, masterName: string, masterSymbol: string, masterDescription: string,
    chainId: int, imageCropInfoJson: string) {.slot.} =
      self.communityTokensModule.computeDeployTokenOwnerFee(uuid, communityId, fromAddress, ownerName, ownerSymbol,
      ownerDescription, masterName, masterSymbol, masterDescription, chainId, imageCropInfoJson)

  proc removeCommunityToken*(self: View, communityId: string, chainId: int, address: string) {.slot.} =
    self.communityTokensModule.removeCommunityToken(communityId, chainId, address)

  proc refreshCommunityToken*(self: View, chainId: int, address: string) {.slot.} =
    self.communityTokensModule.refreshCommunityToken(chainId, address)

  proc computeAirdropFee*(self: View, uuid: string, communityId: string, tokensJsonString: string,
    walletsJsonString: string, addressFrom: string) {.slot.} =
    self.communityTokensModule.computeAirdropFee(uuid, communityId, tokensJsonString, walletsJsonString, addressFrom)

  proc ownerTokenReceived*(self: View, communityId: string, communityName: string, chainId: int, contractAddress: string) {.signal.}
  proc communityTokenReceived*(self: View, name: string, symbol: string, image: string, communityId: string, communityName: string, balance: string, chainId: int, txHash: string, isFirst: bool, tokenType: int, accountName: string, accountAddress: string) {.signal.}
  proc ownershipNodeLost*(self: View, communityId: string, communityName: string) {.signal.}

  proc computeSetSignerFee*(self: View, uuid: string, communityId: string, chainId: int, contractAddress: string, addressFrom: string) {.slot.} =
    self.communityTokensModule.computeSetSignerFee(uuid, communityId, chainId, contractAddress, addressFrom)

  proc computeSelfDestructFee*(self: View, uuid: string, collectiblesToBurnJsonString: string, contractUniqueKey: string, addressFrom: string) {.slot.} =
    self.communityTokensModule.computeSelfDestructFee(uuid, collectiblesToBurnJsonString, contractUniqueKey, addressFrom)

  proc computeBurnFee*(self: View, uuid: string, contractUniqueKey: string, amount: string, addressFrom: string) {.slot.} =
    self.communityTokensModule.computeBurnFee(uuid, contractUniqueKey, amount, addressFrom)

  proc declineOwnership*(self: View, communityId: string) {.slot.} =
    self.communityTokensModule.declineOwnership(communityId)

  proc emitOwnerTokenReceived*(self: View, communityId: string, communityName: string, chainId: int, contractAddress: string) =
    self.ownerTokenReceived(communityId, communityName, chainId, contractAddress)

  proc emitCommunityTokenReceived*(self: View, name: string, symbol: string, image: string, communityId: string, communityName: string, balance: string, chainId: int, txHash: string, isFirst: bool, tokenType: int, accountName: string, accountAddress: string) =
    self.communityTokenReceived(name, symbol, image, communityId, communityName, balance, chainId, txHash, isFirst, tokenType, accountName, accountAddress)

  proc emitOwnershipLost*(self: View, communityId: string, communityName: string) =
    self.ownershipNodeLost(communityId, communityName)

  proc asyncGetOwnerTokenDetails*(self: View, communityId: string) {.slot.} =
    self.communityTokensModule.asyncGetOwnerTokenDetails(communityId)

  proc ownerTokenDetailsChanged*(self: View) {.signal.}
  proc getOwnerTokenDetails*(self: View): string {.slot.} =
    return self.ownerTokenDetails
  proc setOwnerTokenDetails*(self: View, ownerTokenDetails: string) =
    self.ownerTokenDetails = ownerTokenDetails
    self.ownerTokenDetailsChanged()

  QtProperty[string] ownerTokenDetails:
    read = getOwnerTokenDetails
    notify = ownerTokenDetailsChanged

  proc suggestedRoutesReady(self: View, uuid: string, nativeCryptoCurrency: QVariant, fiatCurrency: QVariant,
    costPerPath: string, errCode: string, errDescription: string) {.signal.}
  proc emitSuggestedRoutesReadySignal*(self: View, uuid: string, nativeCryptoCurrency: CurrencyAmount, fiatCurrency: CurrencyAmount,
    costPerPath: JsonNode, errCode: string, errDescription: string) =
    self.suggestedRoutesReady(uuid, newQVariant(nativeCryptoCurrency), newQVariant(fiatCurrency),
      $costPerPath, errCode, errDescription)

  proc stopUpdatesForSuggestedRoute*(self: View) {.slot.} =
    self.communityTokensModule.stopUpdatesForSuggestedRoute()

  proc delete*(self: View) =
    self.QObject.delete

