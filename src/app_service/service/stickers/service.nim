import nimqml, tables, json, sequtils, chronicles, strutils, sets, stint

import app/core/[main]
import app/core/tasks/[qt, threadpool]

import web3/conversions, stew/byteutils, nimcrypto, json_serialization

import backend/stickers as status_stickers
import backend/chat as status_chat
import backend/response_type
import backend/eth as status_eth
import backend/backend as status_go_backend

import ./dto/stickers
import ../token/service as token_service
import ../settings/service as settings_service
import ../wallet_account/service as wallet_account_service
import ../transaction/service as transaction_service
import ../network/service as network_service
import ../chat/service as chat_service
import app_service/common/types

export StickerDto
export StickerPackDto

include async_tasks

logScope:
  topics = "stickers-service"

type
  TransactionArgs = transaction_service.TransactionArgs
  StickerPackLoadedArgs* = ref object of Args
    stickerPack*: StickerPackDto
    isInstalled*: bool
    isBought*: bool
    isPending*: bool
  StickerGasEstimatedArgs* = ref object of Args
    estimate*: int
    uuid*: string
  GasPriceArgs* = ref object of Args
    gasPrice*: string
  StickerTransactionArgs* = ref object of Args
    transactionHash*: string
    packID*: string
    transactionType*: string
  StickerPackInstalledArgs* = ref object of Args
    packId*: string
  StickersArgs* = ref object of Args
    stickers*: seq[StickerDto]
  StickerPacksArgs* = ref object of Args
    packs*: Table[string, StickerPackDto]
  StickerBuyResultArgs* = ref object of Args
    chainId*: int
    packId*: string
    txHash*: string
    error*: string

# Signals which may be emitted by this service:
const SIGNAL_STICKER_PACK_LOADED* = "stickerPackLoaded"
const SIGNAL_ALL_STICKER_PACKS_LOADED* = "allStickerPacksLoaded"
const SIGNAL_ALL_STICKER_PACKS_LOAD_FAILED* = "allStickerPacksLoadFailed"
const SIGNAL_STICKER_TRANSACTION_SENT* = "stickerTransactionSent"
const SIGNAL_STICKER_TRANSACTION_CONFIRMED* = "stickerTransactionConfirmed"
const SIGNAL_STICKER_TRANSACTION_REVERTED* = "stickerTransactionReverted"
const SIGNAL_STICKER_PACK_INSTALLED* = "stickerPackInstalled"
const SIGNAL_LOAD_RECENT_STICKERS_STARTED* = "loadRecentStickersStarted"
const SIGNAL_LOAD_RECENT_STICKERS_FAILED* = "loadRecentStickersFailed"
const SIGNAL_LOAD_RECENT_STICKERS_DONE* = "loadRecentStickersDone"
const SIGNAL_LOAD_INSTALLED_STICKER_PACKS_STARTED* = "loadInstalledStickerPacksStarted"
const SIGNAL_LOAD_INSTALLED_STICKER_PACKS_FAILED* = "loadInstalledStickerPacksFailed"
const SIGNAL_LOAD_INSTALLED_STICKER_PACKS_DONE* = "loadInstalledStickerPacksDone"

QtObject:
  type Service* = ref object of QObject
    threadpool: ThreadPool
    marketStickerPacks*: Table[string, StickerPackDto]
    recentStickers*: seq[StickerDto]
    events: EventEmitter
    settingsService: settings_service.Service
    walletAccountService: wallet_account_service.Service
    transactionService: transaction_service.Service
    networkService: network_service.Service
    chatService: chat_service.Service
    tokenService: token_service.Service
    installedStickerPacks: Table[string, StickerPackDto]

  # Forward declaration
  proc obtainMarketStickerPacks*(self: Service)

  proc delete*(self: Service)
  proc newService*(
      events: EventEmitter,
      threadpool: ThreadPool,
      settingsService: settings_service.Service,
      walletAccountService: wallet_account_service.Service,
      transactionService: transaction_service.Service,
      networkService: network_service.Service,
      chatService: chat_service.Service,
      tokenService: token_service.Service
  ): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.settingsService = settingsService
    result.walletAccountService = walletAccountService
    result.transactionService = transactionService
    result.networkService = networkService
    result.tokenService = tokenService
    result.chatService = chatService
    result.marketStickerPacks = initTable[string, StickerPackDto]()
    result.recentStickers = @[]
    result.installedStickerPacks = initTable[string, StickerPackDto]()

  proc getInstalledStickerPacks*(self: Service): Table[string, StickerPackDto] =
    return self.installedStickerPacks

  proc getStickerMarketAddress*(self: Service): string =
    try:
      let chainId = self.networkService.getAppNetwork().chainId
      let response = status_stickers.stickerMarketAddress(chainId)
      return response.result.getStr()
    except RpcException:
      error "Error obtaining sticker market address", message = getCurrentExceptionMsg()

  proc updateStickersPack(self: Service, transactionHash: string, status: string) =
    if status == TxStatusPending:
      return

    # find packID by transactionHash
    var packId = ""
    for pId, stickerPack in self.marketStickerPacks.pairs:
      if stickerPack.txHash == transactionHash:
        packId = pId
        break

    if packId.len == 0:
      return

    if status == TxStatusSuccess:
      self.marketStickerPacks[packId].status = StickerPackStatus.Purchased
      let data = StickerTransactionArgs(transactionHash: transactionHash, packID: packId, transactionType: $PendingTransactionTypeDto.BuyStickerPack)
      self.events.emit(SIGNAL_STICKER_TRANSACTION_CONFIRMED, data)
      return
    if status == TxStatusFailed:
      self.marketStickerPacks[packId].status = StickerPackStatus.Available
      let data = StickerTransactionArgs(transactionHash: transactionHash, packID: packId, transactionType: $PendingTransactionTypeDto.BuyStickerPack)
      self.events.emit(SIGNAL_STICKER_TRANSACTION_REVERTED, data)
      return
    error "Error updating sticker pack status", message = "unknown status: " & status

  proc init*(self: Service) =
    self.events.on(SIGNAL_TRANSACTION_SENT) do(e:Args):
      let args = TransactionArgs(e)
      let txType = SendType(args.sendDetails.sendType)
      if txType != SendType.StickersBuy:
        return
      self.marketStickerPacks[$args.sendDetails.packId].status = StickerPackStatus.Pending
      self.marketStickerPacks[$args.sendDetails.packId].txHash = args.sentTransaction.hash
      let data = StickerBuyResultArgs(
        chainId: args.sendDetails.fromChain,
        packId: args.sendDetails.packId,
        txHash: args.sentTransaction.hash,
        error: if not args.sendDetails.errorResponse.isNil: args.sendDetails.errorResponse.details else: ""
      )
      self.events.emit(SIGNAL_STICKER_TRANSACTION_SENT, data)

    self.events.on(SIGNAL_TRANSACTION_STATUS_CHANGED) do(e:Args):
      let args = TransactionArgs(e)
      self.updateStickersPack(args.sentTransaction.hash, args.status)

  proc setMarketStickerPacks*(self: Service, strickersJSON: string) {.slot.} =
    let stickersResult = Json.decode(strickersJSON, tuple[packs: seq[StickerPackDto], error: string])

    if stickersResult.error != "":
      self.events.emit(SIGNAL_ALL_STICKER_PACKS_LOAD_FAILED, Args())
      return

    let availableStickers = stickersResult.packs

    for stickerPack in availableStickers:
      if self.marketStickerPacks.contains(stickerPack.id):
        continue

      self.marketStickerPacks[stickerPack.id] = stickerPack
      self.events.emit(SIGNAL_STICKER_PACK_LOADED, StickerPackLoadedArgs(
        stickerPack: stickerPack,
        isInstalled: false,
        isBought: stickerPack.status == StickerPackStatus.Purchased,
        isPending: false
      ))

    let pendingStickerPacksResponse = status_stickers.pending()
    for (packId, stickerPackJson) in pendingStickerPacksResponse.result.pairs():
        if self.marketStickerPacks.contains(packId):
          continue
        self.marketStickerPacks[packId] = stickerPackJson.toStickerPackDto()
        self.events.emit(SIGNAL_STICKER_PACK_LOADED, StickerPackLoadedArgs(
          stickerPack: self.marketStickerPacks[packId],
          isInstalled: false,
          isBought: false,
          isPending: true
        ))
    self.events.emit(SIGNAL_ALL_STICKER_PACKS_LOADED, Args())

  proc obtainMarketStickerPacks*(self: Service) =
    let chainId = self.networkService.getAppNetwork().chainId

    let arg = ObtainMarketStickerPacksTaskArg(
      tptr: obtainMarketStickerPacksTask,
      vptr: cast[uint](self.vptr),
      slot: "setMarketStickerPacks",
      chainId: chainId,
    )
    self.threadpool.start(arg)

  proc addStickerToRecent*(self: Service, sticker: StickerDto, save: bool = false) =
    try:
      discard status_stickers.addRecent(sticker.packId, sticker.hash)
    except RpcException:
      error "Error adding recent sticker", message = getCurrentExceptionMsg()

  proc getPackIdForSticker*(packs: Table[string, StickerPackDto], hash: string): string =
    for packId, pack in packs.pairs:
      if pack.stickers.any(proc(sticker: StickerDto): bool = return sticker.hash == hash):
        return packId
    return "0"

  proc getStickersByPackId*(self: Service, packId: string): StickerPackDto =
    if self.marketStickerPacks.hasKey(packId):
      return self.marketStickerPacks[packId]

  proc getRecentStickers*(self: Service): seq[StickerDto] =
    try:
      let recentResponse = status_stickers.recent()
      for stickerJson in recentResponse.result:
        result = stickerJson.toStickerDto() & result
    except RpcException:
      error "Error getting recent stickers", message = getCurrentExceptionMsg()

  proc asyncLoadRecentStickers*(self: Service) =
    self.events.emit(SIGNAL_LOAD_RECENT_STICKERS_STARTED, Args())
    try:
      let arg = AsyncGetRecentStickersTaskArg(
        tptr: asyncGetRecentStickersTask,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncGetRecentStickersDone"
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error loading recent stickers", msg = e.msg

  proc onAsyncGetRecentStickersDone*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson
      if (rpcResponseObj{"error"}.kind != JNull):
         raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      let recentStickers = map(rpcResponseObj{"result"}.getElems(), toStickerDto)
      self.events.emit(SIGNAL_LOAD_RECENT_STICKERS_DONE, StickersArgs(stickers: recentStickers))
    except Exception as e:
      error "error loading recent stickers: ", procName = "onAsyncGetRecentStickersDone", errMsg = e.msg
      self.events.emit(SIGNAL_LOAD_RECENT_STICKERS_FAILED, Args())

  proc asyncLoadInstalledStickerPacks*(self: Service) =
    self.events.emit(SIGNAL_LOAD_INSTALLED_STICKER_PACKS_STARTED, Args())
    try:
      let arg = AsyncGetInstalledStickerPacksTaskArg(
        tptr: asyncGetInstalledStickerPacksTask,
        vptr: cast[uint](self.vptr),
        slot: "onAsyncGetInstalledStickerPacksDone"
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "Error loading installed sticker packs", msg = e.msg

  proc onAsyncGetInstalledStickerPacksDone*(self: Service, response: string) {.slot.} =
    try:
      let rpcResponseObj = response.parseJson
      if (rpcResponseObj{"error"}.kind != JNull):
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      for (packID, stickerPackJson) in rpcResponseObj{"result"}.pairs():
        self.installedStickerPacks[packID] = stickerPackJson.toStickerPackDto()
      self.events.emit(SIGNAL_LOAD_INSTALLED_STICKER_PACKS_DONE, StickerPacksArgs(packs: self.installedStickerPacks))
    except Exception as e:
      error "error loading installed sticker packs: ", procName="onAsyncGetInstalledStickerPacksDone", errMsg = e.msg
      self.events.emit(SIGNAL_LOAD_INSTALLED_STICKER_PACKS_FAILED, Args())

  proc getNumInstalledStickerPacks*(self: Service): int =
    try:
      let installedResponse = status_stickers.installed()
      return installedResponse.result.len
    except RpcException:
      error "Error getting installed stickers number", message = getCurrentExceptionMsg()
    return 0

  proc installStickerPack*(self: Service, packId: string) =
    let arg = InstallStickerPackTaskArg(
      tptr: installStickerPackTask,
      vptr: cast[uint](self.vptr),
      slot: "onStickerPackInstalled",
      chainId: self.networkService.getAppNetwork().chainId,
      packId: packId,
    )
    self.threadpool.start(arg)

  proc onStickerPackInstalled*(self: Service, installedPackJson: string) {.slot.} =
    let installedPack = Json.decode(installedPackJson, tuple[packId: string, installed: bool])
    if installedPack.installed:
      if self.marketStickerPacks.hasKey(installedPack.packId):
        self.marketStickerPacks[installedPack.packId].status = StickerPackStatus.Installed
      self.events.emit(SIGNAL_STICKER_PACK_INSTALLED, StickerPackInstalledArgs(
        packId: installedPack.packId
      ))
    else:
      error "Sticker pack did not get installed", packId = installedPack.packId

  proc uninstallStickerPack*(self: Service, packId: string) =
    try:
      discard status_stickers.uninstall(packId)
    except RpcException:
      error "Error removing installed sticker", message = getCurrentExceptionMsg()

  proc asyncSendSticker*(
      self: Service,
      chatId: string,
      replyTo: string,
      sticker: StickerDto,
      preferredUsername: string,
      threadId: string = "") =
    let arg = AsyncSendStickerTaskArg(
      tptr: asyncSendStickerTask,
      vptr: cast[uint](self.vptr),
      slot: "onAsyncSendStickerDone",
      chatId: chatId,
      replyTo: replyTo,
      threadId: threadId,
      stickerHash: sticker.hash,
      stickerPackId: sticker.packId,
      preferredUsername: preferredUsername,
    )

    self.threadpool.start(arg)
    self.addStickerToRecent(sticker)

  proc onAsyncSendStickerDone*(self: Service, rpcResponseJson: string) {.slot.} =
    let rpcResponseObj = rpcResponseJson.parseJson
    try:
      let errorString = rpcResponseObj{"error"}.getStr()
      if errorString != "":
        raise newException(CatchableError, errorString)

      let rpcResponse = Json.decode($rpcResponseObj["response"], RpcResponse[JsonNode])
      discard self.chatService.processMessengerResponse(rpcResponse)
    except Exception as e:
      error "Error sending sticker", msg = e.msg
      self.events.emit(SIGNAL_SENDING_FAILED,
        MessageSendingFailure(chatId: rpcResponseObj["chatId"].getStr, error: e.msg))

  proc removeRecentStickers*(self: Service, packId: string) =
    self.recentStickers.keepItIf(it.packId != packId)

  proc clearRecentStickers*(self: Service) =
    try:
      discard status_stickers.clearRecentStickers()
    except RpcException:
      error "Error removing recent stickers", message = getCurrentExceptionMsg()

  proc delete*(self: Service) =
    self.QObject.delete

