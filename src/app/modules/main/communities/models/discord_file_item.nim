import std/strformat
type
  DiscordFileItem* = object
    filePath*: string
    errorMessage*: string
    errorCode*: int
    selected*: bool
    validated*: bool

proc initDiscordFileItem*(
  filePath: string,
  errorMessage: string,
  errorCode: int,
  selected: bool,
  validated: bool,
): DiscordFileItem =
  result.filePath = filePath
  result.errorMessage = errorMessage
  result.errorCode = errorCode
  result.selected = selected
  result.validated = validated

proc `$`*(self: DiscordFileItem): string =
  result = fmt"""DiscordFileItem(
    filePath: {self.filePath},
    errorMessage: {self.errorMessage},
    errorCode: {self.errorCode},
    selected: {self.selected},
    validated: {self.validated}
    ]"""

proc getFilePath*(self: DiscordFileItem): string =
  return self.filePath

proc filePath*(self: DiscordFileItem): string =
  return self.filePath

proc `filePath=`*(self: var DiscordFileItem, value: string) =
  self.filePath = value

proc getErrorMessage*(self: DiscordFileItem): string =
  return self.errorMessage

proc errorMessage*(self: DiscordFileItem): string =
  return self.errorMessage

proc `errorMessage=`*(self: var DiscordFileItem, value: string) =
  self.errorMessage = value

proc getErrorCode*(self: DiscordFileItem): int =
  return self.errorCode

proc errorCode*(self: DiscordFileItem): int =
  return self.errorCode

proc `errorCode=`*(self: var DiscordFileItem, value: int) =
  self.errorCode = value

proc getSelected*(self: DiscordFileItem): bool =
  return self.selected

proc selected*(self: DiscordFileItem): bool =
  return self.selected

proc `selected=`*(self: var DiscordFileItem, value: bool) =
  self.selected = value

proc getValidated*(self: DiscordFileItem): bool =
  return self.validated

proc validated*(self: DiscordFileItem): bool =
  return self.validated

proc `validated=`*(self: var DiscordFileItem, value: bool) =
  self.validated = value
