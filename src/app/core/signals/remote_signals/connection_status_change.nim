import json
import base
import signal_type

type ConnectionStatusChangeSignal* = ref object of Signal
  isOnline*: bool

proc fromEvent*(T: type ConnectionStatusChangeSignal, jsonSignal: JsonNode): ConnectionStatusChangeSignal =
  result = ConnectionStatusChangeSignal()
  result.signalType = SignalType.ConnectionStatusChange
  if jsonSignal["event"].kind != JNull:
    result.isOnline = jsonSignal["event"]["isOnline"].getBool()