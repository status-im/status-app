import nimqml, tables, strutils, std/strformat, sequtils, chronicles, options

import ./entry

import app/modules/shared_models/currency_amount
import app_service/service/currency/service
import backend/activity as backend

type
  ModelRole {.pure.} = enum
    ActivityEntryRole = UserRole + 1

QtObject:
  type
    Model* = ref object of QAbstractListModel
      entries: seq[entry.ActivityEntry]
      hasMore: bool

  proc delete(self: Model)
  proc setup(self: Model)
  proc newModel*(): Model =
    new(result, delete)

    result.entries = @[]
    result.hasMore = true

    result.setup

  proc `$`*(self: Model): string =
    for i in 0 ..< self.entries.len:
      result &= fmt"""[{i}]:({$self.entries[i]})"""

  proc getEntry*(self: Model, index: int): entry.ActivityEntry =
    if index < 0 or index >= self.entries.len:
      return nil

    return self.entries[index]

  proc countChanged(self: Model) {.signal.}

  proc getCount*(self: Model): int {.slot.} =
    self.entries.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  method rowCount(self: Model, index: QModelIndex = nil): int =
    return self.entries.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.ActivityEntryRole.int:"activityEntry",
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.entries.len):
      return

    let entry = self.entries[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.ActivityEntryRole:
      result = newQVariant(entry)

  proc hasMoreChanged*(self: Model) {.signal.}

  proc setHasMore(self: Model, hasMore: bool) {.slot.} =
    self.hasMore = hasMore
    self.hasMoreChanged()

  proc resetModel*(self: Model, newEntries: seq[entry.ActivityEntry]) =
    self.beginResetModel()
    self.entries = newEntries
    self.endResetModel()

  proc setEntries*(self: Model, newEntries: seq[entry.ActivityEntry], offset: int, hasMore: bool) =
    if offset == 0:
      self.resetModel(newEntries)
    else:
      let parentModelIndex = newQModelIndex()
      defer: parentModelIndex.delete

      if offset != self.entries.len:
        error "offset != self.entries.len"
        return

      self.beginInsertRows(parentModelIndex, self.entries.len, self.entries.len + newEntries.len - 1)
      self.entries.add(newEntries)
      self.endInsertRows()

    self.countChanged()
    self.setHasMore(hasMore)

  proc addNewEntries*(self: Model, newEntries: seq[entry.ActivityEntry], insertPositions: seq[int]) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    for j in countdown(newEntries.high, 0):
      let ae = newEntries[j]
      let pos = insertPositions[j]
      self.beginInsertRows(parentModelIndex, pos, pos)
      self.entries.insert(ae, pos)
      self.endInsertRows()

    self.countChanged()

  proc updateEntries*(self: Model, updates: seq[backend.Data]) =
    for i in countdown(self.entries.high, 0):
      for j in countdown(updates.high, 0):
        if self.entries[i].getId() == updates[j].key:
          if updates[j].nftName.isSome():
            self.entries[i].setNftName(updates[j].nftName.get())
          if updates[j].nftUrl.isSome():
            self.entries[i].setNftImageUrl(updates[j].nftUrl.get())
          if updates[j].activityStatus.isSome():
            self.entries[i].setStatus(updates[j].activityStatus.get())
          break

  proc getHasMore*(self: Model): bool {.slot.} =
    return self.hasMore

  QtProperty[bool] hasMore:
    read = getHasMore
    notify = hasMoreChanged
    
  proc refreshItemsContainingAddress*(self: Model, address: string) =
    for i in 0..self.entries.high:
      if cmpIgnoreCase(self.entries[i].getSender(), address) == 0 or
        cmpIgnoreCase(self.entries[i].getRecipient(), address) == 0:
          let index = self.createIndex(i, 0, nil)
          defer: index.delete
          self.dataChanged(index, index, @[ModelRole.ActivityEntryRole.int])

  proc refreshAmountCurrency*(self: Model, currencyService: Service) =
    for i in 0..self.entries.high:
      self.entries[i].resetAmountCurrency(currencyService)

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

