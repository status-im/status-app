## Cheap signal-type triage for the signals manager.
##
## status-go delivers every backend event as an envelope string
## `{"type":"<t>","event":{...}}`. A large payload of an unhandled type (e.g. a
## ~222KB local-notifications event) would otherwise be fully JSON-decoded on the
## Qt main thread only to be thrown away once nobody is found to handle the type.
##
## This module extracts the envelope type with a substring scan (no JSON parse)
## and checks it against the known `SignalType` set. Only known types are worth a
## full decode; unknown/unhandled ones are counted and dropped untouched.

import std/strutils
import ./remote_signals/signal_type

const TYPE_TOKEN = "\"type\":\""

# Signal processing runs single-threaded on the Qt main thread, so a plain
# module-level counter is sufficient (no threadvar / lock needed).
var gUnhandledSignalCount = 0

proc extractSignalType*(rawSignal: string): string =
  ## Extract the envelope's top-level `"type"` value by substring scan, without
  ## building a JsonNode. status-go marshals `Type` before `Event` (see
  ## signal.Envelope), so the first occurrence is the envelope's, never a nested
  ## one. Signal type strings are plain identifiers (no JSON escapes). Returns
  ## "" when no type member is present.
  let key = rawSignal.find(TYPE_TOKEN)
  if key < 0:
    return ""
  let start = key + TYPE_TOKEN.len
  let stop = rawSignal.find('"', start)
  if stop < 0:
    return ""
  rawSignal[start ..< stop]

proc isKnownSignalType*(signalType: string): bool =
  ## True when the type string maps to a `SignalType` enum member, i.e. a type
  ## the desktop knows how to decode/dispatch.
  if signalType.len == 0:
    return false
  try:
    discard parseEnum[SignalType](signalType)
    true
  except CatchableError:
    false

proc noteUnhandledSignal*() =
  ## Record that one signal was dropped without decoding (observability +
  ## test seam).
  inc gUnhandledSignalCount

proc unhandledSignalCount*(): int = gUnhandledSignalCount

proc resetUnhandledSignalCount*() = gUnhandledSignalCount = 0
