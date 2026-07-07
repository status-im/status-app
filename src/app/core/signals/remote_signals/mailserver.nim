import json

import base
import signal_type

type MailserverRequestCompletedSignal* = ref object of Signal
  requestID*: string
  lastEnvelopeHash*: string
  cursor*: string
  errorMessage*: string
  error*: bool

type MailserverRequestExpiredSignal* = ref object of Signal
  # TODO

type HistoryRequestStartedSignal* = ref object of Signal
  numBatches*: int

type HistoryRequestCompletedSignal* = ref object of Signal

type MailserverAvailableSignal* = ref object of Signal
  address*: string

type MailserverNotWorkingSignal* = ref object of Signal

proc fromEvent*(T: type MailserverRequestCompletedSignal, jsonSignal: JsonNode): MailserverRequestCompletedSignal =
  result = MailserverRequestCompletedSignal()
  result.signalType = SignalType.MailserverRequestCompleted
  if jsonSignal["event"].kind != JNull:
    result.requestID = jsonSignal["event"]{"requestID"}.getStr()
    result.lastEnvelopeHash = jsonSignal["event"]{"lastEnvelopeHash"}.getStr()
    result.cursor = jsonSignal["event"]{"cursor"}.getStr()
    result.errorMessage = jsonSignal["event"]{"errorMessage"}.getStr()
    result.error = result.errorMessage != ""

proc fromEvent*(T: type MailserverRequestExpiredSignal, jsonSignal: JsonNode): MailserverRequestExpiredSignal =
  # TODO: parse signal
  result = MailserverRequestExpiredSignal()
  result.signalType = SignalType.MailserverRequestExpired

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
