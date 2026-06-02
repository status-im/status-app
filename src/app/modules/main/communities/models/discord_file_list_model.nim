import app/modules/shared_models/model_utils
import nimqml, tables
import discord_file_item

type
  ModelRole {.pure.} = enum
    FilePath = UserRole + 1
    ErrorMessage
    ErrorCode
    Selected
    Validated

QtObject:
  type DiscordFileListModel* = ref object of QAbstractListModel
    items*: seq[DiscordFileItem]

  proc setup(self: DiscordFileListModel)
  proc delete(self: DiscordFileListModel)
  proc newDiscordFileListModel*(): DiscordFileListModel =
    new(result, delete)
    result.setup

  proc selectedFilesValidChanged(self: DiscordFileListModel) {.signal.}

  proc getSelectedFilesValid*(self: DiscordFileListModel): bool {.slot.} =
    for i in 0 ..< self.items.len:
      if self.items[i].getSelected() and not self.items[i].getValidated():
        return false
    return true

  QtProperty[bool] selectedFilesValid:
    read = getSelectedFilesValid
    notify = selectedFilesValidChanged

  proc getSelectedFilePaths*(self: DiscordFileListModel): seq[string] =
    var filePaths: seq[string] = @[]
    for i in 0 ..< self.items.len:
      filePaths.add(self.items[i].getFilePath())
    return filePaths

  proc countChanged(self: DiscordFileListModel) {.signal.}

  proc getCount(self: DiscordFileListModel): int {.slot.} =
    self.items.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc selectedCountChanged(self: DiscordFileListModel) {.signal.}
  proc getSelectedCount(self: DiscordFileListModel): int {.slot.} =
    for i in 0 ..< self.items.len:
      if self.items[i].getSelected():
        result = result + 1

  QtProperty[int] selectedCount:
    read = getSelectedCount
    notify = selectedCountChanged

  method rowCount(self: DiscordFileListModel, index: QModelIndex = nil): int =
    return self.items.len

  proc setItems*(self: DiscordFileListModel, items: seq[DiscordFileItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()
    self.countChanged()
    self.selectedCountChanged()
    self.selectedFilesValidChanged()

  method roleNames(self: DiscordFileListModel): Table[int, string] =
    {
      ModelRole.FilePath.int:"filePath",
      ModelRole.ErrorMessage.int:"errorMessage",
      ModelRole.ErrorCode.int:"errorCode",
      ModelRole.Selected.int:"selected",
      ModelRole.Validated.int:"validated",
    }.toTable

  method setData(self: DiscordFileListModel, index: QModelIndex, value: QVariant, role: int): bool =
    let row = index.row
    guardModelSetDataIndex(index, row, self.items.len)
    guardModelSetDataRole(role, ModelRole)

    case role.ModelRole:
      of ModelRole.FilePath:
        self.items[index.row].filePath = value.stringVal()
        self.dataChanged(index, index, @[ModelRole.FilePath.int])
      of ModelRole.ErrorMessage:
        self.items[index.row].errorMessage = value.stringVal()
        self.dataChanged(index, index, @[ModelRole.ErrorMessage.int])
      of ModelRole.ErrorCode:
        self.items[index.row].errorCode = value.intVal()
        self.dataChanged(index, index, @[ModelRole.ErrorCode.int])
      of ModelRole.Selected:
        self.items[index.row].selected = value.boolVal()
        self.dataChanged(index, index, @[ModelRole.Selected.int])
        self.selectedCountChanged()
      of ModelRole.Validated:
        self.items[index.row].validated = value.boolVal()
        self.dataChanged(index, index, @[ModelRole.Validated.int])
        self.selectedFilesValidChanged()
    return true

  method data(self: DiscordFileListModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.FilePath:
        result = newQVariant(item.getFilePath())
      of ModelRole.ErrorMessage:
        result = newQVariant(item.getErrorMessage())
      of ModelRole.ErrorCode:
        result = newQVariant(item.getErrorCode())
      of ModelRole.Selected:
        result = newQVariant(item.getSelected())
      of ModelRole.Validated:
        result = newQVariant(item.getValidated())

  proc findIndexByFilePath(self: DiscordFileListModel, filePath: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].getFilePath() == filePath):
        return i
    return -1

  proc removeItem*(self: DiscordFileListModel, filePath: string) =
    let idx = self.findIndexByFilePath(filePath)
    if(idx == -1):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, idx, idx)
    self.items.delete(idx)
    self.endRemoveRows()
    self.countChanged()

  proc addItem*(self: DiscordFileListModel, item: DiscordFileItem) =
      let parentModelIndex = newQModelIndex()
      defer: parentModelIndex.delete
      self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
      self.items.add(item)
      self.endInsertRows()
      self.countChanged()

  proc setAllValidated*(self: DiscordFileListModel) =
    for i in 0 ..< self.items.len:
      let index = self.createIndex(i, 0, nil)
      defer: index.delete
      self.items[i].validated = true
      self.dataChanged(index, index, @[ModelRole.Validated.int])
    self.selectedFilesValidChanged()

  proc updateErrorState*(self: DiscordFileListModel, filePath: string, errorMessage: string, errorCode: int) =
    let idx = self.findIndexByFilePath(filePath)
    if idx > -1:
      let index = self.createIndex(idx, 0, nil)
      defer: index.delete
      self.items[idx].errorMessage = errorMessage
      self.items[idx].errorCode = errorCode
      self.items[idx].selected = false
      self.items[idx].validated = true
      self.dataChanged(index, index, @[
        ModelRole.ErrorMessage.int,
        ModelRole.ErrorCode.int,
        ModelRole.Selected.int,
        ModelRole.Validated.int
      ])
      self.selectedCountChanged()

  proc clearItems*(self: DiscordFileListModel) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()
    self.countChanged()
    self.selectedCountChanged()
    self.selectedFilesValidChanged()

  proc setup(self: DiscordFileListModel) =
    self.QAbstractListModel.setup

  proc delete(self: DiscordFileListModel) =
    self.QAbstractListModel.delete
