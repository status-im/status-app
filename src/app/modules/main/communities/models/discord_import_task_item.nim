import std/strformat
import discord_import_errors_model, discord_import_error_item
import ../../../../../app_service/service/community/dto/community


const MAX_VISIBLE_ERROR_ITEMS* = 3

type
  DiscordImportTaskItem* = object
    `type`*: string
    progress*: float
    state*: string
    errors*: DiscordImportErrorsModel
    stopped*: bool
    errorsCount*: int
    warningsCount*: int

proc `$`*(self: DiscordImportTaskItem): string =
  result = fmt"""DiscordImportTaskItem(
    type: {self.type},
    state: {self.state},
    progress: {self.progress},
    stopped: {self.stopped},
    ]"""

proc initDiscordImportTaskItem*(
  `type`: string,
  progress: float,
  state: string,
  errors: seq[DiscordImportError],
  stopped: bool,
  errorsCount: int,
  warningsCount: int
): DiscordImportTaskItem =
  result.type = type
  result.progress = progress
  result.state = state
  result.errors = newDiscordDiscordImportErrorsModel()
  result.stopped = stopped
  result.errorsCount = errorsCount
  result.warningsCount = warningsCount

  # We only show the first 3 errors per task, then we add another
  # "#n more issues" item in the UI
  for i, error in errors:
    if i < MAX_VISIBLE_ERROR_ITEMS or error.code > ord(DiscordImportErrorCode.Warning):
      result.errors.addItem(initDiscordImportErrorItem(`type`, error.code, error.message))

proc getType*(self: DiscordImportTaskItem): string =
  return self.`type`

proc `type`*(self: DiscordImportTaskItem): string =
  return self.`type`

proc `type=`*(self: var DiscordImportTaskItem, value: string) =
  self.`type` = value

proc getProgress*(self: DiscordImportTaskItem): float =
  return self.progress

proc progress*(self: DiscordImportTaskItem): float =
  return self.progress

proc `progress=`*(self: var DiscordImportTaskItem, value: float) =
  self.progress = value

proc getState*(self: DiscordImportTaskItem): string =
  return self.state

proc state*(self: DiscordImportTaskItem): string =
  return self.state

proc `state=`*(self: var DiscordImportTaskItem, value: string) =
  self.state = value

proc getErrors*(self: DiscordImportTaskItem): DiscordImportErrorsModel =
  return self.errors

proc errors*(self: DiscordImportTaskItem): DiscordImportErrorsModel =
  return self.errors

proc `errors=`*(self: var DiscordImportTaskItem, value: DiscordImportErrorsModel) =
  self.errors = value

proc getStopped*(self: DiscordImportTaskItem): bool =
  return self.stopped

proc stopped*(self: DiscordImportTaskItem): bool =
  return self.stopped

proc `stopped=`*(self: var DiscordImportTaskItem, value: bool) =
  self.stopped = value

proc getErrorsCount*(self: DiscordImportTaskItem): int =
  return self.errorsCount

proc errorsCount*(self: DiscordImportTaskItem): int =
  return self.errorsCount

proc `errorsCount=`*(self: var DiscordImportTaskItem, value: int) =
  self.errorsCount = value

proc getWarningsCount*(self: DiscordImportTaskItem): int =
  return self.warningsCount

proc warningsCount*(self: DiscordImportTaskItem): int =
  return self.warningsCount

proc `warningsCount=`*(self: var DiscordImportTaskItem, value: int) =
  self.warningsCount = value
