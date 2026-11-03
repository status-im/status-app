## Held resources driven by single-shot QTimers on the GUI thread.
## Dispose deletes the timers at once, so it is unsupported from inside an
## onLoad or onDrop callback (which may run from a timer's timeout).

import std/monotimes
import chronicles
from seaqt/qtimer import QTimer, create, setSingleShot, onTimeout, start, stop

import held_resource
export held_resource

type QTimerOwner = ref object
  timer: QTimer
  fire: proc()

proc qtimerHeldResourceTimer(name, purpose: string, fire: proc()): HeldResourceTimer =
  let owner = QTimerOwner(timer: QTimer.create(), fire: fire)
  owner.timer.setSingleShot(true)
  # seaqt never frees a slot closure, so the slot reaches `fire` only through
  # the owner, and disposing cuts it off
  owner.timer.onTimeout(proc() {.closure, raises: [].} =
    if owner.fire.isNil:
      return
    try:
      owner.fire()
    except Exception as e:
      error "held resource timer failed", resource = name, purpose, msg = e.msg)
  HeldResourceTimer(
    start: proc(ms: int) =
      if not owner.timer.h.isNil:
        owner.timer.start(ms.cint),
    stop: proc() =
      if not owner.timer.h.isNil:
        owner.timer.stop(),
    dispose: proc() =
      owner.fire = nil
      owner.timer = QTimer(),
  )

proc monotonicMs*(): int64 =
  getMonoTime().ticks div 1_000_000

proc newHeldResourceWithQTimers*(name: string, onLoad: proc(generation: int), onDrop: proc(),
    idleReleaseMs = DefaultIdleReleaseMs): HeldResource =
  ## `name` only labels log lines.
  var resource: HeldResource
  resource = newHeldResource(
    qtimerHeldResourceTimer(name, "release", proc() = resource.onReleaseTimeout()),
    qtimerHeldResourceTimer(name, "retry", proc() = resource.onRetryTimeout()),
    onLoad, onDrop, idleReleaseMs)
  resource

proc newHeldResourcesWithQTimers*[K](name: string, onLoad: proc(key: K, generation: int), onDrop: proc(key: K),
    idleReleaseMs = DefaultIdleReleaseMs): HeldResources[K] =
  var resources: HeldResources[K]
  resources = newHeldResources[K](
    qtimerHeldResourceTimer(name, "release", proc() = resources.onReleaseTimeout()),
    qtimerHeldResourceTimer(name, "retry", proc() = resources.onRetryTimeout()),
    monotonicMs, onLoad, onDrop, idleReleaseMs)
  resources
