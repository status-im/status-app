import json

import base
import signal_type

type MessagesSentSignal* = ref object of Signal
  messageIds*: seq[string]

proc fromEvent*(T: type MessagesSentSignal, jsonSignal: JsonNode): MessagesSentSignal =
  result = MessagesSentSignal()
  result.signalType = SignalType.MessagesSent
  if jsonSignal["event"].kind != JNull and jsonSignal["event"].hasKey("ids") and jsonSignal["event"]["ids"].kind != JNull:
    for messageId in jsonSignal["event"]["ids"]:
      result.messageIds.add(messageId.getStr)
