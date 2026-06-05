import # vendor libs
  nimqml, json_serialization

import # status-desktop libs
  ./common,
  app/global/app_lifecycle

type
  QObjectTaskArg* = ref object of TaskArg
    vptr*: uint
    slot*: string

proc finish*[T](arg: QObjectTaskArg, payload: T) =
  if isShuttingDown(): return
  signal_handler(cast[pointer](arg.vptr), cstring(Json.encode(payload)), cstring(arg.slot))

proc finish*(arg: QObjectTaskArg, payload: string) =
  if isShuttingDown(): return
  signal_handler(cast[pointer](arg.vptr), cstring(payload), cstring(arg.slot))
