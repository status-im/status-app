import json, times

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
    archived*: bool
    muteRevision*: int64
    muted*: bool
    muteTill*: int64
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
  discard jsonObj.getProp("archived", result.archived)
  discard jsonObj.getProp("muteRevision", result.muteRevision)
  discard jsonObj.getProp("muted", result.muted)
  let muteTill = jsonObj{"muteTill"}.getStr()
  if muteTill.len > 0 and muteTill != "0001-01-01T00:00:00Z":
    result.muteTill = parse(muteTill, "yyyy-MM-dd'T'HH:mm:sszzz").toTime().toUnix() * 1000
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
