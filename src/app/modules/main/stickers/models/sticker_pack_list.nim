import app/modules/shared_models/model_utils
import nimqml, tables, sequtils, sugar
import ./sticker_list
import ../io_interface, ../item
# TODO remove those uses of services stuff
import app_service/service/eth/utils as eth_utils
import app_service/common/conversion as service_conversion


type
  StickerPackRoles {.pure.} = enum
    Author = UserRole + 1,
    Id = UserRole + 2
    Name = UserRole + 3
    Price = UserRole + 4
    Preview = UserRole + 5
    Stickers = UserRole + 6
    Thumbnail = UserRole + 7
    Installed = UserRole + 8
    Bought = UserRole + 9
    Pending = UserRole + 10

type
  StickerPackView* = tuple[pack: PackItem, stickers: StickerList, installed, bought, pending: bool]

QtObject:
  type
    StickerPackList* = ref object of QAbstractListModel
      delegate: io_interface.AccessInterface
      packs*: seq[StickerPackView]
      foundStickers*: QVariant

  proc setup(self: StickerPackList)
  proc delete(self: StickerPackList)
  proc newStickerPackList*(delegate: io_interface.AccessInterface): StickerPackList =
    new(result, delete)
    result.delegate = delegate
    result.packs = @[]
    result.setup()

  proc clear*(self: StickerPackList) =
    self.beginResetModel()
    self.packs = @[]
    self.endResetModel()

  method rowCount(self: StickerPackList, index: QModelIndex = nil): int = self.packs.len

  method data(self: StickerPackList, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.packs.len, role, StickerPackRoles)

    let packInfo = self.packs[index.row]
    let stickerPack = packInfo.pack
    let stickerPackRole = role.StickerPackRoles
    case stickerPackRole:
      of StickerPackRoles.Author: result = newQVariant(stickerPack.author)
      of StickerPackRoles.Id: result = newQVariant(stickerPack.id)
      of StickerPackRoles.Name: result = newQVariant(stickerPack.name)
      of StickerPackRoles.Price: result = newQVariant(service_conversion.wei2Eth(stickerPack.price))
      of StickerPackRoles.Preview: result = newQVariant(stickerPack.preview)
      of StickerPackRoles.Stickers: result = newQVariant(packInfo.stickers)
      of StickerPackRoles.Thumbnail: result = newQVariant(stickerPack.thumbnail)
      of StickerPackRoles.Installed: result = newQVariant(packInfo.installed)
      of StickerPackRoles.Bought: result = newQVariant(packInfo.bought)
      of StickerPackRoles.Pending: result = newQVariant(packInfo.pending)

  method roleNames(self: StickerPackList): Table[int, string] =
    {
      StickerPackRoles.Author.int:"author",
      StickerPackRoles.Id.int:"packId",
      StickerPackRoles.Name.int: "name",
      StickerPackRoles.Price.int: "price",
      StickerPackRoles.Preview.int: "preview",
      StickerPackRoles.Stickers.int: "stickers",
      StickerPackRoles.Thumbnail.int: "thumbnail",
      StickerPackRoles.Installed.int: "installed",
      StickerPackRoles.Bought.int: "bought",
      StickerPackRoles.Pending.int: "pending"
    }.toTable

  proc findIndexById*(self: StickerPackList, packId: string, mustBeInstalled: bool = false): int {.slot.} =
    result = -1
    var idx = -1
    for item in self.packs:
      inc idx
      let installed = if mustBeInstalled: item.installed else: true
      if(item.pack.id == packId and installed):
        result = idx
        break

  proc hasKey*(self: StickerPackList, packId: string): bool =
    result = self.packs.anyIt(it.pack.id == packId)

  proc `[]`*(self: StickerPackList, packId: string): PackItem =
    if not self.hasKey(packId):
      raise newException(ValueError, "Sticker pack list does not have a pack with id " & $packId)
    result = eth_utils.find(self.packs, (view: StickerPackView) => view.pack.id == packId).pack

  proc addStickerPackToList*(self: StickerPackList, pack: PackItem, stickers: StickerList, installed, bought, pending: bool) =
    let modelIndex = newQModelIndex()
    defer: modelIndex.delete
    self.beginInsertRows(modelIndex, 0, 0)
    self.packs.insert((pack: pack, stickers: stickers, installed: installed, bought: bought, pending: pending), 0)
    self.endInsertRows()

  proc removeStickerPackFromList*(self: StickerPackList, packId: string) =
    let idx = self.findIndexById(packId)
    let modelIndex = newQModelIndex()
    defer: modelIndex.delete
    self.beginRemoveRows(modelIndex, idx, idx)
    self.packs.delete(idx)
    self.endRemoveRows()

  proc updateStickerPackInList*(self: StickerPackList, packId: string, installed: bool, pending: bool) =
    let idx = self.findIndexById(packId)
    if idx == -1:
      return
    let index = self.createIndex(idx, 0, nil)
    defer: index.delete
    self.packs.apply(proc(it: var StickerPackView) =
      if it.pack.id == packId:
        it.installed = installed
        if installed:
          it.bought = true
        it.pending = pending)
    self.dataChanged(index, index, @[StickerPackRoles.Installed.int, StickerPackRoles.Bought.int,
      StickerPackRoles.Pending.int])

  # We cannot return QVariant from the proc which has arguments.
  # First findStickersById has to be called, then getFoundStickers
  proc findStickersById*(self: StickerPackList, packId: string) {.slot.} =
    self.foundStickers = newQVariant()
    for item in self.packs:
      if(item.pack.id == packId):
        self.foundStickers = newQVariant(item.stickers)
        break

  proc getFoundStickers*(self: StickerPackList): QVariant {.slot.} =
    return self.foundStickers

  proc setup(self: StickerPackList) = self.QAbstractListModel.setup
  proc delete(self: StickerPackList) = self.QAbstractListModel.delete