import nimqml, tables, sugar, sequtils
import ./io_interface, ./view, ./controller, ./item, ./models/sticker_pack_list
import ../io_interface as delegate_interface
import app/global/global_singleton
import app/core/eventemitter
import app_service/service/stickers/service as stickers_service
import app_service/service/settings/service as settings_service
import app_service/service/network/service as network_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/token/service as token_service

export io_interface

const cancelledRequest* = "cancelled"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  stickersService: stickers_service.Service,
  settingsService: settings_Service.Service,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  tokenService: token_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, stickersService, settingsService, walletAccountService,
    networkService, tokenService)
  result.moduleLoaded = false

  singletonInstance.engine.setRootContextProperty("stickersModule", result.viewVariant)

method delete*(self: Module) =
  self.view.delete

method load*(self: Module) =
  self.controller.init()
  let stickerMarketAddress = self.controller.getStickerMarketAddress()
  self.view.load(stickerMarketAddress)

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.stickersDidLoad()

method obtainMarketStickerPacks*(self: Module) =
  self.controller.obtainMarketStickerPacks()

method getNumInstalledStickerPacks*(self: Module): int =
  self.controller.getNumInstalledStickerPacks()

method installStickerPack*(self: Module, packId: string) =
  self.controller.installStickerPack(packId)

method onStickerPackInstalled*(self: Module, packId: string) =
  self.view.onStickerPackInstalled(packId)

method installedStickerPacksLoaded*(self: Module) =
  self.view.setInstalledStickerPacksLoaded(true)

method uninstallStickerPack*(self: Module, packId: string) =
  self.controller.uninstallStickerPack(packId)

method removeRecentStickers*(self: Module, packId: string) =
  self.controller.removeRecentStickers(packId)

method sendSticker*(self: Module, channelId: string, replyTo: string, sticker: Item, threadId: string) =
  let stickerDto = StickerDto(hash: sticker.getHash, packId: sticker.getPackId)
  self.controller.sendSticker(
    channelId,
    replyTo,
    stickerDto,
    singletonInstance.userProfile.getPreferredName(),
    threadId)

method addRecentStickerToList*(self: Module, sticker: StickerDto) =
  self.view.addRecentStickerToList(initItem(sticker.hash, sticker.packId, sticker.url))

method getRecentStickers*(self: Module) =
  self.controller.loadRecentStickers()

method getInstalledStickerPacks*(self: Module) =
  self.controller.loadInstalledStickerPacks()

method clearStickerPacks*(self: Module) =
  self.view.clearStickerPacks()

method clearStickers*(self: Module) =
  self.view.clearStickers()

method allPacksLoaded*(self: Module) =
  self.view.allPacksLoaded()

method allPacksLoadFailed*(self: Module) =
  self.view.allPacksLoadFailed()

method populateInstalledStickerPacks*(self: Module, stickers: Table[string, StickerPackDto]) =
  var stickerPackItems: seq[PackItem] = @[]
  for stickerPack in stickers.values:
    stickerPackItems.add(initPackItem(
      stickerPack.id,
      stickerPack.name,
      stickerPack.author,
      stickerPack.price,
      stickerPack.preview,
      stickerPack.stickers.map(s => initItem(s.hash, s.packId, s.url)),
      stickerPack.thumbnail
    ))
  self.view.populateInstalledStickerPacks(stickerPackItems)

method addStickerPackToList*(self: Module, stickerPack: StickerPackDto, isInstalled: bool, isBought: bool, isPending: bool) =
  let stickerPackItem = initPackItem(
          stickerPack.id,
          stickerPack.name,
          stickerPack.author,
          stickerPack.price,
          stickerPack.preview,
          stickerPack.stickers.map(s => initItem(s.hash, s.packId, s.url)),
          stickerPack.thumbnail
        )
  self.view.addStickerPackToList(stickerPackItem, isInstalled, isBought, isPending)

method getWalletDefaultAddress*(self: Module): string =
  return self.controller.getWalletDefaultAddress()

method getCurrentCurrency*(self: Module): string =
  return self.controller.getCurrentCurrency()

method stickerTransactionSent*(self: Module, chainId: int, packId: string, txHash: string, error: string) =
  self.view.stickerPacks.updateStickerPackInList(packId, installed = false, pending = true)
  self.view.transactionWasSent(chainId, txHash, error)

method stickerTransactionConfirmed*(self: Module, trxType: string, packID: string, transactionHash: string) =
  self.view.stickerPacks.updateStickerPackInList(packID, installed = true, pending = false)
  self.controller.installStickerPack(packID)
  self.view.emitTransactionCompletedSignal(true, transactionHash, packID, trxType)

method stickerTransactionReverted*(self: Module, trxType: string, packID: string, transactionHash: string) =
  self.view.stickerPacks.updateStickerPackInList(packID, installed = false, pending = false)
  self.view.emitTransactionCompletedSignal(false, transactionHash, packID, trxType)
