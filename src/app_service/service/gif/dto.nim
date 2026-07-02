import json, std/strformat

type
  GifDto* = object
    id*: string
    title*: string
    url*: string
    tinyUrl*: string
    height*: int
    isFavorite*: bool

proc klipyToGifDto*(jsonMsg: JsonNode): GifDto =
  # We send the `md` gif and show the lightweight `sm` gif for preview
  return GifDto(
    id: $jsonMsg{"id"}.getBiggestInt,
    title: jsonMsg{"title"}.getStr,
    url: jsonMsg{"file"}{"md"}{"gif"}{"url"}.getStr,
    tinyUrl: jsonMsg{"file"}{"sm"}{"gif"}{"url"}.getStr,
    height: jsonMsg{"file"}{"sm"}{"gif"}{"height"}.getInt
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
