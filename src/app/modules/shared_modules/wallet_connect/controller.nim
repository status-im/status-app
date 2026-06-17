import nimqml
import chronicles, json, tables

import app/core/eventemitter
import app/global/global_singleton
import app_service/common/utils
import app_service/service/wallet_connect/service as wallet_connect_service
import app_service/service/wallet_account/service as wallet_account_service

import helpers

logScope:
  topics = "wallet-connect-controller"

# Keep it in sync with Constants.signingReason.walletConnect in ui/imports/utils/Constants.qml
const WC_SIGNING_REASON_PREFIX* = "wallet-connect"

type
  WcSignKind = enum
    wskMessage      # personal_sign / eth_sign / typed data -> return the canonical signature as-is
    wskSignTx       # eth_signTransaction -> build the raw transaction
    wskSendTx       # eth_sendTransaction -> sign and send the transaction

  PendingWcSign = object
    topic: string
    id: string
    address: string
    chainId: int
    kind: WcSignKind
    txData: JsonNode

QtObject:
  type
    Controller* = ref object of QObject
      service: wallet_connect_service.Service
      walletAccountService: wallet_account_service.Service
      events: EventEmitter
      pendingSignRequests: Table[string, PendingWcSign]

  proc delete*(self: Controller)
  proc newController*(
    service: wallet_connect_service.Service,
    walletAccountService: wallet_account_service.Service,
    events: EventEmitter): Controller =
    new(result, delete)

    result.service = service
    result.walletAccountService = walletAccountService
    result.events = events

    result.QObject.setup

  proc estimatedTimeResponse*(self: Controller, topic: string, estimatedTime: int) {.signal.}
  proc suggestedFeesResponse*(self: Controller, topic: string, suggestedFeesJson: string) {.signal.}
  proc estimatedGasResponse*(self: Controller, topic: string, gasEstimate: string) {.signal.}
  proc signingRequested*(self: Controller, reason: string, keyUid: string, hash: string, path: string, address: string) {.signal.}
  proc signingResultReceived*(self: Controller, topic: string, id: string, data: string) {.signal.}

  proc init*(self: Controller) =
    self.events.on(SIGNAL_ESTIMATED_TIME_RESPONSE) do(e: Args):
      let args = EstimatedTimeArgs(e)
      self.estimatedTimeResponse(args.topic, args.estimatedTime)

    self.events.on(SIGNAL_SUGGESTED_FEES_RESPONSE) do(e: Args):
      let args = SuggestedFeesArgs(e)
      self.suggestedFeesResponse(args.topic, $(args.suggestedFees))

    self.events.on(SIGNAL_ESTIMATED_GAS_RESPONSE) do(e: Args):
      let args = EstimatedGasArgs(e)
      self.estimatedGasResponse(args.topic, args.estimatedGas)

  proc resolveSigningParams(self: Controller, address: string): tuple[keyUid: string, path: string, ok: bool] =
    let acc = self.walletAccountService.getAccountByAddress(address)
    if acc.isNil:
      return ("", "", false)
    let keypair = self.walletAccountService.getKeypairByAccountAddress(address)
    if keypair.isNil:
      return ("", "", false)
    var keyUid = singletonInstance.userProfile.getKeyUid()
    if keypair.migratedToColdWallet():
      keyUid = keypair.keyUid
    return (keyUid, acc.path, true)

  proc requestSignature(self: Controller, topic, id, address: string, chainId: int, kind: WcSignKind, hash: string, txData: JsonNode = nil) =
    if hash.len == 0:
      error "wallet connect: empty hash to sign", topic=topic, id=id
      self.signingResultReceived(topic, id, "")
      return
    let (keyUid, path, ok) = self.resolveSigningParams(address)
    if not ok:
      error "wallet connect: cannot resolve signing params", address=address
      self.signingResultReceived(topic, id, "")
      return
    let reason = WC_SIGNING_REASON_PREFIX & "-" & id
    self.pendingSignRequests[reason] = PendingWcSign(topic: topic, id: id, address: address, chainId: chainId, kind: kind, txData: txData)
    self.signingRequested(reason, keyUid, hash, path, address)

  proc onSigningResult*(self: Controller, reason: string, signature: string) {.slot.} =
    if not self.pendingSignRequests.hasKey(reason):
      return
    let req = self.pendingSignRequests[reason]
    self.pendingSignRequests.del(reason)
    var data = ""
    try:
      if signature.len == 0:
        raise newException(CatchableError, "signing cancelled or failed")
      case req.kind
      of wskMessage:
        # personal_sign / typed data expect the canonical (yellow-paper, 1b/1c) signature
        data = signature
      of wskSignTx, wskSendTx:
        # transaction signing expects r+s+v with v as the recovery id (00/01)
        let (r, s, v) = getRSVFromSignature(signature)
        if r.len == 0 or s.len == 0 or v.len == 0:
          raise newException(CatchableError, "invalid signature")
        let recidSignature = r & s & v
        if req.kind == wskSignTx:
          data = self.service.buildRawTransaction(req.chainId, $req.txData, recidSignature)
        else:
          data = self.service.sendTransactionWithSignature(req.chainId, $req.txData, recidSignature)
    except Exception as e:
      error "wallet connect: onSigningResult failed", msg=e.msg
      data = ""
    self.signingResultReceived(req.topic, req.id, data)

  proc signMessage*(self: Controller, topic: string, id: string, address: string, message: string) {.slot.} =
    try:
      if message.len == 0:
        raise newException(CatchableError, "message is empty")
      let hashedMessage = self.service.hashMessageEIP191(message)
      if hashedMessage.len == 0:
        raise newException(CatchableError, "hashMessageEIP191 failed")
      self.requestSignature(topic, id, address, 0, wskMessage, hashedMessage)
    except Exception as e:
      error "signMessage failed: ", msg=e.msg
      self.signingResultReceived(topic, id, "")

  proc signMessageUnsafe*(self: Controller, topic: string, id: string, address: string, message: string) {.slot.} =
    self.signMessage(topic, id, address, message)

  proc safeSignTypedData*(self: Controller, topic: string, id: string, address: string, typedDataJson: string, chainId: int, legacy: bool) {.slot.} =
    try:
      let dataToSign = if legacy: self.service.hashTypedData(typedDataJson)
                       else: self.service.hashTypedDataV4(typedDataJson)
      if dataToSign.len == 0:
        raise newException(CatchableError, "hashTypedData failed")
      self.requestSignature(topic, id, address, chainId, wskMessage, dataToSign)
    except Exception as e:
      error "safeSignTypedData failed: ", msg=e.msg
      self.signingResultReceived(topic, id, "")

  proc signTransaction*(self: Controller, topic: string, id: string, address: string, chainId: int, txJson: string) {.slot.} =
    try:
      let (txHash, txData) = self.service.buildTransaction(chainId, txJson)
      if txHash.len == 0 or txData.isNil:
        raise newException(CatchableError, "building transaction failed")
      self.requestSignature(topic, id, address, chainId, wskSignTx, txHash, txData)
    except Exception as e:
      error "signTransaction failed: ", msg=e.msg
      self.signingResultReceived(topic, id, "")

  proc sendTransaction*(self: Controller, topic: string, id: string, address: string, chainId: int, txJson: string) {.slot.} =
    try:
      let (txHash, txData) = self.service.buildTransaction(chainId, txJson)
      if txHash.len == 0 or txData.isNil:
        raise newException(CatchableError, "building transaction failed")
      self.requestSignature(topic, id, address, chainId, wskSendTx, txHash, txData)
    except Exception as e:
      error "sendTransaction failed: ", msg=e.msg
      self.signingResultReceived(topic, id, "")

  proc requestEstimatedTime(self: Controller, topic: string, chainId: int, maxFeePerGasHex: string) {.slot.} =
    self.service.getEstimatedTime(topic, chainId, maxFeePerGasHex)

  proc requestSuggestedFeesJson(self: Controller, topic: string, chainId: int) {.slot.} =
    self.service.requestSuggestedFees(topic, chainId)

  proc requestGasEstimate(self: Controller, topic: string, chainId: int, txJson: string) {.slot.} =
    let txObj = parseJson(txJson)
    self.service.requestGasEstimate(topic, txObj, chainId)

  proc hexToDecBigString*(self: Controller, hex: string): string {.slot.} =
    try:
      return hexToDec(hex)
    except Exception as e:
      error "Failed to convert hex big int: ", hex=hex, ex=e.msg
      return ""

  # Convert from float gwei to hex wei
  proc convertFeesInfoToHex*(self: Controller, feesInfoJson: string): string {.slot.} =
    try:
      return convertFeesInfoToHex(feesInfoJson)
    except Exception as e:
      error "Failed to convert fees info to hex: ", feesInfoJson=feesInfoJson, ex=e.msg
      return ""

  proc delete*(self: Controller) =
    self.QObject.delete

