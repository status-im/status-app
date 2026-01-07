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

proc getErrorMessage*(self: DiscordFileItem): string =
  return self.errorMessage

proc getErrorCode*(self: DiscordFileItem): int =
  return self.errorCode

proc getSelected*(self: DiscordFileItem): bool =
  return self.selected

proc getValidated*(self: DiscordFileItem): bool =
  return self.validated
