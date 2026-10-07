import json

include ../../../common/json_utils

type
  ThreadLastMessageDto* = object
    `from`*: string
    text*: string
    timestamp*: int64

  ThreadDto* = object
    threadId*: string
    chatId*: string
    parentMessageId*: string
    name*: string
    creatorId*: string
    unviewedMessagesCount*: int
    unviewedMentionsCount*: int
    messagesCount*: int
    participantsCount*: int
    participantsPreviewIds*: seq[string]
    lastMessage*: ThreadLastMessageDto

proc toThreadDto*(jsonObj: JsonNode): ThreadDto =
  result = ThreadDto()
  discard jsonObj.getProp("threadId", result.threadId)
  discard jsonObj.getProp("chatId", result.chatId)
  discard jsonObj.getProp("parentMessageId", result.parentMessageId)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("creatorId", result.creatorId)
  discard jsonObj.getProp("unviewedMessagesCount", result.unviewedMessagesCount)
  discard jsonObj.getProp("unviewedMentionsCount", result.unviewedMentionsCount)
  discard jsonObj.getProp("messagesCount", result.messagesCount)
  discard jsonObj.getProp("participantsCount", result.participantsCount)
  var participantsPreviewIds: JsonNode
  if jsonObj.getProp("participantsPreviewIds", participantsPreviewIds) and participantsPreviewIds.kind == JArray:
    for participantId in participantsPreviewIds:
      result.participantsPreviewIds.add(participantId.getStr())
  if result.participantsCount == 0:
    result.participantsCount = result.participantsPreviewIds.len
  var lastMessage: JsonNode
  if jsonObj.getProp("lastMessage", lastMessage) and lastMessage.kind == JObject:
    discard lastMessage.getProp("from", result.lastMessage.`from`)
    discard lastMessage.getProp("text", result.lastMessage.text)
    discard lastMessage.getProp("timestamp", result.lastMessage.timestamp)
