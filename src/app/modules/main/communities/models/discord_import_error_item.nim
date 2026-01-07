import std/strformat
type
  DiscordImportErrorItem* = object
    taskId*: string
    code*: int
    message*: string

proc initDiscordImportErrorItem*(
  taskId: string,
  code: int,
  message: string,
): DiscordImportErrorItem =
  result.taskId = taskId
  result.code = code
  result.message = message

proc `$`*(self: DiscordImportErrorItem): string =
  result = fmt"""DiscordImportErrorItem(
    taskId: {self.taskId},
    code: {self.code},
    message: {self.message}
    ]"""

proc getTaskId*(self: DiscordImportErrorItem): string =
  return self.taskId

proc getCode*(self: DiscordImportErrorItem): int =
  return self.code

proc getMessage*(self: DiscordImportErrorItem): string =
  return self.message
