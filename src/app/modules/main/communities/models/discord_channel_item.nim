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

proc id*(self: DiscordChannelItem): string =
  return self.id

proc `id=`*(self: var DiscordChannelItem, value: string) =
  self.id = value

proc getCategoryId*(self: DiscordChannelItem): string =
  return self.categoryId

proc categoryId*(self: DiscordChannelItem): string =
  return self.categoryId

proc `categoryId=`*(self: var DiscordChannelItem, value: string) =
  self.categoryId = value

proc getName*(self: DiscordChannelItem): string =
  return self.name

proc name*(self: DiscordChannelItem): string =
  return self.name

proc `name=`*(self: var DiscordChannelItem, value: string) =
  self.name = value

proc getDescription*(self: DiscordChannelItem): string =
  return self.description

proc description*(self: DiscordChannelItem): string =
  return self.description

proc `description=`*(self: var DiscordChannelItem, value: string) =
  self.description = value

proc getFilePath*(self: DiscordChannelItem): string =
  return self.filePath

proc filePath*(self: DiscordChannelItem): string =
  return self.filePath

proc `filePath=`*(self: var DiscordChannelItem, value: string) =
  self.filePath = value

proc getSelected*(self: DiscordChannelItem): bool =
  return self.selected

proc selected*(self: DiscordChannelItem): bool =
  return self.selected

proc `selected=`*(self: var DiscordChannelItem, value: bool) =
  self.selected = value

