import json, options

import base

import ../../../../app_service/service/accounts/dto/[accounts]
import ../../../../app_service/service/settings/dto/[settings]

type NodeSignal* = ref object of Signal
  seq*: Option[uint64] # the login seq of the login it reports, none from an older status-go
  error*: string
  account*: AccountDto
  settings*: SettingsDto

proc fromEvent*(T: type NodeSignal, signalType: SignalType, event: JsonNode): NodeSignal =
  result = NodeSignal()
  result.signalType = signalType

  if not event.contains("event") or event["event"].kind == JNull:
    return

  let e = event["event"]

  result.seq = toLoginSeq(e)

  if e.contains("error"):
    result.error = e["error"].getStr

  if e.contains("account") and e["account"].kind != JNull:
    result.account = e["account"].toAccountDto()

  if e.contains("settings") and e["settings"].kind != JNull:
    result.settings = e["settings"].toSettingsDto()