import std/[unittest, monotimes, times]
from seaqt/qcoreapplication import QCoreApplication, create, processEvents

import app/core/held_resource_qtimer

discard QCoreApplication.create()

type Witness = object
  freed: ref bool

proc `=destroy`(self: Witness) =
  if not self.freed.isNil:
    self.freed[] = true

proc processEventsFor(ms: int, until: proc(): bool) =
  let deadline = getMonoTime() + initDuration(milliseconds = ms)
  while not until() and getMonoTime() < deadline:
    QCoreApplication.processEvents()

suite "held resources on QTimers":
  test "keyed registries build for string and int keys":
    let byName = newHeldResourcesWithQTimers[string]("names",
      onLoad = (proc(key: string, generation: int) = discard), onDrop = (proc(key: string) = discard))
    let byChain = newHeldResourcesWithQTimers[int]("chains",
      onLoad = (proc(key: int, generation: int) = discard), onDrop = (proc(key: int) = discard))
    byName.acquire("a")
    byChain.acquire(1)
    check byName.isActive("a")
    check byChain.isActive(1)
    byName.dispose()
    byChain.dispose()

  test "the release timer drops the resource through the event loop":
    var drops = 0
    let resource = newHeldResourceWithQTimers("fires",
      onLoad = (proc(generation: int) = discard), onDrop = (proc() = inc drops), idleReleaseMs = 1)
    resource.acquire()
    resource.release()
    processEventsFor(1_000, proc(): bool = drops > 0)
    check drops == 1
    resource.dispose()

  test "a disposed resource drops nothing when its timer was due":
    var drops = 0
    let resource = newHeldResourceWithQTimers("disposed",
      onLoad = (proc(generation: int) = discard), onDrop = (proc() = inc drops), idleReleaseMs = 1)
    resource.acquire()
    resource.release()
    resource.dispose()
    processEventsFor(50, proc(): bool = false)
    check drops == 0

  test "disposing frees what the callbacks capture":
    let freed = new bool
    proc build() =
      let witness = Witness(freed: freed)
      let resources = newHeldResourcesWithQTimers[int]("freed",
        onLoad = (proc(key: int, generation: int) = discard witness),
        onDrop = (proc(key: int) = discard witness))
      resources.acquire(1)
      resources.release(1)
      resources.dispose()
    build()
    GC_fullCollect()
    check freed[]
