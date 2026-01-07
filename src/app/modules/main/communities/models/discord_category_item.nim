import std/strformat

type
  DiscordCategoryItem* = object
    id*: string
    name*: string
    selected*: bool

proc initDiscordCategoryItem*(
  id: string,
  name: string,
  selected: bool
): DiscordCategoryItem =
  result.id = id
  result.name = name
  result.selected = selected

proc `$`*(self: DiscordCategoryItem): string =
  result = fmt"""DiscordCategoryItem(
    id: {self.id},
    name: {self.name},
    ]"""

proc getId*(self: DiscordCategoryItem): string =
  return self.id

proc getName*(self: DiscordCategoryItem): string =
  return self.name

proc getSelected*(self: DiscordCategoryItem): bool =
  return self.selected
