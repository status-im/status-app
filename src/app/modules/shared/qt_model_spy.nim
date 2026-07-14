## Qt Model Spy - Tracks all Qt model signal emissions for testing
## 
## This module provides a spy layer that intercepts Qt model signals
## to verify bulk operations are working correctly.

import sequtils

type
  SignalType* = enum
    BeginInsertRows
    EndInsertRows
    BeginRemoveRows
    EndRemoveRows
    DataChanged
    BeginResetModel
    EndResetModel
    BeginMoveRows
    EndMoveRows
  
  SignalCall* = object
    case kind*: SignalType
    of BeginInsertRows, BeginRemoveRows:
      first*: int
      last*: int
    of DataChanged:
      topLeft*: int
      bottomRight*: int
      roles*: seq[int]
    of BeginMoveRows:
      sourceFirst*: int
      sourceLast*: int
      destChild*: int
    else:
      discard
  
  QtModelSpy* = ref object
    calls*: seq[SignalCall]
    enabled*: bool

var globalSpy*: QtModelSpy = nil

proc newQtModelSpy*(): QtModelSpy =
  ## Creates a new Qt model spy
  result = QtModelSpy(calls: @[], enabled: true)

proc enable*(self: QtModelSpy) =
  self.enabled = true
  globalSpy = self

proc disable*(self: QtModelSpy) =
  self.enabled = false
  if globalSpy == self:
    globalSpy = nil

proc clear*(self: QtModelSpy) =
  self.calls = @[]

proc recordBeginInsertRows*(first, last: int) =
  if globalSpy != nil and globalSpy.enabled:
    globalSpy.calls.add(SignalCall(
      kind: BeginInsertRows,
      first: first,
      last: last
    ))

proc recordEndInsertRows*() =
  if globalSpy != nil and globalSpy.enabled:
    globalSpy.calls.add(SignalCall(kind: EndInsertRows))

proc recordBeginRemoveRows*(first, last: int) =
  if globalSpy != nil and globalSpy.enabled:
    globalSpy.calls.add(SignalCall(
      kind: BeginRemoveRows,
      first: first,
      last: last
    ))

proc recordEndRemoveRows*() =
  if globalSpy != nil and globalSpy.enabled:
    globalSpy.calls.add(SignalCall(kind: EndRemoveRows))

proc recordDataChanged*(topLeft, bottomRight: int, roles: seq[int]) =
  if globalSpy != nil and globalSpy.enabled:
    globalSpy.calls.add(SignalCall(
      kind: DataChanged,
      topLeft: topLeft,
      bottomRight: bottomRight,
      roles: roles
    ))

proc recordBeginResetModel*() =
  if globalSpy != nil and globalSpy.enabled:
    globalSpy.calls.add(SignalCall(kind: BeginResetModel))

proc recordEndResetModel*() =
  if globalSpy != nil and globalSpy.enabled:
    globalSpy.calls.add(SignalCall(kind: EndResetModel))

proc recordBeginMoveRows*(sourceFirst, sourceLast, destChild: int) =
  if globalSpy != nil and globalSpy.enabled:
    globalSpy.calls.add(SignalCall(
      kind: BeginMoveRows,
      sourceFirst: sourceFirst,
      sourceLast: sourceLast,
      destChild: destChild
    ))

proc recordEndMoveRows*() =
  if globalSpy != nil and globalSpy.enabled:
    globalSpy.calls.add(SignalCall(kind: EndMoveRows))

# Query helpers
proc countInserts*(self: QtModelSpy): int =
  ## Count number of beginInsertRows calls
  self.calls.filterIt(it.kind == BeginInsertRows).len

proc countRemoves*(self: QtModelSpy): int =
  ## Count number of beginRemoveRows calls
  self.calls.filterIt(it.kind == BeginRemoveRows).len

proc countDataChanged*(self: QtModelSpy): int =
  ## Count number of dataChanged calls
  self.calls.filterIt(it.kind == DataChanged).len

proc countResets*(self: QtModelSpy): int =
  ## Count number of beginResetModel calls
  self.calls.filterIt(it.kind == BeginResetModel).len

proc getInserts*(self: QtModelSpy): seq[SignalCall] =
  ## Get all beginInsertRows calls
  self.calls.filterIt(it.kind == BeginInsertRows)

proc getRemoves*(self: QtModelSpy): seq[SignalCall] =
  ## Get all beginRemoveRows calls
  self.calls.filterIt(it.kind == BeginRemoveRows)

proc getDataChanged*(self: QtModelSpy): seq[SignalCall] =
  ## Get all dataChanged calls
  self.calls.filterIt(it.kind == DataChanged)

proc `$`*(self: SignalCall): string =
  case self.kind
  of BeginInsertRows:
    result = "beginInsertRows(" & $self.first & ", " & $self.last & ")"
  of EndInsertRows:
    result = "endInsertRows()"
  of BeginRemoveRows:
    result = "beginRemoveRows(" & $self.first & ", " & $self.last & ")"
  of EndRemoveRows:
    result = "endRemoveRows()"
  of DataChanged:
    result = "dataChanged(" & $self.topLeft & ", " & $self.bottomRight & ", " & $self.roles & ")"
  of BeginResetModel:
    result = "beginResetModel()"
  of EndResetModel:
    result = "endResetModel()"
  of BeginMoveRows:
    result = "beginMoveRows(" & $self.sourceFirst & ", " & $self.sourceLast & ", " & $self.destChild & ")"
  of EndMoveRows:
    result = "endMoveRows()"

proc `$`*(self: QtModelSpy): string =
  result = "QtModelSpy(" & $self.calls.len & " calls):\n"
  for call in self.calls:
    result &= "  " & $call & "\n"

