import std/strformat

type Item* = object
  itemId: string
  content: string
  time: string
  titleId: string
  title: string
  sectionName: string
  image: string
  color: string
  badgePrimaryText: string
  badgeSecondaryText: string
  badgeImage: string
  badgeIconColor: string
  badgeIsLetterIdenticon: bool
  isUserIcon: bool
  colorId: int

proc initItem*(itemId, content, time, titleId, title, sectionName: string, image, color,
  badgePrimaryText, badgeSecondaryText, badgeImage, badgeIconColor: string, badgeIsLetterIdenticon: bool, 
  isUserIcon: bool = false, colorId: int = 0):
  Item =

  result.itemId = itemId
  result.content = content
  result.time = time
  result.titleId = titleId
  result.title = title
  result.sectionName = sectionName
  result.image = image
  result.color = color
  result.badgePrimaryText = badgePrimaryText
  result.badgeSecondaryText = badgeSecondaryText
  result.badgeImage = badgeImage
  result.badgeIconColor = badgeIconColor
  result.badgeIsLetterIdenticon = badgeIsLetterIdenticon
  result.isUserIcon = isUserIcon
  result.colorId = colorId

proc `$`*(self: Item): string =
  result = "SearchResultItem("
  result &= fmt"itemId:{self.itemId}, "
  result &= fmt"content:{self.content}, "
  result &= fmt"time:{self.time}, "
  result &= fmt"titleId:{self.titleId}, "
  result &= fmt"title:{self.title}"
  result &= fmt"sectionName:{self.sectionName}"
  result &= fmt"image:{self.image}"
  result &= fmt"color:{self.color}"
  result &= fmt"badgePrimaryText:{self.badgePrimaryText}"
  result &= fmt"badgeSecondaryText:{self.badgeSecondaryText}"
  result &= fmt"badgeImage:{self.badgeImage}"
  result &= fmt"badgeIconColor:{self.badgeIconColor}"
  result &= fmt"badgeIsLetterIdenticon:{self.badgeIsLetterIdenticon}"
  result &= ")"

proc itemId*(self: Item): string =
  return self.itemId

proc content*(self: Item): string =
  return self.content

proc time*(self: Item): string =
  return self.time

proc titleId*(self: Item): string =
  return self.titleId

proc title*(self: Item): string =
  return self.title

proc sectionName*(self: Item): string =
  return self.sectionName

proc image*(self: Item): string =
  return self.image

proc color*(self: Item): string =
  return self.color

proc badgePrimaryText*(self: Item): string =
  return self.badgePrimaryText

proc badgeSecondaryText*(self: Item): string =
  return self.badgeSecondaryText

proc badgeImage*(self: Item): string =
  return self.badgeImage

proc badgeIconColor*(self: Item): string =
  return self.badgeIconColor

proc badgeIsLetterIdenticon*(self: Item): bool =
  return self.badgeIsLetterIdenticon

proc isUserIcon*(self: Item): bool =
  return self.isUserIcon

proc colorId*(self: Item): int =
  return self.colorId
