import nimqml, json, strutils

import ./models/[sticker_list, sticker_pack_list]
import ./io_interface, ./item

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      packsLoaded*: bool
      installedStickerPacksLoaded*: bool
      packsLoadFailed*: bool
      stickerPacks*: StickerPackList
      recentStickers*: StickerList
      stickersMarketAddress: string

  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface): View =
    new(result, delete)
    result.QObject.setup
    result.delegate = delegate
    result.stickerPacks = newStickerPackList(result.delegate)
    result.recentStickers = newStickerList(result.delegate)
    result.installedStickerPacksLoaded = false

  proc load*(self: View, stickersMarketAddress: string) =
    self.stickersMarketAddress = stickersMarketAddress
    self.delegate.viewDidLoad()

  proc addStickerPackToList*(self: View, stickerPack: PackItem, isInstalled, isBought, isPending: bool) =
    self.stickerPacks.addStickerPackToList(
      stickerPack,
      newStickerList(self.delegate, stickerPack.stickers),
      isInstalled,
      isBought,
      isPending
    )

  proc getStickerPackList(self: View): QVariant {.slot.} =
    newQVariant(self.stickerPacks)

  QtProperty[QVariant] stickerPacks:
    read = getStickerPackList

  proc recentStickersUpdated*(self: View) {.signal.}
  proc getRecentStickerList*(self: View): QVariant {.slot.} =
    result = newQVariant(self.recentStickers)

  QtProperty[QVariant] recent:
    read = getRecentStickerList
    notify = recentStickersUpdated

  proc transactionWasSent*(self: View, chainId: int, txHash: string, error: string) {.signal.}

  proc transactionCompleted*(self: View, success: bool, txHash: string) {.signal.}

  proc stickerPacksLoaded*(self: View) {.signal.}

  proc stickerPackInstalled*(self: View, packId: string) {.signal.}

  proc packsLoadFailedChanged*(self: View) {.signal.}

  proc installedStickerPacksUpdated*(self: View) {.signal.}

  proc clearStickers*(self: View) =
    self.recentStickers.clear()

  proc clearStickerPacks*(self: View) =
    self.stickerPacks.clear()

  proc populateInstalledStickerPacks*(self: View, installedStickerPacks: seq[PackItem]) =
    for stickerPack in installedStickerPacks:
      if not self.stickerPacks.hasKey(stickerPack.id):
        self.addStickerPackToList(stickerPack, isInstalled = true, isBought = true, isPending = false)

  proc getNumInstalledStickerPacks(self: View): int {.slot.} =
    self.delegate.getNumInstalledStickerPacks()

  QtProperty[int] numInstalledStickerPacks:
    read = getNumInstalledStickerPacks
    notify = installedStickerPacksUpdated

  proc install*(self: View, packId: string) {.slot.} =
    self.delegate.installStickerPack(packId)

  proc onStickerPackInstalled*(self:View, packId: string) =
    self.stickerPacks.updateStickerPackInList(packId, true, false)
    self.installedStickerPacksUpdated()
    self.stickerPackInstalled(packId)

  proc resetBuyAttempt*(self: View, packId: string) {.slot.} =
    self.stickerPacks.updateStickerPackInList(packId, false, false)

  proc setInstalledStickerPacksLoaded*(self: View, flag: bool) =
    self.installedStickerPacksLoaded = flag

  proc getInstalledStickerPacksLoaded*(self: View): bool =
    return self.installedStickerPacksLoaded

  proc uninstall*(self: View, packId: string) {.slot.} =
    self.delegate.uninstallStickerPack(packId)
    self.delegate.removeRecentStickers(packId)
    self.stickerPacks.updateStickerPackInList(packId, false, false)
    self.recentStickers.removeStickersFromList(packId)
    self.installedStickerPacksUpdated()
    self.recentStickersUpdated()

  proc addRecentStickerToList*(self: View, sticker: Item) =
    self.recentStickers.addStickerToList(sticker)
    self.recentStickersUpdated()

  proc getAllPacksLoaded(self: View): bool {.slot.} =
    self.packsLoaded

  QtProperty[bool] packsLoaded:
    read = getAllPacksLoaded
    notify = stickerPacksLoaded

  proc allPacksLoaded*(self: View) =
    self.packsLoaded = true
    self.packsLoadFailed = false

    self.stickerPacksLoaded()
    self.packsLoadFailedChanged()
    self.installedStickerPacksUpdated()

  proc allPacksLoadFailed*(self: View) =
    self.packsLoadFailed = true
    self.packsLoadFailedChanged()

  proc getPacksLoadFailed(self: View): bool {.slot.} =
    self.packsLoadFailed

  QtProperty[bool] packsLoadFailed:
    read = getPacksLoadFailed
    notify = packsLoadFailedChanged

  proc loadStickers(self: View) {.slot.} =
    self.packsLoaded = false
    self.packsLoadFailed = false
    self.stickerPacksLoaded()
    self.packsLoadFailedChanged()

    self.delegate.obtainMarketStickerPacks()

  proc getRecentStickers(self: View) {.slot.} =
    self.delegate.getRecentStickers()

  proc getInstalledStickerPacks(self: View) {.slot.} =
    if not self.installedStickerPacksLoaded:
      self.delegate.getInstalledStickerPacks()

  proc send*(self: View, channelId: string, hash: string, replyTo: string, pack: string, url: string) {.slot.} =
    let sticker = initItem(hash, pack, url)
    self.addRecentStickerToList(sticker)
    self.delegate.sendSticker(channelId, replyTo, sticker)

  proc getStickersMarketAddress(self: View): string {.slot.} =
    return self.stickersMarketAddress

  proc getWalletDefaultAddress*(self: View): string {.slot.} =
    return self.delegate.getWalletDefaultAddress()

  proc getCurrentCurrency*(self: View): string {.slot.} =
    return self.delegate.getCurrentCurrency()

  proc transactionCompleted(self: View, success: bool, txHash: string, packID: string, trxType: string) {.signal.}
  proc emitTransactionCompletedSignal*(self: View, success: bool, txHash: string, packID: string, trxType: string) =
    self.transactionCompleted(success, txHash, packID, trxType)

  proc delete*(self: View) =
    self.QObject.delete

