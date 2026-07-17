## Unit tests for the typed task-completion handoff registry
## (app/core/tasks/typed_handoff). Pure — no Qt.
##
## Proves the ownership contract of the registry seam: a producer parks an
## object graph and a consumer claims it exactly once, with no leak or
## double-free under ORC/refc, and a shutdown drain destroys anything still in
## flight. Delivery *ordering* (a Qt queued-connection property) is proven
## separately in the end-to-end bridge test.

import unittest
import std/atomics

import app/core/tasks/typed_handoff

# Destructor-instrumented pilot payload. `liveCount` is the independent source of
# truth for leak / double-free detection: every construction bumps it, every
# destruction drops it; a clean run ends at exactly zero.
var liveCount: Atomic[int]

type
  PilotPayloadObj = object of RootObj
    value: int
  PilotPayload = ref PilotPayloadObj

proc `=destroy`(o: var PilotPayloadObj) =
  liveCount.atomicDec

proc newPilot(value: int): PilotPayload =
  result = PilotPayload(value: value)
  liveCount.atomicInc

# Leak / double-free is proven by the destructor count reaching zero — but only
# under ORC, the app's actual mm, where destruction is deterministic at scope
# exit. Under refc (the test-runner default) destruction is deferred to GC cycles
# and not deterministic, so the count assertions are ORC-gated. The soak loops
# still *run* under both modes: a double-free would crash the process regardless,
# so refc still exercises the claim/drain paths for corruption.
template checkNoLeak(body: untyped) =
  when compileOption("mm", "orc"):
    body

suite "typed_handoff registry":

  setup:
    drainHandoffs()          # isolate tests from any prior parked entries
    liveCount.store(0)

  test "park then claim returns the same object graph":
    let h = parkHandoff(newPilot(42))
    check pendingHandoffs() == 1
    let got = claimHandoff[PilotPayload](h)
    check got != nil
    check got.value == 42
    check pendingHandoffs() == 0

  test "claim removes the entry; a second claim yields nil":
    let h = parkHandoff(newPilot(7))
    discard claimHandoff[PilotPayload](h)
    check claimHandoff[PilotPayload](h) == nil

  test "claim of an unknown handle yields nil":
    check claimHandoff[PilotPayload](999999.TaskHandle) == nil

  test "claim as the wrong type yields nil (never raises)":
    # Same never-raises contract as an unknown handle: a mismatched claim on the
    # GUI thread must degrade to nil, not an ObjectConversionDefect. The parked
    # object is popped and destroyed either way.
    type UnrelatedPayload = ref object of RootObj
    let h = parkHandoff(newPilot(3))
    let got = claimHandoff[UnrelatedPayload](h)
    check got.isNil
    check pendingHandoffs() == 0

  test "many outstanding handoffs never cross-talk (claimed in reverse)":
    var handles: seq[TaskHandle]
    for i in 0 ..< 1000:
      handles.add parkHandoff(newPilot(i))
    check pendingHandoffs() == 1000
    for i in countdown(999, 0):
      let got = claimHandoff[PilotPayload](handles[i])
      check got.value == i
    check pendingHandoffs() == 0

  test "drain destroys every in-flight handoff (shutdown-in-flight)":
    for i in 0 ..< 50:
      discard parkHandoff(newPilot(i))
    check pendingHandoffs() == 50
    check liveCount.load == 50
    drainHandoffs()
    check pendingHandoffs() == 0
    checkNoLeak: check liveCount.load == 0    # all destroyed, none leaked

  test "soak: no leak or double-free across many park/claim cycles":
    for i in 0 ..< 20000:
      let h = parkHandoff(newPilot(i))
      let got = claimHandoff[PilotPayload](h)
      doAssert got.value == i
    check pendingHandoffs() == 0
    checkNoLeak: check liveCount.load == 0    # every object destroyed exactly once

  test "soak mixed: claimed and drained paths both balance":
    for round in 0 ..< 1000:
      let a = parkHandoff(newPilot(1))
      discard parkHandoff(newPilot(2))     # left in flight
      discard claimHandoff[PilotPayload](a)
      drainHandoffs()                       # sweeps the un-claimed one
    check pendingHandoffs() == 0
    checkNoLeak: check liveCount.load == 0
