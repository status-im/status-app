import std/strformat

type
  Item* = object
    name: string
    url: string
    imageUrl: string

proc initItem*(name, url, imageUrl: string): Item =
  result.name = name
  result.url = url
  result.imageUrl = imageUrl

proc `$`*(self: Item): string =
  result = fmt"""BrowserItem(
    name: {self.name},
    url: {self.url},
    imageUrl: {self.imageUrl}
    ]"""

proc name*(self: Item): string =
  return self.name

proc `name=`*(self: var Item, value: string) =
  self.name = value

proc url*(self: Item): string =
  return self.url

proc `url=`*(self: var Item, value: string) =
  self.url = value

proc imageUrl*(self: Item): string =
  return self.imageUrl

proc `imageUrl=`*(self: var Item, value: string) =
  self.imageUrl = value
