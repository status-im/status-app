import json, std/strformat
import base_item

export base_item

type
  SubItem* = ref object of BaseItem
    isUserIcon: bool
    isImage: bool
    colorId: int
    position: int
    lastMessageTimestamp: int

proc initSubItem*(
    value,
    text,
    image,
    icon,
    iconColor: string,
    isUserIcon: bool,
    isImage: bool,
    position: int,
    lastMessageTimestamp: int,
    colorId: int = 0,
  ): SubItem =
  result = SubItem()
  result.setup(value, text, image, icon, iconColor)
  result.isUserIcon = isUserIcon
  result.isImage = isImage
  result.position = position
  result.lastMessageTimestamp = lastMessageTimestamp
  result.colorId = colorId

proc `$`*(self: SubItem): string =
  result = fmt"""SearchMenuSubItem(
    value: {self.value},
    text: {self.text},
    position: {self.position},
    lastMessageTimestamp: {self.lastMessageTimestamp},
    isUserIcon: {self.isUserIcon},
    isImage: {self.isImage},
    imageSource: {self.image},
    iconName: {self.icon},
    iconColor: {self.iconColor},
    ]"""

proc toJsonNode*(self: SubItem): JsonNode =
  result = %* {
    "value": self.value,
    "text": self.text,
    "position": self.position,
    "lastMessageTimestamp": self.lastMessageTimestamp,
    "imageSource": self.image,
    "iconName": self.icon,
    "iconColor": self.iconColor,
    "isUserIcon": self.isUserIcon,
    "isImage": self.isImage,
    "colorId": self.colorId,
  }

proc position*(self: SubItem): int =
  return self.position

proc lastMessageTimestamp*(self: SubItem): int =
  return self.lastMessageTimestamp

proc isUserIcon*(self: SubItem): bool =
  return self.isUserIcon

proc isImage*(self: SubItem): bool =
  return self.isImage

proc colorId*(self: SubItem): int =
  return self.colorId
