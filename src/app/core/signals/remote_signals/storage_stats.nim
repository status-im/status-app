import json

import base
import signal_type

type StorageStatsProgressSignal* = ref object of Signal
  ## Emitted once per collection step; `total` is known before the first one.
  requestId*: string
  step*: int
  total*: int

type StorageStatsResultSignal* = ref object of Signal
  ## Emitted once per collection; `data` is the profile.
  requestId*: string
  error*: string
  data*: JsonNode

proc fromEvent*(T: type StorageStatsProgressSignal, jsonSignal: JsonNode): StorageStatsProgressSignal =
  result = StorageStatsProgressSignal()
  result.signalType = SignalType.StorageStatsProgress
  if jsonSignal["event"].kind != JNull:
    let event = jsonSignal["event"]
    result.requestId = event{"requestId"}.getStr()
    result.step = event{"step"}.getInt()
    result.total = event{"total"}.getInt()

proc fromEvent*(T: type StorageStatsResultSignal, jsonSignal: JsonNode): StorageStatsResultSignal =
  result = StorageStatsResultSignal()
  result.signalType = SignalType.StorageStatsResult
  result.data = newJNull()
  if jsonSignal["event"].kind != JNull:
    let event = jsonSignal["event"]
    result.requestId = event{"requestId"}.getStr()
    result.error = event{"error"}.getStr()
    if event.hasKey("data"):
      result.data = event["data"]
