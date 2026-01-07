import json, std/strformat, nimqml
import ./link_preview_thumbnail
include ../../../common/json_utils

type
  LinkType* {.pure.} = enum
    Link = 0
    Image

proc toLinkType*(value: int): LinkType =
  try:
    return LinkType(value)
  except RangeDefect:
    return LinkType.Link


QtObject:
  type StandardLinkPreview* = ref object of QObject
    url*: string # this property is set manually and only used in`toJSON` conversion
    hostname: string
    title: string
    description: string
    linkType: LinkType
    thumbnail: LinkPreviewThumbnail
  
  proc setup*(self: StandardLinkPreview)
  proc delete*(self: StandardLinkPreview)

  proc newStandardLinkPreview*(hostname: string, title: string, description: string, thumbnail: LinkPreviewThumbnail, linkType: LinkType): StandardLinkPreview =
    new(result, delete)
    result.setup()
    result.hostname = hostname
    result.title = title
    result.description = description
    result.linkType = linkType
    result.thumbnail.copy(thumbnail)

  proc setup*(self: StandardLinkPreview) =
    self.QObject.setup
    self.thumbnail = newLinkPreviewThumbnail()

  proc delete*(self: StandardLinkPreview) =
    self.QObject.delete

  proc hostnameChanged*(self: StandardLinkPreview) {.signal.}
  proc getHostname*(self: StandardLinkPreview): string {.slot.} =
    result = self.hostname
  QtProperty[string] hostname:
    read = getHostname
    notify = hostnameChanged

  proc titleChanged*(self: StandardLinkPreview) {.signal.}
  proc getTitle*(self: StandardLinkPreview): string {.slot.} =
    result = self.title
  QtProperty[string] title:
    read = getTitle
    notify = titleChanged

  proc descriptionChanged*(self: StandardLinkPreview) {.signal.}
  proc getDescription*(self: StandardLinkPreview): string {.slot.} =
    result = self.description
  QtProperty[string] description:
    read = getDescription
    notify = descriptionChanged

  proc linkTypeChanged*(self: StandardLinkPreview) {.signal.}
  proc getLinkType*(self: StandardLinkPreview): int {.slot.} =
    result = self.linkType.int
  QtProperty[int] linkType:
    read = getLinkType
    notify = linkTypeChanged

  proc getThumbnail*(self: StandardLinkPreview): LinkPreviewThumbnail =
    result = self.thumbnail

  
  proc toStandardLinkPreview*(jsonObj: JsonNode): StandardLinkPreview =
    var hostname: string
    var title: string
    var description: string
    var linkType: LinkType
    var thumbnail: LinkPreviewThumbnail

    discard jsonObj.getProp("hostname", hostname)
    discard jsonObj.getProp("title", title)
    discard jsonObj.getProp("description", description)
    linkType = toLinkType(jsonObj["type"].getInt)

    var thumbnailJson: JsonNode
    if jsonObj.getProp("thumbnail", thumbnailJson):
      thumbnail = toLinkPreviewThumbnail(thumbnailJson)

    result = newStandardLinkPreview(hostname, title, description, thumbnail, linkType)

  proc `$`*(self: StandardLinkPreview): string =
    result = fmt"""StandardLinkPreview(
      type: {self.linkType},
      hostname: {self.hostname},
      title: {self.title},
      description: {self.description},
      thumbnail: {self.thumbnail}
    )"""

  # Custom JSON converter to force `linkType` integer instead of string
  proc `%`*(self: StandardLinkPreview): JsonNode =
    result = %* {
      "url": self.url,
      "type": self.linkType.int,
      "hostname": self.hostname,
      "title": self.title,
      "description": self.description,
      "thumbnail": %self.thumbnail,
    }  

  proc empty*(self: StandardLinkPreview): bool =
    return self.hostname.len == 0
