import json, std/strformat, nimqml, chronicles
include ../../../common/json_utils

QtObject:
  type LinkPreviewThumbnail* = ref object of QObject
    width: int
    height: int
    url: string
    dataUri: string

  proc setup*(self: LinkPreviewThumbnail)
  proc delete*(self: LinkPreviewThumbnail)

  proc update*(self: LinkPreviewThumbnail, width: int, height: int, url: string, dataUri: string)

  proc copy*(self: LinkPreviewThumbnail, other: LinkPreviewThumbnail) =
    if other != nil:
      self.update(other.width, other.height, other.url, other.dataUri)
    else:
      self.update(0, 0, "", "")
    
  proc newLinkPreviewThumbnail*(width: int = 0, height: int = 0, url: string = "", dataUri: string = ""): LinkPreviewThumbnail =
    new(result, delete)
    result.setup()
    result.update(width, height, url, dataUri)

  proc setup*(self: LinkPreviewThumbnail) =
    self.QObject.setup()

  proc delete*(self: LinkPreviewThumbnail) =
    self.QObject.delete()

  proc widthChanged*(self: LinkPreviewThumbnail) {.signal.}
  proc getWidth*(self: LinkPreviewThumbnail): int {.slot.} =
    result = self.width
  QtProperty[int] width:
    read = getWidth
    notify = widthChanged

  proc heightChanged*(self: LinkPreviewThumbnail) {.signal.}
  proc getHeight*(self: LinkPreviewThumbnail): int {.slot.} =
    result = self.height
  QtProperty[int] height:
    read = getHeight
    notify = heightChanged

  proc urlChanged*(self: LinkPreviewThumbnail) {.signal.}
  proc getUrl*(self: LinkPreviewThumbnail): string {.slot.} =
    result = self.url
  QtProperty[string] url:
    read = getUrl
    notify = urlChanged

  proc dataUriChanged*(self: LinkPreviewThumbnail) {.signal.}
  proc getDataUri*(self: LinkPreviewThumbnail): string {.slot.} =
    result = self.dataUri
  QtProperty[string] dataUri:
    read = getDataUri
    notify = dataUriChanged


  proc toLinkPreviewThumbnail*(jsonObj: JsonNode): LinkPreviewThumbnail =
    result = LinkPreviewThumbnail()
    discard jsonObj.getProp("width", result.width)
    discard jsonObj.getProp("height", result.height)
    discard jsonObj.getProp("url", result.url)
    discard jsonObj.getProp("dataUri", result.dataUri)

  proc `$`*(self: LinkPreviewThumbnail): string =
    result = fmt"""LinkPreviewThumbnail(
      width: {self.width},
      height: {self.height},
      urlLength: {self.url.len},
      dataUriLength: {self.dataUri.len}
    )"""

  proc `%`*(self: LinkPreviewThumbnail): JsonNode =
    result = %*{
      "width": self.width,
      "height": self.height,
      "url": self.url,
      "dataUri": self.dataUri
    }

  proc update*(self: LinkPreviewThumbnail, width: int, height: int, url: string, dataUri: string) =
    if self.width != width:
      self.width = width
      self.widthChanged()
    if self.height != height:
      self.height = height
      self.heightChanged()
    if self.url != url:
      self.url = url
      self.urlChanged()
    if self.dataUri != dataUri:
      self.dataUri = dataUri
      self.dataUriChanged()
