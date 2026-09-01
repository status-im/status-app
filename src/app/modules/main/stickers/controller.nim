import tables, uuids

import ./io_interface

import app/core/eventemitter
import app_service/service/stickers/service as stickers_service
import app_service/service/token/service
import app_service/service/settings/service as settings_service
import app_service/service/network/service as network_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/token/service as token_service

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    stickerService: stickers_service.Service
    settingsService: settings_service.Service
    networkService: network_service.Service
    walletAccountService: wallet_account_service.Service
    tokenService: token_service.Service
    connectionKeycardResponse: UUID
    disconnected: bool

proc newController*(
    delegate: io_interface.AccessInterface,
    events: EventEmitter,
    stickerService: stickers_service.Service,
    settingsService: settings_service.Service,
    walletAccountService: wallet_account_service.Service,
    networkService: network_service.Service,
    tokenService: token_service.Service,
    ): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.stickerService = stickerService
  result.settingsService = settingsService
  result.networkService = networkService
  result.walletAccountService = walletAccountService
  result.tokenService = tokenService
  result.disconnected = false

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =

  self.events.on(SIGNAL_LOAD_RECENT_STICKERS_DONE) do(e: Args):
    self.delegate.clearStickers()
    let args = StickersArgs(e)
    for sticker in args.stickers:
      self.delegate.addRecentStickerToList(sticker)

  self.events.on(SIGNAL_STICKER_PACK_LOADED) do(e: Args):
    let args = StickerPackLoadedArgs(e)
    self.delegate.addStickerPackToList(
      args.stickerPack,
      args.isInstalled,
      args.isBought,
      args.isPending
    )

  self.events.on(SIGNAL_LOAD_INSTALLED_STICKER_PACKS_DONE) do(e: Args):
    let args = StickerPacksArgs(e)
    self.delegate.installedStickerPacksLoaded()
    self.delegate.populateInstalledStickerPacks(args.packs)

  self.events.on(SIGNAL_ALL_STICKER_PACKS_LOADED) do(e: Args):
    self.delegate.allPacksLoaded()

  self.events.on(SIGNAL_ALL_STICKER_PACKS_LOAD_FAILED) do(e: Args):
    self.delegate.allPacksLoadFailed()

  self.events.on(SIGNAL_STICKER_TRANSACTION_SENT) do(e:Args):
    let args = StickerBuyResultArgs(e)
    self.delegate.stickerTransactionSent(args.chainId, args.packId, args.txHash, args.error)

  self.events.on(SIGNAL_STICKER_TRANSACTION_CONFIRMED) do(e:Args):
    let args = StickerTransactionArgs(e)
    self.delegate.stickerTransactionConfirmed(args.transactionType, args.packID, args.transactionHash)

  self.events.on(SIGNAL_STICKER_TRANSACTION_REVERTED) do(e:Args):
    let args = StickerTransactionArgs(e)
    self.delegate.stickerTransactionReverted(args.transactionType, args.packID, args.transactionHash)

  self.events.on(SIGNAL_STICKER_PACK_INSTALLED) do(e: Args):
    let args = StickerPackInstalledArgs(e)
    self.delegate.onStickerPackInstalled(args.packId)

proc getRecentStickers*(self: Controller): seq[StickerDto] =
  return self.stickerService.getRecentStickers()

proc loadRecentStickers*(self: Controller) =
  self.stickerService.asyncLoadRecentStickers()

proc loadInstalledStickerPacks*(self: Controller) =
  self.stickerService.asyncLoadInstalledStickerPacks()

proc getInstalledStickerPacks*(self: Controller): Table[string, StickerPackDto] =
  self.stickerService.getInstalledStickerPacks()

proc obtainMarketStickerPacks*(self: Controller) =
  self.stickerService.obtainMarketStickerPacks()

proc getNumInstalledStickerPacks*(self: Controller): int =
  self.stickerService.getNumInstalledStickerPacks()

proc installStickerPack*(self: Controller, packId: string) =
  self.stickerService.installStickerPack(packId)

proc uninstallStickerPack*(self: Controller, packId: string) =
  self.stickerService.uninstallStickerPack(packId)

proc removeRecentStickers*(self: Controller, packId: string) =
  self.stickerService.removeRecentStickers(packId)

proc sendSticker*(
    self: Controller,
    channelId: string,
    replyTo: string,
    sticker: StickerDto,
    preferredUsername: string,
    threadId: string = "") =
  self.stickerService.asyncSendSticker(channelId, replyTo, sticker, preferredUsername, threadId)

proc getStickerMarketAddress*(self: Controller): string =
  return self.stickerService.getStickerMarketAddress()

proc getWalletDefaultAddress*(self: Controller): string =
  return self.walletAccountService.getWalletAccount(0).address

proc getCurrentCurrency*(self: Controller): string =
  return self.settingsService.getCurrency()