import nimqml, tables, strutils, sequtils, sugar, std/strformat

import ./derived_address_item

export derived_address_item

type
  ModelRole {.pure.} = enum
    AddressDetails = UserRole + 1

QtObject:
  type
    DerivedAddressModel* = ref object of QAbstractListModel
      items: seq[DerivedAddressItem]

  proc delete(self: DerivedAddressModel)
  proc setup(self: DerivedAddressModel)
  proc newDerivedAddressModel*(): DerivedAddressModel =
    new(result, delete)
    result.setup

  proc `$`*(self: DerivedAddressModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""[{i}]:({$self.items[i]})"""

  proc countChanged(self: DerivedAddressModel) {.signal.}
  proc getCount(self: DerivedAddressModel): int {.slot.} =
    self.items.len
  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc loadedCountChanged(self: DerivedAddressModel) {.signal.}
  proc getLoadedCount(self: DerivedAddressModel): int {.slot.} =
    return self.items.filter(x => x.getDetailsLoaded()).len
  QtProperty[int] loadedCount:
    read = getLoadedCount
    notify = loadedCountChanged

  method rowCount(self: DerivedAddressModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: DerivedAddressModel): Table[int, string] =
    {
      ModelRole.AddressDetails.int: "addressDetails"
    }.toTable

  method data(self: DerivedAddressModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.AddressDetails:
      result = newQVariant(item)

  proc reset*(self: DerivedAddressModel) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()
    self.countChanged()
    self.loadedCountChanged()

  proc setItems*(self: DerivedAddressModel, items: seq[DerivedAddressItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()
    self.loadedCountChanged()

  proc getItemByAddress*(self: DerivedAddressModel, address: string): DerivedAddressItem =
    for it in self.items:
      if it.getAddress() == address:
        return it
    return nil
  
  proc updateDetailsForAddressAndBubbleItToTop*(
    self: DerivedAddressModel,
    address: string,
    hasActivity: bool,
    detailsLoaded: bool,
    errorInScanningActivity: bool) =
    var item: DerivedAddressItem
    for i in 0 ..< self.items.len:
      if cmpIgnoreCase(self.items[i].getAddress(), address) == 0:
        item = self.items[i]
       
        let parentModelIndex = newQModelIndex()
        defer: parentModelIndex.delete
        self.beginRemoveRows(parentModelIndex, i, i)
        self.items.delete(i)
        self.endRemoveRows()
        break

    if item.isNil:
      return

    var indexToInsertTo = 0
    for i in 0 ..< self.items.len:
      if not self.items[i].getDetailsLoaded():
        break
      indexToInsertTo.inc

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginInsertRows(parentModelIndex, indexToInsertTo, indexToInsertTo)
    self.items.insert(
      newDerivedAddressItem(item.getOrder(), item.getAddress(), item.getPublicKey(), item.getPath(), item.getAlreadyCreated(), 
        hasActivity, alreadyCreatedChecked = true, detailsLoaded = detailsLoaded,
        errorInScanningActivity = errorInScanningActivity),
      indexToInsertTo
    )
    self.endInsertRows()
    self.countChanged() # we need this to trigger bindings on the qml side
    self.loadedCountChanged()

  proc getAllAddresses*(self: DerivedAddressModel): seq[string] =
    return self.items.map(x => x.getAddress())

  proc delete(self: DerivedAddressModel) =
    self.QAbstractListModel.delete

  proc setup(self: DerivedAddressModel) =
    self.QAbstractListModel.setup

