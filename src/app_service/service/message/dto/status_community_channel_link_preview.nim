import json, std/strformat, nimqml, chronicles
import link_preview_thumbnail
import status_community_link_preview

include ../../../common/json_utils

QtObject:
  type StatusCommunityChannelLinkPreview* = ref object of QObject
    channelUuid*: string
    emoji*: string
    displayName*: string
    description*: string
    color*: string
    community*: StatusCommunityLinkPreview
  
  proc setup*(self: StatusCommunityChannelLinkPreview)
  proc delete*(self: StatusCommunityChannelLinkPreview)
  proc toStatusCommunityChannelLinkPreview*(jsonObj: JsonNode): StatusCommunityChannelLinkPreview =
    new(result, delete)
    result.setup()

    discard jsonObj.getProp("channelUuid", result.channelUuid)
    discard jsonObj.getProp("emoji", result.emoji)
    discard jsonObj.getProp("displayName", result.displayName)
    discard jsonObj.getProp("description", result.description)
    discard jsonObj.getProp("color", result.color)
  
    var communityJsonNode: JsonNode
    if jsonObj.getProp("community", communityJsonNode):
      result.community = toStatusCommunityLinkPreview(communityJsonNode)


  proc channelUuidChanged*(self: StatusCommunityChannelLinkPreview) {.signal.}
  proc getChannelUuid*(self: StatusCommunityChannelLinkPreview): string {.slot.} =
    return self.channelUuid
  QtProperty[string] channelUuid:
    read = getChannelUuid
    notify = channelUuidChanged

  proc emojiChanged*(self: StatusCommunityChannelLinkPreview) {.signal.}
  proc getEmoji*(self: StatusCommunityChannelLinkPreview): string {.slot.} =
    return self.emoji
  QtProperty[string] emoji:
    read = getEmoji
    notify = emojiChanged

  proc displayNameChanged*(self: StatusCommunityChannelLinkPreview) {.signal.}
  proc getDisplayName*(self: StatusCommunityChannelLinkPreview): string {.slot.} =
    return self.displayName
  QtProperty[string] displayName:
    read = getDisplayName
    notify = displayNameChanged

  proc descriptionChanged*(self: StatusCommunityChannelLinkPreview) {.signal.}
  proc getDescription*(self: StatusCommunityChannelLinkPreview): string {.slot.} =
    return self.description
  QtProperty[string] description:
    read = getDescription
    notify = descriptionChanged

  proc colorChanged*(self: StatusCommunityChannelLinkPreview) {.signal.}
  proc getColor*(self: StatusCommunityChannelLinkPreview): string {.slot.} =
    return self.color
  QtProperty[string] color:
    read = getColor
    notify = colorChanged

  proc getCommunity*(self: StatusCommunityChannelLinkPreview): StatusCommunityLinkPreview =
    return self.community

  
  proc setup*(self: StatusCommunityChannelLinkPreview) =
    self.QObject.setup()

  proc delete*(self: StatusCommunityChannelLinkPreview) =
    self.QObject.delete()
  
  proc `$`*(self: StatusCommunityChannelLinkPreview): string =
    return fmt"""StatusCommunityChannelLinkPreview(
      channelUuid: {self.channelUuid},
      emoji: {self.emoji},
      displayName: {self.displayName},
      description: {self.description},
      color: {self.color},
      community: {self.community}
    )"""

  proc `%`*(self: StatusCommunityChannelLinkPreview): JsonNode =
    return %* {
      "channelUuid": self.channelUuid,
      "emoji": self.emoji,
      "displayName": self.displayName,
      "description": self.description,
      "color": self.color,
      "community": self.community
    }

  proc empty*(self: StatusCommunityChannelLinkPreview): bool =
    return self.channelUUID.len == 0
