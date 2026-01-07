import nimqml, json, std/strformat, sequtils, strutils, chronicles, stint, options

import backend/backend as backend_backend
import backend/activity as backend_activity

import app/modules/shared_models/currency_amount

import app/global/global_singleton

import app_service/common/utils as common_utils
import app_service/service/currency/service

import app/modules/shared/wallet_utils

import web3/eth_api_types as eth

import ./transaction

# Additional data needed to build an Entry, which is
# not included in the metadata and needs to be
# fetched from a different source.
type
  ChainId = backend_activity.ChainId

  ExtraData* = object
    inAmount*: float64
    outAmount*: float64

# Used to display an activity history header entry in the QML UI
QtObject:
  type
    ActivityEntry* = ref object of QObject
      metadata: backend_activity.ActivityEntry
      extradata: ExtraData

      transaction: transaction.TransactionIdentity

      amountCurrency: CurrencyAmount
      noAmount: CurrencyAmount

      nftName: string
      nftImageURL: string

      # true for entries that were changed/added in the current session
      highlight: bool

  proc setup(self: ActivityEntry)
  proc delete*(self: ActivityEntry)
  proc isInTransactionType(self: ActivityEntry): bool =
    return self.metadata.activityType == backend_activity.ActivityType.Receive or self.metadata.activityType == backend_activity.ActivityType.Mint

  proc extractCurrencyAmount(self: ActivityEntry, currencyService: Service): CurrencyAmount =
    let usedToken = if self.isInTransactionType(): self.metadata.tokenIn.get() else: self.metadata.tokenOut.get()
    let tokenKey = common_utils.createTokenKey(usedToken.chainId.int, $usedToken.address.get())

    let amount = if self.isInTransactionType(): self.metadata.amountIn else: self.metadata.amountOut
    let symbol = if self.isInTransactionType(): self.metadata.symbolIn.get("") else: self.metadata.symbolOut.get("")
    result = currencyAmountToItem(
      currencyService.getCurrencyValueForToken(tokenKey, amount),
      currencyService.getCurrencyFormat(tokenKey),
    )

  proc newTransactionActivityEntry*(metadata: backend_activity.ActivityEntry, fromAddresses: seq[string], extradata: ExtraData, currencyService: Service): ActivityEntry =
    new(result, delete)
    result.metadata = metadata
    result.extradata = extradata


    var txIdentity: backend_backend.TransactionIdentity
    if metadata.transaction.isSome():
      txIdentity = metadata.transaction.get()
    result.transaction = newTransactionIdentity(txIdentity)

    result.noAmount = newCurrencyAmount()

    result.amountCurrency = result.extractCurrencyAmount(currencyService)

    result.highlight = metadata.isNew

    result.setup()

  proc buildMultiTransactionExtraData(metadata: backend_activity.ActivityEntry, currencyService: Service): ExtraData =
    if metadata.symbolIn.isSome():
      result.inAmount = currencyService.getCurrencyValueForToken(metadata.symbolIn.get(), metadata.amountIn) # TODO: use tokenKey instead of symbol
    if metadata.symbolOut.isSome():
      result.outAmount = currencyService.getCurrencyValueForToken(metadata.symbolOut.get(), metadata.amountOut) # TODO: use tokenKey instead of symbol

  proc buildTransactionExtraData(metadata: backend_activity.ActivityEntry, currencyService: Service): ExtraData =
    if metadata.symbolIn.isSome() or metadata.amountIn > 0:
      result.inAmount = currencyService.getCurrencyValueForToken(metadata.symbolIn.get(""), metadata.amountIn) # TODO: use tokenKey instead of symbol
    if metadata.symbolOut.isSome() or metadata.amountOut > 0:
      result.outAmount = currencyService.getCurrencyValueForToken(metadata.symbolOut.get(""), metadata.amountOut) # TODO: use tokenKey instead of symbol

  proc buildExtraData(backendEntry: backend_activity.ActivityEntry, currencyService: Service): ExtraData =
    var extraData: ExtraData
    case backendEntry.getPayloadType():
      of MultiTransaction:
        extraData = buildMultiTransactionExtraData(backendEntry, currencyService)
      of SimpleTransaction, PendingTransaction:
        extraData = buildTransactionExtraData(backendEntry, currencyService)
    return extraData

  proc newActivityEntry*(backendEntry: backend_activity.ActivityEntry, addresses: seq[string], currencyService: Service): ActivityEntry =
    let extraData = buildExtraData(backendEntry, currencyService)
    case backendEntry.getPayloadType():
      of MultiTransaction:
        error "MultiTransaction - old type - not supported anymore"
        return nil
      of SimpleTransaction, PendingTransaction:
        return newTransactionActivityEntry(backendEntry, addresses, extraData, currencyService)

  proc resetAmountCurrency*(self: ActivityEntry, service: Service) =
    self.extraData = buildExtraData(self.metadata, service)
    self.amountCurrency = self.extractCurrencyAmount(service)

  proc isMultiTransaction*(self: ActivityEntry): bool {.slot.} =
    return self.metadata.getPayloadType() == backend_activity.PayloadType.MultiTransaction

  QtProperty[bool] isMultiTransaction:
    read = isMultiTransaction

  proc isPendingTransaction*(self: ActivityEntry): bool {.slot.} =
    return self.metadata.getPayloadType() == backend_activity.PayloadType.PendingTransaction

  QtProperty[bool] isPendingTransaction:
    read = isPendingTransaction

  proc `$`*(self: ActivityEntry): string =
    return fmt"""ActivityEntry(
      metadata:{$self.metadata},
      extradata:{$self.extradata},
      transactionHash:{$self.transaction.getHash()},
      transactionAddress:{$self.transaction.getAddress()},
      transactionChainId:{$self.transaction.getChainId()},
    )"""

  proc getId*(self: ActivityEntry): string {.slot.} =
    return self.metadata.getKey()

  QtProperty[string] id:
    read = getId

  proc getTransaction*(self: ActivityEntry): QVariant {.slot.} =
    return newQVariant(self.transaction)
  QtProperty[QVariant] transaction:
    read = getTransaction

  proc getMetadata*(self: ActivityEntry): backend_activity.ActivityEntry =
    return self.metadata

  proc getSender*(self: ActivityEntry): string {.slot.} =
    return if self.metadata.sender.isSome(): "0x" & self.metadata.sender.unsafeGet().toHex() else: ""

  QtProperty[string] sender:
    read = getSender

  proc getRecipient*(self: ActivityEntry): string {.slot.} =
    return if self.metadata.recipient.isSome(): "0x" & self.metadata.recipient.unsafeGet().toHex() else: ""

  QtProperty[string] recipient:
    read = getRecipient

  proc getInSymbol*(self: ActivityEntry): string {.slot.} =
    return self.metadata.symbolIn.get("")

  QtProperty[string] inSymbol:
    read = getInSymbol

  proc getOutSymbol*(self: ActivityEntry): string {.slot.} =
    return self.metadata.symbolOut.get("")

  QtProperty[string] outSymbol:
    read = getOutSymbol

  proc getSymbol*(self: ActivityEntry): string {.slot.} =
    if self.isInTransactionType():
      return self.getInSymbol()
    return self.getOutSymbol()

  QtProperty[string] symbol:
    read = getSymbol

  proc getTimestamp*(self: ActivityEntry): int {.slot.} =
    return self.metadata.timestamp

  QtProperty[int] timestamp:
    read = getTimestamp

  proc statusChanged*(self: ActivityEntry) {.signal.}

  proc getStatus*(self: ActivityEntry): int {.slot.} =
    return self.metadata.activityStatus.int

  proc setStatus*(self: ActivityEntry, status: ActivityStatus) =
    self.metadata.activityStatus = status
    self.statusChanged()

  QtProperty[int] status:
    read = getStatus
    notify = statusChanged

  proc getChainIdIn*(self: ActivityEntry): int {.slot.} =
    return self.metadata.chainIdIn.get(ChainId(0)).int

  QtProperty[int] chainIdIn:
    read = getChainIdIn

  proc getChainIdOut*(self: ActivityEntry): int {.slot.} =
    return self.metadata.chainIdOut.get(ChainId(0)).int

  QtProperty[int] chainIdOut:
    read = getChainIdOut

  proc getChainId*(self: ActivityEntry): int {.slot.} =
    if self.isInTransactionType():
      return self.getChainIdIn()
    return self.getChainIdOut()

  QtProperty[int] chainId:
    read = getChainId

  proc getIsNFT*(self: ActivityEntry): bool {.slot.} =
    if self.metadata.transferType.isNone():
      return false
    let transferType = self.metadata.transferType.unsafeGet()
    return transferType == TransferType.Erc721 or transferType == TransferType.Erc1155

  QtProperty[bool] isNFT:
    read = getIsNFT

  proc nftNameChanged*(self: ActivityEntry) {.signal.}

  proc getNftName*(self: ActivityEntry): string {.slot.} =
    return self.nftName

  proc setNftName*(self: ActivityEntry, nftName: string) =
    self.nftName = nftName
    self.nftNameChanged()

  QtProperty[string] nftName:
    read = getNftName
    write = setNftName
    notify = nftNameChanged

  proc nftImageUrlChanged*(self: ActivityEntry) {.signal.}

  proc getNftImageUrl*(self: ActivityEntry): string {.slot.} =
    return self.nftImageUrl

  proc setNftImageUrl*(self: ActivityEntry, nftImageUrl: string) =
    self.nftImageUrl = nftImageUrl
    self.nftImageUrlChanged()

  QtProperty[string] nftImageUrl:
    read = getNftImageUrl
    write = setNftImageUrl
    notify = nftImageUrlChanged

  proc getTxType*(self: ActivityEntry): int {.slot.} =
    return self.metadata.activityType.int

  QtProperty[int] txType:
    read = getTxType

  proc getTokenInAddress*(self: ActivityEntry): string {.slot.} =
    if self.metadata.tokenIn.isSome:
      let address = self.metadata.tokenIn.unsafeGet().address
      if address.isSome:
        return "0x" & toHex(address.unsafeGet())
    return ""

  QtProperty[string] tokenInAddress:
    read = getTokenInAddress

  proc getTokenOutAddress*(self: ActivityEntry): string {.slot.} =
    if self.metadata.tokenOut.isSome:
      let address = self.metadata.tokenOut.unsafeGet().address
      if address.isSome:
        return "0x" & toHex(address.unsafeGet())
    return ""

  QtProperty[string] tokenOutAddress:
    read = getTokenOutAddress

  proc getTokenAddress*(self: ActivityEntry): string {.slot.} =
    if self.isInTransactionType():
      return self.getTokenInAddress()
    return self.getTokenOutAddress()

  QtProperty[string] tokenAddress:
    read = getTokenAddress

  proc getTokenID*(self: ActivityEntry): string {.slot.} =
    if self.metadata.getPayloadType() == backend_activity.PayloadType.MultiTransaction:
      error "getTokenID: ActivityEntry is not a transaction"
      return ""

    var tokenId: Option[TokenID]
    if self.isInTransactionType():
      if self.metadata.tokenIn.isSome():
        tokenId = self.metadata.tokenIn.unsafeGet().tokenId
    elif self.metadata.tokenOut.isSome():
        tokenId = self.metadata.tokenOut.unsafeGet().tokenId

    if tokenId.isSome():
      return $stint.fromHex(UInt256, string(tokenId.unsafeGet()))
    return ""

  QtProperty[string] tokenID:
    read = getTokenID

  proc getOutAmount*(self: ActivityEntry): float {.slot.} =
    return self.extradata.outAmount

  QtProperty[float] outAmount:
    read = getOutAmount

  proc getInAmount*(self: ActivityEntry): float {.slot.} =
    return self.extradata.inAmount

  QtProperty[float] inAmount:
    read = getInAmount

  proc getAmount*(self: ActivityEntry): float {.slot.} =
    if self.isInTransactionType():
      return self.getInAmount()
    return self.getOutAmount()

  QtProperty[float] amount:
    read = getAmount

  proc getAmountCurrency*(self: ActivityEntry): QVariant {.slot.} =
    return newQVariant(self.amountCurrency)

  QtProperty[QVariant] amountCurrency:
    read = getAmountCurrency

  proc getCommunityId*(self: ActivityEntry): string {.slot.} =
    if self.metadata.communityId.isSome():
      return self.metadata.communityId.unsafeGet()
    return ""

  QtProperty[string] communityId:
    read = getCommunityId

  proc getApprovalSpender*(self: ActivityEntry): string {.slot.} =
    if self.metadata.approvalSpender.isSome():
      return "0x" & toHex(self.metadata.approvalSpender.unsafeGet())
    return ""

  QtProperty[string] approvalSpender:
    read = getApprovalSpender

  proc getInteractedContractAddress*(self: ActivityEntry): string {.slot.} =
    if self.metadata.interactedContractAddress.isSome():
      return "0x" & toHex(self.metadata.interactedContractAddress.unsafeGet())
    return ""

  QtProperty[string] interactedContractAddress:
    read = getInteractedContractAddress

  proc highlightChanged*(self: ActivityEntry) {.signal.}

  proc getHighlight*(self: ActivityEntry): bool {.slot.} =
    return self.highlight

  proc doneHighlighting*(self: ActivityEntry) {.slot.} =
    if self.highlight:
      self.highlight = false
      self.highlightChanged()

  QtProperty[bool] highlight:
    read = getHighlight
    notify = highlightChanged

  proc setup(self: ActivityEntry) =
    self.QObject.setup

  proc delete*(self: ActivityEntry) =
    self.QObject.delete

