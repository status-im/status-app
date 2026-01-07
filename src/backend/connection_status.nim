import json, std/strformat, tables

const INVALID_TIMESTAMP* = -1

type
  # Mirrors services/wallet/connection/types.go StateValue
  StateValue* {.pure.} = enum
    Unknown,
    Connected,
    Disconnected

  # Mirrors services/wallet/connection/types.go State
  ConnectionState* = ref object of RootObj
    value*: StateValue
    lastCheckedAt*: int
    lastSuccessAt*: int

  # Mirrors services/wallet/connection/status_notifier.go StatusNotification
  ConnectionStatusNotification* = Table[string, ConnectionState]

# ConnectionState
proc initConnectionState*(value: StateValue, lastCheckedAt: int = INVALID_TIMESTAMP, lastSuccessAt: int = INVALID_TIMESTAMP): ConnectionState =
  result = ConnectionState()
  result.value = value
  result.lastCheckedAt = lastCheckedAt
  result.lastSuccessAt = lastSuccessAt

proc `$`*(self: ConnectionState): string =
  return fmt"""ConnectionState(
    value:{self.value},
    lastCheckedAt:{self.lastCheckedAt},
    lastSuccessAt:{self.lastSuccessAt}
  )"""

proc fromJson*(t: JsonNode, T: typedesc[ConnectionState]): ConnectionState {.inline.} =
  result = ConnectionState()
  result.value = StateValue(t["value"].getInt())
  result.lastCheckedAt = t["last_checked_at"].getInt()
  result.lastSuccessAt = t["last_success_at"].getInt()

# ConnectionStatusNotification
proc initCustomStatusNotification*(): ConnectionStatusNotification =
  result = initTable[string, ConnectionState]()

proc fromJson*(t: JsonNode, T: typedesc[ConnectionStatusNotification]): ConnectionStatusNotification {.inline.} =
  result = initCustomStatusNotification()
  if t.kind != JNull:
    for k, v in t.pairs:
      if v.kind != JNull:
        result[k] = fromJson(v, ConnectionState)
