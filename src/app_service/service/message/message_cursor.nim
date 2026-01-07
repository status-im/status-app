import std/strformat

type
  CursorValue* = string
  MessageCursor* = ref object
    value: CursorValue
    pending: bool
    mostRecent: bool

proc initMessageCursor*(value: CursorValue, pending: bool,
    mostRecent: bool): MessageCursor =
  MessageCursor(value: value, pending: pending, mostRecent: mostRecent)

proc getValue*(self: MessageCursor): CursorValue =
  self.value

proc setValue*(self: MessageCursor, value: CursorValue) =
  if value == "" or value == self.value:
    self.mostRecent = true
  else:
    self.value = value

  self.pending = false

proc setPending*(self: MessageCursor) =
  self.pending = true

proc isFetchable*(self: MessageCursor): bool =
  return not (self.pending or self.mostRecent)

proc isPending*(self: MessageCursor): bool =
  return self.pending

proc isMostRecent*(self: MessageCursor): bool =
  return self.mostRecent

proc isEmpty*(self: MessageCursor): bool =
  return self.value == ""

proc makeObsolete*(self: MessageCursor) =
  self.mostRecent = false

proc isLessThan*(self: MessageCursor, value: CursorValue): bool =
  return self.value < value

proc initCursorValue*(id: string, clock: int64): CursorValue =
  return fmt"{clock:064}" & id

proc `$`*(self: MessageCursor): string =
  return fmt"value:{self.value}, pending:{self.pending}, mostRecent:{self.mostRecent}"
