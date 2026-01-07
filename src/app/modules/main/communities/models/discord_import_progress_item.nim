import std/strformat
type
  DiscordImportProgressItem* = object
    communityId*: string
    progress*: float
    errorsCount*: int
    warningsCount*: int
    stopped*: bool

proc initDiscordImportProgressItem*(
  communityId: string,
  progress: float,
  errorsCount: int,
  warningsCount: int,
  stopped: bool,
): DiscordImportProgressItem =
  result.communityId = communityId
  result.progress = progress
  result.errorsCount = errorsCount
  result.warningsCount = warningsCount
  result.stopped = stopped

proc `$`*(self: DiscordImportProgressItem): string =
  result = fmt"""DiscordImportProgressItem(
    communityId: {self.communityId},
    progress: {self.progress},
    errorsCount: {self.errorsCount},
    warningsCount: {self.warningsCount},
    stopped: {self.stopped}
    ]"""

proc getCommunitId*(self: DiscordImportProgressItem): string =
  return self.communityId

proc getProgress*(self: DiscordImportProgressItem): float =
  return self.progress

proc getErrorsCount*(self: DiscordImportProgressItem): int =
  return self.errorsCount

proc getWarningsCount*(self: DiscordImportProgressItem): int =
  return self.warningsCount

proc getStopped*(self: DiscordImportProgressItem): bool =
  return self.stopped
