import nimqml, tables, std/strformat, sequtils
import keycard_item

export keycard_item

type
  ModelRole {.pure.} = enum
    Keycard = UserRole + 1

QtObject:
  type
    KeycardModel* = ref object of QAbstractListModel
      items: seq[KeycardItem]

  proc delete(self: KeycardModel)
  proc setup(self: KeycardModel)
  proc newKeycardModel*(): KeycardModel =
    new(result, delete)
    result.setup

  proc countChanged(self: KeycardModel) {.signal.}
  proc getCount*(self: KeycardModel): int {.slot.} =
    self.items.len
  QtProperty[int]count:
    read = getCount
    notify = countChanged

  proc lockedItemsCountChanged(self: KeycardModel) {.signal.}
  proc getLockedItemsCount*(self: KeycardModel): int {.slot.} =
    for i in 0 ..< self.items.len:
      if self.items[i].getLocked():
        result.inc
  QtProperty[int]lockedItemsCount:
    read = getLockedItemsCount
    notify = lockedItemsCountChanged

  proc setItems*(self: KeycardModel, items: seq[KeycardItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()
    self.lockedItemsCountChanged()

  proc addItem*(self: KeycardModel, item: KeycardItem) =
    let modelIndex = newQModelIndex()
    defer: modelIndex.delete
    self.beginInsertRows(modelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()
    self.countChanged()
    self.lockedItemsCountChanged()

  proc replaceItemWithKeyUid*(self: KeycardModel, item: KeycardItem) =
    for i in 0 ..< self.items.len:
      if self.items[i].getKeyUid() == item.getKeyUid():
        self.items[i].setItem(item)

  proc removeItem*(self: KeycardModel, index: int) =
    if (index < 0 or index >= self.items.len):
      return
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.endRemoveRows()
    self.countChanged()

  proc removeItemsWithKeyUid*(self: KeycardModel, keyUid: string) =
    for i in countdown(self.items.len-1, 0):
      if self.items[i].getKeyUid() == keyUid:
        self.removeItem(i)

  proc `$`*(self: KeycardModel): string =
    for i in 0 ..< self.items.len:
      result &= fmt"""KeycardModel:
      [{i}]:({$self.items[i]})
      """

  method rowCount(self: KeycardModel, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: KeycardModel): Table[int, string] =
    {
      ModelRole.Keycard.int: "keycard"
    }.toTable

  method data(self: KeycardModel, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return
    if (index.row < 0 or index.row >= self.items.len):
      return
    let item = self.items[index.row]
    let enumRole = role.ModelRole
    case enumRole:
    of ModelRole.Keycard:
      result = newQVariant(item)

  proc getItemForKeyUid*(self: KeycardModel, keyUid: string): KeycardItem =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeyUid() == keyUid):
        return self.items[i]
    return nil

  proc getItemForKeycardUid*(self: KeycardModel, keycardUid: string): KeycardItem =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeycardUid() == keycardUid):
        return self.items[i]
    return nil

  proc findIndexForKeyUid(self: KeycardModel, keyUid: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeyUid() == keyUid):
        return i
    return -1

  proc setImage*(self: KeycardModel, keyUid: string, image: string) =
    let ind = self.findIndexForKeyUid(keyUid)
    if(ind == -1):
      return
    self.items[ind].setImage(image)

  proc setName*(self: KeycardModel, keyUid: string, name: string) =
    let ind = self.findIndexForKeyUid(keyUid)
    if(ind == -1):
      return
    self.items[ind].setName(name)

  proc setLockedForKeycardWithKeycardUid*(self: KeycardModel, keycardUid: string, locked: bool) =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeycardUid() == keycardUid):
        self.items[i].setLocked(locked)
        self.lockedItemsCountChanged()

  proc setLockedForKeycardsWithKeyUid*(self: KeycardModel, keyUid: string, locked: bool) =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeyUid() == keyUid):
        self.items[i].setLocked(locked)
        self.lockedItemsCountChanged()

  proc setNameForKeycardWithKeycardUid*(self: KeycardModel, keycardUid: string, name: string) =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeycardUid() == keycardUid):
        self.items[i].setName(name)

  proc setKeycardUid*(self: KeycardModel, keycardUid: string, keycardNewUid: string) =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeycardUid() == keycardUid):
        self.items[i].setKeycardUid(keycardNewUid)

  proc removeAccountsFromKeycardWithKeycardUid*(self: KeycardModel, keycardUid: string, accountsToRemove: seq[string],
    removeKeycardItemIfHasNoAccounts: bool) =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeycardUid() == keycardUid):
        for acc in accountsToRemove:
          self.items[i].removeAccountByAddress(acc)
        if removeKeycardItemIfHasNoAccounts and self.items[i].getAccountsModel().getCount() == 0:
          self.removeItem(i)

  proc removeAccountsFromKeycardsWithKeyUid*(self: KeycardModel, keyUid: string, accountsToRemove: seq[string],
    removeKeycardItemIfHasNoAccounts: bool) =
    for i in 0 ..< self.items.len:
      if(self.items[i].getKeyUid() == keyUid):
        for acc in accountsToRemove:
          self.items[i].removeAccountByAddress(acc)
        if removeKeycardItemIfHasNoAccounts and self.items[i].getAccountsModel().getCount() == 0:
          self.removeItem(i)

  proc delete(self: KeycardModel) =
    self.QAbstractListModel.delete

  proc setup(self: KeycardModel) =
    self.QAbstractListModel.setup

