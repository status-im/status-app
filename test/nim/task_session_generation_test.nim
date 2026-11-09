## Task completions after the session that submitted them ended (in-process logout)
## must not reach their receivers, both when the worker finishes after the session
## ended and when the completion was already queued to the GUI thread before that.
## Runs over the real StatusQ queued-invoke bridge.

import unittest, os
import nimqml
import app/core/tasks/qt
import app/core/signal_handler
import app/global/app_lifecycle
# Selective import: pulling all of gen_qcoreapplication would re-export the seaqt
# QObject and make the nimqml QtObject macro below ambiguous.
from seaqt/qcoreapplication import QCoreApplication, create, processEvents

type
  AsyncGenerationTaskArg = ref object of QObjectTaskArg

QtObject:
  type Receiver = ref object of QObject
    got: seq[string]

  proc delete(self: Receiver)

  proc newReceiver(): Receiver =
    new(result, delete)
    result.QObject.setup

  proc delete(self: Receiver) =
    self.QObject.delete

  proc onDone*(self: Receiver, response: string) {.slot.} =
    self.got.add response

discard QCoreApplication.create()

proc taskArg(r: Receiver): AsyncGenerationTaskArg =
  # ThreadPool.start stamps this; the tests stamp it directly.
  AsyncGenerationTaskArg(vptr: cast[uint](r.vptr), slot: "onDone",
    sessionGeneration: currentSessionGeneration())

proc pump() =
  for _ in 0 ..< 50:
    QCoreApplication.processEvents()
    sleep(1)

suite "task completions across session generations":

  setup:
    discard advanceSessionGeneration()

  test "completion of the current session is delivered":
    let r = newReceiver()
    r.taskArg().finish("current")
    pump()
    check r.got == @["current"]

  test "completion finishing after the session ended is not delivered":
    let r = newReceiver()
    let arg = r.taskArg()
    discard advanceSessionGeneration()
    arg.finish("stale")
    pump()
    check r.got.len == 0

  test "completion queued before the session ended is dropped on delivery":
    let r = newReceiver()
    r.taskArg().finish("queued")
    discard advanceSessionGeneration()
    pump()
    check r.got.len == 0

  test "the next session's completions are delivered":
    let r = newReceiver()
    let old = r.taskArg()
    discard advanceSessionGeneration()
    r.taskArg().finish("new")
    old.finish("old")
    pump()
    check r.got == @["new"]

suite "session-owned producers":

  test "a producer of the current session runs until the session ends":
    let generation = currentSessionGeneration()
    check not hasSessionEnded(generation)
    discard advanceSessionGeneration()
    check hasSessionEnded(generation)

  test "a producer that captured the first session's generation stops in later ones":
    discard advanceSessionGeneration()
    check hasSessionEnded(0)
