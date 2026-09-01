import tables
import ./item

import app_service/service/stickers/service as stickers_service

type
  AccessInterface* {.pure inheritable.} = ref object of RootObj
  ## Abstract class for any input/interaction with this module.

method delete*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method load*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method isLoaded*(self: AccessInterface): bool {.base.} =
  raise newException(ValueError, "No implementation available")

method viewDidLoad*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getRecentStickers*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method loadRecentStickers*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getInstalledStickerPacks*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method installedStickerPacksLoaded*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method obtainMarketStickerPacks*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method addRecentStickerToList*(self: AccessInterface, sticker: StickerDto) {.base.} =
  raise newException(ValueError, "No implementation available")

method clearStickers*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method clearStickerPacks*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method getNumInstalledStickerPacks*(self: AccessInterface): int {.base.} =
  raise newException(ValueError, "No implementation available")

method allPacksLoaded*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method allPacksLoadFailed*(self: AccessInterface) {.base.} =
  raise newException(ValueError, "No implementation available")

method estimate*(self: AccessInterface, packId: string, address: string, price: string, uuid: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method installStickerPack*(self: AccessInterface, packId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method onStickerPackInstalled*(self: AccessInterface, packId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method uninstallStickerPack*(self: AccessInterface, packId: string) {.base.} =
  raise newException(ValueError, "No implementation available")


method removeRecentStickers*(self: AccessInterface, packId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method sendSticker*(self: AccessInterface, channelId: string, replyTo: string, sticker: Item, threadId: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method populateInstalledStickerPacks*(self: AccessInterface, stickers: Table[string, StickerPackDto]) {.base.} =
  raise newException(ValueError, "No implementation available")

method addStickerPackToList*(self: AccessInterface, stickerPack: StickerPackDto, isInstalled: bool, isBought: bool, isPending: bool) {.base.} =
  raise newException(ValueError, "No implementation available")

method getWalletDefaultAddress*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method getCurrentCurrency*(self: AccessInterface): string {.base.} =
  raise newException(ValueError, "No implementation available")

method stickerTransactionSent*(self: AccessInterface, chainId: int, packId: string, txHash: string, error: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method stickerTransactionConfirmed*(self: AccessInterface, trxType: string, packID: string, transactionHash: string) {.base.} =
  raise newException(ValueError, "No implementation available")

method stickerTransactionReverted*(self: AccessInterface, trxType: string, packID: string, transactionHash: string) {.base.} =
  raise newException(ValueError, "No implementation available")