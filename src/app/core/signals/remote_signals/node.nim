import json

import base

import ../../../../app_service/service/accounts/dto/[accounts]
import ../../../../app_service/service/settings/dto/[settings]

type NodeSignal* = ref object of Signal
  seq*: uint64 # the login sequence number of the login it reports
  error*: string
  account*: AccountDto
  settings*: SettingsDto

proc fromEvent*(T: type NodeSignal, signalType: SignalType, event: JsonNode): NodeSignal =
  result = NodeSignal()
  result.signalType = signalType

  if not event.contains("event") or event["event"].kind == JNull:
    return

  let e = event["event"]

  result.seq = e{"seq"}.getBiggestInt.uint64

  if e.contains("error"):
    result.error = e["error"].getStr

  if e.contains("account") and e["account"].kind != JNull:
    result.account = e["account"].toAccountDto()

  if e.contains("settings") and e["settings"].kind != JNull:
    result.settings = e["settings"].toSettingsDto()