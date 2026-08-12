import json, stint
import app_service/service/community_tokens/dto/deployment_parameters

include  app_service/common/json_utils

const
  TxStatusSending* = "Sending"
  TxStatusPending* = "Pending"
  TxStatusSuccess* = "Success"
  TxStatusFailed* = "Failed"

type
  ErrorResponse* = ref object
    details*: string
    code*: string

type
  TansferDetails* = ref object
    tokenType*: int
    privilegeLevel*: int
    tokenContractAddress*: string
    amount*: UInt256

type
  CommunityParamsDto* = ref object
    communityID*: string
    signerPubKey*: string
    tokenIds*: seq[UInt256]
    walletAddresses*: seq[string]
    tokenDeploymentSignature*: string
    ownerTokenParameters*: DeploymentParameters
    masterTokenParameters*: DeploymentParameters
    deploymentParameters*: DeploymentParameters
    transferDetails*: seq[TansferDetails]

type
  SendDetailsDto* = ref object
    uuid*: string
    sendType*: int
    fromChain*: int
    toChain*: int
    fromAddress*: string
    toAddress*: string
    fromToken*: string
    toToken*: string
    fromAmount*: UInt256 # total amount
    toAmount*: UInt256
    ownerTokenBeingSent*: bool
    errorResponse*: ErrorResponse
    username*: string
    publicKey*: string
    packId*: string
    communityParams*: CommunityParamsDto

const
  HashKindTx* = "tx"
  HashKindPermit* = "permit"

type
  ## HashToSign is a single hash the backend asks us to sign. `kind` says what signing it
  ## actually authorises: a transaction the backend built, or an EIP-712 permit granting a
  ## token allowance. They are indistinguishable as bare hashes, which is why the kind has
  ## to be carried through to the confirmation UI.
  HashToSign* = object
    hash*: string
    kind*: string
    ## typedData is the EIP-712 payload as JSON, set for HashKindPermit only. It is what
    ## the user must be shown instead of the opaque digest.
    typedData*: string

proc isPermit*(self: HashToSign): bool =
  return self.kind == HashKindPermit

type
  SigningDetails* = ref object
    address*: string
    addressPath*: string
    keyUid*: string
    signOnKeycard*: bool
    hashes*: seq[HashToSign]

type
  RouterTransactionsForSigningDto* = ref object
    sendDetails*: SendDetailsDto
    signingDetails*: SigningDetails

type
  RouterSentTransaction* = ref object
    fromAddress*: string
    toAddress*: string
    fromChain*: int
    toChain*: int
    fromToken*: string
    toToken*: string
    amount*: UInt256 # amount sent
    amountIn*: UInt256 # amount that is "data" of tx (important for erc20 tokens)
    amountOut*: UInt256 # amount that will be received
    hash*: string
    approvalTx*: bool

type
  RouterSentTransactionsDto* = ref object
    sendDetails*: SendDetailsDto
    sentTransactions*: seq[RouterSentTransaction]

type
  TransactionStatusChange* = ref object
    status*: string
    hash*: string
    chainId*: int
    sendDetails*: SendDetailsDto
    sentTransactions*: seq[RouterSentTransaction]

proc toErrorResponse*(jsonObj: JsonNode): ErrorResponse =
  result = ErrorResponse()
  if jsonObj.contains("details"):
    result.details = jsonObj["details"].getStr
  if jsonObj.contains("code"):
    result.code = jsonObj["code"].getStr

proc toTansferDetails*(jsonObj: JsonNode): TansferDetails =
  result = TansferDetails()
  discard jsonObj.getProp("tokenType", result.tokenType)
  discard jsonObj.getProp("privilegeLevel", result.privilegeLevel)
  discard jsonObj.getProp("tokenContractAddress", result.tokenContractAddress)
  var tmpObj: JsonNode
  if jsonObj.getProp("amount", tmpObj):
    result.amount = stint.fromHex(UInt256, tmpObj.getStr)

proc toCommunityParamsDto*(jsonObj: JsonNode): CommunityParamsDto =
  result = CommunityParamsDto()
  discard jsonObj.getProp("communityID", result.communityID)
  discard jsonObj.getProp("signerPubKey", result.signerPubKey)
  discard jsonObj.getProp("tokenDeploymentSignature", result.tokenDeploymentSignature)
  var tmpObj: JsonNode
  if jsonObj.getProp("tokenIds", tmpObj) and tmpObj.kind == JArray:
    for id in tmpObj:
      result.tokenIds.add(stint.fromHex(UInt256, id.getStr))
  if jsonObj.getProp("walletAddresses", tmpObj) and tmpObj.kind == JArray:
    for addr in tmpObj:
      result.walletAddresses.add(addr.getStr)
  if jsonObj.getProp("ownerTokenParameters", tmpObj):
    result.ownerTokenParameters = toDeploymentParameters(tmpObj)
  if jsonObj.getProp("masterTokenParameters", tmpObj):
    result.masterTokenParameters = toDeploymentParameters(tmpObj)
  if jsonObj.getProp("deploymentParameters", tmpObj):
    result.deploymentParameters = toDeploymentParameters(tmpObj)
  if jsonObj.getProp("transferDetails", tmpObj) and tmpObj.kind == JArray:
    for tx in tmpObj:
      result.transferDetails.add(toTansferDetails(tx))

proc toSendDetailsDto*(jsonObj: JsonNode): SendDetailsDto =
  result = SendDetailsDto()
  discard jsonObj.getProp("uuid", result.uuid)
  discard jsonObj.getProp("sendType", result.sendType)
  discard jsonObj.getProp("fromChain", result.fromChain)
  discard jsonObj.getProp("toChain", result.toChain)
  discard jsonObj.getProp("fromAddress", result.fromAddress)
  discard jsonObj.getProp("toAddress", result.toAddress)
  discard jsonObj.getProp("fromToken", result.fromToken)
  discard jsonObj.getProp("toToken", result.toToken)
  discard jsonObj.getProp("ownerTokenBeingSent", result.ownerTokenBeingSent)
  var tmpObj: JsonNode
  if jsonObj.getProp("fromAmount", tmpObj):
    result.fromAmount = stint.fromHex(UInt256, tmpObj.getStr)
  if jsonObj.getProp("toAmount", tmpObj):
    result.toAmount = stint.fromHex(UInt256, tmpObj.getStr)
  if jsonObj.getProp("errorResponse", tmpObj) and tmpObj.kind == JObject:
    result.errorResponse = toErrorResponse(tmpObj)
  discard jsonObj.getProp("username", result.username)
  discard jsonObj.getProp("publicKey", result.publicKey)
  if jsonObj.getProp("packId", tmpObj):
    let packId = stint.fromHex(UInt256, tmpObj.getStr)
    result.packId = $packId
  if jsonObj.getProp("communityParams", tmpObj) and tmpObj.kind == JObject:
    result.communityParams = toCommunityParamsDto(tmpObj)

proc toHashToSign*(jsonObj: JsonNode): HashToSign =
  result = HashToSign()
  discard jsonObj.getProp("hash", result.hash)
  discard jsonObj.getProp("kind", result.kind)
  discard jsonObj.getProp("typedData", result.typedData)
  if result.kind.len == 0:
    result.kind = HashKindTx

proc toSigningDetails*(jsonObj: JsonNode): SigningDetails =
  result = SigningDetails()
  discard jsonObj.getProp("address", result.address)
  discard jsonObj.getProp("addressPath", result.addressPath)
  discard jsonObj.getProp("keyUid", result.keyUid)
  discard jsonObj.getProp("signOnKeycard", result.signOnKeycard)
  var tmpObj: JsonNode
  if jsonObj.getProp("hashes", tmpObj) and tmpObj.kind == JArray:
    for tx in tmpObj:
      result.hashes.add(toHashToSign(tx))

proc toRouterTransactionsForSigningDto*(jsonObj: JsonNode): RouterTransactionsForSigningDto =
  result = RouterTransactionsForSigningDto()
  var tmpObj: JsonNode
  if jsonObj.getProp("sendDetails", tmpObj) and tmpObj.kind == JObject:
    result.sendDetails = toSendDetailsDto(tmpObj)
  if jsonObj.getProp("signingDetails", tmpObj) and tmpObj.kind == JObject:
    result.signingDetails = toSigningDetails(tmpObj)

proc toRouterSentTransaction*(jsonObj: JsonNode): RouterSentTransaction =
  result = RouterSentTransaction()
  discard jsonObj.getProp("fromAddress", result.fromAddress)
  discard jsonObj.getProp("toAddress", result.toAddress)
  discard jsonObj.getProp("fromChain", result.fromChain)
  discard jsonObj.getProp("toChain", result.toChain)
  discard jsonObj.getProp("fromToken", result.fromToken)
  discard jsonObj.getProp("toToken", result.toToken)
  discard jsonObj.getProp("hash", result.hash)
  discard jsonObj.getProp("approvalTx", result.approvalTx)
  var tmpObj: JsonNode
  if jsonObj.getProp("amount", tmpObj):
    result.amount = stint.fromHex(UInt256, tmpObj.getStr)
  if jsonObj.getProp("amountIn", tmpObj):
    result.amountIn = stint.fromHex(UInt256, tmpObj.getStr)
  if jsonObj.getProp("amountOut", tmpObj):
    result.amountOut = stint.fromHex(UInt256, tmpObj.getStr)

proc toRouterSentTransactionsDto*(jsonObj: JsonNode): RouterSentTransactionsDto =
  result = RouterSentTransactionsDto()
  var tmpObj: JsonNode
  if jsonObj.getProp("sendDetails", tmpObj) and tmpObj.kind == JObject:
    result.sendDetails = toSendDetailsDto(tmpObj)
  if jsonObj.getProp("sentTransactions", tmpObj) and tmpObj.kind == JArray:
    for tx in tmpObj:
      result.sentTransactions.add(toRouterSentTransaction(tx))

proc toTransactionStatusChange*(jsonObj: JsonNode): TransactionStatusChange =
  result = TransactionStatusChange()
  discard jsonObj.getProp("status", result.status)
  discard jsonObj.getProp("hash", result.hash)
  discard jsonObj.getProp("chainId", result.chainId)
  var tmpObj: JsonNode
  if jsonObj.getProp("sendDetails", tmpObj) and tmpObj.kind == JObject:
    result.sendDetails = toSendDetailsDto(tmpObj)
  if jsonObj.getProp("sentTransactions", tmpObj) and tmpObj.kind == JArray:
    for tx in tmpObj:
      result.sentTransactions.add(toRouterSentTransaction(tx))