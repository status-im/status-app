import std/strformat

type
  DiscordChannelItem* = object
    id*: string
    categoryId*: string
    name*: string
    description*: string
    filePath*: string
    selected*: bool

proc initDiscordChannelItem*(
  id: string,
  categoryId: string,
  name: string,
  description: string,
  filePath: string,
  selected: bool
): DiscordChannelItem =
  result.id = id
  result.categoryId = categoryId
  result.name = name
  result.description = description
  result.filePath = filePath
  result.selected = selected

proc `$`*(self: DiscordChannelItem): string =
  result = fmt"""DiscordChannelItem(
    id: {self.id},
    categoryId: {self.categoryId},
    name: {self.name},
    description: {self.description},
    filePath: {self.filePath},
    selected: {self.selected},
    ]"""

proc getId*(self: DiscordChannelItem): string =
  return self.id

proc getCategoryId*(self: DiscordChannelItem): string =
  return self.categoryId

proc getName*(self: DiscordChannelItem): string =
  return self.name

proc getDescription*(self: DiscordChannelItem): string =
  return self.description

proc getFilePath*(self: DiscordChannelItem): string =
  return self.filePath

proc getSelected*(self: DiscordChannelItem): bool =
  return self.selected

