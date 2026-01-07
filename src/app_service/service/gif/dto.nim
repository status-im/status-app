import json, std/strformat

type
  GifDto* = object
    id*: string
    title*: string
    url*: string
    tinyUrl*: string
    height*: int
    isFavorite*: bool

proc tenorToGifDto*(jsonMsg: JsonNode): GifDto =
  return GifDto(
    id: jsonMsg{"id"}.getStr,
    title: jsonMsg{"title"}.getStr,
    url: jsonMsg{"media"}[0]["gif"]["url"].getStr,
    tinyUrl: jsonMsg{"media"}[0]["tinygif"]["url"].getStr,
    height: jsonMsg{"media"}[0]["gif"]["dims"][1].getInt
  )

proc settingToGifDto*(jsonMsg: JsonNode): GifDto =
  return GifDto(
    id: jsonMsg{"id"}.getStr,
    title: jsonMsg{"title"}.getStr,
    url: jsonMsg{"url"}.getStr,
    tinyUrl: jsonMsg{"tinyUrl"}.getStr,
    height: jsonMsg{"height"}.getInt
  )

proc toJsonNode*(self: GifDto): JsonNode =
  result = %* {
    "id": self.id,
    "title": self.title,
    "url": self.url,
    "tinyUrl": self.tinyUrl,
    "height": self.height
  }

proc `$`*(self: GifDto): string =
  return fmt"GifDto(id:{self.id}, title:{self.title}, url:{self.url}, tinyUrl:{self.tinyUrl}, height:{self.height})"
