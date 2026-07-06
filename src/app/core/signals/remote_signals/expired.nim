import json

import base
import signal_type

type MessagesExpiredSignal* = ref object of Signal
  messageIds*: seq[string]

proc fromEvent*(T: type MessagesExpiredSignal, jsonSignal: JsonNode): MessagesExpiredSignal =
  result = MessagesExpiredSignal()
  result.signalType = SignalType.MessagesExpired
  if jsonSignal["event"].kind != JNull and jsonSignal["event"].hasKey("ids") and jsonSignal["event"]["ids"].kind != JNull:
    for messageId in jsonSignal["event"]["ids"]:
      result.messageIds.add(messageId.getStr)
