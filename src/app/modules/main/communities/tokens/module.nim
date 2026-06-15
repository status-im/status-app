import nimqml
import tables, json, sequtils, sugar, stint, strutils, chronicles

import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/community_tokens/service as community_tokens_service
import app_service/service/transaction/service as transaction_service
import app_service/service/network/service as networks_service
import app_service/service/community/service as community_service
import app_service/service/accounts/utils as utl
import app_service/common/types
import app_service/common/utils
import app_service/common/wallet_constants
import app/core/eventemitter
import app/global/global_singleton
import app/modules/shared_models/currency_amount
import ../io_interface as parent_interface
import ./io_interface, ./view , ./controller

export io_interface

const DEFAULT_COMMUNITY_TOKENS_DECIMALS = 18 # determined by the community creation contract

type
  ContractAction {.pure.} = enum
    Unknown = 0
    Deploy = 1
    Airdrop = 2
    SelfDestruct = 3
    Burn = 4
    DeployOwnerToken = 5
    SetSigner = 6

type
  Module*  = ref object of io_interface.AccessInterface
    parent: parent_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    tempUuid: string
    tempPin: string
    tempPassword: string
    tempTokenAndAmountList: seq[CommunityTokenAndAmount]
    tempWalletAndAmountList: seq[WalletAndAmount]
    tempAddressPath: string
    tempAddressFrom: string
    tempCommunityId: string
    tempChainId: int
    tempContractAddress: string
    tempDeploymentParams: DeploymentParameters
    tempWalletAddresses: seq[string]
    tempContractAction: ContractAction
    tempContractUniqueKey: string
    tempAmount: Uint256
    tempOwnerDeploymentParams: DeploymentParameters
    tempMasterDeploymentParams: DeploymentParameters
    tempOwnerTokenCommunity: CommunityDto
    tempResolvedSignatures: TransactionsSignatures
    tempTxHashBeingProcessed: string

proc newCommunityTokensModule*(
    parent: parent_interface.AccessInterface,
    events: EventEmitter,
    walletAccountService: wallet_account_service.Service,
    communityTokensService: community_tokens_service.Service,
    transactionService: transaction_service.Service,
    networksService: networks_service.Service,
    communityService: community_service.Service
  ): Module =
  result = Module()
  result.parent = parent
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newCommunityTokensController(result, events, walletAccountService, communityTokensService,
    transactionService, networksService, communityService)

## Forward declarations
proc buildTransactionsFromRoute(self: Module)

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method resetTempValues(self:Module) =
  self.tempUuid = ""
  self.tempPin = ""
  self.tempPassword = ""
  self.tempAddressPath = ""
  self.tempAddressFrom = ""
  self.tempCommunityId = ""
  self.tempDeploymentParams = DeploymentParameters()
  self.tempChainId = 0
  self.tempContractAddress = ""
  self.tempWalletAddresses = @[]
  self.tempContractAction = ContractAction.Unknown
  self.tempTokenAndAmountList = @[]
  self.tempWalletAndAmountList = @[]
  self.tempContractUniqueKey = ""
  self.tempOwnerDeploymentParams = DeploymentParameters()
  self.tempMasterDeploymentParams = DeploymentParameters()
  self.tempOwnerTokenCommunity = CommunityDto()
  self.tempResolvedSignatures.clear()
  self.tempTxHashBeingProcessed = ""

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("communityTokensModule", self.viewVariant)
  self.controller.init()
  self.view.load()

proc createOwnerAndMasterDeploymentParams(self: Module, communityId: string): (DeploymentParameters, DeploymentParameters) =
  let commName = self.controller.getCommunityById(communityId).name
  let commNameShort = try: commName[0 .. 2].toUpper except: commName.toUpper
  return (
    DeploymentParameters(
      communityId: communityId,
      name: "Owner-" & commName,
      symbol: "OWN" & commNameShort,
      supply: stint.u256("1"),
      infiniteSupply: false,
      transferable: true,
      remoteSelfDestruct: false,
      tokenUri: utl.changeCommunityKeyCompression(communityId) & "/"
    ),
    DeploymentParameters(
      communityId: communityId,
      name: "TMaster-" & commName,
      symbol: "TM" & commNameShort,
      infiniteSupply: true,
      transferable: false,
      remoteSelfDestruct: true,
      tokenUri: utl.changeCommunityKeyCompression(communityId) & "/"
    )
  )

method authenticateAndTransfer*(self: Module) =
  self.tempResolvedSignatures.clear()

  if self.tempUuid.len == 0:
    error "No uuid to authenticate and transfer"
    #TODO: notify about error
    return

  if self.tempAddressFrom.len == 0:
    error "No address to send from"
    #TODO: notify about error
    return

  let kp = self.controller.getKeypairByAccountAddress(self.tempAddressFrom)
  if not kp.isNil and kp.migratedToColdWallet():
    let accounts = kp.accounts.filter(acc => cmpIgnoreCase(acc.address, self.tempAddressFrom) == 0)
    if accounts.len != 1:
      error "cannot resolve selected account to send from among known keypair accounts"
      #TODO: notify about error
      return
    self.controller.authenticate(kp.keyUid)
  else:
    self.controller.authenticate()

method onUserAuthenticated*(self: Module, password: string, pin: string) =
  if password.len == 0:
    error "No password provided from authentication"
    #TODO: notify about error
    self.resetTempValues()
  else:
    self.tempPin = pin
    self.tempPassword = password
    self.buildTransactionsFromRoute()

proc buildTransactionsFromRoute(self: Module) =
  let err = self.controller.buildTransactionsFromRoute(self.tempUuid)
  if err.len > 0:
    error "Error building transactions from route", err = err
    #TODO: notify about error
    self.resetTempValues()

proc sendSignedTransactions*(self: Module) =
  try:
    # check if all transactions are signed
    for _, (r, s, v) in self.tempResolvedSignatures.pairs:
      if r.len == 0 or s.len == 0 or v.len == 0:
        raise newException(CatchableError, "not all transactions are signed")

    let err = self.controller.sendRouterTransactionsWithSignatures(self.tempUuid, self.tempResolvedSignatures)
    if err.len > 0:
      raise newException(CatchableError, "sending transaction failed: " & err)
  except Exception as e:
    error "sendSignedTransactions failed: ", msg=e.msg
    #TODO: notify about error
    self.resetTempValues()

proc signOnKeycard(self: Module) =
  error "signing a community transaction on keycard is temporarily unavailable"
  self.resetTempValues()

method prepareSignaturesForTransactions*(self:Module, txForSigning: RouterTransactionsForSigningDto) =
  var res = ""
  try:
    if txForSigning.sendDetails.uuid != self.tempUuid:
      raise newException(CatchableError, "preparing signatures for transactions are not matching the initial request")
    if txForSigning.signingDetails.hashes.len == 0:
      raise newException(CatchableError, "no transaction hashes to be signed")
    if txForSigning.signingDetails.keyUid == "" or txForSigning.signingDetails.address == "" or txForSigning.signingDetails.addressPath == "":
      raise newException(CatchableError, "preparing signatures for transactions failed")

    if txForSigning.signingDetails.signOnKeycard:
      self.tempAddressFrom = txForSigning.signingDetails.address
      self.tempAddressPath = txForSigning.signingDetails.addressPath
      for h in txForSigning.signingDetails.hashes:
        self.tempResolvedSignatures[h] = ("", "", "")
      self.signOnKeycard()
    else:
      var finalPassword = self.tempPassword
      if not singletonInstance.userProfile.getMigratedToColdWallet():
        finalPassword = hashPassword(self.tempPassword)
      for h in txForSigning.signingDetails.hashes:
        self.tempResolvedSignatures[h] = ("", "", "")
        var
          signature = ""
          err: string
        (signature, err) = self.controller.signMessage(txForSigning.signingDetails.address, finalPassword, h)
        if err.len > 0:
          raise newException(CatchableError, "signing transaction failed: " & err)
        self.tempResolvedSignatures[h] = utils.getRSVFromSignature(signature)
      self.sendSignedTransactions()
  except Exception as e:
    error "signMessageWithCallback failed: ", msg=e.msg
    #TODO: notify about error
    self.resetTempValues()

method onTransactionSent*(self: Module, uuid: string, sendType: SendType, chainId: int, approvalTx: bool, txHash: string,
  toAddress: string, error: string) =
  if error.len > 0:
    error "Error sending transaction", error = error
    #TODO: notify about error
    self.resetTempValues()
    return
  if self.tempContractAction == ContractAction.Deploy:
    self.controller.storeDeployedContract(sendType, self.tempAddressFrom, toAddress, chainId, txHash, self.tempDeploymentParams)
    return
  if self.tempContractAction == ContractAction.Airdrop:
    # no action required
    return
  if self.tempContractAction == ContractAction.SelfDestruct:
    # no action required
    return
  if self.tempContractAction == ContractAction.Burn:
    # no action required
    return
  if self.tempContractAction == ContractAction.DeployOwnerToken:
    self.controller.storeDeployedOwnerContract(self.tempAddressFrom, chainId, txHash, self.tempOwnerDeploymentParams, self.tempMasterDeploymentParams)
    return
  if self.tempContractAction == ContractAction.SetSigner:
    # no action required
    return
  error "Unknown contract action"

proc getTokenAndAmountList(self: Module, communityId: string, tokensJsonString: string): seq[CommunityTokenAndAmount] =
  try:
    let tokensJson = tokensJsonString.parseJson
    for token in tokensJson:
      let contractUniqueKey = token["contractUniqueKey"].getStr
      let tokenDto = self.controller.findContractByUniqueId(contractUniqueKey)
      let amountStr = token["amount"].getStr
      if tokenDto.tokenType == TokenType.Unknown:
        error "Can't find token for community", contractUniqueKey=contractUniqueKey
        return @[]
      result.add(CommunityTokenAndAmount(communityToken: tokenDto, amount: amountStr.parse(Uint256)))
  except Exception as e:
    error "Error getTokenAndAmountList", msg = e.msg

proc getTokenAddressFromPermissions(self: Module, communityDto: CommunityDto, chainId: int, permissionType: TokenPermissionType): string =
  for _, tokenPermission in communityDto.tokenPermissions.pairs:
    if tokenPermission.`type` == permissionType:
      for tokenCriteria in tokenPermission.tokenCriteria:
        let addresses = tokenCriteria.contractAddresses
        return addresses.getOrDefault(chainId, "")
  return ""

proc getOwnerAndMasterTokensAddresses(self: Module, communityId: string, chainId: int): (string, string, bool) =
  let communityDto = self.controller.getCommunityById(communityId)
  let ownerTokenAddress = self.getTokenAddressFromPermissions(communityDto, chainId, TokenPermissionType.BecomeTokenOwner)
  let masterTokenAddress = self.getTokenAddressFromPermissions(communityDto, chainId, TokenPermissionType.BecomeTokenMaster)
  return (ownerTokenAddress, masterTokenAddress, ownerTokenAddress != "" and masterTokenAddress != "")

method computeAirdropFee*(self: Module, uuid: string, communityId: string, tokensJsonString: string, walletsJsonString: string,
  addressFrom: string) =
  let tokenAndAmountList = self.getTokenAndAmountList(communityId, tokensJsonString)
  if len(tokenAndAmountList) == 0:
    error "No tokens to airdrop"
    return
  self.tempContractAction = ContractAction.Airdrop
  self.tempUuid = uuid
  self.tempAddressFrom = addressFrom
  self.controller.computeAirdropFee(uuid, tokenAndAmountList, walletsJsonString.parseJson.to(seq[string]), addressFrom)

proc getWalletAndAmountListFromJson(self: Module, collectiblesToBurnJsonString: string): seq[WalletAndAmount] =
  let collectiblesToBurnJson = collectiblesToBurnJsonString.parseJson
  for collectibleToBurn in collectiblesToBurnJson:
    let walletAddress = collectibleToBurn["walletAddress"].getStr
    let amount = collectibleToBurn["amount"].getInt
    result.add(WalletAndAmount(walletAddress: walletAddress, amount: amount))


method computeDeployCollectiblesFee*(self: Module, uuid: string, communityId: string, fromAddress: string, name: string,
  symbol: string, description: string, supply: string, infiniteSupply: bool, transferable: bool, selfDestruct: bool,
  chainId: int, imageCropInfoJson: string) =
  # TODO: move this check to service and send route ready signal to update the UI and notifiy the user
  let (ownerTokenAddress, masterTokenAddress, isDeployed) = self.getOwnerAndMasterTokensAddresses(communityId, chainId)
  if not isDeployed:
    error "Owner token and master token not deployed"
    return
  self.tempUuid = uuid
  self.tempAddressFrom = fromAddress
  self.tempCommunityId = communityId
  self.tempChainId = chainId
  self.tempDeploymentParams.name = name
  self.tempDeploymentParams.symbol = symbol
  self.tempDeploymentParams.supply = supply.parse(Uint256)
  self.tempDeploymentParams.infiniteSupply = infiniteSupply
  self.tempDeploymentParams.decimals = 0 # collectibles have no decimals
  self.tempDeploymentParams.transferable = transferable
  self.tempDeploymentParams.remoteSelfDestruct = selfDestruct
  self.tempDeploymentParams.tokenUri = utl.changeCommunityKeyCompression(communityId) & "/"
  self.tempDeploymentParams.ownerTokenAddress = ownerTokenAddress
  self.tempDeploymentParams.masterTokenAddress = masterTokenAddress
  self.tempDeploymentParams.tokenType = TokenType.ERC721
  self.tempDeploymentParams.description = description

  let croppedImage = imageCropInfoJson.parseJson
  let base65Image = singletonInstance.utils.fromPathUri(croppedImage["imagePath"].getStr)
  self.tempDeploymentParams.base64image = base65Image

  self.tempDeploymentParams.communityId = communityId
  self.tempContractAction = ContractAction.Deploy
  self.controller.computeDeployTokenFee(uuid, chainId, fromAddress, communityId, self.tempDeploymentParams)

method computeDeployTokenOwnerFee*(self: Module, uuid: string, communityId: string, fromAddress: string, ownerName: string,
  ownerSymbol: string, ownerDescription: string, masterName: string, masterSymbol: string, masterDescription: string,
  chainId: int, imageCropInfoJson: string) =
  # TODO: move this check to service and send route ready signal to update the UI and notifiy the user
  let (_, _, isDeployed) = self.getOwnerAndMasterTokensAddresses(communityId, chainId)
  if isDeployed:
    error "Owner token and master token are deployed or pending"
    return

  self.tempUuid = uuid
  self.tempAddressFrom = fromAddress
  self.tempCommunityId = communityId
  self.tempChainId = chainId
  let croppedImage = imageCropInfoJson.parseJson
  let base65Image = singletonInstance.utils.fromPathUri(croppedImage["imagePath"].getStr)
  (self.tempOwnerDeploymentParams, self.tempMasterDeploymentParams) = self.createOwnerAndMasterDeploymentParams(communityId)
  self.tempOwnerDeploymentParams.description = ownerDescription
  self.tempOwnerDeploymentParams.tokenType = TokenType.ERC721
  self.tempOwnerDeploymentParams.base64image = base65Image
  self.tempMasterDeploymentParams.description = masterDescription
  self.tempMasterDeploymentParams.tokenType = TokenType.ERC721
  self.tempMasterDeploymentParams.base64image = base65Image
  self.tempContractAction = ContractAction.DeployOwnerToken

  self.controller.computeDeployOwnerContractsFee(uuid, chainId, fromAddress, communityId, self.tempOwnerDeploymentParams, self.tempMasterDeploymentParams)

method computeDeployAssetsFee*(self: Module, uuid: string, communityId: string, fromAddress: string, name: string, symbol: string, description: string,
  supply: string, infiniteSupply: bool, chainId: int, imageCropInfoJson: string) =
  # TODO: move this check to service and send route ready signal to update the UI and notifiy the user
  let (ownerTokenAddress, masterTokenAddress, isDeployed) = self.getOwnerAndMasterTokensAddresses(communityId, chainId)
  if not isDeployed:
    error "Owner token and master token not deployed"
    return
  self.tempUuid = uuid
  self.tempAddressFrom = fromAddress
  self.tempCommunityId = communityId
  self.tempChainId = chainId
  self.tempDeploymentParams.name = name
  self.tempDeploymentParams.symbol = symbol
  self.tempDeploymentParams.supply = supply.parse(Uint256)
  self.tempDeploymentParams.infiniteSupply = infiniteSupply
  self.tempDeploymentParams.decimals = DEFAULT_COMMUNITY_TOKENS_DECIMALS
  self.tempDeploymentParams.tokenUri = utl.changeCommunityKeyCompression(communityId) & "/"
  self.tempDeploymentParams.ownerTokenAddress = ownerTokenAddress
  self.tempDeploymentParams.masterTokenAddress = masterTokenAddress
  self.tempDeploymentParams.tokenType = TokenType.ERC20
  self.tempDeploymentParams.description = description

  let croppedImage = imageCropInfoJson.parseJson
  let base65Image = singletonInstance.utils.fromPathUri(croppedImage["imagePath"].getStr)
  self.tempDeploymentParams.base64image = base65Image

  self.tempDeploymentParams.communityId = communityId
  self.tempContractAction = ContractAction.Deploy
  self.controller.computeDeployTokenFee(uuid, chainId, fromAddress, communityId, self.tempDeploymentParams)

method removeCommunityToken*(self: Module, communityId: string, chainId: int, address: string) =
  self.controller.removeCommunityToken(communityId, chainId, address)

method refreshCommunityToken*(self: Module, chainId: int, address: string) =
  self.controller.refreshCommunityToken(chainId, address)

method computeSetSignerFee*(self: Module, uuid: string, communityId: string, chainId: int, contractAddress: string, addressFrom: string) =
  self.tempContractAction = ContractAction.SetSigner
  self.tempUuid = uuid
  self.tempAddressFrom = addressFrom
  self.tempCommunityId = communityId
  self.controller.computeSetSignerFee(uuid, communityId, chainId, contractAddress, addressFrom)

method computeSelfDestructFee*(self: Module, uuid: string, collectiblesToBurnJsonString: string, contractUniqueKey: string, addressFrom: string) =
  let walletAndAmountList = self.getWalletAndAmountListFromJson(collectiblesToBurnJsonString)
  if len(walletAndAmountList) == 0:
    error "No collectibles/assets to burn"
    return
  self.tempContractAction = ContractAction.SelfDestruct
  self.tempUuid = uuid
  self.tempAddressFrom = addressFrom
  self.controller.computeSelfDestructFee(uuid, walletAndAmountList, contractUniqueKey, addressFrom)

method computeBurnFee*(self: Module, uuid: string, contractUniqueKey: string, amount: string, addressFrom: string) =
  self.tempContractAction = ContractAction.Burn
  self.tempUuid = uuid
  self.tempAddressFrom = addressFrom
  self.controller.computeBurnFee(uuid, contractUniqueKey, amount, addressFrom)

proc getChainName(self: Module, chainId: int): string =
  let network = self.controller.getNetworkByChainId(chainId)
  result = if network != nil: network.chainName else: ""

method onOwnerTokenReceived*(self: Module, communityId: string, communityName: string, chainId: int, contractAddress: string) =
  self.view.emitOwnerTokenReceived(communityId, communityName, chainId, contractAddress)

method onCommunityTokenReceived*(self: Module, name: string, symbol: string, image: string, communityId: string, communityName: string, balance: string, chainId: int, txHash: string, isFirst: bool, tokenType: int, accountName: string, accountAddress: string) =
  self.view.emitCommunityTokenReceived(name, symbol, image, communityId, communityName, balance, chainId, txHash, isFirst, tokenType, accountName, accountAddress)

method onLostOwnership*(self: Module, communityId: string) =
  self.view.emitOwnershipLost(communityId, self.controller.getCommunityById(communityId).name)

method declineOwnership*(self: Module, communityId: string) =
  self.controller.declineOwnership(communityId)

method asyncGetOwnerTokenDetails*(self: Module, communityId: string) =
  self.tempOwnerTokenCommunity = self.controller.getCommunityById(communityId)
  if self.tempOwnerTokenCommunity.id == "":
    error "No community with id", communityId
    return
  let (chainId, contractAddress) = self.tempOwnerTokenCommunity.getOwnerTokenAddressFromPermissions()
  self.controller.asyncGetOwnerTokenOwnerAddress(chainId, contractAddress)

method onOwnerTokenOwnerAddress*(self: Module, chainId: int, contractAddress: string, address: string, addressName: string) =
  let chainName = self.getChainName(chainId)
  var symbol = ""
  for tokenMetadata in self.tempOwnerTokenCommunity.communityTokensMetadata:
    if tokenMetadata.addresses[chainId] == contractAddress:
      symbol = tokenMetadata.symbol
      break
  let jsonObj = %* {
    "symbol": symbol,
    "chainName": chainName,
    "accountName": addressName,
    "accountAddress": address,
    "chainId": chainId,
    "contractAddress": contractAddress
  }
  self.view.setOwnerTokenDetails($jsonObj)

method suggestedRoutesReady*(self: Module, uuid: string, sendType: SendType, nativeCryptoCurrency: CurrencyAmount,
  fiatCurrency: CurrencyAmount, costPerPath: seq[CostPerPath], errCode: string, errDescription: string) =
  if sendType != SendType.CommunityBurn and
    sendType != SendType.CommunityDeployAssets and
    sendType != SendType.CommunityDeployCollectibles and
    sendType != SendType.CommunityDeployOwnerToken and
    sendType != SendType.CommunityMintTokens and
    sendType != SendType.CommunityRemoteBurn and
    sendType != SendType.CommunitySetSignerPubKey:
      return
  self.view.emitSuggestedRoutesReadySignal(uuid, nativeCryptoCurrency, fiatCurrency, %costPerPath, errCode, errDescription)

method stopUpdatesForSuggestedRoute*(self: Module) =
  self.controller.stopSuggestedRoutesAsyncCalculation()