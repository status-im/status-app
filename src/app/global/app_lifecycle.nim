import std/atomics

var shuttingDown: Atomic[bool]

proc markShuttingDown*() =
  shuttingDown.store(true)

proc isShuttingDown*(): bool =
  shuttingDown.load()
