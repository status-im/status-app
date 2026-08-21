{.used.}

import json

include ../../../common/json_utils

type RemovedMessageDto* = object
  chatId*: string
  messageId*: string
  deletedBy*: string
  clock*: int64

proc toRemovedMessageDto*(jsonObj: JsonNode): RemovedMessageDto =
  result = RemovedMessageDto()
  discard jsonObj.getProp("chatId", result.chatId)
  discard jsonObj.getProp("messageId", result.messageId)
  discard jsonObj.getProp("deletedBy", result.deletedBy)
  discard jsonObj.getProp("clock", result.clock)
