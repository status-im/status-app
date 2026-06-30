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
      if self.items[i].selected and not self.items[i].validated:
        return false
    return true

  QtProperty[bool] selectedFilesValid:
    read = getSelectedFilesValid
    notify = selectedFilesValidChanged

  proc getSelectedFilePaths*(self: DiscordFileListModel): seq[string] =
    var filePaths: seq[string] = @[]
    for i in 0 ..< self.items.len:
      filePaths.add(self.items[i].filePath)
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
      if self.items[i].selected:
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

    let notifySelectedCount = role.ModelRole == ModelRole.Selected and self.items[row].selected != value.boolVal()
    let notifySelectedFilesValid = role.ModelRole == ModelRole.Validated and self.items[row].validated != value.boolVal()

    let ind = row
    updateRolesAndNotify:
      case role.ModelRole:
        of ModelRole.FilePath:
          updateRoleWithValue(filePath, value.stringVal())
        of ModelRole.ErrorMessage:
          updateRoleWithValue(errorMessage, value.stringVal())
        of ModelRole.ErrorCode:
          updateRoleWithValue(errorCode, value.intVal())
        of ModelRole.Selected:
          updateRoleWithValue(selected, value.boolVal())
        of ModelRole.Validated:
          updateRoleWithValue(validated, value.boolVal())
    if notifySelectedCount:
      self.selectedCountChanged()
    if notifySelectedFilesValid:
      self.selectedFilesValidChanged()
    return true

  method data(self: DiscordFileListModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.FilePath:
        result = newQVariant(item.filePath)
      of ModelRole.ErrorMessage:
        result = newQVariant(item.errorMessage)
      of ModelRole.ErrorCode:
        result = newQVariant(item.errorCode)
      of ModelRole.Selected:
        result = newQVariant(item.selected)
      of ModelRole.Validated:
        result = newQVariant(item.validated)

  proc findIndexByFilePath(self: DiscordFileListModel, filePath: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].filePath == filePath):
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
    for ind in 0 ..< self.items.len:
      updateRolesAndNotify:
        updateRoleWithValue(validated, true)
    self.selectedFilesValidChanged()

  proc updateErrorState*(self: DiscordFileListModel, filePath: string, errorMessage: string, errorCode: int) =
    updateItemRolesAndNotify self.findIndexByFilePath(filePath):
      updateRole(errorMessage)
      updateRole(errorCode)
      updateRoleWithValue(selected, false)
      updateRoleWithValue(validated, true)
      if ModelRole.Selected.int in roles:
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
