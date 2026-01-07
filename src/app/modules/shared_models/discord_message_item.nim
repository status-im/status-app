import Nimqml, json, std/strformat

import ../../../app_service/service/message/dto/message

QtObject:
  type
    DiscordMessageItem* = ref object of QObject
      id: string
      timestamp: string
      timestampEdited: string
      content: string
      author: DiscordMessageAuthor

  proc setup(self: DiscordMessageItem)
  proc delete*(self: DiscordMessageItem)
  proc newDiscordMessageItem*(
      id: string,
      timestamp: string,
      timestampEdited: string,
      content: string,
      author: DiscordMessageAuthor
      ): DiscordMessageItem =
    new(result, delete)
    result.setup
    result.id = id
    result.timestamp = timestamp
    result.timestampEdited = timestampEdited
    result.content = content
    result.author = author

  proc `$`*(self: DiscordMessageItem): string =
    result = fmt"""DiscordMessageItem(
      id: {$self.id},
      timestamp: {$self.timestamp},
      timestampEdited: {$self.timestampEdited},
      content: {$self.content},
      )"""

  proc id*(self: DiscordMessageItem): string {.inline.} =
    self.id

  QtProperty[string] id:
    read = id

  proc timestamp*(self: DiscordMessageItem): string {.inline.} =
    self.timestamp

  QtProperty[string] timestamp:
    read = timestamp

  proc timestampEdited*(self: DiscordMessageItem): string {.inline.} =
    self.timestampEdited

  QtProperty[string] timestampEdited:
    read = timestampEdited

  proc content*(self: DiscordMessageItem): string {.inline.} =
    self.content

  QtProperty[string] content:
    read = content

  proc author*(self: DiscordMessageItem): DiscordMessageAuthor {.inline.} =
    self.author

  proc setup(self: DiscordMessageItem) =
    self.QObject.setup

  proc delete*(self: DiscordMessageItem) =
    self.QObject.delete

