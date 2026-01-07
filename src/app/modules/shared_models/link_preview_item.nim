import std/strformat
import ../../../app_service/service/message/dto/link_preview

type
  Item* = ref object
    unfurled*: bool
    immutable*: bool
    isLocalData*: bool
    loadingLocalData*: bool
    linkPreview*: LinkPreview

proc linkPreview*(self: Item): LinkPreview {.inline.} =
  return self.linkPreview

proc `linkPreview=`*(self: Item, linkPreview: LinkPreview) {.inline.} =
  self.linkPreview = linkPreview

proc `$`*(self: Item): string =
  result = fmt"""LinkPreviewItem(
    unfurled: {self.unfurled},
    immutable: {self.immutable},
    linkPreview: {self.linkPreview},
  )"""

proc markAsImmutable*(self: Item) =
  self.linkPreview = initLinkPreview(self.linkPreview.url)
  self.unfurled = false
  self.immutable = true
