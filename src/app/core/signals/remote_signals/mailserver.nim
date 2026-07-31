import json

import base
import signal_type

type HistoryRequestStartedSignal* = ref object of Signal
  numBatches*: int

type HistoryRequestCompletedSignal* = ref object of Signal

type MailserverAvailableSignal* = ref object of Signal
  address*: string

type MailserverNotWorkingSignal* = ref object of Signal

proc fromEvent*(T: type HistoryRequestStartedSignal, jsonSignal: JsonNode): HistoryRequestStartedSignal =
  result = HistoryRequestStartedSignal()
  result.signalType = SignalType.HistoryRequestStarted
  result.numBatches = jsonSIgnal["event"]{"numBatches"}.getInt()

proc fromEvent*(T: type HistoryRequestCompletedSignal, jsonSignal: JsonNode): HistoryRequestCompletedSignal =
  result = HistoryRequestCompletedSignal()
  result.signalType = SignalType.HistoryRequestCompleted

proc fromEvent*(T: type MailserverAvailableSignal, jsonSignal: JsonNode): MailserverAvailableSignal =
  result = MailserverAvailableSignal()
  result.signalType = SignalType.MailserverAvailable
  result.address = jsonSignal["event"]{"address"}.getStr()

proc fromEvent*(T: type MailserverNotWorkingSignal, jsonSignal: JsonNode): MailserverNotWorkingSignal =
  result = MailserverNotWorkingSignal()
  result.signalType = SignalType.MailserverNotWorking
