import json

include ../../../common/json_utils

type ThreadDto* = object
  threadId*: string
  chatId*: string
  parentMessageId*: string
  name*: string
  unviewedMessagesCount*: int
  unviewedMentionsCount*: int

proc toThreadDto*(jsonObj: JsonNode): ThreadDto =
  result = ThreadDto()
  discard jsonObj.getProp("threadId", result.threadId)
  discard jsonObj.getProp("chatId", result.chatId)
  discard jsonObj.getProp("parentMessageId", result.parentMessageId)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("unviewedMessagesCount", result.unviewedMessagesCount)
  discard jsonObj.getProp("unviewedMentionsCount", result.unviewedMentionsCount)
