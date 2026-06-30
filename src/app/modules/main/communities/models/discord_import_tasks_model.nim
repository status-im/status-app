import app/modules/shared_models/model_utils
import nimqml, tables
import discord_import_error_item, discord_import_errors_model
import discord_import_task_item as taskItem 
import ../../../../../app_service/service/community/dto/community

type
  ModelRole {.pure.} = enum
    Type = UserRole + 1
    Progress
    State
    Errors
    Stopped
    ErrorsCount
    WarningsCount

QtObject:
  type DiscordImportTasksModel* = ref object of QAbstractListModel
    items*: seq[DiscordImportTaskItem]

  proc setup(self: DiscordImportTasksModel)
  proc delete(self: DiscordImportTasksModel)
  proc newDiscordDiscordImportTasksModel*(): DiscordImportTasksmodel =
    new(result, delete)
    result.setup

  method roleNames(self: DiscordImportTasksModel): Table[int, string] =
    {
      ModelRole.Type.int:"type",
      ModelRole.Progress.int:"progress",
      ModelRole.State.int:"state",
      ModelRole.Errors.int:"errors",
      ModelRole.Stopped.int:"stopped",
      ModelRole.ErrorsCount.int:"errorsCount",
      ModelRole.WarningsCount.int:"warningsCount",
    }.toTable

  method data(self: DiscordImportTasksModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let item = self.items[index.row]

    let enumRole = role.ModelRole
    case enumRole:
      of ModelRole.Type:
        result = newQVariant(item.`type`)
      of ModelRole.Progress:
        result = newQVariant(item.progress)
      of ModelRole.State:
        result = newQVariant(item.state)
      of ModelRole.Errors:
        result = newQVariant(item.errors)
      of ModelRole.Stopped:
        result = newQVariant(item.stopped)
      of ModelRole.ErrorsCount:
        result = newQVariant(item.errorsCount)
      of ModelRole.WarningsCount:
        result = newQVariant(item.warningsCount)

  method rowCount(self: DiscordImportTasksModel, index: QModelIndex = nil): int =
    return self.items.len

  proc setItems*(self: DiscordImportTasksModel, items: seq[DiscordImportTaskItem]) =
    self.beginResetModel()
    self.items = items
    self.endResetModel()

  proc hasItemByType*(self: DiscordImportTasksModel, `type`: string): bool =
    for i, item in self.items:
      if self.items[i].`type` == `type`:
        return true
    return false

  proc addItem*(self: DiscordImportTasksModel, item: DiscordImportTaskItem) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    self.beginInsertRows(parentModelIndex, self.items.len, self.items.len)
    self.items.add(item)
    self.endInsertRows()

  proc findIndexByType(self: DiscordImportTasksModel, `type`: string): int =
    for i in 0 ..< self.items.len:
      if(self.items[i].`type` == `type`):
        return i
    return -1

  proc updateItem*(self: DiscordImportTasksModel, item: DiscordImportTaskProgress) =
    updateItemRolesAndNotify self.findIndexByType(item.`type`):
      updateRoleWithValue(progress, item.progress)
      updateRoleWithValue(state, item.state)
      updateRoleWithValue(stopped, item.stopped)
      updateRoleWithValue(errorsCount, item.errorsCount)
      updateRoleWithValue(warningsCount, item.warningsCount)

      let errorItemsCount = self.items[ind].errors.items.len
      var errorsChanged = false

      # We only show the first 3 warnings + any error per task,
      # then we add another "#n more issues" item in the UI
      for i, error in item.errors:
        if (errorItemsCount + i < taskItem.MAX_VISIBLE_ERROR_ITEMS) or error.code > ord(DiscordImportErrorCode.Warning):
          let errorItem = initDiscordImportErrorItem(item.`type`, error.code, error.message)
          self.items[ind].errors.addItem(errorItem)
          errorsChanged = true

      addChangedRole(roles, false, errorsChanged, ModelRole.Errors.int): discard


  proc clearItems*(self: DiscordImportTasksModel) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()

  proc setup(self: DiscordImportTasksModel) =
    self.QAbstractListModel.setup

  proc delete(self: DiscordImportTasksModel) =
    self.QAbstractListModel.delete
