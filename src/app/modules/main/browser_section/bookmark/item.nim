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

proc getName*(self: Item): string =
  return self.name

proc getUrl*(self: Item): string =
  return self.url

proc getImageUrl*(self: Item): string =
  return self.imageUrl
