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
        result = newQVariant(item.getType())
      of ModelRole.Progress:
        result = newQVariant(item.getProgress())
      of ModelRole.State:
        result = newQVariant(item.getState())
      of ModelRole.Errors:
        result = newQVariant(item.getErrors())
      of ModelRole.Stopped:
        result = newQVariant(item.getStopped())
      of ModelRole.ErrorsCount:
        result = newQVariant(item.getErrorsCount())
      of ModelRole.WarningsCount:
        result = newQVariant(item.getWarningsCount())

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
    let idx = self.findIndexByType(item.`type`)
    if idx > -1:
      let index = self.createIndex(idx, 0, nil)
      defer: index.delete
      let errorsAndWarningsCount = self.items[idx].warningsCount + self.items[idx].errorsCount
      self.items[idx].progress = item.progress
      self.items[idx].state = item.state
      self.items[idx].stopped = item.stopped
      self.items[idx].errorsCount = item.errorsCount
      self.items[idx].warningsCount = item.warningsCount

      let errorItemsCount = self.items[idx].errors.items.len

      # We only show the first 3 warnings + any error per task,
      # then we add another "#n more issues" item in the UI
      for i, error in item.errors:
        if (errorItemsCount + i < taskItem.MAX_VISIBLE_ERROR_ITEMS) or error.code > ord(DiscordImportErrorCode.Warning):
          let errorItem = initDiscordImportErrorItem(item.`type`, error.code, error.message)
          self.items[idx].errors.addItem(errorItem)

      self.dataChanged(index, index, @[
        ModelRole.Progress.int,
        ModelRole.State.int,
        ModelRole.Errors.int,
        ModelRole.Stopped.int,
        ModelRole.ErrorsCount.int,
        ModelRole.WarningsCount.int
      ])


  proc clearItems*(self: DiscordImportTasksModel) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()

  proc setup(self: DiscordImportTasksModel) =
    self.QAbstractListModel.setup

  proc delete(self: DiscordImportTasksModel) =
    self.QAbstractListModel.delete
