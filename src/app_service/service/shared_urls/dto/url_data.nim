{.used.}

import json, strutils

include ../../../common/json_utils

type CommunityUrlDataDto* = object
  displayName*: string
  description*: string
  membersCount*: int
  color*: string
  tagIndices*: seq[int]
  communityId*: string

type CommunityChannelUrlDataDto* = object
  emoji*: string
  displayName*: string
  description*: string
  color*: string
  uuid*: string

type ContactUrlDataDto* = object
  displayName*: string
  description*: string
  publicKey*: string

type MessageUrlDataDto* = object
  chatId*: string
  messageId*: string
  communityId*: string

type UrlDataDto* = object
  community*: CommunityUrlDataDto
  channel*: CommunityChannelUrlDataDto
  contact*: ContactUrlDataDto
  notASupportedStatusLink*: bool # If this is true, it was not a supported status link, so we should open it in a browser

proc toCommunityUrlDataDto*(jsonObj: JsonNode): CommunityUrlDataDto =
  result = CommunityUrlDataDto()
  discard jsonObj.getProp("displayName", result.displayName)
  discard jsonObj.getProp("description", result.description)
  discard jsonObj.getProp("membersCount", result.membersCount)
  discard jsonObj.getProp("color", result.color)
  var tagIndicesObj: JsonNode
  if (jsonObj.getProp("tagIndices", tagIndicesObj) and tagIndicesObj.kind == JArray):
    for tagIndex in tagIndicesObj:
      result.tagIndices.add(tagIndex.getInt)

  discard jsonObj.getProp("communityId", result.communityId)

proc toCommunityChannelUrlDataDto*(jsonObj: JsonNode): CommunityChannelUrlDataDto =
  result = CommunityChannelUrlDataDto()
  discard jsonObj.getProp("displayName", result.displayName)
  discard jsonObj.getProp("description", result.description)
  discard jsonObj.getProp("emoji", result.emoji)
  discard jsonObj.getProp("color", result.color)
  discard jsonObj.getProp("channelUuid", result.uuid)

proc toContactUrlDataDto*(jsonObj: JsonNode): ContactUrlDataDto =
  result = ContactUrlDataDto()
  discard jsonObj.getProp("displayName", result.displayName)
  discard jsonObj.getProp("description", result.description)
  discard jsonObj.getProp("publicKey", result.publicKey)

proc toMessageUrlDataDto*(jsonObj: JsonNode): MessageUrlDataDto =
  result = MessageUrlDataDto()
  discard jsonObj.getProp("chatId", result.chatId)
  discard jsonObj.getProp("messageId", result.messageId)
  discard jsonObj.getProp("communityId", result.communityId)

proc toUrlDataDto*(jsonObj: JsonNode): UrlDataDto =
  result = UrlDataDto()

  var communityObj: JsonNode
  if (jsonObj.getProp("community", communityObj)):
    result.community = communityObj.toCommunityUrlDataDto()

  var communityChannelObj: JsonNode
  if (jsonObj.getProp("channel", communityChannelObj)):
    result.channel = communityChannelObj.toCommunityChannelUrlDataDto()

  var contactObj: JsonNode
  if (jsonObj.getProp("contact", contactObj)):
    result.contact = contactObj.toContactUrlDataDto()

proc toJsonNode*(communityUrlDataDto: CommunityUrlDataDto): JsonNode =
  var jsonObj = newJObject()
  jsonObj["displayName"] = %* communityUrlDataDto.displayName
  jsonObj["description"] = %* communityUrlDataDto.description
  jsonObj["membersCount"] = %* communityUrlDataDto.membersCount
  jsonObj["color"] = %* communityUrlDataDto.color
  jsonObj["communityId"] = %* communityUrlDataDto.communityId
  return jsonObj

proc `$`*(communityUrlDataDto: CommunityUrlDataDto): string =
  return $(communityUrlDataDto.toJsonNode())

proc `$`*(communityChannelUrlDataDto: CommunityChannelUrlDataDto): string =
  var jsonObj = newJObject()
  jsonObj["displayName"] = %* communityChannelUrlDataDto.displayName
  jsonObj["description"] = %* communityChannelUrlDataDto.description
  jsonObj["emoji"] = %* communityChannelUrlDataDto.emoji
  jsonObj["color"] = %* communityChannelUrlDataDto.color
  jsonObj["uuid"] = %* communityChannelUrlDataDto.uuid
  return $jsonObj

proc `$`*(contactUrlDataDto: ContactUrlDataDto): string =
  var jsonObj = newJObject()
  jsonObj["displayName"] = %* contactUrlDataDto.displayName
  jsonObj["description"] = %* contactUrlDataDto.description
  jsonObj["publicKey"] = %* contactUrlDataDto.publicKey
  return $jsonObj

proc `$`*(messageUrlDataDto: MessageUrlDataDto): string =
  var jsonObj = newJObject()
  jsonObj["chatId"] = %* messageUrlDataDto.chatId
  jsonObj["messageId"] = %* messageUrlDataDto.messageId
  jsonObj["communityId"] = %* messageUrlDataDto.communityId
  return $jsonObj
